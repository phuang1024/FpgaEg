"""
Test on MNIST with small model.

101770 params with grads!!
"""

import time

import torch
import torch.nn as nn
from torch.utils.data import DataLoader
from torch.utils.tensorboard import SummaryWriter
from torchvision import datasets, transforms as T

from serial import Serial
from tqdm import tqdm

DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")

BATCH_SIZE = 64
LR = 1e-3
EPOCHS = 3

QUANT_FAC = 25000

train_data = datasets.MNIST(root="./mnist_data", train=True, download=True, transform=T.ToTensor())
test_data = datasets.MNIST(root="./mnist_data", train=False, download=True, transform=T.ToTensor())


def make_loaders(batch_size):
    loader_args = {
        "batch_size": batch_size,
        "shuffle": True,
    }
    train_loader = DataLoader(train_data, **loader_args)
    test_loader = DataLoader(test_data, **loader_args)
    return train_loader, test_loader


class Model(nn.Module):
    def __init__(self):
        super().__init__()
        self.fc = nn.Sequential(
            nn.Flatten(),
            nn.Linear(28*28, 128),
            nn.ReLU(),
            nn.Linear(128, 10)
        )

    def forward(self, x):
        return self.fc(x)


class Trainer:
    """
    Simulates a single DDP thread.
    Wrapper around model. Samples from dataloader.
    Does forward and backward passes independently, allowing gradient all-reduce.
    """

    def __init__(self, batch_size):
        self.model = Model().to(DEVICE)
        self.train_loader, self.test_loader = make_loaders(batch_size)

        self.criterion = nn.CrossEntropyLoss()
        self.optim = torch.optim.Adam(self.model.parameters(), lr=LR)

    def forward(self, show_pbar=False):
        """
        Forward on loader entire loader.
        Yields loss.
        """
        pbar = self.train_loader
        if show_pbar:
            pbar = tqdm(self.train_loader, total=len(self.train_loader))
        for x, y in pbar:
            x = x.to(DEVICE)
            y = y.to(DEVICE)

            pred = self.model(x)
            loss = self.criterion(pred, y)

            yield loss

    def optim_step(self):
        self.optim.step()
        self.optim.zero_grad()

    @torch.no_grad()
    def eval(self):
        correct = 0
        total = 0

        for x, y in self.test_loader:
            x, y = x.to(DEVICE), y.to(DEVICE)
            logits = self.model(x)
            preds = logits.argmax(dim=1)
            correct += (preds == y).sum().item()
            total += y.size(0)

        acc = correct / total
        return acc

    def sim_quant(self):
        """
        Simulate quantization via rounding.
        """
        for param in self.model.parameters():
            if param.grad is not None:
                param.grad.data = torch.round(param.grad.data * QUANT_FAC) / QUANT_FAC


class Compressor:
    """
    Wrapper around FPGA compressor.
    """

    def __init__(self):
        self.port = Serial("/dev/ttyUSB0", 9600, timeout=3)

        self.delay = 0.01

    def send(self, data):
        """
        data: uint8 list.
        """
        length = len(data)

        send_data = [0, length % 256, length // 256]
        send_data.extend(data)

        self.port.write(bytes(send_data))
        time.sleep(self.delay)

    def recv(self, size_mult=1):
        """
        Receive uint8 list.
        """
        self.port.write(bytes([1]))
        ret_len = self.port.read(2)
        ret_len = ret_len[0] + 256 * ret_len[1]

        ret_data = self.port.read(ret_len * size_mult)
        ret_data = list(ret_data)

        time.sleep(self.delay)
        return ret_data

    def command(self, cmd):
        self.port.write(bytes([cmd]))
        ret = self.port.read(1)
        time.sleep(self.delay)
        return ret

    def compress(self, data):
        self.send(data)
        self.command(2)
        compressed = self.recv(size_mult=2)
        return compressed

    def decompress(self, data):
        self.send(data)
        self.command(3)
        decompressed = self.recv()
        return decompressed


def quantize(data):
    """
    Splits into magnitude and sign.
        Sign is 0 for positive, 1 for negative.
    data (float) --> (uint8, uint8)
    """
    sign = (data < 0).to(torch.uint8)
    mag = torch.round(torch.abs(data) * QUANT_FAC).to(torch.uint8)
    return mag, sign


def sim_allreduce(ten1, ten2, compressor):
    orig_shape = ten1.shape
    print("Orig:", orig_shape)

    mag1, sign1 = quantize(ten1)
    mag2, sign2 = quantize(ten2)

    tensors = [mag1, mag2]
    tensors = [compressor.compress(tensor.flatten().tolist()) for tensor in tensors]
    tensors = [torch.tensor(compressor.decompress(tensor)) for tensor in tensors]
    print("after comp and decmop:", [x.shape for x in tensors])

    tensors = [tensor.float() / QUANT_FAC for tensor in tensors]
    tensors = [tensor[:orig_shape.numel()].reshape(orig_shape) for tensor in tensors]
    mag1, mag2 = tensors

    mag1[sign1 == 1] *= -1
    mag2[sign2 == 1] *= -1
    avg = (mag1 + mag2) / 2
    return avg


def allreduce_blocked(ten1, ten2, compressor, block_size=1000):
    """
    Simulate all-reduce by splitting into blocks and compressing each block.
    """
    orig_shape = ten1.shape
    ten1 = ten1.flatten()
    ten2 = ten2.flatten()
    out = torch.zeros_like(ten1)

    for i in range(0, ten1.size(0), block_size):
        block1 = ten1[i : i + block_size]
        block2 = ten2[i : i + block_size]
        out_block = sim_allreduce(block1, block2, compressor)
        out[i : i + block_size] = out_block

    return out.reshape(orig_shape)


def standard():
    """
    Plain single thread training, BS=BS.
    """
    trainer = Trainer(BATCH_SIZE)
    writer = SummaryWriter("runs/standard")
    global_step = 0

    for epoch in range(EPOCHS):
        for loss in trainer.forward(show_pbar=True):
            loss.backward()

            # Extract grads
            """
            grads = []
            for param in trainer.model.parameters():
                if param.grad is not None:
                    grads.append(param.grad.clone())
            import pickle
            with open("grads.pkl", "wb") as f:
                pickle.dump(grads, f)
            raise Exception  # Done.
            """

            trainer.optim_step()

            writer.add_scalar("train/loss", loss.item(), global_step)
            global_step += 1

        acc = trainer.eval()
        writer.add_scalar("eval/acc", acc, epoch)
        print("Epoch", epoch, "eval acc", acc)


def sim_ddp():
    """
    Two trainers simultaneously.
    BS = BS / 2
    """
    trainer1 = Trainer(BATCH_SIZE // 2)
    trainer2 = Trainer(BATCH_SIZE // 2)
    writer = SummaryWriter("runs/tmp")
    global_step = 0

    compressor = Compressor()

    for epoch in range(EPOCHS):
        losses1 = trainer1.forward(show_pbar=True)
        losses2 = trainer2.forward(show_pbar=False)
        while True:
            try:
                loss1 = next(losses1)
                loss2 = next(losses2)
            except StopIteration:
                break

            loss1.backward()
            loss2.backward()

            # Simulate all-reduce by averaging grads.
            num_bytes = 0
            for param1, param2 in zip(trainer1.model.parameters(), trainer2.model.parameters()):
                if param1.grad is not None and param2.grad is not None:
                    avg_grad = allreduce_blocked(param1.grad.data, param2.grad.data, compressor)
                    param1.grad.data.copy_(avg_grad)
                    param2.grad.data.copy_(avg_grad)

            trainer1.optim_step()
            trainer2.optim_step()

            writer.add_scalar("train/loss1", loss1.item(), global_step)
            writer.add_scalar("train/loss2", loss2.item(), global_step)
            global_step += 1

        acc1 = trainer1.eval()
        acc2 = trainer2.eval()
        writer.add_scalar("eval/acc1", acc1, epoch)
        writer.add_scalar("eval/acc2", acc2, epoch)
        print("Epoch", epoch, "eval acc", acc1, acc2)


def main():
    sim_ddp()


if __name__ == "__main__":
    main()
