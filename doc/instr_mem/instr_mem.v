module instr_mem(
    input [7:0] addr,
    input clk,
    input we,
    input [15:0] din,
    output reg [15:0] instr
);
    // 直接在声明时初始化内容（FPGA综合支持）
    (* ram_style = "block" *) reg [15:0] mem [255:0];
    
    integer i;
    
    // 将初始化改为 initial 块以符合 Verilog 标准
    initial begin
        // 首先将所有内存初始化为 0 (对应原 default: 16'h0000)
        for (i = 0; i < 256; i = i + 1) begin
            mem[i] = 16'h0000;
        end

        // 填入你的原始指令逻辑 [cite: 46, 47]
        mem[0] = 16'h0105;  // IMM R1,5
        mem[1] = 16'h0205;  // IMM R2,5
        mem[2] = 16'h6310;  // MOV R3,R1
        mem[3] = 16'h2320;  // SUB R3,R2
        mem[4] = 16'h5001;  // BZ +1
        mem[5] = 16'h0463;  // IMM R4,99
        mem[6] = 16'h052A;  // IMM R5,42
        mem[7] = 16'h7000;  // HALT
    end
    
    always @(posedge clk) begin
        if (we) mem[addr] <= din;
        instr <= mem[addr];
    end
endmodule
