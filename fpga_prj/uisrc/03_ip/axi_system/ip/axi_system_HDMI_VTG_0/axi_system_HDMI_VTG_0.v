/************************************************************\
**	Copyright (c) 2012-2025 Anlogic Inc.
**	All Right Reserved.
\************************************************************/
/************************************************************\
**	Build time: Sep 21 2025 09:20:37
**	TD version	:	6.2.174248
************************************************************/
`timescale 1 ns / 1 ps
module axi_system_HDMI_VTG_0
(
  input                         aclk,
  input                         arst_n,
  input   [12:0]                s_axi_awaddr,
  input                         s_axi_awvalid,
  output                        s_axi_awready,
  input   [31:0]                s_axi_wdata,
  input   [3:0]                 s_axi_wstrb,
  input                         s_axi_wvalid,
  output                        s_axi_wready,
  output  [1:0]                 s_axi_bresp,
  output                        s_axi_bvalid,
  input                         s_axi_bready,
  input   [12:0]                s_axi_araddr,
  input                         s_axi_arvalid,
  output                        s_axi_arready,
  output  [31:0]                s_axi_rdata,
  output  [1:0]                 s_axi_rresp,
  output                        s_axi_rvalid,
  input                         s_axi_rready,
  input                         ref_clk,
  input                         vtg_ce,
  output                        vtg_pclk_locked,
  output                        vtg_pclk,
  output                        vtg_hsync,
  output                        vtg_vsync,
  output                        vtg_hblank,
  output                        vtg_vblank,
  output                        vtg_active_video
);

  video_timing_generator_v01_dd045705834d
  #(
      .REF_CLK_FREQ(50),
      .FPS(60),
      .H_FRONT(16'd48),
      .H_ACTIVE(16'd1024),
      .H_SYNC(16'd96),
      .H_BACK(16'd144),
      .V_FRONT(16'd3),
      .V_ACTIVE(16'd600),
      .V_SYNC(16'd7),
      .V_BACK(16'd14)
  )video_timing_generator_v01_dd045705834d_Inst
  (
      .aclk(aclk),
      .arst_n(arst_n),
      .s_axi_awaddr(s_axi_awaddr),
      .s_axi_awvalid(s_axi_awvalid),
      .s_axi_awready(s_axi_awready),
      .s_axi_wdata(s_axi_wdata),
      .s_axi_wstrb(s_axi_wstrb),
      .s_axi_wvalid(s_axi_wvalid),
      .s_axi_wready(s_axi_wready),
      .s_axi_bresp(s_axi_bresp),
      .s_axi_bvalid(s_axi_bvalid),
      .s_axi_bready(s_axi_bready),
      .s_axi_araddr(s_axi_araddr),
      .s_axi_arvalid(s_axi_arvalid),
      .s_axi_arready(s_axi_arready),
      .s_axi_rdata(s_axi_rdata),
      .s_axi_rresp(s_axi_rresp),
      .s_axi_rvalid(s_axi_rvalid),
      .s_axi_rready(s_axi_rready),
      .ref_clk(ref_clk),
      .vtg_ce(vtg_ce),
      .vtg_pclk_locked(vtg_pclk_locked),
      .vtg_pclk(vtg_pclk),
      .vtg_hsync(vtg_hsync),
      .vtg_vsync(vtg_vsync),
      .vtg_hblank(vtg_hblank),
      .vtg_vblank(vtg_vblank),
      .vtg_active_video(vtg_active_video)
  );
endmodule
