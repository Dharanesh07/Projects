# ADXL345 IMU with Lattice FPGA

A hardware implementation of gesture recognition using the ADXL345 3-axis accelerometer interfaced with a Lattice FPGA. This project demonstrates real-time sensor data acquisition, processing, and gesture classification entirely in hardware logic.

<img width="500" height="500" alt="smart_sensor" src="https://github.com/user-attachments/assets/f9e62a3e-1c5e-421c-ba5d-56111ac3330d" />
<img src="images/demo.gif" alt="ADXL345 Demo" width="400" height="600"/>


## Overview

This project implements a complete pipeline for reading accelerometer data from an ADXL345 sensor, processing it through digital filters, and recognizing directional gestures. The system communicates results via UART for monitoring and debugging.

## Features

- **SPI Communication**: Custom SPI controller for ADXL345 sensor interface
- **Real-time Data Processing**: 16-bit signed acceleration data for X, Y, and Z axes
- **Digital Filtering**: Sliding window filter (4-sample average) for noise reduction
- **Gesture Recognition**: Direction mapping based on filtered acceleration values
- **UART Output**: Serial transmission of recognized gestures for monitoring
- **FIFO Buffering**: Efficient data handling between acquisition and processing stages

## System Architecture

### Block Diagram
<img width="1801" height="800" alt="smart_sensor_pbl drawio (1)" src="https://github.com/user-attachments/assets/7368a01b-9fc5-47fc-813b-2595411bd59a" />

### System Flow

1. **Initialization**: Write 0x08 to Power Control register to start measurements with full resolution and ±4g range
2. **Data Acquisition**: 6-byte data packets received from sensor via SPI
3. **Buffering**: FIFO buffer collects incoming SPI bytes before processing
4. **Data Processing**: Raw bytes converted to 16-bit signed integers for each axis
5. **Filtering**: Sliding window filter (4 readings) smooths sensor data
6. **Gesture Mapping**: Filtered values mapped to directional gestures
7. **Output**: Recognized gestures transmitted via UART

### Hardware Components

- **Lattice iCE40HX8K FPGA** (development board)
- **ADXL345** 3-axis digital accelerometer
- **SPI Interface** for sensor communication
- **UART Module** for serial output

## Technical Implementation

### Key Modules

- **SPI Controller**: Handles serial communication with ADXL345
- **FIFO Buffer**: Temporary storage for multi-byte reads
- **Data Parser**: Converts raw bytes to signed 16-bit values
- **Moving Average Filter**: 4-sample sliding window implementation
- **Gesture Classifier**: Direction detection logic
- **UART Transmitter**: Serial output for debugging and monitoring

### Configuration

- **Resolution**: Full resolution mode
- **Range**: ±4g
- **Data Format**: 16-bit signed integers
- **Filter Window**: 4 samples
- **Communication**: SPI (sensor), UART (output)


## Skills Demonstrated

- Hardware description language (Verilog/VHDL)
- Digital logic design and state machines
- SPI and UART protocol implementation
- Real-time signal processing and filtering
- FIFO buffer design and management
- Hardware-software integration
- Debugging techniques for embedded systems

## Future Enhancements

- Implement advanced gesture recognition algorithms
- Add calibration routine for sensor offset correction
- Extend to multi-gesture classification
- Optimize filter parameters for different use cases
- Add I2C interface support as alternative to SPI

## Getting Started

1. Clone this repository
2. Open the project in your Lattice FPGA development environment
3. Connect ADXL345 sensor to FPGA according to pin assignments
4. Program the FPGA with the provided bitstream
5. Connect UART interface to monitor gesture output

## Repository Structure

```
├── src/                 # HDL source files
├── constraints/         # Pin assignments and timing constraints
├── testbenches/        # Simulation files
└── docs/               # Additional documentation
```


**Note**: This project was developed as part of my smart sensors program at TUHH and demonstrates practical skills in FPGA development, sensor interfacing, and real-time data processing.
