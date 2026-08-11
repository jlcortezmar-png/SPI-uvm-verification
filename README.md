# SPI UVM Verification

A design and verification project for an **SPI (Serial Peripheral Interface)** protocol, written in SystemVerilog as part of a digital design and verification course.

It includes:
- The RTL design of an SPI master and slave.
- A "classic" class-based testbench (no UVM) to verify the master.
- A complete **UVM** testbench that verifies the master + slave system end to end.

---

## What does this project do?

The master (`spi_master`) receives a byte of data and shifts it out serially, bit by bit, over the `MOSI` line, while generating its own clock (`SCLK`) and driving the chip-select line (`CS`).

The slave (`spi_slave`) listens to those signals, reconstructs the received byte using a shift register, and signals completion through the `done` line.

The testbench takes care of:
1. Generating random data.
2. Sending it through the master.
3. Observing what the slave actually received.
4. Comparing both values and reporting whether they match.

---

## Repository structure

```
spi-uvm-verification/
│
├── rtl/
│   ├── spi_master.sv      # Master module + its interface
│   └── spi_slave.sv       # Slave module + its interface
│
├── tb_classic/
│   └── tb_top.sv          # Classic (non-UVM) class-based testbench
│
├── tb_uvm/
│   └── tb_top.sv          # Full UVM testbench
│
└── README.md
```

---

## Key design concepts

- **CPOL / CPHA**: the master transmits and the slave samples on the same clock edge (`posedge sclk`), a conscious design decision made during the course.
- **Data width**: 8 bits (`din` / `dout`), instead of the 12 bits used in the course's original example.
- **Master state machine**: `idle → enable → send → comp`.
- **Slave state machine**: `start → read`, using a shift register (`{mosi, mem[7:1]}`) to reconstruct the received data.

---

## Classic testbench (no UVM)

Located in `tb_classic/`. Uses the typical classes found in a SystemVerilog testbench:

| Class | Purpose |
|---|---|
| `transaction` | Represents a stimulus (data to send) |
| `generator` | Generates random transactions |
| `driver` | Applies stimuli to the DUT |
| `monitor` | Observes the bus signals and reconstructs the data |
| `scoreboard` | Compares what was sent against what was received |
| `environment` | Connects all of the above pieces together |

Communication between classes is done with `mailbox` and `event`.

---

## UVM testbench

Located in `tb_uvm/`. Follows the standard UVM methodology:

| Component | Classic testbench equivalent |
|---|---|
| `spi_seq_item` | `transaction` |
| `spi_sequence` | `generator` |
| `spi_driver` | `driver` |
| `spi_monitor` | `monitor` |
| `spi_scoreboard` | `scoreboard` |
| `spi_agent` | Groups driver + monitor + sequencer |
| `spi_env` | `environment` |
| `spi_test` | Starts up the whole testbench |

The number of transactions to generate is controlled from `spi_test`, by setting `sequ.num_tr`.

---

## How to simulate it in Vivado

1. Create a new project in Vivado (avoid folders synced with OneDrive, it can cause errors).
2. Add `rtl/spi_master.sv` and `rtl/spi_slave.sv` as **Design Sources**.
3. Add the testbench you want to run (`tb_classic/tb_top.sv` or `tb_uvm/tb_top.sv`) as a **Simulation Source**.
4. Set `tb_top` as the simulation **top module** (right-click → *Set as Top*).
5. In *Simulation Settings*, increase the run time (e.g. `50us`) — Vivado's default (1000ns) isn't enough to complete the transactions.
6. Run *Run Behavioral Simulation*.

You should see console messages like:

```
[SCO] DRV (din) : 154   MON (dout) : 154
[SCO] DATA MATCHED
```

---

## Project status

- [x] Master and slave RTL
- [x] Working classic testbench
- [x] Working UVM testbench
- [x] Timing verification (immediate transmission when CS falls)
- [ ] Functional coverage
- [ ] Verification with additional SPI modes (different CPOL/CPHA)

---

## Notes

This project was built in a guided, step-by-step manner as part of a SystemVerilog and UVM learning process — prioritizing understanding the *why* behind each design decision over copying code.
