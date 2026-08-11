# SPI UVM Verification

A UVM (Universal Verification Methodology) testbench in SystemVerilog for verifying an **SPI (Serial Peripheral Interface)** master/slave design, built as part of a digital design and verification course.

---

## What does this project do?

The master (`spi_master`) receives a byte of data and shifts it out serially, bit by bit, over the `MOSI` line, while generating its own clock (`SCLK`) and driving the chip-select line (`CS`).

The slave (`spi_slave`) listens to those signals, reconstructs the received byte using a shift register, and signals completion through the `done` line.

The UVM testbench:
1. Randomly generates data through a `sequence`.
2. Drives it into the master through a `driver`.
3. Observes what the slave actually received through a `monitor`.
4. Compares both values in a `scoreboard` and reports a match or mismatch.

---

## Repository structure

spi-uvm-verification/
├── spi_master.sv    # Master module + its interface
├── spi_slave.sv     # Slave module + its interface
├── tb_top.sv        # Full UVM testbench (all classes + top module)
└── README.md

---

## Key design concepts

- **CPOL / CPHA**: the master transmits and the slave sample on the same clock edge (`posedge sclk`), a conscious design decision made during the course.
- **Data width**: 8 bits (`din` / `dout`).
- **Master state machine**: `idle → enable → send → comp`.
- **Slave state machine**: `start → read`, using a shift register (`{mosi, mem[7:1]}`) to reconstruct the received data.

---

## UVM testbench architecture

| Component | Role |
|---|---|
| `spi_seq_item` | The transaction: holds `din` (data to send) and `dout` (data received) |
| `spi_sequence` | Generates a configurable number of random transactions |
| `spi_driver` | Drives stimuli into the master and publishes what was sent |
| `spi_monitor` | Observes the bus and publishes what the slave received |
| `spi_scoreboard` | Receives both streams and compares them, transaction by transaction |
| `spi_agent` | Groups driver, monitor, and sequencer together |
| `spi_env` | Instantiates and connects the agent and the scoreboard |
| `spi_test` | Configures and starts the whole testbench |

Communication uses standard UVM mechanisms:
- `uvm_config_db` to pass the virtual interfaces down to each component.
- `start_item` / `finish_item` and `get_next_item` / `item_done` between the sequence and the driver.
- `uvm_analysis_port` / `uvm_analysis_imp` (publish-subscribe) to send data from the driver and monitor into the scoreboard.
- `raise_objection` / `drop_objection` to control when the simulation ends.

The number of transactions is configurable from `spi_test` by setting `sequ.num_tr` before starting the sequence.

---

## How to simulate it in Vivado

1. Create a new project in Vivado (avoid folders synced with OneDrive — it can cause file-access errors).
2. Add `spi_master.sv` and `spi_slave.sv` as **Design Sources**.
3. Add `tb_top.sv` as a **Simulation Source**.
4. Set `tb_top` as the simulation **top module** (right-click → *Set as Top*).
5. In *Simulation Settings*, increase the run time (e.g. `50us`) — Vivado's default (1000ns) isn't enough to complete all transactions.
6. Run *Run Behavioral Simulation*.

Expected console output looks like:

UVM_INFO ... [SCO] DRV (din) : 154   MON (dout) : 154
UVM_INFO ... [SCO] DATA MATCHED

---

## Project status

- [x] Master and slave RTL
- [x] Working UVM testbench (driver, monitor, scoreboard, agent, env, test)
- [x] Timing verification (immediate transmission when CS falls)
- [ ] Functional coverage
- [ ] Verification with additional SPI modes (different CPOL/CPHA)

---

