module PC(
    input         rst_n,
    input         clk,
    input         stall,
    input         branch_jump,   // Asserted when a branch or jump is taken
    input  [31:0] new_pc,        // Target address when branch/jump is active
    output reg [31:0] pc
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc <= 32'b0;
        else if (stall)
            pc <= pc;            // Hold PC during a stall
        else if (branch_jump)
            pc <= new_pc;        // Load new target address for branch/jump
        else
            pc <= pc + 4;        // Otherwise, proceed sequentially
    end
endmodule
