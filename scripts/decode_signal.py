import numpy as np

signal = np.loadtxt("signal.dat")

data_file = open("decoded.prg", "wb")

print("signal array shape: ", signal.shape)

binary_signal = signal > 128

i = 0
while i < len(binary_signal):
    value = binary_signal[i]
    if not value:
        print("start bit detected at i = ", i)
        i += 1
        byte = 0
        bit_counter = 0
        while i < len(binary_signal) and bit_counter < 8:
            byte = byte >> 1
            if binary_signal[i]:
                byte = byte | 0x80
            i += 1
            bit_counter += 1
        print("byte = ", byte)
        data_file.write(bytearray([byte]))
    else:
        i += 1

