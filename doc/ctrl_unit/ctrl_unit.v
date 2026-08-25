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
