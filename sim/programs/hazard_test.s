# =============================================================================
# Program: hazard_test.s
# Description: Targeted verification of RAW Forwarding, Load-Use Stall, and Branch Flush
# =============================================================================

.globl main
main:
    # 1. Test EX-to-EX Forwarding
    addi x1, x0, 10          # x1 = 10 (produced in cycle 3 EX)
    add  x2, x1, x1          # x2 = 10 + 10 = 20 (immediately consumed in cycle 4 EX -> ForwardAE = 2'b10)

    # 2. Test MEM-to-EX Forwarding
    addi x3, x0, 5           # x3 = 5
    addi x0, x0, 0           # NOP
    add  x4, x3, x3          # x4 = 5 + 5 = 10 (ForwardAE = 2'b01)

    # 3. Test Load-Use Data Hazard (Requires 1-cycle bubble stall)
    sd   x2, 0(x0)           # mem[0] = 20
    ld   x5, 0(x0)           # x5 = 20 (Load in progress)
    add  x6, x5, x1          # x6 = 20 + 10 = 30 (Dependent immediately on load -> STALL!)

    # 4. Test Branch Flush (2-cycle penalty on taken branch)
    beq  x1, x1, skip        # Branch taken! (Target: skip)
    addi x7, x0, 99          # FLUSHED (Must remain 0)
    addi x8, x0, 99          # FLUSHED (Must remain 0)
    addi x0, x0, 0           # NOP

skip:
    addi x9, x0, 42          # x9 = 42 (Executed after branch flush)
    # Halt instruction marker (0xFFFFFFFF)
