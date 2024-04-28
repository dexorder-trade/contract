#!/usr/bin/python3

import struct
from fractions import Fraction

def to_float_binary(value):
    # Use 'struct.pack' to pack the value into bytes using IEEE 754 floating-point format
    # '>f' specifies big-endian single-precision float. Change to '>d' for double precision.
    packed = struct.pack('>f', value)
    # Convert the bytes to an integer and then to a binary string
    return ''.join(f'{byte:08b}' for byte in packed)

def to_float_bits(number) :
    float_bytes = struct.pack('>f', number)
    return struct.unpack('>I', float_bytes)[0], float_bytes

def fixedPoint(n, shift) :
    if shift >= 0 :
        return Fraction(n) * (1<<shift)
    else :
        return Fraction(n) / (1<<-shift)

def print_float_fix(number) :
    float_int32, float_bytes = to_float_bits(number)
    print (f"float hex: 0x{float_int32:08x} 0x{int(number*(1<<128)):x}")
    # print ("float hex:",  float_bytes.hex(), hex(int(number*(1<<128))))

print("Assuming 128.128 fixed point")
print("largest number:")
number = fixedPoint(0xffffff, 127-24) # Largest number that converts to FP and fits in 128.128
assert number < 1<<256
# print (hex(1<<255))
# print (hex(int(number)<<128))
print_float_fix(number)
print("negative largest number:")
number = fixedPoint(-0xffffff, 127-24) # Largest number
print_float_fix(number)
print("smallest number:")
number = fixedPoint(0x1, -128) # Smallest number
print_float_fix(number)
print("negative smallest number:")
number = fixedPoint(-0x1, -128)
print_float_fix(number)
print()

# number = fixedPoint(0x7fffff, 127-23)
# print_float_fix(number)
# number = fixedPoint(0xffffff, 127-23)
# print_float_fix(number)
