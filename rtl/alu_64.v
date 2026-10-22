// =============================================================================
// Module: alu_64
// Description: 64-bit Arithmetic Logic Unit for RV64I Architecture
// Operations Supported:
//   - ADD, SUB, AND, OR, XOR
//   - SLL, SRL, SRA (Logical and Arithmetic Shifting)
//   - SLT, SLTU (Signed and Unsigned Set-Less-Than)
// =============================================================================

module alu_64 (
    input  wire [63:0] a,
    input  wire [63:0] b,
    input  wire [3:0]  alu_ctrl,
    output reg  [63:0] result,
    output wire        zero
);

    // Shift amount uses lower 6 bits for 64-bit RV64I
    wire [5:0] shamt = b[5:0];

    always @(*) begin
        case (alu_ctrl)
            4'b0000: result = a + b;                                      // ADD / ADDI / Load / Store
            4'b1000: result = a - b;                                      // SUB / Branch Compare
            4'b0111: result = a & b;                                      // AND
            4'b0110: result = a | b;                                      // OR
            4'b0100: result = a ^ b;                                      // XOR
            4'b0001: result = a << shamt;                                 // SLL (Shift Left Logical)
            4'b0101: result = a >> shamt;                                 // SRL (Shift Right Logical)
            4'b1101: result = $signed(a) >>> shamt;                       // SRA (Shift Right Arithmetic)
            4'b0010: result = ($signed(a) < $signed(b)) ? 64'd1 : 64'd0;  // SLT (Set Less Than Signed)
            4'b0011: result = (a < b) ? 64'd1 : 64'd0;                    // SLTU (Set Less Than Unsigned)
            default: result = 64'd0;
        endcase
    end

    // Zero flag asserted when result is all zeros (used for BEQ branch evaluation)
    assign zero = (result == 64'd0);

endmodule
