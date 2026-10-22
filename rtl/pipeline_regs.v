// =============================================================================
// Module: pipeline_regs
// Description: Pipeline Registers for 5-Stage RV64I Processor
// Contains:
//   - pipe_if_id  : Instruction Fetch to Decode register
//   - pipe_id_ex  : Decode to Execute register
//   - pipe_ex_mem : Execute to Memory register
//   - pipe_mem_wb : Memory to Write-Back register
// =============================================================================

// IF/ID Pipeline Register
module pipe_if_id (
    input  wire        clk,
    input  wire        rst,
    input  wire        en,       // Synchronous enable (~stall_d)
    input  wire        clr,      // Synchronous clear (flush_d)
    input  wire [63:0] pc_f,
    input  wire [31:0] instr_f,
    output reg  [63:0] pc_d,
    output reg  [31:0] instr_d
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc_d    <= 64'd0;
            instr_d <= 32'd0;
        end else if (clr) begin
            pc_d    <= 64'd0;
            instr_d <= 32'd0; // Flush to NOP
        end else if (en) begin
            pc_d    <= pc_f;
            instr_d <= instr_f;
        end
    end
endmodule

// ID/EX Pipeline Register
module pipe_id_ex (
    input  wire        clk,
    input  wire        rst,
    input  wire        clr,          // Synchronous clear (flush_e)
    // Control Inputs (ID stage)
    input  wire        reg_write_d,
    input  wire        result_src_d,
    input  wire        mem_write_d,
    input  wire        branch_d,
    input  wire        alu_src_d,
    input  wire [3:0]  alu_ctrl_d,
    // Data Inputs (ID stage)
    input  wire [63:0] rd1_d,
    input  wire [63:0] rd2_d,
    input  wire [63:0] pc_d,
    input  wire [4:0]  rs1_d,
    input  wire [4:0]  rs2_d,
    input  wire [4:0]  rd_d,
    input  wire [63:0] imm_ext_d,
    // Control Outputs (EX stage)
    output reg         reg_write_e,
    output reg         result_src_e,
    output reg         mem_write_e,
    output reg         branch_e,
    output reg         alu_src_e,
    output reg  [3:0]  alu_ctrl_e,
    // Data Outputs (EX stage)
    output reg  [63:0] rd1_e,
    output reg  [63:0] rd2_e,
    output reg  [63:0] pc_e,
    output reg  [4:0]  rs1_e,
    output reg  [4:0]  rs2_e,
    output reg  [4:0]  rd_e,
    output reg  [63:0] imm_ext_e
);
    always @(posedge clk or posedge rst) begin
        if (rst || clr) begin
            reg_write_e  <= 1'b0;
            result_src_e <= 1'b0;
            mem_write_e  <= 1'b0;
            branch_e     <= 1'b0;
            alu_src_e    <= 1'b0;
            alu_ctrl_e   <= 4'd0;
            rd1_e        <= 64'd0;
            rd2_e        <= 64'd0;
            pc_e         <= 64'd0;
            rs1_e        <= 5'd0;
            rs2_e        <= 5'd0;
            rd_e         <= 5'd0;
            imm_ext_e    <= 64'd0;
        end else begin
            reg_write_e  <= reg_write_d;
            result_src_e <= result_src_d;
            mem_write_e  <= mem_write_d;
            branch_e     <= branch_d;
            alu_src_e    <= alu_src_d;
            alu_ctrl_e   <= alu_ctrl_d;
            rd1_e        <= rd1_d;
            rd2_e        <= rd2_d;
            pc_e         <= pc_d;
            rs1_e        <= rs1_d;
            rs2_e        <= rs2_d;
            rd_e         <= rd_d;
            imm_ext_e    <= imm_ext_d;
        end
    end
endmodule

// EX/MEM Pipeline Register
module pipe_ex_mem (
    input  wire        clk,
    input  wire        rst,
    // Control Inputs (EX stage)
    input  wire        reg_write_e,
    input  wire        result_src_e,
    input  wire        mem_write_e,
    // Data Inputs (EX stage)
    input  wire [63:0] alu_result_e,
    input  wire [63:0] write_data_e,
    input  wire [4:0]  rd_e,
    // Control Outputs (MEM stage)
    output reg         reg_write_m,
    output reg         result_src_m,
    output reg         mem_write_m,
    // Data Outputs (MEM stage)
    output reg  [63:0] alu_result_m,
    output reg  [63:0] write_data_m,
    output reg  [4:0]  rd_m
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            reg_write_m  <= 1'b0;
            result_src_m <= 1'b0;
            mem_write_m  <= 1'b0;
            alu_result_m <= 64'd0;
            write_data_m <= 64'd0;
            rd_m         <= 5'd0;
        end else begin
            reg_write_m  <= reg_write_e;
            result_src_m <= result_src_e;
            mem_write_m  <= mem_write_e;
            alu_result_m <= alu_result_e;
            write_data_m <= write_data_e;
            rd_m         <= rd_e;
        end
    end
endmodule

// MEM/WB Pipeline Register
module pipe_mem_wb (
    input  wire        clk,
    input  wire        rst,
    // Control Inputs (MEM stage)
    input  wire        reg_write_m,
    input  wire        result_src_m,
    // Data Inputs (MEM stage)
    input  wire [63:0] alu_result_m,
    input  wire [63:0] read_data_m,
    input  wire [4:0]  rd_m,
    // Control Outputs (WB stage)
    output reg         reg_write_w,
    output reg         result_src_w,
    // Data Outputs (WB stage)
    output reg  [63:0] alu_result_w,
    output reg  [63:0] read_data_w,
    output reg  [4:0]  rd_w
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            reg_write_w  <= 1'b0;
            result_src_w <= 1'b0;
            alu_result_w <= 64'd0;
            read_data_w  <= 64'd0;
            rd_w         <= 5'd0;
        end else begin
            reg_write_w  <= reg_write_m;
            result_src_w <= result_src_m;
            alu_result_w <= alu_result_m;
            read_data_w  <= read_data_m;
            rd_w         <= rd_m;
        end
    end
endmodule
