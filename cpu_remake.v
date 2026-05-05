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

module instr_mem(
    input [7:0] addr,
    output [15:0] instr
);
    reg [15:0] mem [255:0];
    integer i;

    assign instr = mem[addr];

    initial begin
        // R1 = 5
        mem[0] = 16'h0105; // IMM R1,5

        // R2 = 5
        mem[1] = 16'h0205; // IMM R2,5

        // R3 = R1
        mem[2] = 16'h6310; // MOV R3,R1

        // R3 = R3 - R2 → Z=1
        mem[3] = 16'h2320; // SUB R3,R2

        // if Z jump
        mem[4] = 16'h5001; // BZ +1

        // (should skip)
        mem[5] = 16'h0463; // IMM R4,99

        // label
        mem[6] = 16'h052A; // IMM R5,42

        // stop
        mem[7] = 16'h7000; // HALT
    end
endmodule

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

    assign rdata1 = regs[raddr1];
    assign rdata2 = regs[raddr2];

    integer i;
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 16; i = i + 1)
                regs[i] <= 8'd0;
        end else if (wen) begin
            regs[waddr] <= wdata;
        end
    end
endmodule

module data_mem(
    input clk,
    input wen,
    input [7:0] addr,
    input [7:0] wdata,
    output [7:0] rdata
);
    reg [7:0] mem[255:0];

    assign rdata = mem[addr];

    always @(posedge clk) begin
        if (wen)
            mem[addr] <= wdata;
    end

    integer i;
    initial begin
        for(i=0;i<256;i=i+1)
            mem[i] = 8'd0;
    end
endmodule

module alu(
    input [7:0] a,
    input [7:0] b,
    input [3:0] opcode,
    output reg [7:0] result
);
    always @(*) begin
        case(opcode)
            4'h0: result = b;        // IMM
            4'h1: result = a + b;    // ADD
            4'h2: result = a - b;    // SUB
            4'h6: result = b;        // MOV
            default: result = 8'd0;
        endcase
    end
endmodule

module control_unit(
    input [3:0] opcode,
    input Z,
    output reg reg_wen,
    output reg mem_wen,
    output reg branch_taken,
    output reg halt
);
    always @(*) begin
        reg_wen = 0;
        mem_wen = 0;
        branch_taken = 0;
        halt = 0;

        case(opcode)
            4'h0: reg_wen = 1; // IMM
            4'h1: reg_wen = 1; // ADD
            4'h2: reg_wen = 1; // SUB
            4'h3: reg_wen = 1; // LOAD
            4'h4: mem_wen = 1; // STORE
            4'h5: branch_taken = Z; // BZ
            4'h6: reg_wen = 1; // MOV reg
            4'h7: halt = 1;
        endcase
    end
endmodule

module toplevel(
    input clk,
    input reset,
    output [7:0] out_PC,
    output out_Z,
    output out_halt
);

    wire [7:0] PC, next_pc;
    wire z_wen;
    wire Z;
    wire [15:0] instr;
    wire [3:0] opcode;
    wire [7:0] rdata1, rdata2, alu_result, mem_rdata;
    wire reg_wen, mem_wen, branch_taken, halt;

    // 操作码在指令的高4位
    assign opcode = instr[15:12];
    
    // Z标志更新条件：ADD或SUB指令
    assign z_wen = (opcode == 4'h1) || (opcode == 4'h2);

    // 标志寄存器
    flag_reg flag0(
        .clk(clk),
        .reset(reset),
        .z_wen(z_wen),
        .value(alu_result),   
        .Z(Z)
    );

    // PC寄存器
    pc_reg pc0(
        .clk(clk),
        .reset(reset),
        .next_pc(next_pc),
        .halt(halt),
        .PC(PC)
    );

    // 指令存储器
    instr_mem imem(
        .addr(PC),
        .instr(instr)
    );

    wire [7:0] wdata;
    assign wdata = (opcode == 4'h3) ? mem_rdata : alu_result;  

    // 寄存器堆
    reg_file rf(
        .clk(clk),
        .reset(reset),
        .raddr1(instr[11:8]),   
        .raddr2(instr[7:4]),    
        .waddr(instr[11:8]),    
        .wdata(wdata),
        .wen(reg_wen),
        .rdata1(rdata1),
        .rdata2(rdata2)
    );

    // ALU输入选择
    wire [7:0] alu_a, alu_b;
    assign alu_a = rdata1;  
    
    assign alu_b = (opcode == 4'h0) ? instr[7:0] :   // IMM
               (opcode == 4'h1 || opcode == 4'h2) ? rdata2 :
               (opcode == 4'h6) ? rdata2 :
               8'd0;

    // ALU
    alu alu0(
        .a(alu_a),
        .b(alu_b),
        .opcode(opcode),
        .result(alu_result)
    );

    // 数据存储器
    data_mem dmem(
        .clk(clk),
        .wen(mem_wen),
        .addr(rdata2),   
        .wdata(rdata1),  
        .rdata(mem_rdata)
    );

    // 控制器
    control_unit cu(
        .opcode(opcode),
        .Z(Z),
        .reg_wen(reg_wen),
        .mem_wen(mem_wen),
        .branch_taken(branch_taken),
        .halt(halt)
    );

    // 分支跳转和地址计算
    wire signed [7:0] offset = instr[7:0];
    assign next_pc = branch_taken ? (PC +$signed(8'd1)+ offset) : (PC +8'd1);

    // 输出
    assign out_PC = PC;
    assign out_Z = Z;
    assign out_halt = halt;

endmodule
