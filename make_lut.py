"""
Generate number of bits lookup table.
Index i contains N-1,
    where N is the number of bits in the binary repr of i.
"""

with open("num_bits.hex", "w") as fp:
    for i in range(255):
        value = len(bin(i)) - 2
        fp.write(str(value) + "\n")
