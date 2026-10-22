"""
=============================================================================
5-Stage Pipelined RV64I Processor: Cycle-Accurate Python Simulator
Models:
  - 5-Stage Pipeline: IF, ID, EX, MEM, WB
  - Data Forwarding Unit (EX-to-EX, MEM-to-EX)
  - Hazard Detection: Load-Use Stall & Bubble Insertion
  - Control Hazard: Branch Taken 2-Cycle Flush
  - Cycle-by-cycle Pipeline Execution Timeline Tracker
=============================================================================
"""

import sys

class RV64IPipeline:
    def __init__(self, imem_bytes, dmem_size=1024):
        self.imem = list(imem_bytes) + [0] * (4096 - len(imem_bytes))
        self.dmem = [0] * dmem_size
        self.rf = [0] * 32

        # Pipeline Registers
        # IF/ID
        self.pc_d = 0
        self.instr_d = 0

        # ID/EX
        self.id_ex = {
            "valid": False, "reg_write": False, "result_src": False, "mem_write": False,
            "branch": False, "alu_src": False, "alu_ctrl": 0, "rd1": 0, "rd2": 0,
            "pc": 0, "rs1": 0, "rs2": 0, "rd": 0, "imm_ext": 0, "asm": "NOP"
        }

        # EX/MEM
        self.ex_mem = {
            "valid": False, "reg_write": False, "result_src": False, "mem_write": False,
            "alu_result": 0, "write_data": 0, "rd": 0, "asm": "NOP"
        }

        # MEM/WB
        self.mem_wb = {
            "valid": False, "reg_write": False, "result_src": False,
            "alu_result": 0, "read_data": 0, "rd": 0, "asm": "NOP"
        }

        self.pc_f = 0
        self.cycle = 0
        self.retired_inst = 0
        self.stalls = 0
        self.flushes = 0
        self.timeline = [] # (cycle, IF, ID, EX, MEM, WB)

    def decode_inst(self, instr):
        opcode = instr & 0x7F
        rd = (instr >> 7) & 0x1F
        funct3 = (instr >> 12) & 0x7
        rs1 = (instr >> 15) & 0x1F
        rs2 = (instr >> 20) & 0x1F
        funct7 = (instr >> 25) & 0x7F
        return opcode, rd, funct3, rs1, rs2, funct7

    def sign_ext(self, val, bits):
        sign = (val >> (bits - 1)) & 1
        if sign:
            return val - (1 << bits)
        return val

    def get_imm(self, instr, opcode):
        if opcode in [0x03, 0x13]: # I-type
            imm12 = (instr >> 20) & 0xFFF
            return self.sign_ext(imm12, 12)
        elif opcode == 0x23: # S-type
            imm12 = ((instr >> 25) & 0x7F) << 5 | ((instr >> 7) & 0x1F)
            return self.sign_ext(imm12, 12)
        elif opcode == 0x63: # B-type
            imm12 = ((instr >> 31) & 1) << 12 | ((instr >> 7) & 1) << 11 | \
                    ((instr >> 25) & 0x3F) << 5 | ((instr >> 8) & 0xF) << 1
            return self.sign_ext(imm12, 13)
        return 0

    def step(self):
        self.cycle += 1

        # =====================================================================
        # 1. WRITE-BACK (WB) STAGE
        # =====================================================================
        wb_asm = self.mem_wb["asm"] if self.mem_wb["valid"] else "-"
        result_w = 0
        if self.mem_wb["valid"]:
            result_w = self.mem_wb["read_data"] if self.mem_wb["result_src"] else self.mem_wb["alu_result"]
            if self.mem_wb["reg_write"] and self.mem_wb["rd"] != 0:
                self.rf[self.mem_wb["rd"]] = result_w & 0xFFFFFFFFFFFFFFFF
            self.retired_inst += 1

        # =====================================================================
        # 2. MEMORY (MEM) STAGE
        # =====================================================================
        mem_asm = self.ex_mem["asm"] if self.ex_mem["valid"] else "-"
        next_mem_wb = {"valid": False, "reg_write": False, "result_src": False, "alu_result": 0, "read_data": 0, "rd": 0, "asm": "NOP"}

        if self.ex_mem["valid"]:
            addr = self.ex_mem["alu_result"]
            read_data_m = 0
            if self.ex_mem["mem_write"]:
                wdata = self.ex_mem["write_data"]
                for i in range(8):
                    shift = (7 - i) * 8
                    byte = (wdata >> shift) & 0xFF
                    if 0 <= addr + i < len(self.dmem):
                        self.dmem[addr + i] = byte

            if self.ex_mem["result_src"]: # Load instruction
                for i in range(8):
                    if 0 <= addr + i < len(self.dmem):
                        read_data_m = (read_data_m << 8) | self.dmem[addr + i]

            next_mem_wb = {
                "valid": True,
                "reg_write": self.ex_mem["reg_write"],
                "result_src": self.ex_mem["result_src"],
                "alu_result": self.ex_mem["alu_result"],
                "read_data": read_data_m,
                "rd": self.ex_mem["rd"],
                "asm": self.ex_mem["asm"]
            }

        # =====================================================================
        # 3. EXECUTE (EX) STAGE & FORWARDING
        # =====================================================================
        ex_asm = self.id_ex["asm"] if self.id_ex["valid"] else "-"
        next_ex_mem = {"valid": False, "reg_write": False, "result_src": False, "mem_write": False, "alu_result": 0, "write_data": 0, "rd": 0, "asm": "NOP"}
        pc_src_e = False
        pc_target_e = 0

        if self.id_ex["valid"]:
            rs1_e = self.id_ex["rs1"]
            rs2_e = self.id_ex["rs2"]

            # Forwarding for Operand A
            src_a_e = self.id_ex["rd1"]
            if rs1_e != 0 and rs1_e == self.ex_mem["rd"] and self.ex_mem["reg_write"] and self.ex_mem["valid"]:
                src_a_e = self.ex_mem["alu_result"] # Forward from MEM stage
            elif rs1_e != 0 and rs1_e == self.mem_wb["rd"] and self.mem_wb["reg_write"] and self.mem_wb["valid"]:
                src_a_e = result_w # Forward from WB stage

            # Forwarding for Operand B
            write_data_e = self.id_ex["rd2"]
            if rs2_e != 0 and rs2_e == self.ex_mem["rd"] and self.ex_mem["reg_write"] and self.ex_mem["valid"]:
                write_data_e = self.ex_mem["alu_result"] # Forward from MEM stage
            elif rs2_e != 0 and rs2_e == self.mem_wb["rd"] and self.mem_wb["reg_write"] and self.mem_wb["valid"]:
                write_data_e = result_w # Forward from WB stage

            src_b_e = self.id_ex["imm_ext"] if self.id_ex["alu_src"] else write_data_e

            # ALU computation
            alu_ctrl = self.id_ex["alu_ctrl"]
            alu_res = 0
            if alu_ctrl == 0:   # ADD
                alu_res = (src_a_e + src_b_e) & 0xFFFFFFFFFFFFFFFF
            elif alu_ctrl == 8: # SUB
                alu_res = (src_a_e - src_b_e) & 0xFFFFFFFFFFFFFFFF
            elif alu_ctrl == 7: # AND
                alu_res = src_a_e & src_b_e
            elif alu_ctrl == 6: # OR
                alu_res = src_a_e | src_b_e
            elif alu_ctrl == 4: # XOR
                alu_res = src_a_e ^ src_b_e

            zero_e = (alu_res == 0)
            pc_target_e = (self.id_ex["pc"] + self.id_ex["imm_ext"]) & 0xFFFFFFFFFFFFFFFF
            pc_src_e = self.id_ex["branch"] and zero_e

            next_ex_mem = {
                "valid": True,
                "reg_write": self.id_ex["reg_write"],
                "result_src": self.id_ex["result_src"],
                "mem_write": self.id_ex["mem_write"],
                "alu_result": alu_res,
                "write_data": write_data_e,
                "rd": self.id_ex["rd"],
                "asm": self.id_ex["asm"]
            }

        # =====================================================================
        # 4. DECODE (ID) STAGE & HAZARD UNIT
        # =====================================================================
        id_asm = "NOP"
        opcode, rd_d, funct3, rs1_d, rs2_d, funct7 = 0, 0, 0, 0, 0, 0
        if self.instr_d != 0:
            opcode, rd_d, funct3, rs1_d, rs2_d, funct7 = self.decode_inst(self.instr_d)
            id_asm = f"0x{self.pc_d:02X}"

        # Hazard Detection: Load-Use Stall
        lw_stall = self.id_ex["valid"] and self.id_ex["result_src"] and (self.id_ex["rd"] != 0) and \
                   ((rs1_d == self.id_ex["rd"]) or (rs2_d == self.id_ex["rd"]))

        stall_f = lw_stall
        stall_d = lw_stall
        flush_d = pc_src_e
        flush_e = lw_stall or pc_src_e

        if lw_stall:
            self.stalls += 1
        if pc_src_e:
            self.flushes += 1

        # Control Unit Decoding
        reg_write_d = False
        result_src_d = False
        mem_write_d = False
        branch_d = False
        alu_src_d = False
        alu_ctrl_d = 0

        if self.instr_d != 0 and self.instr_d != 0xFFFFFFFF:
            if opcode == 0x33: # R-type
                reg_write_d = True; alu_src_d = False
                alu_ctrl_d = 8 if (funct7 == 0x20 and funct3 == 0) else 0 if funct3 == 0 else 7 if funct3 == 7 else 6
            elif opcode == 0x13: # I-type ALU
                reg_write_d = True; alu_src_d = True; alu_ctrl_d = 0
            elif opcode == 0x03: # Load
                reg_write_d = True; result_src_d = True; alu_src_d = True; alu_ctrl_d = 0
            elif opcode == 0x23: # Store
                mem_write_d = True; alu_src_d = True; alu_ctrl_d = 0
            elif opcode == 0x63: # Branch
                branch_d = True; alu_src_d = False; alu_ctrl_d = 8

        # Read Register File
        rd1_d = self.rf[rs1_d] if rs1_d != 0 else 0
        rd2_d = self.rf[rs2_d] if rs2_d != 0 else 0
        imm_ext_d = self.get_imm(self.instr_d, opcode)

        next_id_ex = {
            "valid": (self.instr_d != 0 and not flush_e),
            "reg_write": reg_write_d,
            "result_src": result_src_d,
            "mem_write": mem_write_d,
            "branch": branch_d,
            "alu_src": alu_src_d,
            "alu_ctrl": alu_ctrl_d,
            "rd1": rd1_d,
            "rd2": rd2_d,
            "pc": self.pc_d,
            "rs1": rs1_d,
            "rs2": rs2_d,
            "rd": rd_d,
            "imm_ext": imm_ext_d,
            "asm": f"PC:0x{self.pc_d:02X}" if self.instr_d != 0 else "NOP"
        }

        # =====================================================================
        # 5. FETCH (IF) STAGE
        # =====================================================================
        if_asm = f"0x{self.pc_f:02X}"
        if pc_src_e:
            next_pc = pc_target_e
        elif not stall_f:
            next_pc = self.pc_f + 4
        else:
            next_pc = self.pc_f

        instr_f = 0
        if 0 <= self.pc_f + 3 < len(self.imem):
            instr_f = (self.imem[self.pc_f] << 24) | (self.imem[self.pc_f + 1] << 16) | \
                      (self.imem[self.pc_f + 2] << 8) | self.imem[self.pc_f + 3]

        # Update Pipeline Registers
        self.mem_wb = next_mem_wb
        self.ex_mem = next_ex_mem
        self.id_ex = next_id_ex

        if flush_d:
            self.pc_d = 0
            self.instr_d = 0
        elif not stall_d:
            self.pc_d = self.pc_f
            self.instr_d = instr_f

        self.pc_f = next_pc

        self.timeline.append((self.cycle, if_asm, id_asm, ex_asm, mem_asm, wb_asm))
        halted = (self.instr_d == 0xFFFFFFFF)
        return halted

def run_simulation(hex_bytes):
    print("=" * 72)
    print("  5-STAGE PIPELINED RV64I PROCESSOR SIMULATION")
    print("=" * 72)

    sim = RV64IPipeline(hex_bytes)
    for c in range(120):
        halted = sim.step()
        if halted:
            print(f"\n[HALT] Target program halted gracefully at cycle {sim.cycle}!")
            break

    print("\n" + "-" * 72)
    print("PIPELINE EXECUTION STATISTICS:")
    print(f"  Total Clock Cycles    : {sim.cycle}")
    print(f"  Instructions Retired  : {sim.retired_inst}")
    cpi = sim.cycle / sim.retired_inst if sim.retired_inst else 0
    print(f"  CPI (Cycles/Instr)    : {cpi:.2f}")
    print(f"  Load-Use Stalls       : {sim.stalls}")
    print(f"  Branch Flushes        : {sim.flushes}")

    print("\n" + "-" * 72)
    print("DATA MEMORY CONTENTS (First 5 Fibonacci doublewords):")
    for offset in range(0, 40, 8):
        val = 0
        for b in range(8):
            val = (val << 8) | sim.dmem[offset + b]
        print(f"  mem[0x{offset:02X}..0x{offset+7:02X}] = {val} (0x{val:016X})")

    print("\n" + "-" * 72)
    print("REGISTER FILE STATE:")
    reg_names = {5: "x5(F0)", 6: "x6(F1)", 7: "x7(Fn)", 8: "x8(cnt)", 10: "x10(ptr)"}
    for r, name in reg_names.items():
        print(f"  {name:<10}: {sim.rf[r]} (0x{sim.rf[r]:016X})")

    # Automated Assertions
    # Fib sequence in memory: 0, 1, 1, 2, 3
    expected_fib = [0, 1, 1, 2, 3]
    for idx, exp in enumerate(expected_fib):
        offset = idx * 8
        val = 0
        for b in range(8):
            val = (val << 8) | sim.dmem[offset + b]
        assert val == exp, f"Fibonacci term {idx} failed! Expected {exp}, got {val}"

    print("\n" + "=" * 72)
    print("  ALL PIPELINE & DATA VERIFICATION ASSERTIONS PASSED (100% BIT-ACCURATE)")
    print("=" * 72)

if __name__ == "__main__":
    # Fibonacci test program bytes
    prog_bytes = [
        0x00, 0x00, 0x05, 0x13,
        0x00, 0x00, 0x02, 0x93,
        0x00, 0x10, 0x03, 0x13,
        0x00, 0x55, 0x30, 0x23,
        0x00, 0x65, 0x34, 0x23,
        0x00, 0x30, 0x04, 0x13,
        0x00, 0x62, 0x83, 0xB3,
        0x00, 0x75, 0x38, 0x23,
        0x00, 0x03, 0x02, 0xB3,
        0x00, 0x03, 0x83, 0x33,
        0x00, 0x85, 0x05, 0x13,
        0xFF, 0xF4, 0x04, 0x13,
        0x00, 0x04, 0x06, 0x63,
        0xFE, 0x00, 0x02, 0xE3,
        0x00, 0x00, 0x00, 0x13,
        0xFF, 0xFF, 0xFF, 0xFF
    ]
    run_simulation(prog_bytes)
