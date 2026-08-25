//remake^2:

//| 4-bit opcode | 4-bit 寄存器 | 4-bit 寄存器 |  4-bit 留空 |
//| 4-bit opcode | 4-bit 寄存器 | 8-bit 立即数/地址 |

//操作码	助记符	        说明
//0000	IMM Rd，Imm8	    Rd ← Imm8
//0001	ADD Rd, Rs,4'h0	    Rd ← Rd + Rs，Z
//0010	SUB Rd, Rs,4'h0	    Rd ← Rd - Rs，Z
//0011	LOAD Rd, Rs,4'h0	Rd ← Mem[Rs]
//0100	STORE Rd, Rs,4'h0	Mem[Rs] ← Rd
//0101	BZ 4'h0,offset8	    若 Z=1，PC ← PC + 1 + offset
//0110	MOV Rd, Rs,4'h0	    Rd ← Rs
//0111	HALT,12'h0 	        停机

// ========== PC 寄存器 ==========
module pc_reg(
    input clk,
    input reset,
    input [7:0] next_pc,
    input halt,
    output reg [7:0] PC
);
    always @(posedge clk) begin
        if (reset)
            PC <= 8'd0;
        else if (!halt)
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
            Z <= 0;
        else if (z_wen)
            Z <= (value == 0);
    end
endmodule

// ========== 指令存储器 ==========
module instr_mem(
    input [7:0] addr,
    input clk,
    input we,
    input [15:0] din,
    output [15:0] instr
);
    reg [15:0] mem [255:0];
    
    // 使用$readmemh从文件加载初始内容
    initial begin
        $readmemh("instr_mem.hex", mem, 0, 255);
    end

    // 写端口：时序逻辑
    always @(posedge clk) begin
        if (we) mem[addr] <= din;
    end

    // 读端口：组合逻辑（会被Yosys映射为块RAM的读端口）
    assign instr = mem[addr];
endmodule

// ========== 寄存器堆 ==========
module reg_file(
    input clk,
    input reset,
    input [3:0] raddr1,
    input [3:0] raddr2,
    input [3:0] waddr,
    input [7:0] wdata,
    input wen,
    output [7:0] rdata1,
    output [7:0] rdata2
);
    reg [7:0] regs[15:0];
    
    // 如果RISC-V x0寄存器需要恒为0，可以单独处理
    wire [7:0] rdata1_raw = regs[raddr1];
    wire [7:0] rdata2_raw = regs[raddr2];
    
    assign rdata1 = (raddr1 == 4'd0) ? 8'd0 : rdata1_raw;
    assign rdata2 = (raddr2 == 4'd0) ? 8'd0 : rdata2_raw;
    
    always @(posedge clk) begin
        if (wen && (waddr != 4'd0))  // 禁止写入x0
            regs[waddr] <= wdata;
    end
endmodule

// ========== 数据存储器 ==========
module data_mem(
    input clk,
    input wen,
    input [7:0] addr,
    input [7:0] wdata,
    output reg [7:0] rdata
);
    reg [7:0] mem[255:0];

    always @(*) begin
        rdata = mem[addr];
    end

    always @(posedge clk) begin
        if (wen)
            mem[addr] <= wdata;
    end
endmodule

// ========== ALU - 统一数据流核心 ==========
// 所有数据都通过 ALU 输出，统一管理数据通路
module alu(
    input [7:0] a,          // 操作数1 (rdata1)
    input [7:0] b,          // 操作数2 (rdata2)
    input [7:0] imm,        // 立即数
    input [7:0] mem_data,   // 从数据存储器读出的数据
    input [3:0] opcode,     // 操作码，决定ALU做什么
    output reg [7:0] result // 统一的数据输出
);
    wire [7:0] addsub_result;

    // 综合工具会自动将加减法合并为一个加法器
    assign addsub_result = (opcode == 4'h2) ? (a - b) : (a + b);

    always @(*) begin
        case(opcode)
            4'h0: result = imm;         // IMM: 选择立即数
            4'h1,4'h2: result = addsub_result;       // ADD/SUB: 加法/减法
            4'h3: result = mem_data;    // LOAD: 选择内存数据
            4'h4: result = a;           // STORE: 直通 a (rdata1) 到内存
            4'h6: result = b;           // MOV: 选择 rdata2
            default: result = a;        // 默认直通，确保无害
        endcase
    end
endmodule

// ========== 控制单元 ==========
module control_unit(
    input [3:0] opcode,
    input Z,
    output reg reg_wen,      // 寄存器写使能
    output reg mem_wen,      // 存储器写使能
    output reg branch_taken, // 分支是否跳转
    output reg halt,         // 停机
    output reg z_wen         // Z标志写使能
);
    always @(*) begin
        // 默认值：所有控制信号无效
        reg_wen = 0;
        mem_wen = 0;
        branch_taken = 0;
        halt = 0;
        z_wen = 0;

        case(opcode)
            4'h0: reg_wen = 1;                    // IMM: 写寄存器
            4'h1: begin                           // ADD: 写寄存器 + 更新Z
                reg_wen = 1;
                z_wen = 1;
            end
            4'h2: begin                           // SUB: 写寄存器 + 更新Z
                reg_wen = 1;
                z_wen = 1;
            end
            4'h3: reg_wen = 1;                    // LOAD: 写寄存器
            4'h4: mem_wen = 1;                    // STORE: 写存储器
            4'h5: branch_taken = Z;               // BZ: Z=1时跳转
            4'h6: reg_wen = 1;                    // MOV: 写寄存器
            4'h7: halt = 1;                       // HALT: 停机
        endcase
    end
endmodule

// ========== 顶层模块 ==========
module toplevel(
    input clk,
    input reset,
    output [7:0] out_PC,
    output out_Z,
    output out_halt
);
    // 内部连线
    wire [7:0] PC, next_pc;
    wire Z;
    wire z_wen;
    wire [15:0] instr;
    wire [3:0] opcode;
    wire [7:0] rdata1, rdata2;
    wire [7:0] alu_result, mem_rdata;
    wire reg_wen, mem_wen, branch_taken, halt;

    // 指令解码
    assign opcode = instr[15:12];
    
    // 立即数提取（IMM/BZ指令用低8位）
    wire [7:0] imm8 = instr[7:0];

    // 实例化：PC寄存器
    pc_reg pc0(
        .clk(clk),
        .reset(reset),
        .next_pc(next_pc),
        .halt(halt),
        .PC(PC)
    );

    // 实例化：指令存储器
    instr_mem imem(
        .addr(PC),
        .instr(instr),  
        .clk(clk),
        .we(1'b0),      
        .din(16'h0)
    );

    // 实例化：寄存器堆
    // raddr1 = Rd字段，raddr2 = Rs字段
    // waddr 总是写回 Rd 字段 (instr[11:8])
    reg_file rf(
        .clk(clk),
        .reset(reset),
        .raddr1(instr[11:8]),   // 读取Rd (可能是LOAD/STORE的源操作数)
        .raddr2(instr[7:4]),    // 读取Rs (LOAD/STORE的地址)
        .waddr(instr[11:8]),    // 总是写回Rd
        .wdata(alu_result),     // ← 所有写回数据都来自ALU
        .wen(reg_wen),
        .rdata1(rdata1),
        .rdata2(rdata2)
    );

    // 实例化：ALU (数据流核心)
    // 所有数据选择、运算、透传都在这里完成
    alu alu0(
        .a(rdata1),             // 操作数1
        .b(rdata2),             // 操作数2
        .imm(imm8),             // 立即数
        .mem_data(mem_rdata),   // 内存读出数据
        .opcode(opcode),        // 操作码控制功能
        .result(alu_result)     // 统一输出
    );

    // 实例化：数据存储器
    // STORE: wdata = alu_result (此时ALU输出=rdata1)
    // LOAD: rdata = mem[addr] → 送回ALU
    data_mem dmem(
        .clk(clk),
        .wen(mem_wen),
        .addr(rdata2),          // LOAD/STORE 地址都来自 rdata2
        .wdata(alu_result),     // ← 写入数据也来自ALU
        .rdata(mem_rdata)
    );

    // 实例化：标志寄存器 (只受ADD/SUB影响)
    flag_reg flag0(
        .clk(clk),
        .reset(reset),
        .z_wen(z_wen),
        .value(alu_result),
        .Z(Z)
    );

    // 实例化：控制器
    control_unit cu(
        .opcode(opcode),
        .Z(Z),
        .reg_wen(reg_wen),
        .mem_wen(mem_wen),
        .branch_taken(branch_taken),
        .halt(halt),
        .z_wen(z_wen)
    );

    // PC地址计算
    wire signed [7:0] offset = imm8;

    // 在两个加法器里预先算好两个PC值
    wire [7:0] pc_sequential = PC + 8'd1;
    wire [7:0] pc_branch     = PC + 8'd1 + offset;  // offset是带符号立即数

    // 分支判定来临时，只需一个2选1 MUX
    assign next_pc = branch_taken ? pc_branch : pc_sequential;

    // 输出端口
    assign out_PC = PC;
    assign out_Z = Z;
    assign out_halt = halt;

endmodule
