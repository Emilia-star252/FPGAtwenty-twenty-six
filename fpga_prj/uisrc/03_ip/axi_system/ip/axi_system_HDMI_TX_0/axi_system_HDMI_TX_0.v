/************************************************************\
**	Copyright (c) 2012-2025 Anlogic Inc.
**	All Right Reserved.
\************************************************************/
/************************************************************\
**	Build time: Sep 24 2025 12:11:37
**	TD version	:	6.2.168116
************************************************************/
`timescale 1ns / 1ns 
module axi_system_HDMI_TX_0
(
  input                         I_pixel_clk,
  input                         I_serial_clk,
  input                         I_rst,
  input   [23:0]                I_video_in_data,
  input                         I_video_in_de,
  input                         I_video_in_vs,
  input                         I_video_in_hs,
  output                        O_hdmi_clk_p,
  output  [2:0]                 O_hdmi_tx_p
);

  hdmi_tx_c33abe7c933e
  #(
      .DEVICE("DR1")
  )hdmi_tx_c33abe7c933e_Inst
  (
      .I_pixel_clk(I_pixel_clk),
      .I_serial_clk(I_serial_clk),
      .I_rst(I_rst),
      .I_video_in_data(I_video_in_data),
      .I_video_in_de(I_video_in_de),
      .I_video_in_vs(~I_video_in_vs),
      .I_video_in_hs(I_video_in_hs),
      .O_hdmi_clk_p(O_hdmi_clk_p),
      .O_hdmi_tx_p(O_hdmi_tx_p)
  );
endmodule
