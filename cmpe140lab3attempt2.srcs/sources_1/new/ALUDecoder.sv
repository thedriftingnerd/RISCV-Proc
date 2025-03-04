`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/20/2025 10:37:19 AM
// Module Name: ALUDecoder
// Description: Generates ALU control signals based on the funct3 field of the
// instruction. For this lab (only addi is supported), the operation is always ADD.
//////////////////////////////////////////////////////////////////////////////////

module ALUDecoder(
    input  [2:0] funct3,       // Function field (for addi, usually 000)
    output reg [3:0] alu_ctrl  // ALU control signal (4'b0000 means addition)
);

    always @(*) begin
        case(funct3)
            3'b000: alu_ctrl = 4'b0000; // ADD operation
            default: alu_ctrl = 4'b0000;
        endcase
    end

endmodule
