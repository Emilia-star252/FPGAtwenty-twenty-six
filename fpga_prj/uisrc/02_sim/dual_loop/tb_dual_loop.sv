`timescale 1ns/1ps
// Reuse the PLL/ChipWatcher/AXI boundary and serial ADC models in
// adc_fifo/tb_protection.sv. ADC, both PIs, PWM, AXI registers and RS485
// controller are production RTL. No analog power-stage model is included.
module tb_dual_loop;
    reg clk = 0, rst_n = 0;
    always #5 clk = !clk;
    reg signed [15:0] voltage_raw = 40, current_raw = 1;
    wire busy, da, db, cs, sclk, adc_reset, convst, h1, l1, h2, l2;
    reg test_passed = 0;
    integer updates = 0, samples = 0;

    // Simulation-only gains: V PI = 0.25 A/V, I PI = 0.125 duty/A.
    // Integer V/A feedback simplifies independent expected-value checks.
    DCDC_top #(.ADC_RESET_CYCLES(8), .V_SOFT_START_MS(0),
        .V_KP_Q16(16384), .V_KI_Q16(0), .I_KP_Q16(8192), .I_KI_Q16(0),
        .V_SCALE_Q16(65536), .I_SCALE_Q16(65536),
        .V_OFFSET_Q16(0), .I_OFFSET_Q16(0)) dut (
        .I_rs485_rx(1'b1), .O_rs485_tx(), .O_rs485_de(),
        .O_hdmi_tx_p(), .O_hdmi_clk_p(),
        .clk_in(clk), .rst_n(rst_n), .ad_busy(busy),
        .ad_dout_a(da), .ad_dout_b(db), .ad_cs(cs), .ad_sclk(sclk),
        .ad_rst(adc_reset), .ad_convsta(convst), .ad_convstb(),
        .ad_range(), .card_power_en(),
        .pwm1_h(h1), .pwm1_l(l1), .pwm2_h(h2), .pwm2_l(l2)
    );
    protection_adc_model adc(convst, cs, sclk, adc_reset,
                             voltage_raw, current_raw, busy, da, db);

    always @(posedge dut.adc_valid) samples = samples + 1;
    always @(posedge clk) begin
        #1;
        if (!dut.pwm_output_enable && {h1,l1,h2,l2} !== 4'b0000)
            $fatal(1, "Disabled output must hold all four gates low");
        if (dut.pwm_output_enable && ({h1,l1} !== {h2,l2} || h1 === l1))
            $fatal(1, "PWM complement/pair mapping changed");
        if (dut.sample_overrun || dut.adc_error)
            $fatal(1, "Unexpected sample overrun or ADC fault");
    end

    task automatic command(input integer volts, input bit enabled);
        dut.u_axi_system.write_command('h44, volts * 65536);
        dut.u_axi_system.write_command('h40, enabled);
    endtask

    task automatic check_update(input integer volts, amps,
        input signed [31:0] expected_iref, expected_correction,
        input integer expected_counts, input bit disturb_current = 0);
        integer voltage_latency;
        begin
            @(posedge dut.adc_valid); #1;
            if (dut.voltage_raw !== volts || dut.current_raw !== amps)
                $fatal(1, "Serial ADC frame mismatch");
            // The divider adds 16 clocks only when the reference changes.
            voltage_latency = (dut.v_ref_soft_q16 != dut.vref_cmd_q16) ? 21 : 5;
            repeat (voltage_latency) begin @(posedge clk); #1; end
            if (!dut.voltage_pi_valid || dut.pi_out_valid ||
                dut.voltage_pi_out_q16 !== expected_iref ||
                dut.voltage_fbk_q16 !== volts * 65536 ||
                dut.current_fbk_q16 !== amps * 65536)
                $fatal(1, "Outer-loop result, same-frame feedback or latency mismatch");
            // A changing ADC product between PI transactions must not replace
            // the current feedback already latched with this voltage sample.
            if (disturb_current) force dut.current_product = 48'sd196608;
            @(posedge clk); #1;
            if (dut.current_ref_q16 !== expected_iref || dut.loop_state != dut.START_I)
                $fatal(1, "Outer PI did not hand current reference to inner PI");
            @(posedge clk); #1;
            if (!dut.current_pi_busy || dut.current_pi_ready)
                $fatal(1, "Inner PI handshake failed");
            repeat (3) begin @(posedge clk); #1; end
            if (!dut.pi_out_valid || dut.pi_out_q16 !== expected_correction ||
                dut.current_fbk_q16 !== amps * 65536)
                $fatal(1, "Inner correction mismatch: got %0d expected %0d",
                       dut.pi_out_q16, expected_correction);
            if (disturb_current) release dut.current_product;
            @(posedge clk); #1;
            if (dut.duty_counts !== expected_counts || dut.pi_busy || dut.pi_out_valid)
                $fatal(1, "Feedforward/duty update mismatch: got %0d expected %0d",
                       dut.duty_counts, expected_counts);
            updates = updates + 1;
            $display("PASS V=%0d I=%0d Iref_Q16=%0d inner_Q16=%0d duty_counts=%0d latency=%0dns",
                     volts, amps, expected_iref, expected_correction, expected_counts,
                     (voltage_latency + 6) * 10);
        end
    endtask

    task automatic check_pwm_period(input integer expected_counts);
        integer k, highs, triggers;
        begin
            do begin @(posedge clk); #1; end
            while (dut.u_pwm.counter != 0 || dut.pwm_active_counts != expected_counts);
            highs = 0; triggers = 0;
            for (k = 0; k < 4000; k = k + 1) begin
                if (h1) highs = highs + 1;
                if (dut.adc_trigger) triggers = triggers + 1;
                if (k != 3999) begin @(posedge clk); #1; end
            end
            if (highs != expected_counts || triggers != 1)
                $fatal(1, "PWM width or ADC trigger count mismatch");
            $display("PASS PWM high_ticks=%0d ADC_triggers=1", highs);
        end
    endtask

    task automatic expect_control_clear;
        if ({h1,l1,h2,l2} !== 0 || dut.duty_counts !== 0 || dut.pwm_armed ||
            dut.current_ref_q16 !== 0 || dut.current_fbk_q16 !== 0 ||
            dut.voltage_fbk_q16 !== 0 || dut.v_ref_soft_q16 !== 0 ||
            dut.u_voltage_pi.i1 !== 0 || dut.u_current_pi.i1 !== 0 ||
            dut.voltage_pi_busy || dut.current_pi_busy || dut.loop_state != dut.WAIT_SAMPLE)
            $fatal(1, "Shutdown did not clear both loops and PWM");
    endtask

    integer before_stop;
    initial begin
        repeat (5) @(negedge clk); rst_n = 1;
        repeat (2) @(posedge dut.adc_valid); #1;
        if (dut.output_enable_cmd || dut.pwm_output_enable)
            $fatal(1, "Reset default must be output OFF");
        command(48, 1);
        check_update(40, 1, 131072, 8192, 3166, 1);
        check_pwm_period(3166);
        // Same voltage -> same Iref; increasing current lowers duty.
        @(negedge clk); current_raw = 2;
        check_update(40, 2, 131072, 0, 2666);
        @(negedge clk); current_raw = 3;
        check_update(40, 3, 131072, -8192, 2166);
        // Zero voltage error -> zero outer-loop current request (Ki=0).
        @(negedge clk); voltage_raw = 48; current_raw = 1;
        check_update(48, 1, 0, -8192, 2166);
        // Outer 6 A limit and inner +0.2 correction limit are separate units.
        @(negedge clk); voltage_raw = 0; current_raw = 0;
        check_update(0, 0, 393216, 13107, 3466);
        @(negedge clk); voltage_raw = 60; current_raw = 3;
        check_update(60, 3, 0, -13107, 1866);
        check_pwm_period(1866);
        // Changed reference recalculates the existing 24 V bus feedforward.
        @(negedge clk); voltage_raw = 20; current_raw = 1;
        command(24, 1);
        check_update(20, 1, 65536, 0, 2000);
        check_pwm_period(2000);

        // Stop while the inner PI is active; no stale completion may write duty.
        @(posedge dut.current_pi_busy);
        force dut.output_enable_cmd = 0; #1;
        expect_control_clear();
        before_stop = samples;
        repeat (2) @(posedge dut.adc_valid); #1;
        if (samples <= before_stop) $fatal(1, "Stop disabled diagnostic sampling");
        release dut.output_enable_cmd;
        check_update(20, 1, 65536, 0, 2000);

        // ADC protection still trips and clears the restored current PI.
        @(negedge clk); current_raw = 5;
        @(posedge convst); @(posedge dut.adc_valid); @(posedge clk); #1;
        if (!dut.overcurrent_fault) $fatal(1, "Restored loop bypassed OCP");
        expect_control_clear();
        before_stop = samples;
        repeat (2) @(posedge dut.adc_valid); #1;
        if (samples <= before_stop) $fatal(1, "Protection stopped ADC sampling");
        @(negedge clk); rst_n = 0; #1;
        expect_control_clear();
        $display("DUAL_LOOP_TEST_PASS updates=%0d: cascade, current feedback, same-frame latch, limits, feedforward, PWM, stop, OCP, reset", updates);
        test_passed = 1; $finish;
    end
    initial begin #3000000; $fatal(1, "Dual-loop watchdog"); end
endmodule
