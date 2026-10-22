// =============================================================================
// Module: control_unit
// Description: Main Decoder & ALU Control for RV64I Architecture
// Decodes instruction opcode, funct3, and funct7 fields into pipeline control signals
// =============================================================================

module control_unit (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,
    output reg        reg_write,
    output reg        result_src,   // 0: ALU result, 1: Memory read data
    output reg        mem_write,
    output reg        branch,
    output reg        alu_src,      // 0: Register (rs2), 1: Immediate
    output reg  [3:0] alu_ctrl
);

    reg [1:0] alu_op;

    // Main Control Decoder
    always @(*) begin
        case (opcode)
            // R-type (add, sub, and, or, xor, sll, srl, sra, slt, sltu)
            7'b0110011: begin
                reg_write  = 1'b1;
                result_src = 1'b0;
                mem_write  = 1'b0;
                branch     = 1'b0;
                alu_src    = 1'b0;
                alu_op     = 2'b10;
            end

            // I-type ALU (addi, andi, ori, xori, slli, srli, srai, slti, sltiu)
            7'b0010011: begin
                reg_write  = 1'b1;
                result_src = 1'b0;
                mem_write  = 1'b0;
                branch     = 1'b0;
                alu_src    = 1'b1;
                alu_op     = 2'b10;
            end

            // I-type Load (ld - Load Doubleword)
            7'b0000011: begin
                reg_write  = 1'b1;
                result_src = 1'b1;
                mem_write  = 1'b0;
                branch     = 1'b0;
                alu_src    = 1'b1;
                alu_op     = 2'b00; // Address calculation via addition
            end

            // S-type Store (sd - Store Doubleword)
            7'b0100011: begin
                reg_write  = 1'b0;
                result_src = 1'b0;
                mem_write  = 1'b1;
                branch     = 1'b0;
                alu_src    = 1'b1;
                alu_op     = 2'b00; // Address calculation via addition
            end

            // B-type Branch (beq, bne)
            7'b1100011: begin
                reg_write  = 1'b0;
                result_src = 1'b0;
                mem_write  = 1'b0;
                branch     = 1'b1;
                alu_src    = 1'b0;
                alu_op     = 2'b01; // Comparison via subtraction
            end

            default: begin
                reg_write  = 1'b0;
                result_src = 1'b0;
                mem_write  = 1'b0;
                branch     = 1'b0;
                alu_src    = 1'b0;
                alu_op     = 2'b00;
            end
        endcase
    end

    // ALU Decoder
    always @(*) begin
        case (alu_op)
            2'b00: alu_ctrl = 4'b0000; // Addition for Memory Address Calculation
            2'b01: alu_ctrl = 4'b1000; // Subtraction for Branch Comparison
            2'b10: begin
                case (funct3)
                    3'b000: begin
                        // Distinguish SUB from ADD (SUB has funct7[5] == 1 in R-type)
                        if ((opcode == 7'b0110011) && funct7[5])
                            alu_ctrl = 4'b1000; // SUB
                        else
                            alu_ctrl = 4'b0000; // ADD / ADDI
                    end
                    3'b001: alu_ctrl = 4'b0001; // SLL / SLLI
                    3'b010: alu_ctrl = 4'b0010; // SLT / SLTI
                    3'b011: alu_ctrl = 4'b0011; // SLTU / SLTIU
                    3'b100: alu_ctrl = 4'b0100; // XOR / XORI
                    3'b101: begin
                        if (funct7[5])
                            alu_ctrl = 4'b1101; // SRA / SRAI
                        else
                            alu_ctrl = 4'b0101; // SRL / SRLI
                    end
                    3'b110: alu_ctrl = 4'b0110; // OR / ORI
                    3'b111: alu_ctrl = 4'b0111; // AND / ANDI
                    default: alu_ctrl = 4'b0000;
                endcase
            end
            default: alu_ctrl = 4'b0000;
        endcase
    end

endmodule
