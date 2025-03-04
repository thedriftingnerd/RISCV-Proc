`timescale 1ns/1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/03/2025
// Module Name: Registers
// Description: A simple register file with 32 registers, two asynchronous read ports,
// and one synchronous write port.
//////////////////////////////////////////////////////////////////////////////////

module Registers (
    input clk,
    input rst_n,
    input reg_write,           // Write enable
    input [4:0] write_reg,     // Destination register address
    input [31:0] write_data,   // Data to be written
    input [4:0] read_reg1,     // First read register address
    input [4:0] read_reg2,     // Second read register address (unused for addi)
    output reg [31:0] read_data1, // Data from first read port
    output reg [31:0] read_data2  // Data from second read port (unused)
);

    // 32 x 32-bit register file
    reg [31:0] reg_file [31:0];
    integer i;
    
    // Initialize registers to 0
    initial begin
        for (i = 0; i < 32; i = i + 1)
            reg_file[i] = 32'b0;
    end

    // Asynchronous read
    always @(*) begin
        read_data1 = reg_file[read_reg1];
        read_data2 = reg_file[read_reg2];
    end

    // Synchronous write (x0 is hardwired to 0)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 32; i = i + 1)
                reg_file[i] <= 32'b0;
        end else begin
            if (reg_write && (write_reg != 5'b0))
                reg_file[write_reg] <= write_data;
        end
    end

endmodule
