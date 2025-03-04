`timescale 1ns/1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/03/2025
// Module Name: CPU
// Description: A simple pipelined RISCV processor supporting the addi instruction.
// The pipeline has 5 stages: IF, ID, EX, MEM, WB. It includes hazard detection
// (stalling when a source register is not ready), a 16-bit cycle counter, and
// trace-file outputs for the PC and register writes.
//////////////////////////////////////////////////////////////////////////////////

module CPU (
    input rst_n,
    input clk,
    output [31:0] imem_addr,   // Instruction memory address
    input  [31:0] imem_insn,   // Instruction from instruction memory
    output [31:0] dmem_addr,   // Data memory address
    inout  [31:0] dmem_data,   // Data memory data bus
    output dmem_wen          // Data memory write enable (0 for load, 1 for store)
);

    // Pipeline registers definitions
    // IF/ID pipeline register
    reg [31:0] if_id_pc;
    reg [31:0] if_id_insn;

    // ID/EX pipeline register
    reg [31:0] id_ex_pc;
    reg [31:0] id_ex_rs1;
    reg [31:0] id_ex_imm;
    reg [4:0]  id_ex_rd;
    reg        id_ex_reg_write;  // Indicates if the instruction writes to a register

    // EX/MEM pipeline register
    reg [31:0] ex_mem_pc;
    reg [31:0] ex_mem_alu_result;
    reg [4:0]  ex_mem_rd;
    reg        ex_mem_reg_write;

    // MEM/WB pipeline register
    reg [31:0] mem_wb_pc;
    reg [31:0] mem_wb_wb_data;
    reg [4:0]  mem_wb_rd;
    reg        mem_wb_reg_write;

    // 16-bit cycle counter
    reg [15:0] cycle_counter;

    // PC module instance
    wire [31:0] pc_reg;
    wire stall;
    wire [31:0] next_pc;
    PC pc_inst(
        .rst_n(rst_n),
        .clk(clk),
        .stall(stall),
        .next_pc(next_pc),
        .pc(pc_reg)
    );

    // Drive instruction memory address from PC
    assign imem_addr = pc_reg;

    // For dmem interface, addi does not access memory.
    // Forward the ALU result (from EX stage) as address and disable writes.
    assign dmem_addr = ex_mem_alu_result;
    assign dmem_wen  = 1'b0;
    // Set dmem_data to high impedance (unused).
    assign dmem_data = 32'bz;

    // Instruction NOP (using addi x0, x0, 0) to represent bubbles
    localparam [31:0] NOP = 32'h00000013;

    // Hazard detection: stall if the instruction in ID stage depends on a previous
    // instruction's result (only one source register, rs1, is used for addi).
    wire [4:0] id_rs1 = if_id_insn[19:15];
    assign stall = ((id_rs1 != 5'b0) && (
                      (id_ex_reg_write && (id_ex_rd == id_rs1)) ||
                      (ex_mem_reg_write && (ex_mem_rd == id_rs1))
                    ));

    // Next PC: if stalling then hold; otherwise, increment by 4.
    assign next_pc = stall ? pc_reg : (pc_reg + 4);

    // File handles for trace outputs
    integer pc_trace_file, reg_trace_file;

    // Register file instantiation (see Registers.sv)
    // For addi, we only need to read rs1.
    wire [31:0] reg_data1;
    Registers reg_file(
        .clk(clk),
        .rst_n(rst_n),
        .reg_write(mem_wb_reg_write),
        .write_reg(mem_wb_rd),
        .write_data(mem_wb_wb_data),
        .read_reg1(if_id_insn[19:15]),
        .read_reg2(if_id_insn[24:20]), // not used for addi
        .read_data1(reg_data1),
        .read_data2() // not used
    );

    // ALU and ALUDecoder instantiation
    wire [3:0] alu_ctrl;
    // For addi, funct3 is in bits [14:12] of the instruction.
    ALUDecoder alu_dec(
        .funct3(if_id_insn[14:12]),
        .alu_ctrl(alu_ctrl)
    );

    wire [31:0] alu_result;
    ALU alu_inst(
        .op1(id_ex_rs1),
        .op2(id_ex_imm),
        .alu_ctrl(alu_ctrl),
        .result(alu_result)
    );

    // Cycle counter and trace file initialization
    initial begin
        cycle_counter = 16'b0;
        pc_trace_file = $fopen("pc_trace.txt");
        reg_trace_file = $fopen("reg_trace.txt");
    end

    // Pipeline and cycle counter update on every clock cycle
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all pipeline registers and counter
            if_id_pc       <= 32'b0;
            if_id_insn     <= NOP;
            id_ex_pc       <= 32'b0;
            id_ex_rs1      <= 32'b0;
            id_ex_imm      <= 32'b0;
            id_ex_rd       <= 5'b0;
            id_ex_reg_write<= 1'b0;
            ex_mem_pc      <= 32'b0;
            ex_mem_alu_result <= 32'b0;
            ex_mem_rd      <= 5'b0;
            ex_mem_reg_write <= 1'b0;
            mem_wb_pc      <= 32'b0;
            mem_wb_wb_data <= 32'b0;
            mem_wb_rd      <= 5'b0;
            mem_wb_reg_write <= 1'b0;
            cycle_counter  <= 16'b0;
        end else begin
            cycle_counter <= cycle_counter + 1;

            // Write PC trace (hexadecimal) from the IF stage
            $fdisplay(pc_trace_file, "%h", pc_reg);

            // IF stage: latch instruction (if not stalling)
            if (!stall) begin
                if_id_pc   <= pc_reg;
                if_id_insn <= imem_insn;
            end
            // Otherwise, hold IF/ID registers

            // ID stage: decode the instruction
            // For addi, extract rs1, rd, and sign-extended immediate
            if (!stall) begin
                id_ex_pc        <= if_id_pc;
                id_ex_rs1       <= reg_data1;
                id_ex_imm       <= {{20{if_id_insn[31]}}, if_id_insn[31:20]};
                id_ex_rd        <= if_id_insn[11:7];
                id_ex_reg_write <= (if_id_insn[11:7] != 5'b0);
            end else begin
                // Insert a bubble in the ID/EX stage
                id_ex_pc        <= 32'b0;
                id_ex_rs1       <= 32'b0;
                id_ex_imm       <= 32'b0;
                id_ex_rd        <= 5'b0;
                id_ex_reg_write <= 1'b0;
            end

            // EX stage: perform ALU operation (for addi, simply add rs1 and immediate)
            ex_mem_pc         <= id_ex_pc;
            ex_mem_alu_result <= alu_result;
            ex_mem_rd         <= id_ex_rd;
            ex_mem_reg_write  <= id_ex_reg_write;

            // MEM stage: for addi, no memory access; pass ALU result to WB stage.
            mem_wb_pc         <= ex_mem_pc;
            mem_wb_wb_data    <= ex_mem_alu_result;
            mem_wb_rd         <= ex_mem_rd;
            mem_wb_reg_write  <= ex_mem_reg_write;

            // WB stage: register file update is handled in the Registers module.
            // Print register write trace if a register is being written.
            if (mem_wb_reg_write && (mem_wb_rd != 5'b0)) begin
                $fdisplay(reg_trace_file, "Cycle %0d: Reg %0d = %h", cycle_counter, mem_wb_rd, mem_wb_wb_data);
            end
        end
    end

endmodule
