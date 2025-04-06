`timescale 1ns / 1ps

module cpu(
    input         rst_n,
    input         clk,
    output reg [31:0] imem_addr,
    input  [31:0] imem_insn,
    output reg [31:0] dmem_addr,
    inout  [31:0] dmem_data,
    output reg        dmem_wen,
    output      [3:0] byte_en
);
    // Stall register
    reg stall;
    
    // IF/ID pipeline registers
    reg [31:0] IF_ID_insn, IF_ID_pc;
    reg ID_wen;
    reg ID_dmem_wen;
    
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
    reg [2:0]  EX_MEM_insn_type;  // distinguishes load (3'b011) vs. store (3'b010)
    reg [2:0]  EX_MEM_funct3;
    reg [31:0] EX_MEM_store_data; // Propagated store data
    
    // MEM/WB pipeline registers
    reg signed [31:0] MEM_WB_result;
    reg [4:0]         MEM_WB_dest;
    reg               MEM_WB_wen;
    reg [2:0]         MEM_WB_insn_type;
    reg [2:0]         MEM_WB_funct3;
    reg [31:0]        MEM_WB_alu_result;
    reg [31:0]        MEM_WB_ram_result;

    // dmem_data tri-state control:
    // dmem_data is driven by dmem_data_out when writing;
    // otherwise it is tri-stated so that RAM can drive it during loads.
    reg [31:0] dmem_data_out;
    assign dmem_data = (dmem_wen) ? dmem_data_out : 32'hz;
    
    // byte_en output and its internal register. For RAM
    reg [3:0] byte_en_dmem_reg;
    assign byte_en = byte_en_dmem_reg;
    // byte_en internal register. For regfile
    reg [3:0] byte_en_reg;

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
        .pc(pc)
    );
    always @(*) begin
        imem_addr = pc;
    end

    // Instruction Fetch Stage
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            IF_ID_insn <= 32'b0;
            IF_ID_pc   <= 32'b0;
        end else begin
            IF_ID_insn <= imem_insn;
            IF_ID_pc   <= pc;
        end
    end

    // Decode Stage: Instruction Decoder instantiation.
    wire [4:0] destination_reg;
    wire [2:0] funct3;
    wire [4:0] source_reg1;
    wire [4:0] source_reg2;
    wire [11:0] imm;
    wire [6:0] funct7;
    wire [4:0] shamt;
    wire [2:0] insn_type; 
    wire alu_op_mux;
    wire wen;
    
    instruction_decoder decoder(
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

    // ID/EX Pipeline Register Update (including store data capture)
    // For store instructions, the store data comes from reg_data2.
    // (If needed, you might add forwarding for store data as well.)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ID_EX_pc         <= 32'b0;
            ID_EX_dest       <= 5'b0;
            ID_EX_src1       <= 5'b0;
            ID_EX_src2       <= 5'b0;
            ID_EX_imm        <= 32'b0;
            ID_EX_funct3     <= 3'b0;
            ID_EX_funct7     <= 7'b0;
            ID_EX_insn_type  <= 3'b111;
            ID_EX_shamt      <= 5'b0;
            ID_EX_alu_op_mux <= 0;
            ID_EX_wen        <= 0;
            ID_EX_dmem_wen   <= 0;
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
            ID_EX_imm        <= {{20{imm[11]}}, imm};
            ID_EX_wen        <= ID_wen;
            ID_EX_dmem_wen   <= ID_dmem_wen;
        end
    end

    // Register File Instance
    wire [31:0] reg_data1;
    wire [31:0] reg_data2;
    register_file reg_file(
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

    // Forwarding Logic
    reg [31:0] forwarded_op1;
    reg [31:0] forwarded_op2;
    reg ram_forward_flag = 1'b0;
    always @(*) begin
        forwarded_op1 = reg_data1;
        forwarded_op2 = reg_data2;

        // Register "skips" for when the requested data is not yet written to reg.
        if ((EX_MEM_dest != 5'b0) && (EX_MEM_dest == ID_EX_src1) && EX_MEM_wen) begin
            forwarded_op1 = EX_MEM_alu_result;
        end else if ((MEM_WB_dest != 5'b0) && (MEM_WB_dest == ID_EX_src1) && MEM_WB_wen) begin
            forwarded_op1 = MEM_WB_result;
        end

        if ((EX_MEM_dest != 5'b0) && (EX_MEM_dest == ID_EX_src2) && EX_MEM_wen) begin 
            forwarded_op2 = EX_MEM_alu_result;
        end else if ((MEM_WB_dest != 5'b0) && (MEM_WB_dest == ID_EX_src2) && MEM_WB_wen) begin
            forwarded_op2 = MEM_WB_result;
        end

        if (ID_EX_alu_op_mux)
            forwarded_op2 = ID_EX_imm;
    end

    // Execute Stage: ALU instance.
    wire [31:0] alu_result;
    ALU alu(
        .op1(forwarded_op1),
        .op2(forwarded_op2),
        .shamt(ID_EX_shamt),
        .funct3(ID_EX_funct3),
        .funct7(ID_EX_funct7),
        .insn_type(ID_EX_insn_type),
        .result(alu_result)
    );
    
    // EX/MEM Pipeline Register Update (propagating store data)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            EX_MEM_alu_result <= 32'b0;
            EX_MEM_dest       <= 5'b0;
            EX_MEM_wen        <= 1'b0;
            EX_MEM_dmem_wen   <= 1'b0;
            EX_MEM_funct3     <= 3'b0;
            EX_MEM_insn_type  <= 3'b0;
            EX_MEM_store_data <= 32'b0;
            ram_forward_flag  <= 1'b0;
        end else begin
            EX_MEM_alu_result <= alu_result;
            EX_MEM_dest       <= ID_EX_dest;
            EX_MEM_wen        <= ID_EX_wen;
            EX_MEM_dmem_wen   <= ID_EX_dmem_wen;
            EX_MEM_funct3     <= ID_EX_funct3;    // Propagate store type info
            EX_MEM_insn_type  <= ID_EX_insn_type; // 3'b010: store, 3'b011: load
            EX_MEM_store_data <= ID_EX_store_data;
            
            // Load / Store, capture store data from forwarding before passing imm offset value
            if (ram_forward_flag == 1'b1) begin
                EX_MEM_store_data = MEM_WB_result;
                ram_forward_flag = 1'b0;
            end 
            if ((ID_EX_insn_type == 3'b010) && (EX_MEM_dest != 5'b0) && (EX_MEM_dest == ID_EX_src2) && EX_MEM_wen) begin 
                ID_EX_store_data = EX_MEM_alu_result; // not needed?
                ram_forward_flag = 1'b1;
            end
        end
    end

    // Used when reading from RAM, for when the memory being accessed is not yet populated
    // Outputs 1 instead of X bits
    wire [31:0] fixed_data;
    genvar i;
    generate
        for(i = 0; i < 32; i = i + 1) begin : fix_x_bits
            assign fixed_data[i] = (dmem_data[i] === 1'bx) ? 1'b1 : dmem_data[i];
        end
    endgenerate
    //assign fixed_data = dmem_data;

    // Combinational Load Extraction in the MEM stage:
    // This wire computes the correctly extracted and extended load value based on
    // the effective address (MEM_WB_alu_result) and funct3. Note that it is valid only when
    // a load instruction (MEM_WB_insn_type == 3'b011) is in the MEM stage.
    wire [31:0] load_result;
    assign load_result = (MEM_WB_insn_type == 3'b011) ? (
        (MEM_WB_funct3 == 3'b000) ? // LB: sign-extended byte
            ( {{24{fixed_data[7]}},  fixed_data[7:0]} )
        : (MEM_WB_funct3 == 3'b001) ? // LH: sign-extended halfword
            ( {{16{fixed_data[15]}}, fixed_data[15:0]} )
        : (MEM_WB_funct3 == 3'b010) ? // LW: load word
            fixed_data
        : (MEM_WB_funct3 == 3'b100) ? // LBU: zero-extended byte
            ( {24'b0, fixed_data[7:0]} )
        : (MEM_WB_funct3 == 3'b101) ? // LHU: zero-extended halfword
            ( {16'b0, fixed_data[15:0]} )
        : fixed_data
    ) : 32'b0;

    // Register Load: capture memory data OR alu results
    assign MEM_WB_result = (MEM_WB_insn_type == 3'b011) ? load_result : MEM_WB_alu_result;

    // MEM/WB Pipeline Register Update:
    // For load instructions (insn_type == 3'b011), capture the data from dmem_data (in fixed_data).
    // For other instructions, pass the ALU result.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            MEM_WB_alu_result <= 32'b0;
            MEM_WB_dest   <= 5'b0;
            MEM_WB_wen    <= 1'b0;
            MEM_WB_insn_type <= 1'b0;
            MEM_WB_funct3 <= 3'b0;
            dmem_wen <= 1'b0;
            byte_en_dmem_reg = 4'b0;
            byte_en_reg = 4'b0;
        end else begin
            dmem_data_out = EX_MEM_store_data;
            if (EX_MEM_insn_type == 3'b011) begin 
                dmem_addr = EX_MEM_alu_result; // Use the effective address computed in EX stage.

                byte_en_dmem_reg = 4'b0000;
                byte_en_reg = 4'b1111;

            end else if (EX_MEM_insn_type == 3'b010) begin
                dmem_addr = EX_MEM_alu_result; // Use the effective address computed in EX stage.
                // When executing a store (insn_type == 3'b010), drive dmem_wen and set byte_en_dmem.
                case (EX_MEM_funct3)
                    3'b000: begin // SB (Store Byte)
                        /*case (EX_MEM_alu_result[1:0])
                            2'b00: byte_en_dmem_reg = 4'b0001;
                            2'b01: byte_en_dmem_reg = 4'b0010;
                            2'b10: byte_en_dmem_reg = 4'b0100;
                            2'b11: byte_en_dmem_reg = 4'b1000;
                            default: byte_en_dmem_reg = 4'b0000;
                        endcase*/
                        byte_en_dmem_reg = 4'b0001;
                    end
                    3'b001: begin // SH (Store Halfword)
                        /*case (EX_MEM_alu_result[1:0])
                            2'b00: byte_en_dmem_reg = 4'b0011; // bytes 0 and 1
                            2'b01: byte_en_dmem_reg = 4'b0110; // example: bytes 1 and 2
                            2'b10: byte_en_dmem_reg = 4'b1100; // bytes 2 and 3
                            2'b11: byte_en_dmem_reg = 4'b1010; // example: wrap-around (if allowed)
                            default: byte_en_dmem_reg = 4'b0000;
                        endcase*/
                        byte_en_dmem_reg = 4'b0011;
                    end
                    3'b010: begin // SW (Store Word)
                        byte_en_dmem_reg = 4'b1111;
                    end
                    default: byte_en_dmem_reg = 4'b0000;
                endcase
                byte_en_reg = 4'b1111;
            end else begin
                dmem_addr = 32'b0;
                byte_en_dmem_reg = 4'b0000;
                byte_en_reg = 4'b1111; 
            end

            MEM_WB_funct3 <= EX_MEM_funct3;
            MEM_WB_alu_result <= EX_MEM_alu_result;
            MEM_WB_dest <= EX_MEM_dest;
            MEM_WB_wen  <= EX_MEM_wen;
            MEM_WB_insn_type <= EX_MEM_insn_type;
            dmem_wen <= EX_MEM_dmem_wen;
        end
    end

    // File Trace Output (for debugging/tracing purposes)
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

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Do nothing on reset.
        end else begin
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
