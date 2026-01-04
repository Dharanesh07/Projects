import serial
import matplotlib.pyplot as plt
import matplotlib.animation as animation
from collections import deque

# Initialize serial
ser = serial.Serial('/dev/ttyUSB4', 9600, timeout=1)

# Parameters
WINDOW_SIZE = 100  # Number of samples in rolling window
scale = 1 / 256

# Buffer to hold data
x_data = deque([0]*WINDOW_SIZE, maxlen=WINDOW_SIZE)
y_data = deque([0]*WINDOW_SIZE, maxlen=WINDOW_SIZE)
z_data = deque([0]*WINDOW_SIZE, maxlen=WINDOW_SIZE)

def twos_complement(val, bits=16):
    if val & (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def convert_bytes(data):
    x = twos_complement(data[1] << 8 | data[0])
    y = twos_complement(data[3] << 8 | data[2])
    z = twos_complement(data[5] << 8 | data[4])
    return (x * scale, y * scale, z * scale)

# Create plot
fig, ax = plt.subplots()
line_x, = ax.plot([], [], label='X-axis')
line_y, = ax.plot([], [], label='Y-axis')
line_z, = ax.plot([], [], label='Z-axis')
ax.set_xlim(0, WINDOW_SIZE)
ax.relim()
ax.autoscale_view()
ax.set_title("Real-Time Accelerometer Data")
ax.set_xlabel("Samples")
ax.set_ylabel("Acceleration (g)")
ax.legend()
ax.grid(True)

# Update function for animation
def update(frame):
    if ser.in_waiting >= 6:
        data = list(ser.read(6))
        accel = convert_bytes(data)
        x_data.append(accel[0])
        y_data.append(accel[1])
        z_data.append(accel[2])
        
        line_x.set_data(range(len(x_data)), x_data)
        line_y.set_data(range(len(y_data)), y_data)
        line_z.set_data(range(len(z_data)), z_data)

    return line_x, line_y, line_z

ani = animation.FuncAnimation(fig, update, interval=50, blit=True)
plt.tight_layout()
plt.show()
