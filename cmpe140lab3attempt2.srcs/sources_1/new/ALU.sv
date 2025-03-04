`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/20/2025 10:38:30 AM
// Module Name: ALU
// Description: A simple ALU module for the RISCV processor lab. For addi, it performs
// an addition operation.
//////////////////////////////////////////////////////////////////////////////////

module ALU(
    input [31:0] op1,         // First operand
    input [31:0] op2,         // Second operand (immediate)
    input [3:0] alu_ctrl,     // ALU control signal
    output reg [31:0] result  // ALU result
);

    always @(*) begin
        case (alu_ctrl)
            4'b0000: result = op1 + op2; // ADD operation
            default: result = 32'b0;
        endcase
    end

endmodule
