`timescale 1ns/1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/13/2023
// Module Name: rom
// Description: Instruction memory module that loads memory contents from a file.
//////////////////////////////////////////////////////////////////////////////////

module rom #(parameter addr_width = 32, parameter data_width = 32, parameter string init_file = "dummy.dat")
(
    input [addr_width-1:0] addr,
    output [data_width-1:0] data
);

    reg [7:0] mem [255:0];

    initial begin
        $readmemb(init_file, mem);
    end
    
    // Assemble 4 bytes into a 32-bit instruction (little-endian assumed)
    assign data = {mem[addr+3], mem[addr+2], mem[addr+1], mem[addr]};

endmodule
