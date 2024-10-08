
# I2S Verilog Module

## Overview
This project implements an **I2S (Inter-IC Sound)** protocol interface in Verilog. The module simulates the APB (Advanced Peripheral Bus) interface for control and data transactions and generates necessary signals for I2S communication, including the serial clock (SCK), word select (WS), and serial data (SD). A testbench is also included for simulation purposes.

## Features
- APB protocol-based configuration and data interface.
- I2S signals: 
  - **SCK (Serial Clock)**
  - **WS (Word Select)**
  - **SD (Serial Data)**
- 32-bit FIFO for buffering audio data.
- Configurable clock divider for generating the I2S serial clock.
- Interrupt capability when FIFO is full or empty.
  
## Directory Structure
```
├── i2s.v              # Verilog source code for I2S module
├── testI2S.v          # Testbench for simulating the I2S module
├── README.md          # Project documentation
└── LICENSE            # Project license
```

## Getting Started

### Prerequisites
To run this project, you’ll need a Verilog simulator like:
- [ModelSim](https://www.intel.com/content/www/us/en/software/programmable/quartus-prime/model-sim.html)
- [VCS](https://www.synopsys.com/verification/simulation/vcs.html)
- [Verilator](https://www.veripool.org/verilator/)

### Cloning the Repository
```bash
git clone https://github.com/abdelazeem201/APB-I2S.git
cd APB-I2S
```

### Simulation
1. **Open your simulator** and add `i2s.v` and `I2S_TB.v` to the project.
2. **Compile** the Verilog files.
3. **Run the simulation** using the testbench:
    ```bash
    vlog i2s.v I2S_TB.v   # Compile the code (ModelSim example)
    vsim I2S_TB.v           # Simulate the testbench
    ```

### Files
- `i2s.v`: This is the main Verilog file implementing the I2S interface using an APB bus protocol for data and control.
- `I2S_TB.v`: Testbench for simulating the behavior of the I2S module. It writes data to the FIFO and verifies clock generation and data output.

### Testbench Walkthrough
- The testbench initializes the APB signals and writes a sequence of data values to the FIFO.
- The module generates the serial clock (`sck`), word select (`ws`), and serial data (`sd`) as per the I2S protocol.
- Simulation results should show the correct operation of the I2S signals based on the input APB transactions.

## I2S Module

### Ports
| Port       | Width    | Direction | Description                                    |
|------------|----------|-----------|------------------------------------------------|
| `pclk`     | 1-bit    | Input     | APB clock                                      |
| `presetn`  | 1-bit    | Input     | APB reset (active-low)                         |
| `psel`     | 1-bit    | Input     | APB select signal                              |
| `penable`  | 1-bit    | Input     | APB enable signal                              |
| `pwrite`   | 1-bit    | Input     | APB write enable                               |
| `paddr`    | 32-bit   | Input     | APB address                                    |
| `pwdata`   | 32-bit   | Input     | APB write data                                 |
| `prdata`   | 32-bit   | Output    | APB read data                                  |
| `irq`      | 1-bit    | Output    | Interrupt request                              |
| `sck`      | 1-bit    | Output    | I2S serial clock                               |
| `ws`       | 1-bit    | Output    | I2S word select                                |
| `sd`       | 1-bit    | Output    | I2S serial data                                |

### Configuration Registers
| Address    | Description                                  |
|------------|----------------------------------------------|
| `0x00`     | Control register                             |
| `0x04`     | Data FIFO                                    |
| `0x08`     | Interrupt register                           |

### How It Works
1. **Clock and Data Generation**: The module takes an APB clock and uses a configurable divider to generate the I2S serial clock (`sck`). It also toggles the word select (`ws`) signal to alternate between left and right audio channels.
2. **Data Buffering**: Data is written to the FIFO buffer through the APB interface and shifted out serially through the `sd` line.
3. **Interrupts**: The module raises an interrupt (`irq`) when the FIFO is full or empty, allowing the system to manage audio data accordingly.

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing
Contributions are welcome! Please fork this repository and submit a pull request for any enhancements or bug fixes.

## Contact
For any questions, feel free to reach out via GitHub issues or email at [a.abdelazeem201@gmail.com].
