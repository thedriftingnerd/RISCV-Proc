// Updated Program Counter Module
module PC(
    input         rst_n,
    input         clk,
    input         stall,
    input         branch_jump,   // Asserted when a branch or jump is taken
    input  [31:0] new_pc,        // New target address (branch or jump target)
    output reg [31:0] pc
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 32'b0;
        end
        else if (stall) begin
            pc <= pc;            // Hold the current PC during a stall
        end
        else if (branch_jump) begin
            pc <= new_pc;        // Override PC with the branch/jump target address
        end
        else begin
            pc <= pc + 4;        // Default: increment PC by 4 (next sequential instruction)
        end
    end
endmodule
