// ALU Decoder Module
module ALUDecoder(
    input [6:0] opcode, 
    input [2:0] funct3, 
    output reg [2:0] alu_ctrl
);
    always @(*) begin
        case (opcode)
            7'b0010011: begin // I-type ALU Instructions
                case (funct3)
                    3'b000: alu_ctrl = 3'b000; // ADDI
                    3'b100: alu_ctrl = 3'b001; // XORI
                    3'b110: alu_ctrl = 3'b010; // ORI
                    3'b111: alu_ctrl = 3'b011; // ANDI
                    3'b001: alu_ctrl = 3'b100; // SLLI
                    3'b101: alu_ctrl = 3'b101; // SRLI or SRAI 
                    default: alu_ctrl = 3'b000; // just use addi
                endcase
            end
            default: alu_ctrl = 3'b000; 
        endcase
    end
endmodule
