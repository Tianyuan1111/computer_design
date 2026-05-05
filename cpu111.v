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

    integer init_idx;
    initial begin
        // ==========================================
        // 测试程序：计算 1+2+3+4+5 的和
        // ==========================================
        
        // 0x00: MOV R0, 5    - 将立即数 5 加载到 R0 (循环计数器)
        instr_mem[0] = {4'h0, 4'h0, 8'h05};
        
        // 0x01: MOV R1, 0    - 将立即数 0 加载到 R1 (累加器初始化为0)
        instr_mem[1] = {4'h0, 4'h1, 8'h00};
        
        // 0x02: MOV R2, 1    - 将立即数 1 加载到 R2 (递增值)
        instr_mem[2] = {4'h0, 4'h2, 8'h01};
        
        // 0x03: ADD R1, R1, R2  - R1 = R1 + R2 (累加)
        // 指令格式: opcode=1, ra=R1(寄存器1), rb_imm[7:4]=R1, rb_imm[3:0]=R2
        instr_mem[3] = {4'h1, 4'h1, 4'h1, 4'h2};
        
        // 0x04: ADD R2, R2, R3  - R2 = R2 + 1 (递增R2)
        // R3中预存了常数1
        instr_mem[4] = {4'h1, 4'h2, 4'h2, 4'h3};
        
        // 0x05: SUB R0, R0, R3  - R0 = R0 - 1 (递减计数器)
        instr_mem[5] = {4'h2, 4'h0, 4'h0, 4'h3};
        
        // 0x06: BZ 0x09        - 如果 Z=1 (R0==0)，跳转到 0x09
        instr_mem[6] = {4'h5, 4'h0, 8'h09};
        
        // 0x07: MOV R4, 0x03   - 加载跳转偏移(无用，占位)
        instr_mem[7] = {4'h0, 4'h4, 8'h03};
        
        // 0x08: BZ 0x03        - 跳回循环开始(始终跳转，因为R0还未为0)
        instr_mem[8] = {4'h5, 4'h0, 8'h03};
        
        // 0x09: ST R1, 0x20    - 存储结果到内存地址0x20
        // 先用 MOV R4, 0x20 设置地址
        instr_mem[9] = {4'h0, 4'h4, 8'h20};
        
        // 0x0A: ST 操作：寄存器R1存储到地址R4
        // 指令格式: opcode=4, ra(地址寄存器), rb_imm[7:4](数据寄存器)
        instr_mem[10] = {4'h4, 4'h4, 4'h1, 4'h0};
        
        // 0x0B: MOV R3, 1     - 初始化R3为1（如果之前未初始化）
        instr_mem[11] = {4'h0, 4'h3, 8'h01};
        
        // 0x0C: ADD R1, R1, R2  - 额外测试：再执行一次加法
        instr_mem[12] = {4'h1, 4'h1, 4'h1, 4'h2};
        
        // 0x0D: SUB R1, R1, R3  - 额外测试：执行一次减法
        instr_mem[13] = {4'h2, 4'h1, 4'h1, 4'h3};
        
        // 0x0E: MOV R5, 42    - 加载立即数42到R5
        instr_mem[14] = {4'h0, 4'h5, 8'h2A};
        
        // 0x0F: MOV R6, R5    - 寄存器传送：R6 = R5
        // 指令格式: opcode=6, ra=R6, rb_imm[7:4]=R5
        instr_mem[15] = {4'h6, 4'h6, 4'h5, 4'h0};
        
        // 0x10: HALT           - 停止执行
        instr_mem[16] = {4'h7, 4'h0, 8'h00};
        
        // 其余指令位置填充 NOP (MOV R0, 0 到不存在的寄存器或无害操作)
        // 实际上用HALT指令填充，确保不会执行到无用区域
        for (init_idx = 17; init_idx < 256; init_idx = init_idx + 1) begin
            instr_mem[init_idx] = {4'h7, 4'h0, 8'h00};  // HALT
        end
        
        // 初始化数据内存
        for (init_idx = 0; init_idx < 256; init_idx = init_idx + 1) begin
            mem[init_idx] = 8'h00;
        end
        
        // 初始化寄存器文件
        for (init_idx = 0; init_idx < 8; init_idx = init_idx + 1) begin
            regs[init_idx] = 8'h00;
        end
    end
endmodule
