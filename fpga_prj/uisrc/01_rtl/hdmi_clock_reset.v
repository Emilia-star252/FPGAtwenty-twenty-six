`timescale 1ns / 1ps

// Display-only reset domains. Loss of a display clock does not reset acquisition.
module hdmi_clock_reset (
    input wire ctrl_clk,
    input wire mem_clk,
    input wire axis_clk,
    input wire pixel_clk,
    input wire axi_reset_n,
    input wire display_pll_locked,
    input wire pixel_pll_locked,
    input wire serial_pll_locked,
    input wire video_locked,
    output wire serial_pll_reset,
    output wire ctrl_reset_n,
    output wire mem_reset_n,
    output wire axis_reset_n,
    output wire pixel_reset,
    output wire tx_reset
);
    wire display_ready_n = axi_reset_n && display_pll_locked;
    wire tx_ready_n = display_ready_n && pixel_pll_locked &&
                      serial_pll_locked && video_locked;
    wire pixel_ready_n = display_ready_n && pixel_pll_locked;
    (* ASYNC_REG = "TRUE" *) reg [2:0] ctrl_release;
    (* ASYNC_REG = "TRUE" *) reg [2:0] mem_release;
    (* ASYNC_REG = "TRUE" *) reg [2:0] axis_release;
    (* ASYNC_REG = "TRUE" *) reg [2:0] tx_release;
    (* ASYNC_REG = "TRUE" *) reg [2:0] pixel_release;

    assign serial_pll_reset = ~(axi_reset_n && pixel_pll_locked);
    assign ctrl_reset_n = ctrl_release[2];
    assign mem_reset_n = mem_release[2];
    assign axis_reset_n = axis_release[2];
    assign tx_reset = ~tx_release[2];
    assign pixel_reset = ~pixel_release[2];

    always @(posedge ctrl_clk or negedge display_ready_n)
        if (!display_ready_n) ctrl_release <= 3'b000;
        else ctrl_release <= {ctrl_release[1:0], 1'b1};
    always @(posedge mem_clk or negedge display_ready_n)
        if (!display_ready_n) mem_release <= 3'b000;
        else mem_release <= {mem_release[1:0], 1'b1};
    always @(posedge axis_clk or negedge display_ready_n)
        if (!display_ready_n) axis_release <= 3'b000;
        else axis_release <= {axis_release[1:0], 1'b1};
    always @(posedge pixel_clk or negedge tx_ready_n)
        if (!tx_ready_n) tx_release <= 3'b000;
        else tx_release <= {tx_release[1:0], 1'b1};
    always @(posedge pixel_clk or negedge pixel_ready_n)
        if (!pixel_ready_n) pixel_release <= 3'b000;
        else pixel_release <= {pixel_release[1:0], 1'b1};
endmodule
