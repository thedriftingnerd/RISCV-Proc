`timescale 1ns / 1ps

module cpu(
    input rst_n,
    input clk,
    output reg [31:0] imem_addr,
    input [31:0] imem_insn,
    output reg [31:0] dmem_addr,
    inout [31:0] dmem_data,
    output reg dmem_wen
);
    // stall register
    reg stall;

    // IF/ID pipeline register
    reg [31:0] IF_ID_insn, IF_ID_pc;

    // ID/EX pipeline register
    reg [31:0] ID_EX_pc, ID_EX_imm;
    reg [4:0] ID_EX_dest, ID_EX_src1;
    reg [2:0] ID_EX_insn_type;
    reg [2:0] ID_EX_funct3;
    reg [4:0] ID_EX_shamt;
    reg [6:0] ID_EX_funct7;

    // EX/MEM pipeline register
    reg [31:0] EX_MEM_alu_result;
    reg [4:0] EX_MEM_dest;

    // MEM/WB pipeline registers
    reg signed [31:0] MEM_WB_result;
    reg [4:0] MEM_WB_dest;
    reg MEM_WB_wen;
        
    // Clock Cycle Counter
    reg [15:0] cycle_counter;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cycle_counter <= 16'b0;
        else
            cycle_counter <= cycle_counter + 1;
    end

    // Program Counter Module
    wire [31:0] pc, next_pc;

    PC pc_module(
        .rst_n(rst_n),
        .clk(clk),
        .stall(stall),
        .next_pc(next_pc),
        .pc(pc)
    );

    assign next_pc = pc + 4;
    assign imem_addr = pc;

    // Instruction Fetch Stage
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            IF_ID_insn <= 32'b0;
            IF_ID_pc <= 32'b0;
        end else if (stall != 1'b1) begin
            IF_ID_insn <= imem_insn;
            IF_ID_pc <= pc;
        end
    end

    // Decode Stage
    wire [4:0] destination_reg;
    wire [2:0] funct3;
    wire [4:0] source_reg1;
    wire [11:0] imm;
   	wire [6:0] funct7;
    wire [4:0] shamt;
    wire [2:0] insn_type; 

    instruction_decoder decoder(
        .imem_insn(IF_ID_insn),
        .destination_reg(destination_reg),
        .funct3(funct3),
        .source_reg1(source_reg1),
        .imm(imm),
        .funct7(funct7),
        .shamt(shamt),
        .insn_type(insn_type)
    );

    // Hazard detection
    always @ (*) begin
        // Check if source register of current instruction matches destination register in pipeline
        if ((ID_EX_dest != 5'b0) && (ID_EX_dest == source_reg1)) begin
            stall = 1'b1;
        end else if ((EX_MEM_dest != 5'b0) && (EX_MEM_dest == source_reg1)) begin
            stall = 1'b1;
        end else if ((MEM_WB_dest != 5'b0) && (MEM_WB_dest == source_reg1)) begin
            stall = 1'b1; 
        end else begin
            stall = 1'b0;
        end
    end
 
    // Set ID_EX pipelines on clock edge
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ID_EX_pc <= 32'b0;
            ID_EX_dest <= 5'b0;
            ID_EX_src1 <= 5'b0;
            ID_EX_imm <= 32'b0;
            ID_EX_funct3 <=3'b0;
            ID_EX_funct7 <= 7'b0;
            ID_EX_insn_type <= 3'b111;
        end else begin
            ID_EX_pc <= IF_ID_pc;
            ID_EX_dest <= destination_reg;
            ID_EX_src1 <= source_reg1;
            ID_EX_insn_type <= insn_type;
            ID_EX_funct3 <= funct3;
            ID_EX_funct7 <= funct7;
            ID_EX_shamt <= shamt;
            ID_EX_imm <= {{20{imm[11]}}, imm};
            ID_EX_insn_type <= insn_type;
        end
    end

    // Register File
    wire [31:0] reg_data1;

    register_file reg_file(
        .clk(clk),
        .rst_n(rst_n),
        .wen(MEM_WB_wen),
        .destination_reg(MEM_WB_dest),
        .source_reg1(ID_EX_src1),
        .write_data(MEM_WB_result),
        .read_data1(reg_data1)
    );

    // Execute Stage
    wire [31:0] alu_result;
    
    ALU alu(
        .op1(reg_data1),
        .op2(ID_EX_imm),
        .shamt(ID_EX_shamt),
        .funct3(ID_EX_funct3),
        .funct7(ID_EX_funct7),
        .insn_type(ID_EX_insn_type),
        .result(alu_result)
    );
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            EX_MEM_alu_result <= 32'b0;
            EX_MEM_dest <= 5'b0;
        end else begin
            EX_MEM_alu_result <= alu_result;
            EX_MEM_dest <= ID_EX_dest;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            MEM_WB_result <= 32'b0;
            MEM_WB_dest <= 5'b0;
            MEM_WB_wen <= 1'b0;
        end else begin
            MEM_WB_result <= EX_MEM_alu_result;
            MEM_WB_dest <= EX_MEM_dest;
            MEM_WB_wen <= (EX_MEM_dest != 5'b0);
        end
    end
    
    
    // open files
    integer fd_pc, fd_data;
    initial begin
        fd_pc = $fopen("pc.txt", "w");
        fd_data = $fopen("data.txt", "w");
        if (fd_pc == 0 || fd_data == 0) begin
            $display("Error: Could not open file.");
            $finish;
        end
        $display("File descriptors: fd_pc = %0d, fd_data = %0d", fd_pc, fd_data);
    end
    
    // print to trace files
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
        
        end else begin
            $display("IF_ID_pc: %h, MEM_WB_result: %h, MEM_WB_dest: %h", IF_ID_pc, MEM_WB_result, MEM_WB_dest);
            $fdisplay(fd_pc, "PC: 0x%h", IF_ID_pc);
            $fdisplay(fd_data, "MEM_WB_result: %d", MEM_WB_result);
            $fdisplay(fd_data, "MEM_WB_dest: %d", MEM_WB_dest);
            $fdisplay(fd_data, "-----------------------------------");
        end
    end
    
    // close files
    initial begin
        #1000
        $fclose(fd_pc);
        $fclose(fd_data);
        $display("Files closed successfully.");
    end
endmodule
