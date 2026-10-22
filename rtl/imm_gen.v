// =============================================================================
// Module: imm_gen
// Description: Immediate Generator for 64-bit RISC-V (RV64I)
// Decodes and sign-extends immediates for I, S, B, U, and J instruction formats
// =============================================================================

module imm_gen (
    input  wire [31:0] instr,
    output reg  [63:0] imm_ext
);

    wire [6:0] opcode = instr[6:0];

    always @(*) begin
        case (opcode)
            // I-type: Load instructions (ld), Arithmetic immediates (addi, andi, ori)
            7'b0000011, 7'b0010011: begin
                imm_ext = {{52{instr[31]}}, instr[31:20]};
            end

            // S-type: Store instructions (sd)
            7'b0100011: begin
                imm_ext = {{52{instr[31]}}, instr[31:25], instr[11:7]};
            end

            // B-type: Conditional branch instructions (beq, bne, blt, bge)
            7'b1100011: begin
                imm_ext = {{52{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
            end

            // U-type: LUI, AUIPC
            7'b0110111, 7'b0010111: begin
                imm_ext = {{32{instr[31]}}, instr[31:12], 12'b0};
            end

            // J-type: JAL
            7'b1101111: begin
                imm_ext = {{44{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
            end

            default: imm_ext = 64'd0;
        endcase
    end

endmodule
