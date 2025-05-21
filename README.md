# 5-Stage Pipelined RV32I CPU

Authors:
- Haydon Behl
- Mihir Phadke
- Ryan Smith

Overview:
The repository documents the complete development process of a custom 5-stage pipelined RISC-V RV32I compatible CPU which was created for CMPE 140 Computer Architecture labs at San Jose State University. The development of the CPU pipeline progressed through five consecutive labs which began with a basic pipeline structure before moving to arithmetic operations and memory access and hazard resolution and ended with complete control-flow functionality.

Directory Structure:
  * CMPE140/
    - Lab-3/: Basic 5-stage pipeline skeleton with IF/ID, ID/EX, EX/MEM, MEM/WB registers and stall-based RAW hazard detection.
      * `cpu.sv`, `instruction_decoder.sv`, `PC.sv`, `register_file.sv`, simple testbench.
      * Report: `CMPE140_lab3_report.pdf` explains pipeline breaks, stall logic, and initial PC tracing.
    - Lab-4/: Added full R- and I-type ALU support and simple forwarding to reduce stalls.
      * Extended decoder (funct3/funct7/shamt), ALU modules, forwarding logic.
      * Report: `CMPE140_lab4_report.pdf` details ALU design and verify arithmetic sequences.
    - Lab-5/: Introduced load/store (S- and I-type memory ops), data memory interface, byte-granular writes, and two-operand forwarding.
      * RAM/ROM modules, updated control signals, store-data pipelines.
      * Report: `CMPE140_lab5_report.pdf` covers memory timing, byte enables, and hazard paths.
    - Lab-6/: Completed the MEM stage, implemented sign/zero extension for LB/LH/LBU/LHU, and fixed load-use hazards.
      * Full load extraction logic, X-bit masking, and test vectors in `ldst.asm`/`ldst.dat`.
      * Report: `CMPE140_lab6_report.pdf` walks through data correctness and cycle-accurate traces.
    - Lab-7/: Finalized control hazards, B-type branches (BEQ/BNE/BLT/BGE/BLTU/BGEU), and J-type jumps (JAL/JALR), with pipeline flushing.
      * Comprehensive instruction decoder, branch/jump decision in EX stage, IF/ID flush, PC override.
      * Report: `CMPE140_lab7_report.pdf` presents loop benchmarks and PC/data trace outputs.

  * Processor/: Unified, polished version of the CPU integrating all lab features.
    - Source: `cpu.sv`, `PC.sv`, `instruction_decoder.sv`, `ALU.sv`, `register_file.sv`, `ram.sv`, `rom.sv`, `tb.sv`.
    - Data files: `line.asm` (sample program), `line.dat` (instruction ROM image), `dmem.dat` (initial data RAM image).
    - Simulation: testbench produces `pc.txt` and `data.txt` for post-run analysis.

Getting Started:
---------------
Requirements:
  - Any standard SystemVerilog simulator (Vivado, Icarus Verilog, ModelSim, etc.)

Each subdirectory under CMPE140 includes a detailed PDF report describing design rationale, implementation details, and waveform/cycle analyses. Use these reports to follow the evolution of the CPU architecture from a simple pipeline to a fully-featured RISC-V core.

License:
--------
For academic use; see individual lab reports for attribution and further details.
