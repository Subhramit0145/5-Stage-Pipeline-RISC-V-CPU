// =============================================================================
// Module: datapath
// Description: Complete 5-Stage RV64I Datapath with Pipeline Registers & Forwarding
// Pipeline Stages:
//   1. IF  : PC selection, Instruction Fetch, PC+4 increment
//   2. ID  : Register file read, Immediate extension, Instruction field split
//   3. EX  : Forwarding multiplexers, 64-bit ALU, Branch target adder
//   4. MEM : Data memory access (load/store)
//   5. WB  : Result writeback multiplexer
// =============================================================================

module datapath #(
    parameter IMEM_FILE = "instructions.hex",
    parameter DMEM_INIT = ""
)(
    input  wire        clk,
    input  wire        rst,

    // Control signals from Control Unit (Decode stage)
    input  wire        reg_write_d,
    input  wire        result_src_d,
    input  wire        mem_write_d,
    input  wire        branch_d,
    input  wire        alu_src_d,
    input  wire [3:0]  alu_ctrl_d,

    // Hazard signals from Hazard Unit
    input  wire        stall_f,
    input  wire        stall_d,
    input  wire        flush_d,
    input  wire        flush_e,
    input  wire [1:0]  forward_ae,
    input  wire [1:0]  forward_be,

    // Outputs to Control Unit & Hazard Unit
    output wire [31:0] instr_d,
    output wire [4:0]  rs1_d,
    output wire [4:0]  rs2_d,
    output wire [4:0]  rs1_e,
    output wire [4:0]  rs2_e,
    output wire [4:0]  rd_e,
    output wire [4:0]  rd_m,
    output wire [4:0]  rd_w,
    output wire        reg_write_m,
    output wire        reg_write_w,
    output wire        result_src_e,
    output wire        pc_src_e,

    // Diagnostic/Debug probe outputs
    output wire [63:0] pc_f_out,
    output wire [63:0] alu_result_e_out,
    output wire [63:0] result_w_out
);

    // =========================================================================
    // 1. FETCH (IF) STAGE
    // =========================================================================
    wire [63:0] pc_next;
    wire [63:0] pc_plus4_f;
    wire [63:0] pc_target_e;
    reg  [63:0] pc_f;
    wire [31:0] instr_f;

    // Next PC selection: Branch target takes precedence over PC+4
    assign pc_next = pc_src_e ? pc_target_e : pc_plus4_f;
    assign pc_plus4_f = pc_f + 64'd4;
    assign pc_f_out = pc_f;

    // Program Counter register with synchronous enable (~stall_f)
    always @(posedge clk or posedge rst) begin
        if (rst)
            pc_f <= 64'd0;
        else if (!stall_f)
            pc_f <= pc_next;
    end

    // Instruction Memory
    imem #(
        .MEM_SIZE(4096),
        .MEM_FILE(IMEM_FILE)
    ) u_imem (
        .rst  (rst),
        .addr (pc_f),
        .instr(instr_f)
    );

    // IF/ID Pipeline Register
    wire [63:0] pc_d;
    pipe_if_id u_pipe_if_id (
        .clk    (clk),
        .rst    (rst),
        .en     (~stall_d),
        .clr    (flush_d),
        .pc_f   (pc_f),
        .instr_f(instr_f),
        .pc_d   (pc_d),
        .instr_d(instr_d)
    );

    // =========================================================================
    // 2. DECODE (ID) STAGE
    // =========================================================================
    assign rs1_d = instr_d[19:15];
    assign rs2_d = instr_d[24:20];
    wire [4:0] rd_d = instr_d[11:7];

    wire [63:0] rd1_d, rd2_d, imm_ext_d;
    wire [63:0] result_w;

    // Register File (32 x 64-bit)
    regfile u_regfile (
        .clk       (clk),
        .rst       (rst),
        .read_addr1(rs1_d),
        .read_addr2(rs2_d),
        .write_addr(rd_w),
        .write_data(result_w),
        .reg_write (reg_write_w),
        .read_data1(rd1_d),
        .read_data2(rd2_d)
    );

    // Immediate Generator
    imm_gen u_imm_gen (
        .instr  (instr_d),
        .imm_ext(imm_ext_d)
    );

    // ID/EX Pipeline Register
    wire        reg_write_e, mem_write_e, branch_e, alu_src_e;
    wire [3:0]  alu_ctrl_e;
    wire [63:0] rd1_e, rd2_e, pc_e, imm_ext_e;

    pipe_id_ex u_pipe_id_ex (
        .clk         (clk),
        .rst         (rst),
        .clr         (flush_e),
        .reg_write_d (reg_write_d),
        .result_src_d(result_src_d),
        .mem_write_d (mem_write_d),
        .branch_d    (branch_d),
        .alu_src_d   (alu_src_d),
        .alu_ctrl_d  (alu_ctrl_d),
        .rd1_d       (rd1_d),
        .rd2_d       (rd2_d),
        .pc_d        (pc_d),
        .rs1_d       (rs1_d),
        .rs2_d       (rs2_d),
        .rd_d        (rd_d),
        .imm_ext_d   (imm_ext_d),
        .reg_write_e (reg_write_e),
        .result_src_e(result_src_e),
        .mem_write_e (mem_write_e),
        .branch_e    (branch_e),
        .alu_src_e   (alu_src_e),
        .alu_ctrl_e  (alu_ctrl_e),
        .rd1_e       (rd1_e),
        .rd2_e       (rd2_e),
        .pc_e        (pc_e),
        .rs1_e       (rs1_e),
        .rs2_e       (rs2_e),
        .rd_e        (rd_e),
        .imm_ext_e   (imm_ext_e)
    );

    // =========================================================================
    // 3. EXECUTE (EX) STAGE
    // =========================================================================
    wire [63:0] alu_result_m;
    reg  [63:0] src_a_e;
    reg  [63:0] write_data_e;

    // Forwarding Mux for ALU Operand A
    always @(*) begin
        case (forward_ae)
            2'b00: src_a_e = rd1_e;
            2'b01: src_a_e = result_w;
            2'b10: src_a_e = alu_result_m;
            default: src_a_e = rd1_e;
        endcase
    end

    // Forwarding Mux for ALU Operand B / Store Write Data
    always @(*) begin
        case (forward_be)
            2'b00: write_data_e = rd2_e;
            2'b01: write_data_e = result_w;
            2'b10: write_data_e = alu_result_m;
            default: write_data_e = rd2_e;
        endcase
    end

    // ALU Source B Selection (Register or Immediate)
    wire [63:0] src_b_e = alu_src_e ? imm_ext_e : write_data_e;

    // 64-bit ALU
    wire [63:0] alu_result_e;
    wire        zero_e;

    alu_64 u_alu (
        .a       (src_a_e),
        .b       (src_b_e),
        .alu_ctrl(alu_ctrl_e),
        .result  (alu_result_e),
        .zero    (zero_e)
    );

    assign alu_result_e_out = alu_result_e;

    // Branch Target Address Calculation
    assign pc_target_e = pc_e + imm_ext_e;

    // Branch Decision (BEQ taken when zero_e == 1)
    assign pc_src_e = branch_e & zero_e;

    // EX/MEM Pipeline Register
    wire        result_src_m, mem_write_m;
    wire [63:0] write_data_m;

    pipe_ex_mem u_pipe_ex_mem (
        .clk         (clk),
        .rst         (rst),
        .reg_write_e (reg_write_e),
        .result_src_e(result_src_e),
        .mem_write_e (mem_write_e),
        .alu_result_e(alu_result_e),
        .write_data_e(write_data_e),
        .rd_e        (rd_e),
        .reg_write_m (reg_write_m),
        .result_src_m(result_src_m),
        .mem_write_m (mem_write_m),
        .alu_result_m(alu_result_m),
        .write_data_m(write_data_m),
        .rd_m        (rd_m)
    );

    // =========================================================================
    // 4. MEMORY (MEM) STAGE
    // =========================================================================
    wire [63:0] read_data_m;

    dmem #(
        .MEM_SIZE (1024),
        .INIT_FILE(DMEM_INIT)
    ) u_dmem (
        .clk       (clk),
        .rst       (rst),
        .addr      (alu_result_m),
        .write_data(write_data_m),
        .mem_write (mem_write_m),
        .read_data (read_data_m)
    );

    // MEM/WB Pipeline Register
    wire        result_src_w;
    wire [63:0] alu_result_w, read_data_w;

    pipe_mem_wb u_pipe_mem_wb (
        .clk         (clk),
        .rst         (rst),
        .reg_write_m (reg_write_m),
        .result_src_m(result_src_m),
        .alu_result_m(alu_result_m),
        .read_data_m (read_data_m),
        .rd_m        (rd_m),
        .reg_write_w (reg_write_w),
        .result_src_w(result_src_w),
        .alu_result_w(alu_result_w),
        .read_data_w (read_data_w),
        .rd_w        (rd_w)
    );

    // =========================================================================
    // 5. WRITE-BACK (WB) STAGE
    // =========================================================================
    assign result_w = result_src_w ? read_data_w : alu_result_w;
    assign result_w_out = result_w;

endmodule
