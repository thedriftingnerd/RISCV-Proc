// Program Counter Module
module PC(
    input rst_n,
    input clk,
    input stall,
    input [31:0] next_pc,
    output reg [31:0] pc
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc <= 32'b0;
        else if (!stall)
            pc <= next_pc;
    end
endmodule
