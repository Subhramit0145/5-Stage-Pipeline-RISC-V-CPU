// =============================================================================
// Module: dmem
// Description: Byte-Addressable 64-bit Data Memory for RV64I Core
// Supports 64-bit doubleword loads (ld) and stores (sd)
// =============================================================================

module dmem #(
    parameter MEM_SIZE = 1024,
    parameter INIT_FILE = ""
)(
    input  wire        clk,
    input  wire        rst,
    input  wire [63:0] addr,
    input  wire [63:0] write_data,
    input  wire        mem_write,
    output wire [63:0] read_data
);

    reg [7:0] mem [0:MEM_SIZE-1];
    integer i;

    initial begin
        for (i = 0; i < MEM_SIZE; i = i + 1)
            mem[i] = 8'h00;
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, mem);
    end

    // Synchronous write on posedge clk
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < MEM_SIZE; i = i + 1)
                mem[i] <= 8'h00;
        end else if (mem_write && (addr <= MEM_SIZE - 8)) begin
            mem[addr]     <= write_data[63:56];
            mem[addr + 1] <= write_data[55:48];
            mem[addr + 2] <= write_data[47:40];
            mem[addr + 3] <= write_data[39:32];
            mem[addr + 4] <= write_data[31:24];
            mem[addr + 5] <= write_data[23:16];
            mem[addr + 6] <= write_data[15:8];
            mem[addr + 7] <= write_data[7:0];
        end
    end

    // Helper function for simulation testbenches to inspect memory
    function [63:0] read_data_from_addr;
        input [63:0] a;
        begin
            read_data_from_addr = {
                mem[a],
                mem[a + 1],
                mem[a + 2],
                mem[a + 3],
                mem[a + 4],
                mem[a + 5],
                mem[a + 6],
                mem[a + 7]
            };
        end
    endfunction

    // Asynchronous doubleword read
    assign read_data = (addr <= MEM_SIZE - 8) ? {
        mem[addr],
        mem[addr + 1],
        mem[addr + 2],
        mem[addr + 3],
        mem[addr + 4],
        mem[addr + 5],
        mem[addr + 6],
        mem[addr + 7]
    } : 64'd0;

endmodule
