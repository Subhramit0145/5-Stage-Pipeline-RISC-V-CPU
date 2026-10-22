// =============================================================================
// Module: regfile
// Description: 32 x 64-bit General Purpose Register File for RV64I
// Features:
//   - Hardwired x0 = 64'd0 (reads always return 0, writes to x0 are discarded)
//   - Dual asynchronous read ports (rd1, rd2)
//   - Single synchronous write port with internal write-through forwarding
// =============================================================================

module regfile (
    input  wire        clk,
    input  wire        rst,
    input  wire [4:0]  read_addr1,
    input  wire [4:0]  read_addr2,
    input  wire [4:0]  write_addr,
    input  wire [63:0] write_data,
    input  wire        reg_write,
    output wire [63:0] read_data1,
    output wire [63:0] read_data2
);

    reg [63:0] rf [0:31];
    integer i;

    // Synchronous write on posedge clk with async reset
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1)
                rf[i] <= 64'd0;
        end else begin
            if (reg_write && (write_addr != 5'd0))
                rf[write_addr] <= write_data;
        end
    end

    // Asynchronous read ports with write-through bypass:
    // If reading the register being written in the same cycle, return write_data
    assign read_data1 = (read_addr1 == 5'd0) ? 64'd0 :
                        ((read_addr1 == write_addr) && reg_write) ? write_data : rf[read_addr1];

    assign read_data2 = (read_addr2 == 5'd0) ? 64'd0 :
                        ((read_addr2 == write_addr) && reg_write) ? write_data : rf[read_addr2];

endmodule
