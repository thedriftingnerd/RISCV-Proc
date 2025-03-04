`timescale 1ns/1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/13/2023
// Module Name: ram
// Description: Data Memory module using a bidirectional port.
//////////////////////////////////////////////////////////////////////////////////

module ram #(parameter addr_width = 4, parameter data_width = 4, parameter string init_file = "dummy.dat")
(
    input rst_n,
    input clk,
    input wen,
    input [addr_width-1:0] addr,
    inout [data_width-1:0] data
);

    reg [data_width-1:0] mem [(1<<addr_width)-1:0];

    initial begin
        $readmemb(init_file, mem);
    end
    
    assign data = rst_n ? (wen ? 'z : mem[addr]) : 'z;

    always_ff @(posedge clk) begin
        if (rst_n) begin
            if (wen)
                mem[addr] <= #0.1 data;
        end
    end

endmodule
