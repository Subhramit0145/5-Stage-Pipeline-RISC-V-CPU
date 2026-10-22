# 5-Stage Pipelined 64-bit RISC-V (RV64I) Processor

[![Verilog HDL](https://img.shields.io/badge/Language-Verilog%202001-blue.svg)](https://en.wikipedia.org/wiki/Verilog)
[![ISA: RISC-V RV64I](https://img.shields.io/badge/ISA-RISC--V%20RV64I%20Subset-red.svg)](https://riscv.org/)
[![Architecture](https://img.shields.io/badge/Pipeline-5--Stage%20(IF--ID--EX--MEM--WB)-purple.svg)](docs/PIPELINE_ARCHITECTURE.md)
[![Hazard Unit](https://img.shields.io/badge/Hazards-Bypassing%20%7C%20Stalls%20%7C%20Flushes-orange.svg)](rtl/hazard_unit.v)
[![FPGA Target](https://img.shields.io/badge/Target-Xilinx%20Artix--7%20Arty%20A7-informational.svg)](fpga/arty_a7_riscv.xdc)
[![Simulation Coverage](https://img.shields.io/badge/Verification-100%25%20Bit--Accurate-brightgreen.svg)](sim/sim_riscv.py)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A synthesizable, cycle-accurate implementation of a **64-bit RISC-V (RV64I subset) processor core** featuring a classic **5-stage pipeline** (Instruction Fetch, Instruction Decode, Execute, Memory Access, and Write-Back).

The core includes hardware **operand forwarding (bypassing)**, **load-use stall detection with bubble insertion**, **branch resolution with 2-cycle flush penalties**, a 64-bit ALU, and an asynchronous register file with write-through bypass.

---

## Architecture Overview

```
 ┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
 │   1. FETCH   │     │  2. DECODE   │     │  3. EXECUTE  │     │  4. MEMORY   │     │ 5. WRITEBACK │
 │     (IF)     │     │     (ID)     │     │     (EX)     │     │    (MEM)     │     │     (WB)     │
 ├──────────────┤     ├──────────────┤     ├──────────────┤     ├──────────────┤     ├──────────────┤
 │ PC Mux       │     │ RegFile Read │     │ Forward MuxA │     │ Data Memory  │     │ Result Mux   │
 │ PC Register  │──►──│ Imm Generator│──►──│ 64-bit ALU   │──►──│ (64-bit Load │──►──│ (ALU vs Mem  │
 │ Instr Memory │     │ Control Unit │     │ Forward MuxB │     │  and Store)  │     │  Writeback)  │
 │ PC + 4 Adder │     │ Field Split  │     │ Branch Target│     │              │     │              │
 └──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
        │                    │                    │                    │                    │
   [IF/ID Reg]          [ID/EX Reg]          [EX/MEM Reg]         [MEM/WB Reg]         [RegFile WB]
        ▲                    ▲                    ▲                    ▲                    │
        │                    │                    │                    │                    ▼
        └────────────────────┴──────── Hazard Detection & Forwarding Unit ◄─────────────────┘
```

### Key Technical Highlights
1. **5-Stage Pipeline Throughput**: Achieves near-ideal CPI ($\text{CPI} \approx 1.29$) across realistic benchmarks with instruction pipelining.
2. **Hazard Detection & Forwarding Unit**:
   - **EX-to-EX Forwarding**: Bypasses ALU results from EX/MEM register directly into ALU inputs.
   - **MEM-to-EX Forwarding**: Bypasses results from MEM/WB register into ALU inputs.
   - **Load-Use Interlock**: Automatically detects RAW dependencies on in-flight load operations, stalling IF/ID and injecting a single-cycle bubble into EX.
   - **Branch Flush**: Resolves branch conditions in EX, flushing mispredicted/fall-through instructions in IF and ID with a 2-cycle penalty.
3. **Register File with Write-Through Bypass**:
   - 32 general-purpose 64-bit registers ($x_0 - x_{31}$).
   - $x_0$ is hardwired to 0. Writes occurring in the WB stage can be read in the ID stage during the same clock cycle without stalling.
4. **Comprehensive Immediate Generator**: Supports sign-extended immediates across I-type, S-type, B-type, U-type, and J-type instructions.

---

## Supported Instruction Set Architecture (RV64I Subset)

| Type | Instruction | Assembly Syntax | Operation Description |
|:-----|:-----------:|:----------------|:----------------------|
| **R-Type** | `add` | `add rd, rs1, rs2` | $R[rd] \leftarrow R[rs1] + R[rs2]$ |
| **R-Type** | `sub` | `sub rd, rs1, rs2` | $R[rd] \leftarrow R[rs1] - R[rs2]$ |
| **R-Type** | `and` | `and rd, rs1, rs2` | $R[rd] \leftarrow R[rs1] \ \& \ R[rs2]$ |
| **R-Type** | `or`  | `or rd, rs1, rs2`  | $R[rd] \leftarrow R[rs1] \ \| \ R[rs2]$ |
| **R-Type** | `xor` | `xor rd, rs1, rs2` | $R[rd] \leftarrow R[rs1] \ \hat{} \ R[rs2]$ |
| **R-Type** | `sll` | `sll rd, rs1, rs2` | $R[rd] \leftarrow R[rs1] \ll R[rs2][5:0]$ |
| **R-Type** | `srl` | `srl rd, rs1, rs2` | $R[rd] \leftarrow R[rs1] \gg R[rs2][5:0]$ (Logical) |
| **R-Type** | `sra` | `sra rd, rs1, rs2` | $R[rd] \leftarrow R[rs1] \gg R[rs2][5:0]$ (Arithmetic) |
| **R-Type** | `slt` | `slt rd, rs1, rs2` | $R[rd] \leftarrow (R[rs1] < R[rs2]) \ ? \ 1 : 0$ (Signed) |
| **R-Type** | `sltu`| `sltu rd, rs1, rs2`| $R[rd] \leftarrow (R[rs1] < R[rs2]) \ ? \ 1 : 0$ (Unsigned) |
| **I-Type** | `addi`| `addi rd, rs1, imm`| $R[rd] \leftarrow R[rs1] + \text{SignExt}(imm)$ |
| **I-Type** | `ld`  | `ld rd, imm(rs1)`  | $R[rd] \leftarrow \text{Mem}_{64}[R[rs1] + \text{SignExt}(imm)]$ |
| **S-Type** | `sd`  | `sd rs2, imm(rs1)` | $\text{Mem}_{64}[R[rs1] + \text{SignExt}(imm)] \leftarrow R[rs2]$ |
| **B-Type** | `beq` | `beq rs1, rs2, label` | $\text{if } (R[rs1] == R[rs2]) \ \text{PC} \leftarrow \text{PC} + \text{SignExt}(imm)$ |

---

## Hazard Handling & Pipeline Control

### 1. Data Forwarding Truth Table
```
ForwardAE / ForwardBE:
  2'b10 ──► Select ALUResultM (Forward from MEM stage: 1-cycle distance hazard)
  2'b01 ──► Select ResultW    (Forward from WB stage: 2-cycle distance hazard)
  2'b00 ──► Select RD1E/RD2E  (No hazard: use original register operand)
```

### 2. Load-Use Hazard Interlock
When an instruction in the Decode stage depends on a register loaded by an immediately preceding `ld` instruction in Execute:
```
Cycle:       1      2      3      4      5      6      7
ld  x5, 0:  IF ──► ID ──► EX ──► MEM ──► WB
add x6, x5:        IF ──► ID ──► [STALL] ──► EX ──► MEM ──► WB
                          (hold)  (bubble)
```
- **Control Response**: `stall_f = 1`, `stall_d = 1`, `flush_e = 1`.

### 3. Branch Penalty & Pipeline Flush
- Branch decisions resolve in the **EX stage**.
- When taken (`PCSrcE = 1`), fall-through instructions in IF and ID are purged:
  - `flush_d = 1` (clears IF/ID to NOP)
  - `flush_e = 1` (clears ID/EX to NOP)
  - **Penalty**: 2 clock cycles.

---

## Verification & Simulation

### 1. Standalone Cycle-Accurate Python Simulation
A pure Python cycle-accurate model is provided in `sim/sim_riscv.py` for immediate execution without EDA tool dependencies:

```bash
python sim/sim_riscv.py
```

**Simulation Output:**
```text
========================================================================
  5-STAGE PIPELINED RV64I PROCESSOR SIMULATION
========================================================================

[HALT] Target program halted gracefully at cycle 36!

------------------------------------------------------------------------
PIPELINE EXECUTION STATISTICS:
  Total Clock Cycles    : 36
  Instructions Retired  : 28
  CPI (Cycles/Instr)    : 1.29
  Load-Use Stalls       : 0
  Branch Flushes        : 3

------------------------------------------------------------------------
DATA MEMORY CONTENTS (First 5 Fibonacci doublewords):
  mem[0x00..0x07] = 0 (0x0000000000000000)
  mem[0x08..0x0F] = 1 (0x0000000000000001)
  mem[0x10..0x17] = 1 (0x0000000000000001)
  mem[0x18..0x1F] = 2 (0x0000000000000002)
  mem[0x20..0x27] = 3 (0x0000000000000003)

------------------------------------------------------------------------
REGISTER FILE STATE:
  x5(F0)    : 2 (0x0000000000000002)
  x6(F1)    : 3 (0x0000000000000003)
  x7(Fn)    : 3 (0x0000000000000003)
  x8(cnt)   : 0 (0x0000000000000000)
  x10(ptr)  : 24 (0x0000000000000018)

========================================================================
  ALL PIPELINE & DATA VERIFICATION ASSERTIONS PASSED (100% BIT-ACCURATE)
========================================================================
```

### 2. Verilog Simulation with Icarus Verilog + GTKWave
```bash
iverilog -o sim_riscv rtl/*.v sim/tb_riscv.v
vvp sim_riscv
gtkwave processor.vcd
```

### 3. Simulation in ModelSim / QuestaSim
```tcl
vlib work
vlog rtl/*.v sim/tb_riscv.v
vsim tb_riscv
add wave -r /*
run -all
```

---

## FPGA Implementation (Vivado & Artix-7)

Target Device: **Xilinx Artix-7 XC7A100T-1CSG324C** (Digilent Arty A7-100T)

```tcl
# In Vivado TCL Console:
create_project rv64i_pipe ./vivado_project -part xc7a100tcsg324-1
add_files [glob rtl/*.v]
add_files -fileset constrs_1 fpga/arty_a7_riscv.xdc
launch_runs synth_1 -jobs 4
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
```

---

## Directory Structure

```
5-Stage-Pipeline-RISC-V-CPU/
├── docs/
│   └── PIPELINE_ARCHITECTURE.md   # Comprehensive microarchitecture specification
├── fpga/
│   └── arty_a7_riscv.xdc          # Xilinx Vivado pin constraints for Arty A7-100T
├── rtl/
│   ├── alu_64.v                   # 64-bit synthesizable ALU (arithmetic, logic, shifts)
│   ├── control_unit.v             # Main decoder and ALU control logic
│   ├── datapath.v                 # Datapath interconnecting 5 pipeline stages
│   ├── dmem.v                     # 64-bit byte-addressable Data Memory
│   ├── hazard_unit.v              # Forwarding unit, load-use stall & branch flush
│   ├── imem.v                     # Instruction Memory ROM loader
│   ├── imm_gen.v                  # Sign-extending immediate generator
│   ├── pipeline_regs.v            # Synchronous IF/ID, ID/EX, EX/MEM, MEM/WB registers
│   ├── regfile.v                  # 32x64-bit Register File with write-through bypass
│   └── riscv_core.v               # Top-level core integrating datapath & control
├── sim/
│   ├── programs/
│   │   ├── fibonacci.s            # Assembly benchmark: Fibonacci generator
│   │   ├── fibonacci.hex          # Hex machine code for Fibonacci benchmark
│   │   ├── hazard_test.s          # Assembly test for RAW forwarding and load stalls
│   │   └── hazard_test.hex        # Hex machine code for hazard test
│   ├── sim_riscv.py               # Cycle-accurate Python pipeline simulator
│   └── tb_riscv.v                 # Self-checking automated Verilog testbench
├── .gitignore                     # Git ignore rules for simulation & synthesis logs
├── README.md                      # Executive documentation & portfolio showcase
└── LICENSE                        # MIT License
```

---

## References & Standards
- *David A. Patterson and John L. Hennessy*, **Computer Organization and Design: The RISC-V Reader**, Morgan Kaufmann.
- *Andrew Waterman and Krste Asanović*, **The RISC-V Instruction Set Manual, Volume I: Unprivileged Architecture**, Version 20191213.
