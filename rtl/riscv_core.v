// =============================================================================
// Module: riscv_core
// Description: Top-Level 5-Stage Pipelined 64-bit RISC-V (RV64I) Processor Core
// Integrates:
//   - Datapath with 5 Pipeline Stages (IF, ID, EX, MEM, WB)
//   - Main Control Unit & ALU Decoder
//   - Hazard Detection & Operand Forwarding Unit
// =============================================================================

module riscv_core #(
    parameter IMEM_FILE = "instructions.hex",
    parameter DMEM_INIT = ""
)(
    input  wire        clk,
    input  wire        rst,

    // Debug / Monitoring Probes
    output wire [63:0] debug_pc,
    output wire [31:0] debug_instr,
    output wire [63:0] debug_alu_result,
    output wire [63:0] debug_result_w,
    output wire        debug_stall,
    output wire        debug_flush
);

    // Wires between Control Unit and Datapath
    wire        reg_write_d;
    wire        result_src_d;
    wire        mem_write_d;
    wire        branch_d;
    wire        alu_src_d;
    wire [3:0]  alu_ctrl_d;

    // Wires between Hazard Unit and Datapath
    wire        stall_f;
    wire        stall_d;
    wire        flush_d;
    wire        flush_e;
    wire [1:0]  forward_ae;
    wire [1:0]  forward_be;

    // Datapath Status Outputs
    wire [31:0] instr_d;
    wire [4:0]  rs1_d, rs2_d;
    wire [4:0]  rs1_e, rs2_e;
    wire [4:0]  rd_e, rd_m, rd_w;
    wire        reg_write_m, reg_write_w;
    wire        result_src_e;
    wire        pc_src_e;

    // Debug assignments
    assign debug_instr = instr_d;
    assign debug_stall = stall_f;
    assign debug_flush = flush_d;

    // -------------------------------------------------------------------------
    // 1. Control Unit
    // -------------------------------------------------------------------------
    control_unit u_control (
        .opcode    (instr_d[6:0]),
        .funct3    (instr_d[14:12]),
        .funct7    (instr_d[31:25]),
        .reg_write (reg_write_d),
        .result_src(result_src_d),
        .mem_write (mem_write_d),
        .branch    (branch_d),
        .alu_src   (alu_src_d),
        .alu_ctrl  (alu_ctrl_d)
    );

    // -------------------------------------------------------------------------
    // 2. Hazard Detection & Forwarding Unit
    // -------------------------------------------------------------------------
    hazard_unit u_hazard (
        .rs1_d       (rs1_d),
        .rs2_d       (rs2_d),
        .rs1_e       (rs1_e),
        .rs2_e       (rs2_e),
        .rd_e        (rd_e),
        .rd_m        (rd_m),
        .rd_w        (rd_w),
        .reg_write_m (reg_write_m),
        .reg_write_w (reg_write_w),
        .result_src_e(result_src_e),
        .pc_src_e    (pc_src_e),
        .forward_ae  (forward_ae),
        .forward_be  (forward_be),
        .stall_f     (stall_f),
        .stall_d     (stall_d),
        .flush_d     (flush_d),
        .flush_e     (flush_e)
    );

    // -------------------------------------------------------------------------
    // 3. Datapath
    // -------------------------------------------------------------------------
    datapath #(
        .IMEM_FILE(IMEM_FILE),
        .DMEM_INIT(DMEM_INIT)
    ) u_datapath (
        .clk             (clk),
        .rst             (rst),
        .reg_write_d     (reg_write_d),
        .result_src_d    (result_src_d),
        .mem_write_d     (mem_write_d),
        .branch_d        (branch_d),
        .alu_src_d       (alu_src_d),
        .alu_ctrl_d      (alu_ctrl_d),
        .stall_f         (stall_f),
        .stall_d         (stall_d),
        .flush_d         (flush_d),
        .flush_e         (flush_e),
        .forward_ae      (forward_ae),
        .forward_be      (forward_be),
        .instr_d         (instr_d),
        .rs1_d           (rs1_d),
        .rs2_d           (rs2_d),
        .rs1_e           (rs1_e),
        .rs2_e           (rs2_e),
        .rd_e            (rd_e),
        .rd_m            (rd_m),
        .rd_w            (rd_w),
        .reg_write_m     (reg_write_m),
        .reg_write_w     (reg_write_w),
        .result_src_e    (result_src_e),
        .pc_src_e        (pc_src_e),
        .pc_f_out        (debug_pc),
        .alu_result_e_out(debug_alu_result),
        .result_w_out    (debug_result_w)
    );

endmodule
