module axi_system_HDMI_Reset_0(
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
hdmi_clock_reset u_reset(
    .ctrl_clk(ctrl_clk),
    .mem_clk(mem_clk),
    .axis_clk(axis_clk),
    .pixel_clk(pixel_clk),
    .axi_reset_n(axi_reset_n),
    .display_pll_locked(display_pll_locked),
    .pixel_pll_locked(pixel_pll_locked),
    .serial_pll_locked(serial_pll_locked),
    .video_locked(video_locked),
    .serial_pll_reset(serial_pll_reset),
    .ctrl_reset_n(ctrl_reset_n),
    .mem_reset_n(mem_reset_n),
    .axis_reset_n(axis_reset_n),
    .pixel_reset(pixel_reset),
    .tx_reset(tx_reset)
);
endmodule
