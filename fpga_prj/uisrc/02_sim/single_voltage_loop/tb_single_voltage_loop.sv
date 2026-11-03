`timescale 1ns/1ps

// Digital integration test: vendor PLL/debug/PS blocks are behavioral stubs.
// The production ADC driver, voltage PI and PWM are used without modification.
module PLL_sys100(input refclk, reset, output clk0_out, lock);
    assign clk0_out = refclk;
    assign lock = !reset;
endmodule

module ChipWatcher_0(input clk, input [15:0] probe0, probe1,
                     input probe2, probe3);
endmodule

module axi_system(
    input axi_clk, pll_locked, ext_reset_n, adc_sample_valid,
    output axi_reset_n,
    input [15:0] voltage_raw_in, current_raw_in,
    input [31:0] voltage_q16_in, current_q16_in, adc_status_in
);
    assign axi_reset_n = pll_locked && ext_reset_n;
    reg [15:0] voltage_sample, current_sample;
    reg [31:0] voltage_q16_sample, current_q16_sample;
    always @(posedge axi_clk) if (adc_sample_valid) begin
        voltage_sample <= voltage_raw_in;
        current_sample <= current_raw_in;
        voltage_q16_sample <= voltage_q16_in;
        current_q16_sample <= current_q16_in;
    end
endmodule

module adc7606_voltage_model(
    input convst, cs, sclk, reset,
    input [63:0] frame_a,
    output reg busy = 0, dout_a = 0, dout_b = 0
);
    reg [63:0] held_a;
    integer bit_index;
    always @(posedge convst) if (!reset) begin
        held_a = frame_a;
        #25 busy = 1;
        #4000 busy = 0;
    end
    always @(posedge reset) busy = 0;
    always @(negedge cs) begin
        bit_index = 0;
        #30 dout_a = held_a[63];
    end
    always @(posedge sclk) if (!cs && bit_index < 63) begin
        bit_index = bit_index + 1;
        #30 dout_a = held_a[63-bit_index];
    end
endmodule

module tb_single_voltage_loop;
    reg clk = 0;
    always #5 clk = !clk;
    reg rst_n = 0;
    reg [63:0] frame = {16'h1234, 16'd40, 16'd1, 16'hfedc};
    wire busy, da, db, cs, sclk, adc_reset, convst;
    wire h1, l1, h2, l2;
    reg test_passed = 0;
    integer updates = 0;

    // error = 48 - 40 = 8 V; Kp = 1/16 duty/V -> duty = 0.5.
    // These coefficients are chosen only for the digital test, not plant tuning.
    DCDC_top #(.ADC_RESET_CYCLES(8), .V_KP_Q16(4096)) dut (
        .clk_in(clk), .rst_n(rst_n), .ad_busy(busy),
        .ad_dout_a(da), .ad_dout_b(db), .ad_cs(cs), .ad_sclk(sclk),
        .ad_rst(adc_reset), .ad_convsta(convst), .ad_convstb(),
        .ad_range(), .card_power_en(),
        .pwm1_h(h1), .pwm1_l(l1), .pwm2_h(h2), .pwm2_l(l2)
    );
    adc7606_voltage_model adc(convst, cs, sclk, adc_reset, frame,
                              busy, da, db);

    always @(posedge clk) begin
        #1;
        if (!dut.pwm_output_enable && {h1,l1,h2,l2} !== 4'b0000)
            $fatal(1, "PWM must be low during reset/ADC initialization");
        if (dut.pwm_output_enable && ({h1,l1} !== {h2,l2} || h1 === l1))
            $fatal(1, "PWM complement/pair mapping changed");
        if (dut.control_rst_n && (dut.sample_overrun || dut.adc_error))
            $fatal(1, "Unexpected sample overrun or ADC fault");
    end

    task automatic check_update(input signed [15:0] voltage, current,
                                input signed [31:0] expected_q16,
                                input integer expected_counts);
        begin
            @(posedge dut.adc_valid); #1;
            if (dut.voltage_raw !== voltage || dut.current_raw !== current)
                $fatal(1, "ADC frame mismatch");
            // ADC valid -> latch feedback -> PI accept -> 3 PI clocks.
            repeat (5) begin @(posedge clk); #1; end
            if (dut.voltage_pi_valid !== 1 || dut.pi_out_valid !== 1 ||
                dut.pi_out_q16 !== expected_q16 ||
                dut.voltage_fbk_q16 !== voltage * 32'sd65536)
                $fatal(1, "Voltage PI output/latency mismatch: got %0d expected %0d",
                       dut.pi_out_q16, expected_q16);
            @(posedge clk); #1;
            if (dut.duty_counts !== expected_counts || dut.pi_busy || dut.pi_out_valid)
                $fatal(1, "Duty update/handshake mismatch: got %0d expected %0d",
                       dut.duty_counts, expected_counts);
            if (dut.u_axi_system.voltage_sample !== voltage ||
                dut.u_axi_system.current_sample !== current ||
                dut.u_axi_system.voltage_q16_sample !== voltage * 32'sd65536 ||
                dut.u_axi_system.current_q16_sample !== current * 32'sd65536)
                $fatal(1, "Voltage/current telemetry wiring changed");
            updates = updates + 1;
            $display("PASS Vraw=%0d Iraw=%0d duty_q16=%0d counts=%0d sample_to_duty=60ns",
                     voltage, current, expected_q16, expected_counts);
        end
    endtask

    task automatic check_pwm_period(input integer expected_counts);
        integer k, highs, triggers;
        begin
            do begin @(posedge clk); #1; end
            while (dut.u_pwm.counter != 0 ||
                   dut.u_pwm.duty_active != expected_counts);
            highs = 0; triggers = 0;
            for (k = 0; k < 4000; k = k + 1) begin
                if (h1) highs = highs + 1;
                if (dut.adc_trigger) begin
                    triggers = triggers + 1;
                    if (k != expected_counts/2)
                        $fatal(1, "PWM ADC trigger phase changed");
                end
                if (k != 3999) begin @(posedge clk); #1; end
            end
            if (highs != expected_counts || triggers != 1)
                $fatal(1, "PWM width/trigger count mismatch");
            $display("PASS PWM period=4000 high_ticks=%0d ADC_triggers=1", highs);
        end
    endtask

    initial begin
        #32 rst_n = 1;
        check_update(40, 1, 32768, 2000);
        check_pwm_period(2000);
        // Change only current: it remains visible, but cannot change duty.
        @(negedge clk); frame[31:16] = -16'sd20;
        check_update(40, -20, 32768, 2000);
        @(negedge clk); frame[31:16] = 16'sd32767;
        check_update(40, 32767, 32768, 2000);
        // 1 V error -> 6.25%, including the Q16-to-count conversion.
        @(negedge clk); frame[47:32] = 16'd47;
        check_update(47, 32767, 4096, 250);
        // Large positive error must clip at 95%, rather than the old 4 A limit.
        @(negedge clk); frame[47:32] = 16'd0;
        check_update(0, 32767, 62259, 3800);
        check_pwm_period(3800);
        // Negative voltage error clips at 5% and maps to exactly 200 ticks.
        @(negedge clk); frame[47:32] = 16'd60;
        check_update(60, 32767, 3277, 200);
        check_pwm_period(200);
        // With Ki=0, voltage feedback returns the output to the interior.
        @(negedge clk); frame[47:32] = 16'd40;
        check_update(40, 32767, 32768, 2000);
        @(negedge clk); force dut.pll_locked = 0; #1;
        if ({h1,l1,h2,l2} !== 4'b0000 || dut.duty_counts !== 0)
            $fatal(1, "PLL loss must clear duty and all PWM outputs");
        release dut.pll_locked;
        @(negedge clk); rst_n = 0; #1;
        if ({h1,l1,h2,l2} !== 4'b0000 || dut.duty_counts !== 0)
            $fatal(1, "External reset must clear duty and all PWM outputs");
        $display("SINGLE_VOLTAGE_LOOP_PASS updates=%0d", updates);
        test_passed = 1;
        $finish;
    end

    initial begin #1000000; $fatal(1, "Simulation watchdog expired"); end
endmodule
