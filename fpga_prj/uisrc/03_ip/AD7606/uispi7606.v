
/*******************************MILIANKE*******************************
*Company : MiLianKe Electronic Technology Co., Ltd.
*WebSite:https://www.milianke.com
*TechWeb:https://www.uisrc.com
*tmall-shop:https://milianke.tmall.com
*jd-shop:https://milianke.jd.com
*taobao-shop1: https://milianke.taobao.com
*Create Date: 2023/08/07
*Module Name:
*File Name:
*Description: 
*The reference demo provided by Milianke is only used for learning. 
*We cannot ensure that the demo itself is free of bugs, so users 
*should be responsible for the technical problems and consequences
*caused by the use of their own products.
*Copyright: Copyright (c) MiLianKe
*All rights reserved.
*Revision: 1.1
*Signal description
*1) I_ input
*2) O_ output
*3) IO_ input output
*3) S_ system internal signal
*3) _n activ low
*4) _dg debug signal 
*5) _r delay or register
*6) _s state mechine
*********************************************************************/

`timescale 1ns / 1ps

// PWM-triggered, read-after-conversion AD7606 interface.
// I_sample_start: rising-edge event synchronous to I_ad_clk (not a clock).
// Trigger -> CONVST rising edge -> BUSY high/low -> 64 dual-DOUT bits.
// Outputs update atomically; O_ad_cap_en is one I_ad_clk tick.
// At 100 MHz and SPI_HALF_CYCLES=8: SCLK=6.25 MHz, CONVST low=40 ns.
// The 80 ns read settling interval covers the DAQ001 level translators and
// the conservative return-path budget documented in fpga2026.sdc.
// Original eight-channel layout is retained:
//   A = {V1,V2,V3,V4}; B = {V5,V6,V7,V8}, 16-bit two's complement.
// The original ~83.9 ms reset hold is retained by default.
// Busy-time triggers are discarded, not queued; check O_sample_ready.
// O_ad_error latches a missing/stuck/unexpected BUSY until I_ad_rst.
module uispi7606 #(
    parameter integer RESET_CYCLES         = 8388608,
    parameter integer RESET_RELEASE_CYCLES = 10,
    parameter integer CONVST_LOW_CYCLES    = 4,
    parameter integer SPI_HALF_CYCLES      = 8,
    parameter integer BUSY_TIMEOUT_CYCLES  = 1000
)(
    input  wire        I_ad_clk,
    input  wire        I_ad_rst,          // Active high
    input  wire        I_sample_start,    // Connect PWM.adc_trigger
    input  wire        I_ad_busy,
    output wire [2:0]  O_ad_os,
    output reg         O_ad_cs,
    output reg         O_ad_sclk,
    output reg         O_ad_rst,
    output wire        O_ad_convsta,
    output wire        O_ad_convstb,
    output wire        O_ad_range,
    input  wire        I_O_ad_out_a,
    input  wire        I_O_ad_out_b,
    output reg  [63:0] O_ad_out_a,
    output reg  [63:0] O_ad_out_b,
    output reg         O_ad_cap_en,
    output wire        O_sample_ready,
    output wire        O_sample_busy,
    output reg         O_ad_error
);
    localparam [3:0] ST_RESET     = 4'd0,
                     ST_RECOVERY  = 4'd1,
                     ST_IDLE      = 4'd2,
                     ST_CONV_LOW  = 4'd3,
                     ST_BUSY_HIGH = 4'd4,
                     ST_BUSY_LOW  = 4'd5,
                     ST_READ      = 4'd6,
                     ST_FINISH    = 4'd7,
                     ST_FAULT     = 4'd8;

    reg [3:0]  state;
    reg [31:0] wait_count;
    reg [31:0] spi_count;
    reg [6:0]  bit_count;
    reg [63:0] shift_a, shift_b;
    reg        ad_convst;
    reg        busy_meta, busy_sync;
    reg        sample_start_d;

    wire start_event = I_sample_start && !sample_start_d;
    assign O_ad_os      = 3'b000;  // No oversampling
    assign O_ad_range   = 1'b1;    // RANGE=1: +/-10 V input range; RANGE=0: +/-5 V
    assign O_ad_convsta = ad_convst;
    assign O_ad_convstb = ad_convst;
    assign O_sample_ready = (state == ST_IDLE) && !busy_sync && !O_ad_error;
    assign O_sample_busy  = (state != ST_IDLE);

    // BUSY is asynchronous to the FPGA clock. Serial DOUT is sampled
    // directly at the generated SCLK falling edge, with a half-cycle
    // settling interval after CS / the preceding SCLK rising edge.
    always @(posedge I_ad_clk or posedge I_ad_rst) begin
        if (I_ad_rst) begin
            busy_meta     <= 1'b0;
            busy_sync     <= 1'b0;
            sample_start_d <= 1'b0;
        end else begin
            busy_meta     <= I_ad_busy;
            busy_sync     <= busy_meta;
            sample_start_d <= I_sample_start;
        end
    end

    always @(posedge I_ad_clk or posedge I_ad_rst) begin
        if (I_ad_rst) begin
            state        <= ST_RESET;
            wait_count   <= 32'd0;
            spi_count    <= 32'd0;
            bit_count    <= 7'd0;
            shift_a      <= 64'd0;
            shift_b      <= 64'd0;
            O_ad_out_a   <= 64'd0;
            O_ad_out_b   <= 64'd0;
            O_ad_cap_en  <= 1'b0;
            O_ad_error   <= 1'b0;
            O_ad_cs      <= 1'b1;
            O_ad_sclk    <= 1'b1;
            O_ad_rst     <= 1'b1;
            ad_convst    <= 1'b1;
        end else begin
            O_ad_cap_en <= 1'b0;
            case (state)
                ST_RESET: begin
                    if (wait_count == RESET_CYCLES - 1) begin
                        O_ad_rst   <= 1'b0;
                        wait_count <= 32'd0;
                        state      <= ST_RECOVERY;
                    end else
                        wait_count <= wait_count + 1'b1;
                end

                ST_RECOVERY: begin
                    if (wait_count == RESET_RELEASE_CYCLES - 1) begin
                        wait_count <= 32'd0;
                        state      <= ST_IDLE;
                    end else
                        wait_count <= wait_count + 1'b1;
                end

                ST_IDLE: begin
                    O_ad_cs   <= 1'b1;
                    O_ad_sclk <= 1'b1;
                    if (start_event && O_sample_ready) begin
                        ad_convst  <= 1'b0;
                        wait_count <= 32'd0;
                        state      <= ST_CONV_LOW;
                    end
                end

                ST_CONV_LOW: begin
                    if (wait_count == CONVST_LOW_CYCLES - 1) begin
                        ad_convst  <= 1'b1;  // ADC samples on this rising edge
                        wait_count <= 32'd0;
                        state      <= ST_BUSY_HIGH;
                    end else
                        wait_count <= wait_count + 1'b1;
                end

                ST_BUSY_HIGH: begin
                    if (busy_sync) begin
                        wait_count <= 32'd0;
                        state      <= ST_BUSY_LOW;
                    end else if (wait_count == BUSY_TIMEOUT_CYCLES - 1) begin
                        O_ad_error <= 1'b1;
                        state      <= ST_FAULT;
                    end else
                        wait_count <= wait_count + 1'b1;
                end

                ST_BUSY_LOW: begin
                    if (!busy_sync) begin
                        O_ad_cs   <= 1'b0;   // First MSB appears after CS falls
                        O_ad_sclk <= 1'b1;
                        spi_count <= 32'd0;
                        bit_count <= 7'd0;
                        shift_a   <= 64'd0;
                        shift_b   <= 64'd0;
                        state     <= ST_READ;
                    end else if (wait_count == BUSY_TIMEOUT_CYCLES - 1) begin
                        O_ad_error <= 1'b1;
                        state      <= ST_FAULT;
                    end else
                        wait_count <= wait_count + 1'b1;
                end

                ST_READ: begin
                    if (busy_sync) begin
                        // Another conversion during a read would invalidate data.
                        O_ad_cs    <= 1'b1;
                        O_ad_sclk  <= 1'b1;
                        O_ad_error <= 1'b1;
                        state      <= ST_FAULT;
                    end else if (spi_count == SPI_HALF_CYCLES - 1) begin
                        spi_count <= 32'd0;
                        if (O_ad_sclk) begin
                            O_ad_sclk <= 1'b0;
                            shift_a <= {shift_a[62:0], I_O_ad_out_a};
                            shift_b <= {shift_b[62:0], I_O_ad_out_b};
                            if (bit_count == 7'd63)
                                state <= ST_FINISH;
                            else
                                bit_count <= bit_count + 1'b1;
                        end else
                            O_ad_sclk <= 1'b1;
                    end else
                        spi_count <= spi_count + 1'b1;
                end

                ST_FINISH: begin
                    // Hold CS and final SCLK low for a full half-period.
                    if (spi_count == SPI_HALF_CYCLES - 1) begin
                        O_ad_cs     <= 1'b1;
                        O_ad_sclk   <= 1'b1;
                        O_ad_out_a  <= shift_a;
                        O_ad_out_b  <= shift_b;
                        O_ad_cap_en <= 1'b1;
                        spi_count   <= 32'd0;
                        state       <= ST_IDLE;
                    end else
                        spi_count <= spi_count + 1'b1;
                end

                ST_FAULT: begin
                    O_ad_cs   <= 1'b1;
                    O_ad_sclk <= 1'b1;
                    ad_convst <= 1'b1;
                end

                default: begin
                    O_ad_cs    <= 1'b1;
                    O_ad_sclk  <= 1'b1;
                    ad_convst  <= 1'b1;
                    O_ad_error <= 1'b1;
                    state      <= ST_FAULT;
                end
            endcase
        end
    end
endmodule
