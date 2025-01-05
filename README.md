# I2C Main Interface for DS1302

This repository contains the Verilog implementation of an I2C main interface designed for communication with the DS1302 RTC chip. The project includes the RTL implementation and a comprehensive testbench to verify its functionality.

---

## Features

- **Write Operation**: Transmit address and data from the I2C master to the DS1302.
- **Read Operation**: Receive data from the DS1302 using the I2C protocol.
- **State Machine**: Implements a Finite State Machine (FSM) to control the I2C communication flow.
- **Tri-state SDA Line Control**: Dynamically controls the SDA line direction using an IOBUF.
- **Configurable Timing**: Handles clock edges and ensures proper data alignment.
- **Testbench**: Includes a detailed testbench for functional verification of both write and read operations.

---

## Files in the Repository

### 1. **i2c_main.sv**
The main module implementing the I2C master interface. Key features:
- **FSM States**:
  - `IDLE`: Wait for a write or read enable signal.
  - `RW_selec`: Determine if the operation is read or write.
  - `TX_ADD`: Transmit the address to the slave.
  - `RC_selec`: Set the R/W bit.
  - `LAST_BIT`: Handle the last bit before data operations.
  - `TX_DATA`: Transmit data during a write operation.
  - `RX_DATA`: Receive data during a read operation.
  - `DONE`: Return to the `IDLE` state after completing the transaction.
- **Tri-state SDA Line**: Uses an IOBUF to handle the SDA line for both input and output operations.

### 2. **tb_i2c_main.sv**
The testbench for verifying the `i2c_main` module. It includes:
- **Randomized Tests**: Generates random addresses and data for functional validation.
- **Write Tests**: Verifies the correct transmission of address and data.
- **Read Tests**: Ensures correct reception of data from the slave.
- **Waveform Analysis**: Monitors the state transitions, clock signals, and SDA behavior.
- **Assertions**: Checks for protocol compliance and data correctness.

---

## Console Output (Sample)

Below is a sample output from the simulation showing a write and read operation:

```
Write to Slave: Address = 1c = 11100, Data = 3d = 00111101 

START CHECKING
Captured Bit 1: SDA = 0
Captured Bit 2: SDA = 1
...
Final shift_reg_tx = 713d = 0111000100111101
1st 8 bits = 71 = 01110001
R/W = 0, addr = 1c = 11100, R/C = 0, Last bit = 1 

Data = 3d = 00111101
END
Write Test 1 passed! Addr = 1c, Data = 3d
...
Reading master (expected): Address = 01 = 00001, Data = 44 = 01000100 

START CHECKING RX
Captured Bit 1: SDA = 1
...
Data transmitted: 44 = 01000100
START CHECKING RECEIVED DATA
Received Data = 44 = 01000100
RECEIVED DATA CHECK PASSED!
END
```

---


## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.


