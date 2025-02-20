module CPU (
    input rst_n,
    input clk,
    output [31:0] imem_addr,
    input [31:0] imem_insn,
    output [31:0] dmem_addr,
    inout [31:0] dmem_data,
    output dmem_wen
);

ALU alu_module();
ALUDecoder alu_decoder();

endmodule
