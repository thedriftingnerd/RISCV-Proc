module ALU(
    input [31:0] op1,
    input [31:0] op2,
    input [2:0] funct3,
    input [6:0] funct7,
    input [4:0] shamt,
    input [2:0] insn_type,
    output reg [31:0] result
);
    always @ (*) begin
        case (insn_type)
            // I-type arithmetic instructions
            3'b000: begin
                case (funct3)
                    3'b000: result = op1 + op2;          // ADDI
                    3'b010: result = ($signed(op1) < $signed(op2)) ? 1 : 0;  // SLTI
                    3'b011: result = (op1 < op2) ? 1 : 0;  // SLTIU
                    3'b100: result = op1 ^ op2;            // XORI
                    3'b110: result = op1 | op2;            // ORI
                    3'b111: result = op1 & op2;            // ANDI
                    3'b001: result = op1 << shamt;         // SLLI
                    3'b101: begin
                        if (funct7 == 7'b0100000)
                            result = $signed(op1) >>> shamt; // SRAI
                        else if (funct7 == 7'b0000000)
                            result = op1 >> shamt;           // SRLI
                        else
                            result = 32'b0;
                    end
                    default: result = 32'b0;
                endcase
            end
            // R-type arithmetic instructions
            3'b001: begin
                case(funct3)
                    3'b000: begin
                        if(funct7 == 7'b0000000)
                            result = op1 + op2;  // ADD
                        else if(funct7 == 7'b0100000)
                            result = op1 - op2;  // SUB
                    end
                    3'b001: result = op1 << op2[4:0];         // SLL
                    3'b010: result = ($signed(op1) < $signed(op2)) ? 1 : 0; // SLT
                    3'b011: result = (op1 < op2) ? 1 : 0;       // SLTU
                    3'b100: result = op1 ^ op2;                 // XOR
                    3'b101: begin
                        if(funct7 == 7'b0100000)
                            result = $signed(op1) >>> op2[4:0]; // SRA
                        else if(funct7 == 7'b0000000)
                            result = op1 >> op2[4:0];           // SRL
                    end
                    3'b110: result = op1 | op2;                 // OR
                    3'b111: result = op1 & op2;                 // AND
                    default: result = 32'b0;
                endcase
            end
            // S-type (store) and Load: effective address = base + offset.
            3'b010, 3'b011: begin
                result = op1 + op2;
            end
            // U-type
            3'b100: begin
                result = op1 + op2;
            end
            // J-type (jump): target address = base + offset.
            3'b101: begin
                result = op1 + op2;
            end
            // B-type (branch): target address = PC + offset.
            3'b110: begin
                result = op1 + op2;
            end
            // Default: result = 0.
            default: result = 32'b0;
        endcase
    end
endmodule
