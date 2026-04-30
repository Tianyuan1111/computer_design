// Generated automatically via PyRTL
// As one initial test of synthesis, map to FPGA with:
//   yosys -p "synth_xilinx -top toplevel" thisfile.v

module toplevel(clk, reset, out_PC, out_Z, out_halt);
    input clk;
    input reset;
    output[7:0] out_PC;
    output out_Z;
    output out_halt;

    // Memories
    reg[7:0] regs[7:0];  // MemBlock
    reg[7:0] mem[255:0];  // MemBlock
    reg[15:0] instr_mem[255:0];  // MemBlock

    // Registers
    reg[7:0] PC;
    reg Z;

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
    wire[7:0] tmp7;
    wire[7:0] tmp8;
    wire tmp11;
    wire[8:0] tmp12;
    wire tmp16;
    wire[8:0] tmp17;
    wire tmp31;
    wire tmp38;
    wire tmp43;
    wire tmp50;
    wire tmp73;
    wire tmp77;
    wire[7:0] tmp89;
    wire[8:0] tmp123;
    wire[9:0] tmp127;
    wire[7:0] tmp143;
    wire[2:0] w_addr;
    wire z_wen;

    // Combinational logic
    assign alu_result = ((~(tmp11) & ~(tmp16)) ? 8'd0 : ((~(tmp11) & tmp16) ? (tmp17[7:0]) : (tmp11 ? (tmp12[7:0]) : {{7 {1'd0}}, 1'd0})));
    assign branch_taken = ((opcode == {(1'd0), 3'd5}) & Z);
    assign final_pc = (~(halt) ? next_pc : (halt ? PC : {{7 {1'd0}}, 1'd0}));
    assign halt = (opcode == {(1'd0), 3'd7});
    assign imm8 = rb_imm;
    assign instr = tmp0;
    assign mem_addr = ((~(tmp73) & ~(tmp77)) ? 8'd0 : ((~(tmp73) & tmp77) ? (rdata1[7:0]) : (tmp73 ? (rdata2[7:0]) : {{7 {1'd0}}, 1'd0})));
    assign mem_rdata = tmp89;
    assign mem_wdata = rdata2;
    assign mem_wen = (opcode == {(1'd0), 3'd4});
    assign mem_write_enabled = (mem_wen & ~(reset));
    assign next_pc = (~(branch_taken) ? (tmp123[7:0]) : (branch_taken ? (tmp127[7:0]) : {{7 {1'd0}}, 1'd0}));
    assign opcode = (instr[15:12]);
    assign out_PC = PC;
    assign out_Z = Z;
    assign out_halt = halt;
    assign ra = (instr[11:8]);
    assign rb = (rb_imm[7:4]);
    assign rb_imm = (instr[7:0]);
    assign rdata1 = tmp7;
    assign rdata2 = tmp8;
    assign reg_wdata = ((((~(tmp31) & ~(tmp38)) & ~(tmp43)) & ~(tmp50)) ? 8'd0 : ((((~(tmp31) & ~(tmp38)) & ~(tmp43)) & tmp50) ? rdata2 : (((~(tmp31) & ~(tmp38)) & tmp43) ? mem_rdata : ((~(tmp31) & tmp38) ? alu_result : (tmp31 ? imm8 : {{7 {1'd0}}, 1'd0})))));
    assign reg_wen = (((((opcode == {{3 {1'd0}}, 1'd0}) | (opcode == {{3 {1'd0}}, 1'd1})) | (opcode == {{2 {1'd0}}, 2'd2})) | (opcode == {{2 {1'd0}}, 2'd3})) | (opcode == {(1'd0), 3'd6}));
    assign tmp5 = (ra[2:0]);
    assign tmp11 = (opcode == {{3 {1'd0}}, 1'd1});
    assign tmp12 = (rdata1 + rdata2);
    assign tmp16 = (opcode == {{2 {1'd0}}, 2'd2});
    assign tmp17 = (rdata1 - rdata2);
    assign tmp31 = (opcode == {{3 {1'd0}}, 1'd0});
    assign tmp38 = ((opcode == {{3 {1'd0}}, 1'd1}) | (opcode == {{2 {1'd0}}, 2'd2}));
    assign tmp43 = (opcode == {{2 {1'd0}}, 2'd3});
    assign tmp50 = (opcode == {(1'd0), 3'd6});
    assign tmp73 = (opcode == {{2 {1'd0}}, 2'd3});
    assign tmp77 = (opcode == {(1'd0), 3'd4});
    assign tmp123 = (PC + 8'd1);
    assign tmp127 = (tmp123 + {(1'd0), imm8});
    assign w_addr = tmp5;
    assign z_wen = ((opcode == {{3 {1'd0}}, 1'd1}) | (opcode == {{2 {1'd0}}, 2'd2}));

    // Register logic
    always @(posedge clk) begin
        PC <= (reset ? {{7 {1'd0}}, 1'd0} : final_pc);
        Z <= (reset ? 1'd0 : (z_wen ? (8'd0 == reg_wdata) : Z));
    end

    // MemBlock regs logic
    always @(posedge clk) begin
        regs[w_addr] <= (reset ? {{7 {1'd0}}, 1'd0} : (reg_wen ? reg_wdata : tmp143));
    end
    assign tmp7 = regs[tmp5];
    assign tmp8 = regs[(rb[2:0])];
    assign tmp143 = regs[w_addr];

    // MemBlock mem logic
    always @(posedge clk) begin
        if ((mem_write_enabled ? 1'd1 : 1'd0)) begin
            mem[mem_addr] <= mem_wdata;
        end
    end
    assign tmp89 = mem[mem_addr];

    // MemBlock instr_mem logic
    assign tmp0 = instr_mem[PC];
endmodule
