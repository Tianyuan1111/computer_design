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
