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
