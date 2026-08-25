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
