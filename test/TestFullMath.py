
Mask256  = 2**256-1
MinusOne = -1
MAXpos   = Mask256 >> 1
MAXneg   = -MAXpos-1

print("MAXpos:", hex(MAXpos))
print("MAXneg:", hex(MAXneg))

# https://github.com/Uniswap/v3-core/issues/586

a = 316922101631557355182318461781248010879680643072; # ~2^157
b = 2694519998095207227803175883740; # ~2^101
d = 79232019085396855395509160680691688; # ~2^116
expected = 10777876804631170754249523106393912452806121; # ~2^143 

r = a * b // d
print("Expected issue 586", expected)

assert r == expected

pass