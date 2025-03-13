// ALU Module
module ALU(
    input [31:0] op1,
    input [31:0] op2,
    input [2:0] alu_ctrl,
    output reg [31:0] result
);
    always @(*) begin
        case (alu_ctrl)
            3'b000: result = op1 + op2; // ADDI
            3'b001: result = op1 ^ op2; // XORI
            3'b010: result = op1 | op2; // ORI
            3'b011: result = op1 & op2; // ANDI
            3'b100: result = op1 << op2[4:0]; // SLLI 
            3'b101: begin
                if (op2[10]) // Check bit 10 for SRAI vs. SRLI
                    result = $signed(op1) >>> op2[4:0]; // SRAI 
                else
                    result = op1 >> op2[4:0]; // SRLI 
            end
            default: result = 32'b0; // Default case
        endcase
    end
endmodule
