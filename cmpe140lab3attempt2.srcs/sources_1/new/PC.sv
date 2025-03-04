`timescale 1ns/1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/03/2025
// Module Name: PC
// Description: Program Counter module. Holds the current PC value and updates it
// each cycle (unless a stall is asserted).
//////////////////////////////////////////////////////////////////////////////////

module PC(
    input rst_n,
    input clk,
    input stall,
    input [31:0] next_pc,
    output reg [31:0] pc
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc <= 32'b0;
        else if (!stall)
            pc <= next_pc;
    end

endmodule
