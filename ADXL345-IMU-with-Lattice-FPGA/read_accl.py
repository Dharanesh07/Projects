import serial
import sys
ser = serial.Serial(sys.argv[1], 19200, timeout=1)

def twos_complement(val, bits=16):
    if val & (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def convert_bytes(data):
    x = twos_complement(data[1] << 8 | data[0])
    y = twos_complement(data[3] << 8 | data[2])
    z = twos_complement(data[5] << 8 | data[4])
    #scale = 1/128
    scale = 1 / 256  # or 0.00390625
    #return (x * scale, y * scale, z * scale)
    return (x, y , z )

# Print header once
print(f"{'X (g)':>10} | {'Y (g)':>10} | {'Z (g)':>10}")
print("-" * 36)

while True:
    if ser.in_waiting >= 6:
        data = list(ser.read(6))
        accel = convert_bytes(data)
        print(f"{accel[0]:>10.3f} | {accel[1]:>10.3f} | {accel[2]:>10.3f}")
