// Instruction Decoder Module
module instruction_decoder(
    input [31:0] imem_insn,
    output reg [4:0] destination_reg,
    output reg [2:0] funct3,
    output reg [4:0] source_reg1,
    output reg [11:0] imm,
   	output reg [6:0] funct7,
    output reg [4:0] shamt,
    output reg [3:0] insn_type
);

  always @ (*) begin
      case (imem_insn[6:0])
        7'b0010011: begin //I type instruction
          destination_reg = imem_insn[11:7];
          funct3 = imem_insn[14:12];
          source_reg1 = imem_insn[19:15];
          imm = imem_insn[31:20];
          funct7 = imem_insn[31:25];
          shamt = imem_insn[24:20]; 
        end
      endcase
    end
  endmodule
