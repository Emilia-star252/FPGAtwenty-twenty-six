`timescale 1ns/1ps
module PLL_sys100(input refclk, reset, output clk0_out, lock);
    assign clk0_out = refclk;
    assign lock = !reset;
endmodule
module ChipWatcher_0(input clk, input [15:0] probe0, probe1, input probe2, probe3);
endmodule
// Command boundary stub. The real AXI register validation is covered by tb_adc_fifo.
module axi_system(output [2:0] O_hdmi_tx_p, output O_hdmi_clk_p, input axi_clk, pll_locked, ext_reset_n, adc_sample_valid, protection_stop,
    input [31:0] adc_status_in,
    input [47:0] voltage_product_in, current_product_in,
    input [31:0] duty_q16_in, control_status_in, vref_active_q16_in,
    output reg output_enable_cmd = 0, output reg [31:0] vref_cmd_q16 = 0,
    output axi_reset_n, output fault_clear_cmd);
    assign fault_clear_cmd = 0;
    assign axi_reset_n = pll_locked && ext_reset_n;
    always @(posedge axi_clk or negedge ext_reset_n or negedge pll_locked)
        if (!ext_reset_n || !pll_locked || protection_stop) begin
            output_enable_cmd <= 0;
            vref_cmd_q16 <= 0;
        end
endmodule
module remote_adc_model(input convst, cs, sclk, reset,
    output reg busy = 0, dout_a = 0, dout_b = 0);
    localparam [63:0] FRAME = {16'h1234, 16'd1966, 16'd3277, 16'hfedc};
    integer bit_index = 0;
    always @(posedge convst) if (!reset) begin
        #25 busy = 1;
        #4000 busy = 0;
    end
    always @(posedge reset) busy = 0;
    always @(negedge cs) begin bit_index = 0; #30 dout_a = FRAME[63]; end
    always @(posedge sclk) if (!cs && bit_index < 63) begin
        bit_index = bit_index + 1; #30 dout_a = FRAME[63 - bit_index];
    end
endmodule

module tb_remote_control;
    reg clk = 0, rst_n = 0;
    always #5 clk = !clk;
    wire busy, da, db, cs, sclk, adc_reset, convst, h1, l1, h2, l2;
    reg test_passed = 0;
    integer adc_frames = 0;
    // Isolate reference ramp/feedforward from the configurable PI gains.
    DCDC_top #(.ADC_RESET_CYCLES(8), .V_SOFT_START_MS(1),
        .V_KP_Q16(0), .V_KI_Q16(0), .I_KP_Q16(0), .I_KI_Q16(0)) dut (
        .I_rs485_rx(1'b1), .O_rs485_tx(), .O_rs485_de(), .O_hdmi_tx_p(), .O_hdmi_clk_p(),
        .clk_in(clk), .rst_n(rst_n), .ad_busy(busy), .ad_dout_a(da), .ad_dout_b(db),
        .ad_cs(cs), .ad_sclk(sclk), .ad_rst(adc_reset), .ad_convsta(convst),
        .ad_convstb(), .ad_range(), .card_power_en(),
        .pwm1_h(h1), .pwm1_l(l1), .pwm2_h(h2), .pwm2_l(l2));
    remote_adc_model adc(convst, cs, sclk, adc_reset, busy, da, db);

    always @(posedge dut.adc_valid) adc_frames = adc_frames + 1;
    always @(posedge clk) begin
        #1;
        if (!dut.pwm_output_enable && {h1,l1,h2,l2} !== 0)
            $fatal(1, "Output OFF did not drive all gates low");
        if (dut.pwm_output_enable && ({h1,l1} !== {h2,l2} || h1 === l1))
            $fatal(1, "PWM pair/complement mapping changed");
        if (dut.applied_duty_q16 !== (dut.pwm_output_enable
                ? ({20'd0, dut.pwm_active_counts} << 16) / 4000 : 0))
            $fatal(1, "Reported duty is not the applied PWM high time");
    end
    always @(posedge dut.pwm_output_enable) begin
        #1;
        if (dut.u_pwm.counter !== 0) $fatal(1, "Output armed in the middle of a period");
    end

    task automatic set_command(input integer volts, input bit enabled);
        @(negedge clk);
        dut.u_axi_system.vref_cmd_q16 = volts * 65536;
        dut.u_axi_system.output_enable_cmd = enabled && (volts != 0);
    endtask
    task automatic frames(input integer count);
        repeat (count) begin @(posedge dut.adc_valid); repeat (24) @(posedge clk); end
        #1;
    endtask
    task automatic wait_reference(input integer volts);
        integer cycles;
        cycles = 0;
        while (dut.v_ref_soft_q16 !== volts * 65536 && cycles < 40) begin
            frames(1); cycles = cycles + 1;
        end
        if (dut.v_ref_soft_q16 !== volts * 65536) $fatal(1, "Reference ramp timeout");
        frames(2);
    endtask
    task automatic check_period(input integer expected_highs);
        integer highs, triggers;
        @(negedge clk);
        while (dut.u_pwm.counter !== 0) @(negedge clk);
        highs = 0; triggers = 0;
        repeat (4000) begin
            if (h1) highs = highs + 1;
            if (dut.adc_trigger) triggers = triggers + 1;
            @(negedge clk);
        end
        if (highs != expected_highs || triggers != 1)
            $fatal(1, "PWM applied high ticks=%0d expected=%0d triggers=%0d", highs, expected_highs, triggers);
    endtask

    integer before_off, n;
    reg signed [31:0] previous_ref;
    initial begin
        repeat (5) @(negedge clk); rst_n = 1;
        frames(5);
        if (dut.pwm_output_enable || dut.applied_duty_q16 !== 0 || adc_frames < 5)
            $fatal(1, "Reset default must be output OFF while ADC continues");
        set_command(0, 1); frames(2);
        if (dut.pwm_output_enable) $fatal(1, "Zero Vref enabled PWM");

        set_command(12, 1);
        wait_reference(12);
        if (!dut.pwm_output_enable || dut.duty_counts !== 1333 ||
            dut.applied_duty_q16 !== (1333 * 65536 / 4000))
            $fatal(1, "12 V feedforward / applied-duty mismatch");
        check_period(1333);

        previous_ref = dut.v_ref_soft_q16;
        set_command(24, 1);
        for (n = 0; n < 8; n = n + 1) begin
            frames(1);
            if (dut.v_ref_soft_q16 < previous_ref || dut.v_ref_soft_q16 > 24 * 65536 ||
                dut.v_ref_soft_q16 - previous_ref > 125830)
                $fatal(1, "Upward reference slew bound");
            previous_ref = dut.v_ref_soft_q16;
        end
        wait_reference(24); check_period(2000);
        if (dut.applied_duty_q16 !== 32768) $fatal(1, "50 percent must be Q16 32768");

        previous_ref = dut.v_ref_soft_q16;
        set_command(64, 1);
        for (n = 0; n < 24; n = n + 1) begin
            frames(1);
            if (dut.v_ref_soft_q16 < previous_ref || dut.v_ref_soft_q16 > 64 * 65536 ||
                dut.v_ref_soft_q16 - previous_ref > 125830)
                $fatal(1, "64 V upward reference slew bound");
            previous_ref = dut.v_ref_soft_q16;
        end
        wait_reference(64); check_period(2909);
        if (dut.duty_counts !== 2909 || !dut.pwm_output_enable)
            $fatal(1, "64 V feedforward / applied-duty mismatch");

        previous_ref = dut.v_ref_soft_q16;
        set_command(6, 1);
        for (n = 0; n < 12; n = n + 1) begin
            frames(1);
            if (dut.v_ref_soft_q16 > previous_ref || dut.v_ref_soft_q16 < 6 * 65536 ||
                previous_ref - dut.v_ref_soft_q16 > 125830)
                $fatal(1, "Downward reference slew bound");
            previous_ref = dut.v_ref_soft_q16;
        end
        wait_reference(6); check_period(799);

        before_off = adc_frames;
        set_command(6, 0); #1;
        if ({h1,l1,h2,l2} !== 0 || dut.applied_duty_q16 !== 0)
            $fatal(1, "Output OFF must take effect immediately");
        frames(5);
        if (adc_frames < before_off + 5 || dut.v_ref_soft_q16 !== 0)
            $fatal(1, "Output OFF stopped sampling or failed to clear control state");
        set_command(12, 1); wait_reference(12); check_period(1333);
        force dut.adc_error = 1'b1; #1;
        if ({h1,l1,h2,l2} !== 0 || dut.applied_duty_q16 !== 0)
            $fatal(1, "ADC fault did not shut off PWM");
        @(negedge clk); rst_n = 0;
        repeat (5) @(negedge clk); release dut.adc_error; rst_n = 1;
        frames(3);
        if (dut.output_enable_cmd || dut.pwm_output_enable || dut.vref_cmd_q16 !== 0)
            $fatal(1, "External reset restored an old output request");

        set_command(12, 1); wait_reference(12);
        force dut.pll_locked = 0; #1;
        if ({h1,l1,h2,l2} !== 0) $fatal(1, "PLL loss did not shut off PWM");
        repeat (5) @(negedge clk); release dut.pll_locked;
        frames(3);
        if (dut.output_enable_cmd || dut.pwm_output_enable)
            $fatal(1, "PLL recovery restored an old output request");
        test_passed = 1;
        $display("REMOTE_CONTROL_TEST_PASS: default OFF, sampling while OFF, 64 V target, unchanged up/down Vref slew, applied PWM duty, boundary arming, disable/fault/reset");
        $finish;
    end
    initial begin #20000000; $fatal(1, "Remote control test timeout"); end
endmodule
