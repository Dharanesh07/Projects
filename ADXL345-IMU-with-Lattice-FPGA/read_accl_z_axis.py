import serial
import sys

ser = serial.Serial(sys.argv[1], 19200, timeout=1)

def twos_complement(val, bits=16):
    if val & (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def convert_bytes(data):
    #z = twos_complement(data[1] << 8 | data[0])
    z = (data[1] << 8 | data[0])
    return (z)


while True:
    if ser.in_waiting >= 2:
        data = list(ser.read(2))
        accel = convert_bytes(data)
        print(accel)
