/************************************************************\
**	Copyright (c) 2012-2026 anlogic Inc.
**	All Right Reserved.
\************************************************************/
/************************************************************\
**	Gen time	:	2026-10-12 19:03:57
**	DI version	:	197563 2026/05/12
**	App version	:	(build number:6.2.2.200067)
\************************************************************/

module axi_system_axi4lite_slave_0 
#(
    parameter ADDR_WIDTH = 8 ,
    parameter DATA_WIDTH = 32
)
(
    output wire fault_clear_cmd,
    input wire protection_stop,
    input wire [31:0] control_status_in,
    input wire [31:0] vref_active_q16_in,
    output wire output_enable_cmd,
    output wire [31:0] vref_cmd_q16,
    input             adc_sample_valid ,
    input      [31:0] adc_status_in ,
    input      [31:0] s_axis_tdata ,
    input       [3:0] s_axis_tkeep ,
    input             s_axis_tlast ,
    input             s_axis_tvalid ,
    output            s_axis_tready ,
    input      [31:0] fifo_level_in ,
    input      [31:0] fifo_drop_count_in ,
    input             fifo_ready_in ,
    output            capture_enable ,
    output            fifo_clear ,
    input             clk ,
    input             rst_n ,
    input  [(ADDR_WIDTH - 1):0] s_axi_awaddr ,
    input             s_axi_awvalid ,
    output            s_axi_awready ,
    input  [(DATA_WIDTH - 1):0] s_axi_wdata ,
    input       [3:0] s_axi_wstrb ,
    input             s_axi_wvalid ,
    output            s_axi_wready ,
    output      [1:0] s_axi_bresp ,
    output            s_axi_bvalid ,
    input             s_axi_bready ,
    input  [(ADDR_WIDTH - 1):0] s_axi_araddr ,
    input             s_axi_arvalid ,
    output            s_axi_arready ,
    output [(DATA_WIDTH - 1):0] s_axi_rdata ,
    output      [1:0] s_axi_rresp ,
    output            s_axi_rvalid ,
    input             s_axi_rready
) ;

    axi4lite_slave #(
        .ADDR_WIDTH(ADDR_WIDTH) ,
        .DATA_WIDTH(DATA_WIDTH)
    ) axi4lite_slave (
        .fault_clear_cmd(fault_clear_cmd),
        .protection_stop(protection_stop),
        .control_status_in(control_status_in),
        .vref_active_q16_in(vref_active_q16_in),
        .output_enable_cmd(output_enable_cmd),
        .vref_cmd_q16(vref_cmd_q16),
        .adc_sample_valid(adc_sample_valid) ,
        .adc_status_in(adc_status_in) ,
        .s_axis_tdata(s_axis_tdata) ,
        .s_axis_tkeep(s_axis_tkeep) ,
        .s_axis_tlast(s_axis_tlast) ,
        .s_axis_tvalid(s_axis_tvalid) ,
        .s_axis_tready(s_axis_tready) ,
        .fifo_level_in(fifo_level_in) ,
        .fifo_drop_count_in(fifo_drop_count_in) ,
        .fifo_ready_in(fifo_ready_in) ,
        .capture_enable(capture_enable) ,
        .fifo_clear(fifo_clear) ,
        .clk(clk) ,
        .rst_n(rst_n) ,
        .s_axi_awaddr(s_axi_awaddr) ,
        .s_axi_awvalid(s_axi_awvalid) ,
        .s_axi_awready(s_axi_awready) ,
        .s_axi_wdata(s_axi_wdata) ,
        .s_axi_wstrb(s_axi_wstrb) ,
        .s_axi_wvalid(s_axi_wvalid) ,
        .s_axi_wready(s_axi_wready) ,
        .s_axi_bresp(s_axi_bresp) ,
        .s_axi_bvalid(s_axi_bvalid) ,
        .s_axi_bready(s_axi_bready) ,
        .s_axi_araddr(s_axi_araddr) ,
        .s_axi_arvalid(s_axi_arvalid) ,
        .s_axi_arready(s_axi_arready) ,
        .s_axi_rdata(s_axi_rdata) ,
        .s_axi_rresp(s_axi_rresp) ,
        .s_axi_rvalid(s_axi_rvalid) ,
        .s_axi_rready(s_axi_rready)
    );


endmodule
