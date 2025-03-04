`timescale 1ns/1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/03/2025
// Module Name: DataMem
// Description: Data Memory for RISCV processor lab. This module implements a simple
// memory that reads an initialization file and supports write operations.
// (Note: This module is provided as part of lab materials and is similar to the ram.)
//////////////////////////////////////////////////////////////////////////////////

module DataMem #(parameter addr_width = 32, parameter data_width = 32, parameter string init_file = "dummy.dat")
(
    input rst_n,
    input clk,
    input wen,
    input [addr_width-1:0] addr,
    inout [data_width-1:0] data
);

    // Memory array declaration
    reg [data_width-1:0] mem [(1<<addr_width)-1:0];

    // Initialize memory from file
    initial begin
        $readmemb(init_file, mem);
    end

    // Tri-state buffer for data output
    assign data = (rst_n && !wen) ? mem[addr] : {data_width{1'bz}};

    // Write operation on positive clock edge
    always @(posedge clk) begin
        if (rst_n && wen)
            mem[addr] <= data;
    end

endmodule
