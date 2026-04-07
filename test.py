import time
import random

import numpy as np

from serial import Serial

ser = Serial("/dev/ttyUSB0", 9600)

DELAY = 0.01


def send_array(data):
    length = len(data)
    print("Data length:", length)

    send_data = [0, length % 256, length // 256]
    send_data.extend(data)
    send_data = bytes(send_data)

    print("Sending array.")
    ser.write(bytes(send_data))
    print("  Done sending.")
    time.sleep(DELAY)


def recv_array(len_mult=1):
    print("Sending receive command.")
    ser.write(bytes([1]))
    print("  Waiting for response.")
    ret_len = ser.read(2)
    ret_len = ret_len[0] + 256 * ret_len[1]
    print("  Received length (bytes):", ret_len, "*", len_mult)
    ret_data = ser.read(ret_len * len_mult)
    ret_data = list(ret_data)
    print("  Received data.")
    time.sleep(DELAY)
    return ret_data


def command(cmd):
    print("Sending command", cmd)
    ser.write(bytes([cmd]))
    print("  Waiting for response:")
    ret = ser.read(1)
    print("  Return:", ret)
    time.sleep(DELAY)


# Generate random data array.
length = 500
print("Generate random array length:", length)
data = np.random.randint(0, 5, size=[length], dtype=np.uint8)
print("Data:", data)


# Encode command
send_array(data)
command(2)
compressed = recv_array(2)

print("Received compress data:")
bin_str = ""
for d in compressed:
    #print(f"value={d}; bin={d:08b}")
    bin_str += f"{d:08b}"[::-1]

# Do an eg decode
zero_count = 0
i = 0
while i < len(bin_str):
    if bin_str[i] == "0":
        zero_count += 1
        i += 1
    else:
        value = bin_str[i : i + zero_count + 1]
        value = int(value, base=2) - 1
        print(value, end=" ")

        i += zero_count + 1
        zero_count = 0
print()


# Decode command
send_array(compressed)
command(3)
decomp = recv_array()

print("Received decompressed:", list(decomp))

print("Equal:", decomp[:length] == data.tolist())
print("Incorrect amount:", (decomp[:length] != data).sum())


ser.close()
