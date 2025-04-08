module instruction_decoder(
    input [31:0] imem_insn,
    output reg [4:0]  destination_reg,
    output reg [2:0]  funct3,
    output reg [4:0]  source_reg1,
    output reg [4:0]  source_reg2,
    output reg [31:0] imm,         // 32-bit full immediate (after shift/sign-extension where needed)
    output reg [6:0]  funct7,
    output reg [4:0]  shamt,
    output reg [2:0]  insn_type,   // 000: I-type, 001: R-type, 010: S-type, 011: Load,
                                   // 100: U-type, 101: J-type, 110: Branch, 111: Default/NOP
    output reg        alu_op_mux,
    output reg        wen,
    output reg        dmem_wen
);

  always @ (*) begin
      case (imem_insn[6:0])
        // I-type instructions (e.g. ADDI, SLTI, ...)
        7'b0010011: begin
          insn_type       = 3'b000;
          destination_reg = imem_insn[11:7];
          funct3          = imem_insn[14:12];
          source_reg1     = imem_insn[19:15];
          source_reg2     = 5'b0;
          imm             = {{20{imem_insn[31]}}, imem_insn[31:20]};
          funct7          = imem_insn[31:25];
          shamt           = imem_insn[24:20];
          alu_op_mux      = 1'b1;
          wen             = 1'b1;
          dmem_wen        = 1'b0;
        end

        // R-type instructions (e.g. ADD, SUB, ...)
        7'b0110011: begin
          insn_type       = 3'b001;
          destination_reg = imem_insn[11:7];
          funct3          = imem_insn[14:12];
          source_reg1     = imem_insn[19:15];
          source_reg2     = imem_insn[24:20];
          funct7          = imem_insn[31:25];
          imm             = 32'b0;
          shamt           = 5'b0;
          alu_op_mux      = 1'b0;
          wen             = 1'b1;
          dmem_wen        = 1'b0;
        end

        // S-type instructions (Store instructions: e.g. SW)
        7'b0100011: begin
          insn_type       = 3'b010;
          destination_reg = 5'b0;
          funct3          = imem_insn[14:12];
          source_reg1     = imem_insn[19:15];
          source_reg2     = imem_insn[24:20];
          // Construct immediate from imm[11:5] and imm[4:0].
          imm             = {{20{imem_insn[31]}}, imem_insn[31:25], imem_insn[11:7]};
          funct7          = 7'b0;
          shamt           = 5'b0; 
          alu_op_mux      = 1'b1;
          wen             = 1'b0;
          dmem_wen        = 1'b1;
        end

        // Load instructions (e.g. LW)
        7'b0000011: begin
          insn_type       = 3'b011;
          destination_reg = imem_insn[11:7];
          funct3          = imem_insn[14:12];
          source_reg1     = imem_insn[19:15];
          source_reg2     = 5'b0;
          imm             = {{20{imem_insn[31]}}, imem_insn[31:20]};
          funct7          = 7'b0;
          shamt           = 5'b0; 
          alu_op_mux      = 1'b1;
          wen             = 1'b1;
          dmem_wen        = 1'b0;
        end

        // U-type instructions: LUI
        7'b0110111: begin
          insn_type       = 3'b100;
          destination_reg = imem_insn[11:7];
          funct3          = 3'b0; // not used
          source_reg1     = 5'b0;
          source_reg2     = 5'b0;
          // Immediate is bits [31:12] shifted left by 12.
          imm             = {imem_insn[31:12], 12'b0};
          funct7          = 7'b0;
          shamt           = 5'b0;
          alu_op_mux      = 1'b1;
          wen             = 1'b1;
          dmem_wen        = 1'b0;
        end

        // U-type instructions: AUIPC
        7'b0010111: begin
          insn_type       = 3'b100;
          destination_reg = imem_insn[11:7];
          funct3          = 3'b0; // not used
          source_reg1     = 5'b0;
          source_reg2     = 5'b0;
          imm             = {imem_insn[31:12], 12'b0};
          funct7          = 7'b0;
          shamt           = 5'b0;
          alu_op_mux      = 1'b1;
          wen             = 1'b1;
          dmem_wen        = 1'b0;
        end

        // J-type instruction: JAL
        7'b1101111: begin
          insn_type       = 3'b101;
          destination_reg = imem_insn[11:7];
          funct3          = 3'b0; // not used
          source_reg1     = 5'b0;
          source_reg2     = 5'b0;
          // Assemble immediate: imm[20|10:1|11|19:12] with a 0 as LSB.
          imm             = {{11{imem_insn[31]}}, imem_insn[31],
                             imem_insn[19:12], imem_insn[20],
                             imem_insn[30:21], 1'b0};
          funct7          = 7'b0;
          shamt           = 5'b0;
          alu_op_mux      = 1'b1;
          wen             = 1'b1;  // Write return address (PC+4) into rd.
          dmem_wen        = 1'b0;
        end

        // J-type instruction: JALR (I-type format)
        7'b1100111: begin
          insn_type       = 3'b101;
          destination_reg = imem_insn[11:7];
          funct3          = imem_insn[14:12]; // should be 000
          source_reg1     = imem_insn[19:15];
          source_reg2     = 5'b0;
          imm             = {{20{imem_insn[31]}}, imem_insn[31:20]};
          funct7          = 7'b0;
          shamt           = 5'b0;
          alu_op_mux      = 1'b1;
          wen             = 1'b1;
          dmem_wen        = 1'b0;
        end

        // B-type instructions: Branches (BEQ, BNE, BLT, BGE, BLTU, BGEU)
        7'b1100011: begin
          insn_type       = 3'b110;
          destination_reg = 5'b0;
          funct3          = imem_insn[14:12];
          source_reg1     = imem_insn[19:15];
          source_reg2     = imem_insn[24:20];
          // Assemble branch immediate: imm[12|10:5|4:1|11] with 0 as LSB.
          imm             = {{19{imem_insn[31]}}, imem_insn[31],
                             imem_insn[7], imem_insn[30:25],
                             imem_insn[11:8], 1'b0};
          funct7          = 7'b0;
          shamt           = 5'b0;
          alu_op_mux      = 1'b1;
          wen             = 1'b0;
          dmem_wen        = 1'b0;
        end

        // Default case: Unknown instruction -> NOP.
        default: begin
          insn_type       = 3'b111;
          destination_reg = 5'b0;
          funct3          = 3'b0;
          source_reg1     = 5'b0;
          source_reg2     = 5'b0;
          imm             = 32'b0;
          funct7          = 7'b0;
          shamt           = 5'b0;
          alu_op_mux      = 1'b0;
          wen             = 1'b0;
          dmem_wen        = 1'b0;
        end
      endcase
    end
endmodule
