`timescale 1ns / 1ps

module cpu(
    input         rst_n,
    input         clk,
    output [31:0] imem_addr,
    input  [31:0] imem_insn,
    output reg [31:0] dmem_addr,
    inout  [31:0] dmem_data,
    output reg        dmem_wen,
    output      [3:0] byte_en
);
    // Stall signal (for hazards)
    reg stall;

    //-------------------------------------------------------
    // Pipeline Registers
    //-------------------------------------------------------
    // IF/ID pipeline registers
    reg [31:0] IF_ID_insn, IF_ID_pc;
    reg ID_wen;
    reg ID_dmem_wen;
    // A flush register to clear IF/ID on branch/jump.
    reg flush_pipeline;
    
    // ID/EX pipeline registers
    reg [31:0] ID_EX_pc, ID_EX_imm;
    reg [4:0]  ID_EX_dest, ID_EX_src1, ID_EX_src2;
    reg [2:0]  ID_EX_insn_type;
    reg [2:0]  ID_EX_funct3;
    reg [4:0]  ID_EX_shamt;
    reg [6:0]  ID_EX_funct7;
    reg        ID_EX_alu_op_mux;
    reg        ID_EX_wen;
    reg        ID_EX_dmem_wen;
    reg [31:0] ID_EX_store_data;
    
    // EX/MEM pipeline registers
    reg [31:0] EX_MEM_alu_result;
    reg [4:0]  EX_MEM_dest;
    reg        EX_MEM_wen;
    reg        EX_MEM_dmem_wen;
    reg [2:0]  EX_MEM_insn_type;  // (e.g. 010: store, 011: load)
    reg [2:0]  EX_MEM_funct3;
    reg [31:0] EX_MEM_store_data;
    
    // MEM/WB pipeline registers
    reg signed [31:0] MEM_WB_result;
    reg [4:0]         MEM_WB_dest;
    reg               MEM_WB_wen;
    reg [2:0]         MEM_WB_insn_type;
    reg [2:0]         MEM_WB_funct3;
    reg [31:0]        MEM_WB_alu_result;
    reg [31:0]        MEM_WB_ram_result;

    //-------------------------------------------------------
    // dmem_data Tri-state Control & Byte Enable Signals
    //-------------------------------------------------------
    reg [31:0] dmem_data_out;
    assign dmem_data = (dmem_wen) ? dmem_data_out : 32'hz;
    
    reg [3:0] byte_en_dmem_reg;
    assign byte_en = byte_en_dmem_reg;
    reg [3:0] byte_en_reg;  // For register file (if needed)

    //-------------------------------------------------------
    // Cycle Counter (for debugging/tracing)
    //-------------------------------------------------------
    reg [15:0] cycle_counter;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cycle_counter <= 16'b0;
        else
            cycle_counter <= cycle_counter + 1;
    end

    //-------------------------------------------------------
    // Program Counter (PC) Module Instantiation
    // The PC now accepts branch/jump override signals.
    //-------------------------------------------------------
    wire [31:0] pc;
    wire branch_jump;
    wire [31:0] new_pc;
    
    PC pc_module(
        .rst_n(rst_n),
        .clk(clk),
        .stall(stall),
        .branch_jump(branch_jump),
        .new_pc(new_pc),
        .pc(pc)
    );
    
    // The instruction memory address is driven by the PC.
    assign imem_addr = pc;

    //-------------------------------------------------------
    // Flush Pipeline Register
    // We register the branch/jump decision (from EX stage) so that the IF/ID
    // registers are flushed in the next clock cycle.
    //-------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            flush_pipeline <= 1'b0;
        else
            flush_pipeline <= branch_jump;
    end

    //-------------------------------------------------------
    // Instruction Fetch (IF) Stage with Flush Logic
    //-------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            IF_ID_insn <= 32'b0;
            IF_ID_pc   <= 32'b0;
        end else if (flush_pipeline) begin
            // Flush the pipeline by inserting a NOP (all zeros)
            IF_ID_insn <= 32'b0;
            IF_ID_pc   <= 32'b0;
        end else begin
            IF_ID_insn <= imem_insn;
            IF_ID_pc   <= pc;
        end
    end

    //-------------------------------------------------------
    // Decode Stage: Instruction Decoder Instantiation
    //-------------------------------------------------------
    // Our updated decoder outputs a 32-bit immediate.
    wire [4:0] destination_reg;
    wire [2:0] funct3;
    wire [4:0] source_reg1;
    wire [4:0] source_reg2;
    wire [31:0] imm;
    wire [6:0] funct7;
    wire [4:0] shamt;
    wire [2:0] insn_type;
    // insn_type encoding: 
    // 000: I-type, 001: R-type, 010: S-type, 011: Load,
    // 100: U-type, 101: J-type, 110: Branch, 111: Default (NOP)
    wire alu_op_mux;
    
    instruction_decoder decoder (
        .imem_insn(IF_ID_insn),
        .destination_reg(destination_reg),
        .funct3(funct3),
        .source_reg1(source_reg1),
        .source_reg2(source_reg2),
        .imm(imm),
        .funct7(funct7),
        .shamt(shamt),
        .insn_type(insn_type),
        .alu_op_mux(alu_op_mux),
        .wen(ID_wen),
        .dmem_wen(ID_dmem_wen)
    );

    //-------------------------------------------------------
    // ID/EX Pipeline Register Update
    // (If IF/ID is flushed, the decoder outputs a NOP.)
    //-------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ID_EX_pc         <= 32'b0;
            ID_EX_dest       <= 5'b0;
            ID_EX_src1       <= 5'b0;
            ID_EX_src2       <= 5'b0;
            ID_EX_imm        <= 32'b0;
            ID_EX_funct3     <= 3'b0;
            ID_EX_funct7     <= 7'b0;
            ID_EX_insn_type  <= 3'b111;  // Default to NOP
            ID_EX_shamt      <= 5'b0;
            ID_EX_alu_op_mux <= 1'b0;
            ID_EX_wen        <= 1'b0;
            ID_EX_dmem_wen   <= 1'b0;
            ID_EX_store_data <= 32'b0;
        end else begin
            ID_EX_pc         <= IF_ID_pc;
            ID_EX_dest       <= destination_reg;
            ID_EX_src1       <= source_reg1;
            ID_EX_src2       <= source_reg2;
            ID_EX_insn_type  <= insn_type;
            ID_EX_funct3     <= funct3;
            ID_EX_funct7     <= funct7;
            ID_EX_shamt      <= shamt;
            ID_EX_alu_op_mux <= alu_op_mux;
            ID_EX_imm        <= imm;
            ID_EX_wen        <= ID_wen;
            ID_EX_dmem_wen   <= ID_dmem_wen;
        end
    end

    //-------------------------------------------------------
    // Register File Instance
    //-------------------------------------------------------
    wire [31:0] reg_data1;
    wire [31:0] reg_data2;
    register_file reg_file (
        .clk(clk),
        .rst_n(rst_n),
        .wen(MEM_WB_wen),
        .destination_reg(MEM_WB_dest),
        .source_reg1(ID_EX_src1),
        .source_reg2(ID_EX_src2),
        .write_data(MEM_WB_result),
        .byte_en(byte_en_reg),
        .read_data1(reg_data1),
        .read_data2(reg_data2)
    );

    //-------------------------------------------------------
    // Forwarding Logic (for ALU operands)
    //-------------------------------------------------------
    wire [31:0] forwarded_op1;
    wire [31:0] forwarded_op2;

    // Register "skips" for when the requested data is not yet written to reg.
    assign forwarded_op1 = ((EX_MEM_dest != 5'b0) && (EX_MEM_dest == ID_EX_src1) && EX_MEM_wen) ? EX_MEM_alu_result :
                            ((MEM_WB_dest != 5'b0) && (MEM_WB_dest == ID_EX_src1) && MEM_WB_wen) ? MEM_WB_result :
                            reg_data1;
    assign forwarded_op2 = (ID_EX_alu_op_mux) ? ID_EX_imm :
                            ((EX_MEM_dest != 5'b0) && (EX_MEM_dest == ID_EX_src2) && EX_MEM_wen) ? EX_MEM_alu_result :
                            ((MEM_WB_dest != 5'b0) && (MEM_WB_dest == ID_EX_src2) && MEM_WB_wen) ? MEM_WB_result :
                            reg_data2;

    //-------------------------------------------------------
    // ALU Operand for Jump Instructions
    // For JAL, the base should be the PC. For JALR, use register.
    //-------------------------------------------------------
    wire [31:0] alu_op1;
    assign alu_op1 = ((ID_EX_insn_type == 3'b101) && (ID_EX_src1 == 5'b0)) ? ID_EX_pc : forwarded_op1;

    //-------------------------------------------------------
    // Execute (EX) Stage: ALU Instance
    //-------------------------------------------------------
    wire [31:0] alu_result;
    ALU alu (
        .op1(alu_op1),
        .op2(forwarded_op2),
        .shamt(ID_EX_shamt),
        .funct3(ID_EX_funct3),
        .funct7(ID_EX_funct7),
        .insn_type(ID_EX_insn_type),
        .result(alu_result)
    );
    
    //-------------------------------------------------------
    // Branch Decision & Target Computation (EX Stage)
    //-------------------------------------------------------
    wire branch_taken;
    wire [31:0] branch_target;

    assign branch_taken = (ID_EX_insn_type == 3'b110) ?
        ((ID_EX_funct3 == 3'b000) ? (forwarded_op1 == forwarded_op2) :  // BEQ
        (ID_EX_funct3 == 3'b001) ? (forwarded_op1 != forwarded_op2) :  // BNE
        (ID_EX_funct3 == 3'b100) ? ($signed(forwarded_op1) < $signed(forwarded_op2)) :  // BLT
        (ID_EX_funct3 == 3'b101) ? ($signed(forwarded_op1) >= $signed(forwarded_op2)) : // BGE
        (ID_EX_funct3 == 3'b110) ? (forwarded_op1 < forwarded_op2) :   // BLTU
        (ID_EX_funct3 == 3'b111) ? (forwarded_op1 >= forwarded_op2) :  // BGEU
        1'b0)
        : 1'b0;

    assign branch_target = ID_EX_pc + ID_EX_imm;

    //-------------------------------------------------------
    // Branch/Jump Control Signals for PC Update
    // For jumps (insn_type 3'b101) the branch is unconditional.
    // For branches (insn_type 3'b110) use branch_taken.
    //-------------------------------------------------------
    assign branch_jump = ((ID_EX_insn_type == 3'b101) || ((ID_EX_insn_type == 3'b110) && branch_taken));
    // For jump instructions, use the ALU result as target; for branch instructions, use branch_target.
    assign new_pc = (ID_EX_insn_type == 3'b101) ? alu_result : branch_target;

    //-------------------------------------------------------
    // EX/MEM Pipeline Register Update
    //-------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            EX_MEM_alu_result <= 32'b0;
            EX_MEM_dest       <= 5'b0;
            EX_MEM_wen        <= 1'b0;
            EX_MEM_dmem_wen   <= 1'b0;
            EX_MEM_funct3     <= 3'b0;
            EX_MEM_insn_type  <= 3'b0;
            EX_MEM_store_data <= 32'b0;
        end else begin
            EX_MEM_alu_result <= alu_result;
            EX_MEM_dest       <= ID_EX_dest;
            EX_MEM_wen        <= ID_EX_wen;
            EX_MEM_dmem_wen   <= ID_EX_dmem_wen;
            EX_MEM_funct3     <= ID_EX_funct3;
            EX_MEM_insn_type  <= ID_EX_insn_type;
            EX_MEM_store_data <= ID_EX_store_data;
        end
    end

    //-------------------------------------------------------
    // Memory (MEM) Stage
    //-------------------------------------------------------
    // Fix X values on dmem_data.
    wire [31:0] fixed_data;
    genvar i;
    generate
        for(i = 0; i < 32; i = i + 1) begin : fix_x_bits
            assign fixed_data[i] = (dmem_data[i] === 1'bx) ? 1'b1 : dmem_data[i];
        end
    endgenerate

    // Load extraction logic (active for load instructions, insn_type 3'b011)
    wire [31:0] load_result;
    assign load_result = (MEM_WB_insn_type == 3'b011) ? (
        (MEM_WB_funct3 == 3'b000) ? { {24{fixed_data[7]}},  fixed_data[7:0]} : // LB
        (MEM_WB_funct3 == 3'b001) ? { {16{fixed_data[15]}}, fixed_data[15:0]} : // LH
        (MEM_WB_funct3 == 3'b010) ? fixed_data :                              // LW
        (MEM_WB_funct3 == 3'b100) ? {24'b0, fixed_data[7:0]} :                // LBU
        (MEM_WB_funct3 == 3'b101) ? {16'b0, fixed_data[15:0]} :               // LHU
        fixed_data
    ) : 32'b0;

    // Write-back selection: use load_result for loads; otherwise use the ALU result.
    assign MEM_WB_result = (MEM_WB_insn_type == 3'b011) ? load_result : MEM_WB_alu_result;

    //-------------------------------------------------------
    // MEM/WB Pipeline Register Update
    //-------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            MEM_WB_alu_result <= 32'b0;
            MEM_WB_dest     <= 5'b0;
            MEM_WB_wen      <= 1'b0;
            MEM_WB_insn_type<= 3'b0;
            MEM_WB_funct3   <= 3'b0;
            dmem_wen        <= 1'b0;
            dmem_addr       <= 32'b0;
            byte_en_dmem_reg<= 4'b0;
            byte_en_reg     <= 4'b0;
        end else begin
            dmem_data_out = EX_MEM_store_data;
            if (EX_MEM_insn_type == 3'b011) begin 
                dmem_addr <= EX_MEM_alu_result; // Effective address for load
                byte_en_dmem_reg <= 4'b0000;
                byte_en_reg <= 4'b1111;
            end else if (EX_MEM_insn_type == 3'b010) begin
                dmem_addr <= EX_MEM_alu_result; // Effective address for store
                case (EX_MEM_funct3)
                    3'b000: byte_en_dmem_reg <= 4'b0001; // SB
                    3'b001: byte_en_dmem_reg <= 4'b0011; // SH
                    3'b010: byte_en_dmem_reg <= 4'b1111; // SW
                    default: byte_en_dmem_reg <= 4'b0000;
                endcase
                byte_en_reg <= 4'b0000;
            end else begin
                dmem_addr <= 32'b0;
                byte_en_dmem_reg <= 4'b0000;
                byte_en_reg <= 4'b1111; 
            end

            MEM_WB_funct3    <= EX_MEM_funct3;
            MEM_WB_alu_result<= EX_MEM_alu_result;
            MEM_WB_dest      <= EX_MEM_dest;
            MEM_WB_wen       <= EX_MEM_wen;
            MEM_WB_insn_type <= EX_MEM_insn_type;
            dmem_wen         <= EX_MEM_dmem_wen;
        end
    end

    //-------------------------------------------------------
    // File Trace Output (for debugging/tracing)
    //-------------------------------------------------------
    integer fd_pc, fd_data;
    initial begin
        fd_pc = $fopen("pc.txt", "w");
        fd_data = $fopen("data.txt", "w");
        if (fd_pc == 0 || fd_data == 0) begin
            $display("Error: Could not open file.");
            $finish;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (rst_n) begin
            $display("IF_ID_pc: %h, MEM_WB_result: %h, MEM_WB_dest: %h", IF_ID_pc, MEM_WB_result, MEM_WB_dest);
            $fdisplay(fd_pc, "PC: 0x%h", IF_ID_pc);
            $fdisplay(fd_data, "MEM_WB_result: %d", MEM_WB_result);
            $fdisplay(fd_data, "MEM_WB_dest: %d", MEM_WB_dest);
            $fdisplay(fd_data, "-----------------------------------");
        end
    end

    initial begin
        #1000
        $fclose(fd_pc);
        $fclose(fd_data);
        $display("Files closed successfully.");
    end

endmodule
