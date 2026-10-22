// =============================================================================
// Module: imem
// Description: Byte-Addressable Instruction Memory for RV64I Core
// Loads standard big-endian hex machine code representation via $readmemh
// =============================================================================

module imem #(
    parameter MEM_SIZE = 4096,
    parameter MEM_FILE = "instructions.hex"
)(
    input  wire        rst,
    input  wire [63:0] addr,
    output wire [31:0] instr
);

    reg [7:0] ram [0:MEM_SIZE-1];
    integer i;

    initial begin
        for (i = 0; i < MEM_SIZE; i = i + 1)
            ram[i] = 8'h00;
        if (MEM_FILE != "")
            $readmemh(MEM_FILE, ram);
    end

    // Assemble 32-bit instruction from 4 sequential bytes in big-endian layout
    assign instr = (rst || (addr > MEM_SIZE - 4)) ? 32'd0 :
                   {ram[addr], ram[addr+1], ram[addr+2], ram[addr+3]};

endmodule
