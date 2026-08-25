// remake_v5:
// 指令集编码:
// | 2-bit opcode | 3-bit Rd | 3-bit Rs |     (MOV指令)
// | 2-bit opcode | 6-bit Imm |                 (IMM指令)  
// | 2-bit opcode | 3-bit Rd | 3-bit Rs |     (SUB指令)
// | 2-bit opcode | 6-bit offset |             (JNZ指令)
//
// 指令集 (4条):
// 00 (MOV): Rd ← Rs, 不更新标志
// 01 (IMM): R0 ← Imm6 不更新标志
// 10 (SUB): Rd ← Rd - Rs, 更新Z标志 (结果为0时Z=1)
// 11 (JNZ): 若 Z=0, PC ← PC + 1 + offset6 (符号扩展, 范围-32~+31)
//           停机通过 JNZ -1 实现 (-1 的 6 位补码是 6'b111111 = 0x3F)
//           加载负数: MOV R0=0, IMM value, SUB Rd, R0, Rtmp

// ========== PC 寄存器 ==========
module pc_reg(
    input clk, 
    input reset,
    input [7:0] next_pc,
    output reg [7:0] PC
);
    always @(posedge clk) begin
        if (reset) 
            PC <= 8'd0;
        else 
            PC <= next_pc;
    end
endmodule

// ========== 标志寄存器 ==========
module flag_reg(
    input clk, 
    input reset, 
    input z_wen,
    input [7:0] value,
    output reg Z
);
    always @(posedge clk) begin
        if (reset) 
            Z <= 1'b0;
        else if (z_wen) 
            Z <= (value == 8'd0);
    end
endmodule

// ========== 8位指令存储器 ==========
module instr_mem(
    input [7:0] addr,
    output [7:0] instr
);
    reg [7:0] mem [255:0];
    
    initial begin
        // 默认初始化为0 (即IMM 0 - 加载0到R0)
        $readmemh("instr_mem.hex", mem, 0, 255);
    end
    
    assign instr = mem[addr];
endmodule

// ========== 寄存器堆 ==========
module reg_file(
    input clk,
    input [2:0] raddr1, 
    input [2:0] raddr2,  
    input [2:0] waddr,                        
    input [7:0] wdata, 
    input wen,
    output [7:0] rdata1, 
    output [7:0] rdata2
);
    reg [7:0] regs[7:0];  // 8个寄存器 (R0-R7)
    
    // 读端口组合逻辑
    assign rdata1 = regs[raddr1];
    assign rdata2 = regs[raddr2];
    
    // 写端口时序逻辑
    always @(posedge clk) begin
        if (wen) begin
            regs[waddr] <= wdata;
        end
    end
endmodule

// ========== 译码+控制+ALU ==========
module enhanced_controller(
    input [7:0] instr,           // 8位指令字
    input Z,                      // 零标志位
    input [7:0] rdata1,          // 读数据1（Rd当前值）
    input [7:0] rdata2,          // 读数据2（Rs当前值）
    input [7:0] current_pc,      // 当前程序计数器值
    
    // 控制信号输出
    output reg [2:0] rd_addr,    // 目标寄存器地址（也用作读地址1）
    output reg [2:0] rs_addr,    // 源寄存器地址（读地址2）
    output reg reg_wen,           // 寄存器写使能
    output reg z_wen,             // 零标志写使能
    output reg [7:0] alu_result,  // ALU运算结果
    output reg [7:0] next_pc      // 下一条指令地址
);
    // ========== 指令译码（组合逻辑） ==========
    wire [1:0] opcode = instr[7:6];
    wire [2:0] rd_field = instr[5:3];
    wire [2:0] rs_field = instr[2:0];
    wire [5:0] imm6 = instr[5:0];
    
    // ========== JNZ偏移量符号扩展（6位→8位） ==========
    wire [5:0] offset6 = instr[5:0];
    wire [7:0] offset_sext = {{2{offset6[5]}}, offset6};
    
    // 立即数处理
    wire [7:0] imm8_zeroext = {2'd0, imm6};
    
    //指令字 instr[7:0]
    //├── rd_field = instr[5:3]  ──→  rd_addr  ──→  raddr1  ──→  rdata1 = regs[rd_field]
    //└── rs_field = instr[2:0]  ──→  rs_addr  ──→  raddr2  ──→  rdata2 = regs[rs_field]
    
    // ========== 控制逻辑与ALU运算（组合逻辑） ==========
    always @(*) begin
        case(opcode)
            2'b00: begin  // MOV Rd, Rs   
                rd_addr = rd_field;      // |目标寄存器 = Rd字段|
                rs_addr = rs_field;      // |源寄存器 = Rs字段|
                reg_wen = 1'b1;          // 使能寄存器写
                z_wen = 1'b0;            // 不更新标志
                alu_result = rdata2;     // |Rd ← Rs (数据透传)|
            end
            
            2'b01: begin  // IMM imm6
                rd_addr = 3'd0;          // |目标固定为R0|
                rs_addr = 3'd0;          // 不需要读源寄存器
                reg_wen = 1'b1;          // 使能寄存器写
                z_wen = 1'b0;            // 不更新标志
                alu_result = imm8_zeroext; // |R0 ← 零扩展立即数|
            end
            
            2'b10: begin  // SUB Rd, Rs
                rd_addr = rd_field;      // |目标寄存器 = Rd字段|
                rs_addr = rs_field;      // |源寄存器 = Rs字段|
                reg_wen = 1'b1;          // 使能寄存器写
                z_wen = 1'b1;            // |更新零标志|
                alu_result = rdata1 - rdata2; // |Rd ← Rd - Rs|
            end
            
            2'b11: begin  // JNZ offset6
                rd_addr = 3'd0;          // 不写寄存器
                rs_addr = 3'd0;          // 不需要读源寄存器
                reg_wen = 1'b0;          // |不写寄存器|
                z_wen = 1'b0;            // 不更新标志
                alu_result = 8'd0;       // alu_result保持0
            end
        endcase
    end
    
    // ========== PC更新逻辑（组合逻辑） ==========
    // 分支跳转条件：JNZ指令且Z=0
    wire branch_taken = (opcode == 2'b11) && (Z == 1'b0);
    
    // 计算下一PC值
    wire [7:0] pc_sequential = current_pc + 8'd1;
    wire [7:0] pc_branch = pc_sequential  + offset_sext;
    
    assign next_pc = branch_taken ? pc_branch : pc_sequential;
endmodule

// ========== 顶层模块 ==========
module toplevel(
    input clk, 
    input reset,
    
    // 调试和外部连接端口
    output [7:0] out_PC,
    output out_Z,
    output [7:0] out_instr,
    output [1:0] out_opcode,
    output [7:0] out_rdata1,
    output [7:0] out_rdata2,
    output [7:0] out_alu_result,
    output out_reg_wen,
    output out_z_wen,
    output [2:0] out_rd_addr,      
    output [2:0] out_rs_addr       
);
    // ========== 内部信号 ==========
    wire [7:0] PC, next_pc;
    wire Z, z_wen;
    wire [7:0] instr;
    wire [2:0] rd_addr, rs_addr;
    wire [7:0] rdata1, rdata2;
    wire [7:0] alu_result;
    wire reg_wen;
    
    // ========== 指令译码（用于调试） ==========
    wire [1:0] opcode = instr[7:6];
    
    // ========== 模块实例化 ==========
    
    // 1. 程序计数器
    pc_reg pc0(
        .clk(clk), 
        .reset(reset), 
        .next_pc(next_pc), 
        .PC(PC)
    );
    
    // 2. 指令存储器
    instr_mem imem(
        .addr(PC), 
        .instr(instr)
    );
    
    // 3. 寄存器堆
    reg_file rf(
        .clk(clk),
        .raddr1(rd_addr),      // 读地址1来自控制器
        .raddr2(rs_addr),      // 读地址2来自控制器
        .waddr(rd_addr),       // 写地址 = 目标寄存器地址
        .wdata(alu_result),    // 写数据 = ALU结果
        .wen(reg_wen),         // 写使能
        .rdata1(rdata1), 
        .rdata2(rdata2)
    );
    
    // 4. 增强型控制器（整合了译码、控制和ALU）
    enhanced_controller ctrl(
        .instr(instr),          // 指令输入
        .Z(Z),                  // 零标志输入
        .rdata1(rdata1),        // 寄存器读数据1
        .rdata2(rdata2),        // 寄存器读数据2
        .current_pc(PC),        // 当前PC
        .rd_addr(rd_addr),      // 目标寄存器地址
        .rs_addr(rs_addr),      // 源寄存器地址
        .reg_wen(reg_wen),      // 寄存器写使能
        .z_wen(z_wen),          // 标志写使能
        .alu_result(alu_result),// ALU结果
        .next_pc(next_pc)       // 下一PC
    );
    
    // 5. 标志寄存器
    flag_reg flag0(
        .clk(clk), 
        .reset(reset),
        .z_wen(z_wen),
        .value(alu_result),
        .Z(Z)
    );
    
    // ========== 调试输出 ==========
    assign out_PC = PC;
    assign out_Z = Z;
    assign out_instr = instr;
    assign out_opcode = opcode;
    assign out_rdata1 = rdata1;
    assign out_rdata2 = rdata2;
    assign out_alu_result = alu_result;
    assign out_reg_wen = reg_wen;
    assign out_z_wen = z_wen;
    assign out_rd_addr = rd_addr;
    assign out_rs_addr = rs_addr;
endmodule