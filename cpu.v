// Generated automatically via PyRTL
// As one initial test of synthesis, map to FPGA with:
//   yosys -p "synth_xilinx -top toplevel" thisfile.v

module toplevel(clk, reset, out_PC, out_R0, out_R1, out_R2, out_R3, out_Z, out_halt);
    input clk;
    input reset;
    output[7:0] out_PC;
    output[7:0] out_R0;
    output[7:0] out_R1;
    output[7:0] out_R2;
    output[7:0] out_R3;
    output out_Z;
    output out_halt;

    // Memories
    reg[7:0] mem[255:0];  // MemBlock
    reg[15:0] instr_mem[255:0];  // MemBlock

    // Registers
    reg[7:0] PC;
    reg Z;
    reg[7:0] r0;
    reg[7:0] r1;
    reg[7:0] r2;
    reg[7:0] r3;
    reg[7:0] r4;
    reg[7:0] r5;
    reg[7:0] r6;
    reg[7:0] r7;

    // Temporaries
    wire[7:0] alu_result;
    wire branch_taken;
    wire[7:0] final_pc;
    wire halt;
    wire[7:0] imm8;
    wire[15:0] instr;
    wire[7:0] mem_addr;
    wire[7:0] mem_rdata;
    wire[7:0] mem_wdata;
    wire mem_wen;
    wire mem_write_enabled;
    wire[7:0] next_pc;
    wire[3:0] opcode;
    wire[3:0] ra;
    wire[3:0] rb;
    wire[7:0] rb_imm;
    wire[7:0] rdata1;
    wire[7:0] rdata2;
    wire[7:0] reg_wdata;
    wire reg_wen;
    wire[15:0] tmp0;
    wire[2:0] tmp5;
    wire[2:0] tmp6;
    wire[1:0] tmp8;
    wire[1:0] tmp15;
    wire[1:0] tmp24;
    wire[1:0] tmp31;
    wire tmp41;
    wire[8:0] tmp42;
    wire tmp46;
    wire[8:0] tmp47;
    wire tmp61;
    wire tmp68;
    wire tmp73;
    wire tmp80;
    wire tmp103;
    wire tmp107;
    wire[7:0] tmp119;
    wire[8:0] tmp153;
    wire[9:0] tmp157;
    wire[2:0] w_addr;
    wire z_wen;

    // Combinational logic
    assign alu_result = ((~(tmp41) & ~(tmp46)) ? 8'd0 : ((~(tmp41) & tmp46) ? (tmp47[7:0]) : (tmp41 ? (tmp42[7:0]) : {{7 {1'd0}}, 1'd0})));
    assign branch_taken = ((opcode == {(1'd0), 3'd5}) & Z);
    assign final_pc = (~(halt) ? next_pc : (halt ? PC : {{7 {1'd0}}, 1'd0}));
    assign halt = (opcode == {(1'd0), 3'd7});
    assign imm8 = rb_imm;
    assign instr = tmp0;
    assign mem_addr = ((~(tmp103) & ~(tmp107)) ? 8'd0 : ((~(tmp103) & tmp107) ? (rdata1[7:0]) : (tmp103 ? (rdata2[7:0]) : {{7 {1'd0}}, 1'd0})));
    assign mem_rdata = tmp119;
    assign mem_wdata = rdata2;
    assign mem_wen = (opcode == {(1'd0), 3'd4});
    assign mem_write_enabled = (mem_wen & ~(reset));
    assign next_pc = (~(branch_taken) ? (tmp153[7:0]) : (branch_taken ? (tmp157[7:0]) : {{7 {1'd0}}, 1'd0}));
    assign opcode = (instr[15:12]);
    assign out_PC = PC;
    assign out_R0 = r0;
    assign out_R1 = r1;
    assign out_R2 = r2;
    assign out_R3 = r3;
    assign out_Z = Z;
    assign out_halt = halt;
    assign ra = (instr[11:8]);
    assign rb = (rb_imm[7:4]);
    assign rb_imm = (instr[7:0]);
    assign rdata1 = ((tmp5[2]) ? ((tmp15[1]) ? ((tmp15[0]) ? r7 : r6) : ((tmp15[0]) ? r5 : r4)) : ((tmp8[1]) ? ((tmp8[0]) ? r3 : r2) : ((tmp8[0]) ? r1 : r0)));
    assign rdata2 = ((tmp6[2]) ? ((tmp31[1]) ? ((tmp31[0]) ? r7 : r6) : ((tmp31[0]) ? r5 : r4)) : ((tmp24[1]) ? ((tmp24[0]) ? r3 : r2) : ((tmp24[0]) ? r1 : r0)));
    assign reg_wdata = ((((~(tmp61) & ~(tmp68)) & ~(tmp73)) & ~(tmp80)) ? 8'd0 : ((((~(tmp61) & ~(tmp68)) & ~(tmp73)) & tmp80) ? rdata2 : (((~(tmp61) & ~(tmp68)) & tmp73) ? mem_rdata : ((~(tmp61) & tmp68) ? alu_result : (tmp61 ? imm8 : {{7 {1'd0}}, 1'd0})))));
    assign reg_wen = (((((opcode == {{3 {1'd0}}, 1'd0}) | (opcode == {{3 {1'd0}}, 1'd1})) | (opcode == {{2 {1'd0}}, 2'd2})) | (opcode == {{2 {1'd0}}, 2'd3})) | (opcode == {(1'd0), 3'd6}));
    assign tmp5 = (ra[2:0]);
    assign tmp6 = (rb[2:0]);
    assign tmp8 = (tmp5[1:0]);
    assign tmp15 = (tmp5[1:0]);
    assign tmp24 = (tmp6[1:0]);
    assign tmp31 = (tmp6[1:0]);
    assign tmp41 = (opcode == {{3 {1'd0}}, 1'd1});
    assign tmp42 = (rdata1 + rdata2);
    assign tmp46 = (opcode == {{2 {1'd0}}, 2'd2});
    assign tmp47 = (rdata1 - rdata2);
    assign tmp61 = (opcode == {{3 {1'd0}}, 1'd0});
    assign tmp68 = ((opcode == {{3 {1'd0}}, 1'd1}) | (opcode == {{2 {1'd0}}, 2'd2}));
    assign tmp73 = (opcode == {{2 {1'd0}}, 2'd3});
    assign tmp80 = (opcode == {(1'd0), 3'd6});
    assign tmp103 = (opcode == {{2 {1'd0}}, 2'd3});
    assign tmp107 = (opcode == {(1'd0), 3'd4});
    assign tmp153 = (PC + 8'd1);
    assign tmp157 = (tmp153 + {(1'd0), imm8});
    assign w_addr = tmp5;
    assign z_wen = ((opcode == {{3 {1'd0}}, 1'd1}) | (opcode == {{2 {1'd0}}, 2'd2}));

    // Register logic
    always @(posedge clk) begin
        PC <= (reset ? {{7 {1'd0}}, 1'd0} : final_pc);
        Z <= (reset ? 1'd0 : (z_wen ? (8'd0 == reg_wdata) : Z));
        r0 <= (reset ? {{7 {1'd0}}, 1'd0} : ((reg_wen & (3'd0 == w_addr)) ? reg_wdata : r0));
        r1 <= (reset ? {{7 {1'd0}}, 1'd0} : ((reg_wen & (3'd1 == w_addr)) ? reg_wdata : r1));
        r2 <= (reset ? {{7 {1'd0}}, 1'd0} : ((reg_wen & (3'd2 == w_addr)) ? reg_wdata : r2));
        r3 <= (reset ? {{7 {1'd0}}, 1'd0} : ((reg_wen & (3'd3 == w_addr)) ? reg_wdata : r3));
        r4 <= (reset ? {{7 {1'd0}}, 1'd0} : ((reg_wen & (3'd4 == w_addr)) ? reg_wdata : r4));
        r5 <= (reset ? {{7 {1'd0}}, 1'd0} : ((reg_wen & (3'd5 == w_addr)) ? reg_wdata : r5));
        r6 <= (reset ? {{7 {1'd0}}, 1'd0} : ((reg_wen & (3'd6 == w_addr)) ? reg_wdata : r6));
        r7 <= (reset ? {{7 {1'd0}}, 1'd0} : ((reg_wen & (3'd7 == w_addr)) ? reg_wdata : r7));
    end

    // MemBlock mem logic
    always @(posedge clk) begin
        if ((mem_write_enabled ? 1'd1 : 1'd0)) begin
            mem[mem_addr] <= mem_wdata;
        end
    end
    assign tmp119 = mem[mem_addr];

    // MemBlock instr_mem logic
    assign tmp0 = instr_mem[PC];
endmodule
