import torch
import torch.nn as nn
from torch.utils.data import DataLoader
from torchvision import datasets, transforms as T

DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")

BATCH_SIZE = 64
LR = 1e-3
EPOCHS = 3

train_data = datasets.MNIST(root="./mnist_data", train=True, download=True, transform=T.ToTensor()),
test_data = datasets.MNIST(root="./mnist_data", train=False, download=True, transform=T.ToTensor()),


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

    def forward(self, index):
        """
        Forward on loader[index].
        Returns loss.
        """
        x, y = self.train_loader[index]
        x = x.to(DEVICE)
        y = y.to(DEVICE)

        pred = self.model(x)
        loss = self.criterion(pred, y)

        return loss

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


def single_thread():
    trainer = Trainer(BATCH_SIZE)

    for epoch in range(EPOCHS):
        for i in range(len(trainer.train_loader)):
            loss = trainer.forward(i)
            loss.backward()
            trainer.optim_step()
        acc = trainer.eval()
        print("Epoch", epoch, "eval acc", acc)


def main():
    single_thread()


if __name__ == "__main__":
    main()
