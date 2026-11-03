`timescale 1ns / 1ps

// 100 MHz / 4000 = 25 kHz, with a 50% duty cycle.
// This is a counter divider; it does not instantiate a hardware PLL.
module PLL (
    input  wire clk_100m,
    input  wire rst_n,
    output reg  clk_25k
);

    // Each half-period lasts 2000 input clock cycles (20 us).
    reg [10:0] count;

    always @(posedge clk_100m or negedge rst_n) begin
        if (!rst_n) begin
            count   <= 11'd0;
            clk_25k <= 1'b0;
        end else if (count == 11'd1999) begin
            count   <= 11'd0;
            clk_25k <= ~clk_25k;
        end else begin
            count <= count + 11'd1;
        end
    end

endmodule
