// ALU Module
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
            3'b000: begin
                case (funct3)
                    // ADDI
                    3'b000: result = op1 + op2; 
                    // SLTI
                    3'b010: begin
                        if ($signed(op1) < $signed(op2)) begin
                            result = 1;
                        end
                        else begin
                            result = 0;
                        end
                    end
                    // SLTIU
                    3'b011: begin
                        if (op1 < op2) begin
                            result = 1;
                        end
                        else begin
                            result = 0;
                        end
                    end
                    // XORI
                    3'b100: result = op1 ^ op2; 
                    // ORI
                    3'b110: result = op1 | op2;
                    // ANDI
                    3'b111: result = op1 & op2;
                    // SLLI 
                    3'b001: result = op1 << shamt;
                    // SRLI / SRAI
                    3'b101: begin
                        if (funct7 == 7'b0100000) begin
                            // SRAI
                            result = $signed(op1) >>> shamt; 
                        end
                        else if (funct7 == 7'b0000000) begin
                            // SRLI
                            result = op1 >> shamt;
                        end
                        else begin
                            // Default case for funct3 = 3'b101
                            result = 32'b0;
                        end
                    end
                    // Default case for funct3
                    default: result = 32'b0;
                endcase
            end
            3'b001: begin
                case(funct3)
                    // add or sub
                    3'b000: begin
                        if(funct7 == 7'b0000000) begin
                            result = op1 + op2;
                        end
                        else if(funct7 == 7'b0100000) begin
                            result = op1 - op2;
                        end
                    end
                    3'b001:
                        result = op1 << op2[4:0];
                    3'b010: begin
                        if ($signed(op1) < $signed(op2)) begin
                            result = 1;
                        end
                        else begin
                            result = 0;
                        end
                    end
                    3'b011: begin
                        if (op1 < op2) begin
                            result = 1;
                        end
                        else begin
                            result = 0;
                        end
                    end
                    3'b100:
                        result = op1 ^ op2;
                    3'b101: begin
                        if(funct7 == 7'b0100000) begin
                            result = $signed(op1) >>> op2[4:0];
                        end
                        else if(funct7 == 7'b0000000) begin
                            result = op1 >> op2[4:0];
                        end
                    end
                    3'b110:
                        result = op1 | op2;
                    3'b111:
                        result = op1 & op2;
                    default: result = 32'b0;
                endcase
            end
            // For I-type Load-Store (stores)
            3'b010: begin
                result = op1; // effective address
            end

            // For R-type Load-Store (loads)
            3'b011: begin
                result = op1;
            end

            // Default case for insn_type
            default: result = 32'b0;
        endcase
    end
endmodule
