module alu_control(
  input [1:0] ALUOp,
  input [2:0] funct3,
  input [6:0] funct7,
  output reg [3:0] ALUControl
);
  
  always @(*)begin
    case(ALUOp)
      2'b00 : ALUControl = 4'b0000;
      2'b01 : ALUControl = 4'b1000;
      2'b10 : begin
        case(funct3)
          3'b111 : ALUControl = 4'b0111;
          3'b110 : ALUControl = 4'b0110;
          3'b000 : begin
            case(funct7)
              7'b0000000 : ALUControl = 4'b0000;
              7'b0100000 : ALUControl = 4'b1000;
              default : ALUControl = 4'b0000;
            endcase
          end
          default : ALUControl = 4'b0000;
        endcase
      end
      default : ALUControl = 4'b0000;
    endcase
  end
  
endmodule
