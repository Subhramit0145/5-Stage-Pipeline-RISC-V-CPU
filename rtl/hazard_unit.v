// =============================================================================
// Module: hazard_unit
// Description: Hazard Detection and Forwarding Unit for 5-Stage RV64I Pipeline
// Resolves:
//   1. Data Hazards (RAW): Handled via ALU Operand Forwarding (EX-to-EX, MEM-to-EX)
//   2. Load-Use Data Hazards: Handled via 1-cycle pipeline stall (bubble insertion)
//   3. Control Hazards (Branch Penalty): Handled via 2-cycle pipeline flush
// =============================================================================

module hazard_unit (
    input  wire [4:0] rs1_d,
    input  wire [4:0] rs2_d,
    input  wire [4:0] rs1_e,
    input  wire [4:0] rs2_e,
    input  wire [4:0] rd_e,
    input  wire [4:0] rd_m,
    input  wire [4:0] rd_w,
    input  wire       reg_write_m,
    input  wire       reg_write_w,
    input  wire       result_src_e, // High when instruction in EX is a Load (ld)
    input  wire       pc_src_e,     // High when branch is taken in EX
    output reg  [1:0] forward_ae,   // Forwarding control for ALU Input A
    output reg  [1:0] forward_be,   // Forwarding control for ALU Input B
    output wire       stall_f,      // Freeze Program Counter
    output wire       stall_d,      // Freeze IF/ID Register
    output wire       flush_d,      // Flush IF/ID Register on branch
    output wire       flush_e       // Flush ID/EX Register (inject bubble)
);

    wire lw_stall;

    // -------------------------------------------------------------------------
    // 1. Data Forwarding Logic (Bypassing)
    // -------------------------------------------------------------------------
    // Priority: MEM stage forwarding takes precedence over WB stage forwarding
    // because MEM stage holds the most recent instruction execution result.
    // Writes to x0 (zero register) are never forwarded.

    // Forwarding for Operand A (rs1_e)
    always @(*) begin
        if ((rs1_e != 5'd0) && (rs1_e == rd_m) && reg_write_m)
            forward_ae = 2'b10; // Forward from MEM stage (EX-to-EX hazard)
        else if ((rs1_e != 5'd0) && (rs1_e == rd_w) && reg_write_w)
            forward_ae = 2'b01; // Forward from WB stage (MEM-to-EX hazard)
        else
            forward_ae = 2'b00; // No forwarding, use register operand from ID/EX
    end

    // Forwarding for Operand B (rs2_e)
    always @(*) begin
        if ((rs2_e != 5'd0) && (rs2_e == rd_m) && reg_write_m)
            forward_be = 2'b10; // Forward from MEM stage
        else if ((rs2_e != 5'd0) && (rs2_e == rd_w) && reg_write_w)
            forward_be = 2'b01; // Forward from WB stage
        else
            forward_be = 2'b00; // No forwarding
    end

    // -------------------------------------------------------------------------
    // 2. Load-Use Hazard Detection
    // -------------------------------------------------------------------------
    // If instruction in EX is a Load and its destination matches rs1 or rs2 in Decode:
    // A stall is required because the memory data is not available until the end of MEM.
    assign lw_stall = result_src_e && (rd_e != 5'd0) && ((rs1_d == rd_e) || (rs2_d == rd_e));

    // Freeze IF and ID stages to hold the dependent instruction
    assign stall_f = lw_stall;
    assign stall_d = lw_stall;

    // -------------------------------------------------------------------------
    // 3. Control Hazard Handling (Branch Flush) & Bubble Injection
    // -------------------------------------------------------------------------
    // Flush IF/ID register when branch is taken
    assign flush_d = pc_src_e;

    // Flush ID/EX register (insert NOP bubble) on either load stall or branch taken
    assign flush_e = lw_stall || pc_src_e;

endmodule
