`timescale 1ns/1ps
// Production top/ADC/PI/PWM. Only vendor PLL, debug and PS blocks are stubs.
module PLL_sys100(input refclk,reset,output clk0_out,lock);
    assign clk0_out=refclk;
    assign lock=!reset;
endmodule
module ChipWatcher_0(input clk,input [15:0] probe0,probe1,input probe2,probe3);
endmodule
module axi_system(input axi_clk,pll_locked,ext_reset_n,adc_sample_valid,
    input [47:0] voltage_product_in,current_product_in,
    input [31:0] duty_q16_in,control_status_in,vref_active_q16_in,adc_status_in,
    input protection_stop,
    output axi_reset_n,output_enable_cmd,fault_clear_cmd,
    output [31:0] vref_cmd_q16);
    assign axi_reset_n=pll_locked&&ext_reset_n;
    assign output_enable_cmd=0;
    assign fault_clear_cmd=0;
    assign vref_cmd_q16=1572864;
endmodule

module tb_pi_precision_top;
    reg clk=0,rst_n=0;
    always #5 clk=~clk;
    wire cs,sclk,adc_reset,convst,h1,l1,h2,l2;
    reg busy=0,da=0;
    reg [63:0] held_frame;
    integer bit_index=0,n,first_counts,last_counts;
    integer first_pi,last_pi;
    reg test_passed=0;
    DCDC_top #(.ADC_RESET_CYCLES(8),.V_SOFT_START_MS(0)) dut(
        .clk_in(clk),.rst_n(rst_n),.ad_busy(busy),.ad_dout_a(da),.ad_dout_b(1'b0),
        .ad_cs(cs),.ad_sclk(sclk),.ad_rst(adc_reset),.ad_convsta(convst),
        .ad_convstb(),.ad_range(),.card_power_en(),
        .pwm1_h(h1),.pwm1_l(l1),.pwm2_h(h2),.pwm2_l(l2));
    always @(posedge convst) if (!adc_reset) begin
        held_frame={16'd0,16'd3916,16'd1687,16'd0};
        #25 busy=1;
        #4000 busy=0;
    end
    always @(posedge adc_reset) busy=0;
    always @(negedge cs) begin bit_index=0; #30 da=held_frame[63]; end
    always @(posedge sclk) if (!cs && bit_index<63) begin
        bit_index=bit_index+1; #30 da=held_frame[63-bit_index];
    end
    always @(posedge clk) begin
        #1;
        if (!dut.pwm_output_enable && {h1,l1,h2,l2} !== 4'b0000)
            $fatal(1,"Gates active while disabled");
        if (dut.pwm_output_enable && ({h1,l1} !== {h2,l2} || h1===l1))
            $fatal(1,"PWM pair/complement mapping changed");
        if (dut.sample_overrun || dut.adc_error || dut.protection_stop)
            $fatal(1,"ADC/control fault");
    end
    task automatic update;
        begin
            @(posedge dut.voltage_pi_valid); #1;
            if (dut.voltage_raw !== 16'd3916 || dut.current_raw !== 16'd1687 ||
                dut.voltage_fbk_q16 !== 32'sd1537203 || dut.v_ref_soft_q16 !== 32'sd1572864)
                $fatal(1,"Feedback/reference mismatch");
            if (dut.pi_out_q16 < -13107 || dut.pi_out_q16 > 13107)
                $fatal(1,"Correction clamp failed");
            @(posedge clk); #1;
        end
    endtask
    initial begin
        #32; rst_n=1;
        update(); first_counts=dut.duty_counts; first_pi=dut.pi_out_q16;
        for (n=1;n<256;n=n+1) update();
        last_counts=dut.duty_counts; last_pi=dut.pi_out_q16;
        if (last_pi <= first_pi || last_counts <= first_counts)
            $fatal(1,"Small error did not increase applied duty");
        // For a fixed error this is a digital arithmetic/connection check;
        // the constant ADC source is not a model of power-stage convergence.
        if (first_pi !== 35 || last_pi !== 126 || first_counts !== 2002 || last_counts !== 2007)
            $fatal(1,"Unexpected precision result first=%0d/%0d last=%0d/%0d",first_pi,first_counts,last_pi,last_counts);
        @(posedge dut.pwm_period_start);
        @(posedge clk); #1;
        if (dut.pwm_active_counts !== last_counts || !dut.pwm_output_enable)
            $fatal(1,"PWM failed to latch new duty");
        // A reset while the accumulator is fractional must clear its residue.
        #2; rst_n=0; #1;
        if ({h1,l1,h2,l2} !== 4'b0000) $fatal(1,"Async gate reset failed");
        repeat(4) @(posedge clk); #1;
        if (dut.u_voltage_pi.i1 !== 0 || dut.duty_counts !== 0)
            $fatal(1,"Control reset did not clear state");
        $display("PI_PRECISION_TOP_PASS frames=256 PI_Q16=%0d->%0d PWM_counts=%0d->%0d",first_pi,last_pi,first_counts,last_counts);
        test_passed=1; $finish;
    end
    initial begin #20000000; $fatal(1,"Top watchdog"); end
endmodule
