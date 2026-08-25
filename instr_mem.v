module instr_mem(
    input [7:0] addr,
    input clk,
    input we,
    input [15:0] din,
    output reg [15:0] instr
);
    (* ram_style = "block" *) reg [15:0] mem [255:0] = '{
        0: 16'h0105,
        1: 16'h0205,
        2: 16'h6310,
        3: 16'h2320,
        4: 16'h5001,
        5: 16'h0463,
        6: 16'h052A,
        7: 16'h7000,
        default: 16'h0000
    };

    // 写端口：独立的 always
    always @(posedge clk) begin
        if (we) mem[addr] <= din;
    end

    // 读端口：另一个独立的 always（或直接用 assign）
    always @(posedge clk) begin
        instr <= mem[addr];
    end
endmodule