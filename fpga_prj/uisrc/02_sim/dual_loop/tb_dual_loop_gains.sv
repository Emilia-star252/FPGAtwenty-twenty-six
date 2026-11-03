`timescale 1ns/1ps
// Check production inner-loop gain defaults through the complete digital chain.
// Shared boundary/ADC models are defined in adc_fifo/tb_protection.sv.
module tb_dual_loop_gains;
    reg clk = 0, rst_n = 0;
    always #5 clk = !clk;
    reg signed [15:0] current_raw = 1;
    wire busy, da, db, cs, sclk, adc_reset, convst;
    reg test_passed = 0;
    integer updates = 0;
    // Only the outer gain and calibration are simplified for this test.
    // The inner Kp/Ki are deliberately not overridden.
    DCDC_top #(.ADC_RESET_CYCLES(8), .V_SOFT_START_MS(0),
        .V_KP_Q16(16384), .V_KI_Q16(0),
        .V_SCALE_Q16(65536), .I_SCALE_Q16(65536),
        .V_OFFSET_Q16(0), .I_OFFSET_Q16(0)) dut (
        .I_rs485_rx(1'b1), .O_rs485_tx(), .O_rs485_de(),
        .O_hdmi_tx_p(), .O_hdmi_clk_p(),
        .clk_in(clk), .rst_n(rst_n), .ad_busy(busy),
        .ad_dout_a(da), .ad_dout_b(db), .ad_cs(cs), .ad_sclk(sclk),
        .ad_rst(adc_reset), .ad_convsta(convst), .ad_convstb(),
        .ad_range(), .card_power_en(),
        .pwm1_h(), .pwm1_l(), .pwm2_h(), .pwm2_l());
    protection_adc_model adc(convst, cs, sclk, adc_reset,
                             16'd40, current_raw, busy, da, db);

    task automatic start_output;
        dut.u_axi_system.write_command('h44, 48 * 65536);
        dut.u_axi_system.write_command('h40, 1);
    endtask

    task automatic check_output(input integer amps, correction, counts);
        @(posedge dut.pi_out_valid); #1;
        if (dut.current_ref_q16 !== 131072 || dut.current_fbk_q16 !== amps * 65536 ||
            dut.pi_out_q16 !== correction || dut.sample_overrun || dut.adc_error ||
            dut.protection_fault)
            $fatal(1, "Default inner gain arithmetic mismatch: got=%0d expected=%0d",
                   dut.pi_out_q16, correction);
        @(posedge clk); #1;
        if (dut.duty_counts !== counts)
            $fatal(1, "Default inner gain duty mismatch: got=%0d expected=%0d",
                   dut.duty_counts, counts);
        updates = updates + 1;
        $display("PASS production I_Kp=655 I_Ki=1311 current=%0d correction=%0d duty=%0d",
                 amps, correction, counts);
    endtask

    initial begin
        if (dut.I_KP_Q16 != 655 || dut.I_KI_Q16 != 1311 || dut.I_REF_MAX_Q16 != 393216)
            $fatal(1, "Production gain/current-limit defaults were not updated");
        repeat (5) @(negedge clk); rst_n = 1;
        repeat (2) @(posedge dut.adc_valid); #1;
        start_output();
        // Iref=2 A, feedback=1 A. P=655 Q16. Each increment retains
        // 65536*655*1311=56276090880 Q48, or about 13.103 Q16 counts.
        check_output(1, 668, 2707);
        check_output(1, 681, 2708);
        check_output(1, 694, 2708);
        @(negedge clk); current_raw = 3;
        check_output(3, -629, 2628);
        @(negedge clk); current_raw = 2;
        check_output(2, 26, 2668);
        if (dut.u_current_pi.i1 === 0) $fatal(1, "Expected nonzero stored integral");
        @(negedge clk); rst_n = 0; #1;
        if (dut.u_current_pi.i1 !== 0 || dut.duty_counts !== 0)
            $fatal(1, "Reset did not clear active inner integral");
        current_raw = 1;
        repeat (5) @(negedge clk); rst_n = 1;
        repeat (2) @(posedge dut.adc_valid); #1;
        start_output();
        check_output(1, 668, 2707);
        $display("DUAL_LOOP_GAINS_PASS updates=%0d: production defaults, P/I accumulation, signed correction, reset", updates);
        test_passed = 1; $finish;
    end
    initial begin #1500000; $fatal(1, "Default inner gain watchdog"); end
endmodule
