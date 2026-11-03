/************************************************************\
**	Copyright (c) 2012-2026 anlogic Inc.
**	All Right Reserved.
\************************************************************/
/************************************************************\
**	Gen time	:	2026-10-12 18:59:54
**	DI version	:	197563 2026/05/12
**	App version	:	(build number:6.2.2.200067)
\************************************************************/

module axi_system_adc_axis_source_0 
#(
    parameter PACKET_SAMPLES = 256 ,
    parameter RESET_HOLD_CYCLES = 32
)
(
    input wire [31:0] duty_q16_in,
    input             clk ,
    input             rst_n ,
    input             capture_enable ,
    input             fifo_clear ,
    input             adc_sample_valid ,
    input      [47:0] voltage_product_in ,
    input      [47:0] current_product_in ,
    output     [31:0] m_axis_tdata ,
    output      [3:0] m_axis_tkeep ,
    output            m_axis_tlast ,
    output            m_axis_tvalid ,
    input             m_axis_tready ,
    output     [31:0] drop_count ,
    input             fifo_out_tvalid ,
    input             fifo_out_tready ,
    output     [31:0] fifo_level ,
    output            fifo_reset_n
) ;

    adc_axis_source #(
        .PACKET_SAMPLES(PACKET_SAMPLES) ,
        .RESET_HOLD_CYCLES(RESET_HOLD_CYCLES)
    ) adc_axis_source (
        .duty_q16_in(duty_q16_in),
        .clk(clk) ,
        .rst_n(rst_n) ,
        .capture_enable(capture_enable) ,
        .fifo_clear(fifo_clear) ,
        .adc_sample_valid(adc_sample_valid) ,
        .voltage_product_in(voltage_product_in) ,
        .current_product_in(current_product_in) ,
        .m_axis_tdata(m_axis_tdata) ,
        .m_axis_tkeep(m_axis_tkeep) ,
        .m_axis_tlast(m_axis_tlast) ,
        .m_axis_tvalid(m_axis_tvalid) ,
        .m_axis_tready(m_axis_tready) ,
        .drop_count(drop_count) ,
        .fifo_out_tvalid(fifo_out_tvalid) ,
        .fifo_out_tready(fifo_out_tready) ,
        .fifo_level(fifo_level) ,
        .fifo_reset_n(fifo_reset_n)
    );


endmodule
