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
    output reg wen,
    output reg dmem_wen
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
          dmem_wen = 0;
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
          dmem_wen = 0;
        end
        7'b0100011: begin // Store type Load-Store
          insn_type = 3'b010;
          destination_reg = 0;
          imm[4:0] = imem_insn[11:7];
          funct3 = imem_insn[14:12];
          source_reg1 = imem_insn[19:15];
          source_reg2 = imem_insn[24:20];
          imm[11:5] = imem_insn[31:25];
          funct7 = 0;
          shamt = 0; 
          alu_op_mux = 1;
          wen = 0;
          dmem_wen = 1;
        end
        7'b0000011: begin // Load type Load-Store
          insn_type = 3'b011;
          destination_reg = imem_insn[11:7];
          funct3 = imem_insn[14:12];
          source_reg1 = imem_insn[19:15];
          source_reg2 = 5'b0;
          imm[11:0] = imem_insn[31:20];
          funct7 = 0;
          shamt = 0; 
          alu_op_mux = 1;
          wen = 1;
          dmem_wen = 0;
        end
        7'b0110111: begin // U-type instructions: LUI
          insn_type       = 3'b100; // U-type
          destination_reg = imem_insn[11:7];
          funct3          = 3'b000; // not used
          source_reg1     = 0;
          source_reg2     = 0;
          // Immediate: take bits [31:12] and shift left 12 bits
          imm             = {imem_insn[31:12], 12'b0};
          funct7          = 0;
          shamt           = 0;
          alu_op_mux      = 1;
          wen             = 1;
          dmem_wen        = 0;
        end
        7'b0010111: begin // U-type instructions: AUIPC
          insn_type       = 3'b100; // U-type
          destination_reg = imem_insn[11:7];
          funct3          = 3'b000; // not used
          source_reg1     = 0;
          source_reg2     = 0;
          // Immediate: bits [31:12] shifted left 12 bits (to be added to PC)
          imm             = {imem_insn[31:12], 12'b0};
          funct7          = 0;
          shamt           = 0;
          alu_op_mux      = 1;
          wen             = 1;
          dmem_wen        = 0;
        end
        7'b1101111: begin // J-type instruction: JAL
          insn_type       = 3'b101; // J-type
          destination_reg = imem_insn[11:7];
          funct3          = 3'b000; // not used
          source_reg1     = 0;
          source_reg2     = 0;
          // Assemble immediate from scattered bits:
          // imm[20]    = imem_insn[31]
          // imm[10:1]  = imem_insn[30:21]
          // imm[11]    = imem_insn[20]
          // imm[19:12] = imem_insn[19:12]
          // LSB is 0
          imm             = {{11{imem_insn[31]}}, imem_insn[31],
                             imem_insn[19:12], imem_insn[20],
                             imem_insn[30:21], 1'b0};
          funct7          = 0;
          shamt           = 0;
          alu_op_mux      = 1;
          wen             = 1;  // writes the return address into rd
          dmem_wen        = 0;
        end
        7'b1100111: begin // J-type instruction: JALR (I-type format, but used for jumps)
          insn_type       = 3'b101; // J-type jump
          destination_reg = imem_insn[11:7];
          funct3          = imem_insn[14:12]; // should be 000
          source_reg1     = imem_insn[19:15];
          source_reg2     = 0;
          // Sign-extend 12-bit immediate
          imm             = {{20{imem_insn[31]}}, imem_insn[31:20]};
          funct7          = 0;
          shamt           = 0;
          alu_op_mux      = 1;
          wen             = 1;  // writes the return address into rd
          dmem_wen        = 0;
        end
        7'b1100011: begin // B-type instructions: Branches (BEQ, BNE, BLT, etc.)
          insn_type       = 3'b110; // Branch type
          destination_reg = 0;        // no rd for branches
          funct3          = imem_insn[14:12]; // determines branch type
          source_reg1     = imem_insn[19:15];
          source_reg2     = imem_insn[24:20];
          // Assemble branch immediate from bits:
          // imm[12]   = imem_insn[31]
          // imm[10:5] = imem_insn[30:25]
          // imm[4:1]  = imem_insn[11:8]
          // imm[11]   = imem_insn[7]
          // LSB is 0
          imm             = {{19{imem_insn[31]}}, imem_insn[31],
                             imem_insn[7], imem_insn[30:25],
                             imem_insn[11:8], 1'b0};
          funct7          = 0;
          shamt           = 0;
          alu_op_mux      = 1;
          wen             = 0;
          dmem_wen        = 0;
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
          alu_op_mux = 0;
          wen = 0;
          dmem_wen = 0;
        end
      endcase
    end
  endmodule
