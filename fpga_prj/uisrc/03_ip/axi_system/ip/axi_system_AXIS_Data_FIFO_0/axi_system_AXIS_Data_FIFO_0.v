/************************************************************\
**	Copyright (c) 2012-2026 Anlogic Inc.
**	All Right Reserved.
\************************************************************/
/************************************************************\
**	Gen time	:	Oct 12 2026 16:52:36
**	IpTool version	:	2026.03(193873 2026/03/31)
**	App version	:	Release_2026.1_SP2
**	Ip Version	:	1.0
\************************************************************/
`timescale 1ns/1ps
module axi_system_AXIS_Data_FIFO_0
(
  input                         us_aclk,
  input                         us_aresetn,
  input                         us_tvalid,
  output                        us_tready,
  input   [31:0]                us_tdata,
  input   [3:0]                 us_tkeep,
  input                         us_tlast,
  output                        almost_full,
  output  [31:0]                axis_wr_data_count,
  output                        ds_tvalid,
  input                         ds_tready,
  output  [31:0]                ds_tdata,
  output  [3:0]                 ds_tkeep,
  output                        ds_tlast,
  output  [0:0]                 ds_tuser,
  output                        almost_empty,
  output  [31:0]                axis_rd_data_count
);

  axis_data_fifo_axi_system_AXIS_Data_FIFO_0
  #(
      .AL_AXIS_TDATA_WIDTH(32),
      .AL_AXIS_TID_WIDTH(1),
      .AL_AXIS_TDEST_WIDTH(1),
      .AL_AXIS_TUSER_WIDTH(1),
      .AL_AXIS_SIGNAL_SET(32'b00011011),
      .AL_FIFO_DEPTH(4096),
      .AL_FIFO_MODE(1),
      .AL_IS_ACLK_ASYNC(0),
      .AL_ACLKEN_CONV_MODE(0)
  )axis_data_fifo_Inst
  (
      .us_aclk(us_aclk),
      .us_aresetn(us_aresetn),
      .us_tvalid(us_tvalid),
      .us_tready(us_tready),
      .us_tdata(us_tdata),
      .us_tkeep(us_tkeep),
      .us_tlast(us_tlast),
      .almost_full(almost_full),
      .axis_wr_data_count(axis_wr_data_count),
      .ds_tvalid(ds_tvalid),
      .ds_tready(ds_tready),
      .ds_tdata(ds_tdata),
      .ds_tkeep(ds_tkeep),
      .ds_tlast(ds_tlast),
      .ds_tuser(ds_tuser),
      .almost_empty(almost_empty),
      .axis_rd_data_count(axis_rd_data_count)
  );
endmodule
