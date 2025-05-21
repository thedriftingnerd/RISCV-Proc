// Instruction Decoder Module
module instruction_decoder(
    input [31:0] imem_insn,
    output reg [4:0] destination_reg,
    output reg [2:0] funct3,
    output reg [4:0] source_reg1,
    output reg [4:0] source_reg2,
    output reg [11:0] imm,
   	output reg [6:0] funct7,
    output reg [4:0] shamt,
    output reg [2:0] insn_type,
    output reg alu_op_mux,
    output reg wen
);

  always @ (*) begin
      case (imem_insn[6:0])
        7'b0010011: begin //I type instruction
          insn_type = 3'b000;
          destination_reg = imem_insn[11:7];
          funct3 = imem_insn[14:12];
          source_reg1 = imem_insn[19:15];
          source_reg2 = 0;
          imm = imem_insn[31:20];
          funct7 = imem_insn[31:25];
          shamt = imem_insn[24:20]; 
          alu_op_mux = 1;
          wen = 1;
        end
        7'b0110011: begin //R type instruction
          insn_type = 3'b001;
          destination_reg = imem_insn[11:7];
          funct3 = imem_insn[14:12];
          source_reg1 = imem_insn[19:15];
          source_reg2 = imem_insn[24:20];
          funct7 = imem_insn[31:25];
          imm = 0;
          shamt = 0;
          alu_op_mux = 0;
          wen = 1;
        end
        default: begin
          insn_type = 3'b111;
          destination_reg = 0;
          funct3 = 0;
          source_reg1 = 0;
          source_reg2 = 0;
          imm = 0;
          funct7 = 0;
          shamt = 0;
          wen = 0;
          alu_op_mux = 0;
        end
      endcase
    end
  endmodule
