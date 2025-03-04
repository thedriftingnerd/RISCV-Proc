`timescale 1ns/1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/03/2025
// Module Name: InstMem
// Description: Instruction Memory module wrapper that instantiates the rom module.
//////////////////////////////////////////////////////////////////////////////////

module InstMem #(parameter addr_width = 32, parameter data_width = 32, parameter string init_file = "dummy.dat")
(
    input [addr_width-1:0] addr,
    output [data_width-1:0] data
);

    rom #(addr_width, data_width, init_file) rom_inst (
        .addr(addr),
        .data(data)
    );

endmodule
