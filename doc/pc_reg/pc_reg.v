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
