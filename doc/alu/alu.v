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
