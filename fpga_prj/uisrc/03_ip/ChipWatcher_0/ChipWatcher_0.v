/************************************************************\
**	Copyright (c) 2012-2026 Anlogic Inc.
**	All Right Reserved.
\************************************************************/
/************************************************************\
**	Gen time	:	Oct 30 2026 18:56:24
**	IpTool version	:	2026.03(193873 2026/03/31)
**	App version	:	Release_2026.1_SP2
**	Ip Version	:	1.0
\************************************************************/
module ChipWatcher_0
(
  input   [15:0]                probe0,
  input   [15:0]                probe1,
  input   [0:0]                 probe2,
  input   [0:0]                 probe3,
  input   [0:0]                 probe4,
  input                         clk
);

  ChipWatcher_ChipWatcher_0  ChipWatcher_Inst
  (
      .probe0(probe0),
      .probe1(probe1),
      .probe2(probe2),
      .probe3(probe3),
      .probe4(probe4),
      .clk(clk)
  );
endmodule
