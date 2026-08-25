// remake_v4:
// | 2-bit opcode | 3-bit Rd | 3-bit Rs | 8-bit 立即数/偏移量 |

// 指令集 (4条):
// 00 (IMM):  Rd ← Imm8
// 01 (ADD):  Rd ← Rd + Rs，更新Z标志
// 10 (BZ):   若 Z=1，PC ← PC + 1 + offset
// 11 (JMP):  PC ← PC + 1 + offset  (无条件跳转)
//            停机通过 JMP 0 (跳转到自身) 实现

// ========== PC 寄存器 ==========
module pc_reg(
    input clk, input reset,
    input [7:0] next_pc,
    output reg [7:0] PC
);
    always @(posedge clk) begin
        if (reset) PC <= 8'd0;
        else PC <= next_pc;
    end
endmodule

// ========== 标志寄存器 ==========
module flag_reg(
    input clk, input reset, 
    input z_wen,
    input [7:0] value,
    output reg Z
);
    always @(posedge clk) begin
        if (reset) Z <= 0;
        else if (z_wen) Z <= (value == 0);
    end
endmodule

// ========== 指令存储器 ==========
module instr_mem(
    input [7:0] addr, input clk, input we,
    input [15:0] din,
    output [15:0] instr
);
    reg [15:0] mem [255:0];
    initial begin
        $readmemh("instr_mem.hex", mem, 0, 255);
    end
    always @(posedge clk) begin
        if (we) mem[addr] <= din;
    end
    assign instr = mem[addr];
endmodule

// ========== 寄存器堆 ==========
module reg_file(
    input clk, input reset,
    input [2:0] raddr1, input [2:0] raddr2,  
    input [2:0] waddr,                        
    input [7:0] wdata, input wen,
    output [7:0] rdata1, output [7:0] rdata2
);
    reg [7:0] regs[7:0];  
    
    wire [7:0] rdata1_raw = regs[raddr1];
    wire [7:0] rdata2_raw = regs[raddr2];
    
    assign rdata1 = (raddr1 == 3'd0) ? 8'd0 : rdata1_raw;
    assign rdata2 = (raddr2 == 3'd0) ? 8'd0 : rdata2_raw;
    
    always @(posedge clk) begin
        if (wen && (waddr != 3'd0)) 
            regs[waddr] <= wdata;
    end
endmodule

// ========== ALU + 控制单元 ==========
module alu_unit(
    input [1:0] opcode,         
    input Z,
    input [7:0] a, b, imm,
    output reg reg_wen,
    output reg branch_taken,
    output reg z_wen,
    output reg [7:0] result
);
    always @(*) begin
        // 所有信号默认为0
        reg_wen = 0; 
        z_wen = 0; 
        branch_taken = 0; 
        result = 8'd0;

        case(opcode)
            2'd0: begin  // IMM: 写寄存器，结果为立即数
                reg_wen = 1;
                result = imm;
            end
            
            2'd1: begin  // ADD: 写寄存器 + 更新标志，结果为加法
                reg_wen = 1; 
                z_wen = 1;
                result = a + b;
            end
            
            2'd2: branch_taken = Z;  // BZ: Z=1时分支
            
            2'd3: branch_taken = 1;  // JMP: 无条件跳转
        endcase
    end
endmodule

// ========== 顶层模块 ==========
module toplevel(
    input clk, input reset,
    output [7:0] out_PC,
    output out_Z
);
    // --- 内部信号 ---
    wire [7:0] PC, next_pc;
    wire Z, z_wen;
    wire [15:0] instr;
    wire [1:0] opcode;         
    wire [7:0] rdata1, rdata2;
    wire [7:0] alu_result;
    wire reg_wen, branch_taken;
    
    // ========== 指令译码 ==========
    assign opcode = instr[15:14];               // 2-bit操作码
    wire [2:0] rd_addr = instr[13:11];          // 3-bit Rd
    wire [2:0] rs_addr = instr[10:8];           // 3-bit Rs
    wire [7:0] imm8 = instr[7:0];               // 8-bit立即数/偏移量

    // --- PC 计算逻辑 ---
    wire signed [7:0] offset = imm8;
    wire [7:0] pc_sequential = PC + 8'd1;
    wire [7:0] pc_branch = PC + 8'd1 + offset;
    assign next_pc = branch_taken ? pc_branch : pc_sequential;

    // --- 模块实例化 ---
    pc_reg pc0(
        .clk(clk), .reset(reset), 
        .next_pc(next_pc), 
        .PC(PC)
    );
    
    instr_mem imem(
        .addr(PC), .instr(instr), 
        .clk(clk), .we(1'b0), .din(16'h0)
    );
    
    reg_file rf(
        .clk(clk), .reset(reset),
        .raddr1(rd_addr), .raddr2(rs_addr),  
        .waddr(rd_addr),
        .wdata(alu_result),
        .wen(reg_wen),
        .rdata1(rdata1), .rdata2(rdata2)
    );

    alu_unit au(
        .opcode(opcode), .Z(Z),
        .a(rdata1), .b(rdata2), .imm(imm8),
        .reg_wen(reg_wen), .branch_taken(branch_taken),
        .z_wen(z_wen),
        .result(alu_result)
    );

    flag_reg flag0(
        .clk(clk), .reset(reset),
        .z_wen(z_wen),
        .value(alu_result),
        .Z(Z)
    );

    // --- 输出 ---
    assign out_PC = PC;
    assign out_Z = Z;
endmodule