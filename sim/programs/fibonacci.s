# =============================================================================
# Program: fibonacci.s
# Description: Generates the first 5 terms of the Fibonacci sequence
# Storage: Consecutive 64-bit doublewords in Data Memory starting at address 0x00
# Target: RV64I 5-Stage Pipelined Processor
# =============================================================================

.globl main
main:
    # 1. Initialize Pointers and First Two Terms
    addi x10, x0, 0          # x10 = Memory base write pointer (0x00)
    addi x5,  x0, 0          # x5  = F(0) = 0
    addi x6,  x0, 1          # x6  = F(1) = 1

    # 2. Store Initial Terms in Memory
    sd   x5,  0(x10)         # mem[0x00] = 0
    sd   x6,  8(x10)         # mem[0x08] = 1

    # 3. Setup Loop Counter
    addi x8,  x0, 3          # x8  = Loop counter = 3 iterations

loop:
    # 4. Compute Next Term F(n) = F(n-2) + F(n-1)
    add  x7,  x5,  x6        # x7  = F(n)

    # 5. Store Computed Term to Memory
    sd   x7,  16(x10)        # mem[offset + 16] = F(n)

    # 6. Shift Terms Forward: F(n-2) <- F(n-1), F(n-1) <- F(n)
    add  x5,  x6,  x0        # x5  = x6
    add  x6,  x7,  x0        # x6  = x7

    # 7. Advance Pointer and Decrement Loop Counter
    addi x10, x10, 8         # Advance pointer by 8 bytes (doubleword size)
    addi x8,  x8,  -1        # Decrement counter

    # 8. Loop Control Branches
    beq  x8,  x0,  done      # If counter reaches 0, exit loop
    beq  x0,  x0,  loop      # Unconditional jump back to loop

done:
    addi x0,  x0,  0         # NOP
    # Halt instruction marker (0xFFFFFFFF)
