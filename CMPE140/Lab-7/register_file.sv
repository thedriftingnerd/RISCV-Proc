// Register File Module
module register_file(
    input clk,
    input rst_n,
    input wen,
    input [4:0] destination_reg,
    input [4:0] source_reg1, 
    input [4:0] source_reg2,
    input [31:0] write_data,
    input [3:0] byte_en,
    output reg [31:0] read_data1,
    output reg [31:0] read_data2
);
    reg [31:0] registers [0:31];

    initial begin
        integer i;
        for (i = 0; i < 32; i = i + 1)
            registers[i] = 32'b0;
    end

    always @(*) begin
        read_data1 = registers[source_reg1];
        read_data2 = registers[source_reg2];
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            integer i;
            for (i = 0; i < 32; i = i + 1)
                registers[i] <= 32'b0;
        end else if (wen && (destination_reg != 5'b0)) begin
            //registers[destination_reg] <= write_data;
            if (byte_en[3])
                    registers[destination_reg][31:24] <= #0.1 write_data[31:24];
            if (byte_en[2])
                    registers[destination_reg][23:16] <= #0.1 write_data[23:16];
            if (byte_en[1])
                    registers[destination_reg][15:8] <= #0.1 write_data[15:8];
            if (byte_en[0])
                    registers[destination_reg][7:0] <= #0.1 write_data[7:0];
        end
    end
endmodule
