`timescale 1ns/1ps
// Verify the production top's raw-code conversion independently of the plant.
module PLL_sys100(input refclk, reset, output clk0_out, lock);
    assign clk0_out = refclk;
    assign lock = !reset;
endmodule
module ChipWatcher_0(input clk, input [15:0] probe0, probe1, input probe2, probe3);
endmodule
module axi_system(input axi_clk, pll_locked, ext_reset_n, adc_sample_valid, protection_stop,
    input [31:0] adc_status_in,
    input [47:0] voltage_product_in, current_product_in,
    input [31:0] duty_q16_in, control_status_in, vref_active_q16_in,
    output output_enable_cmd, output [31:0] vref_cmd_q16, output axi_reset_n,
    output fault_clear_cmd);
    assign fault_clear_cmd = 0;
    assign output_enable_cmd = 0;
    assign vref_cmd_q16 = 0;
    assign axi_reset_n = pll_locked && ext_reset_n;
endmodule

module tb_adc_scaling;
    reg clk = 0;
    always #5 clk = ~clk;
    reg [63:0] frame_a = 0;
    wire range_pin;
    reg test_passed = 0;
    reg [11:0] duty_test_counts;
    integer duty_test_index;
    DCDC_top dut (.clk_in(clk), .rst_n(1'b0), .ad_busy(1'b0),
        .ad_dout_a(1'b0), .ad_dout_b(1'b0), .ad_range(range_pin),
        .pwm1_h(), .pwm1_l(), .pwm2_h(), .pwm2_l(), .card_power_en(),
        .ad_cs(), .ad_sclk(), .ad_rst(), .ad_convsta(), .ad_convstb());
    DCDC_top #(.V_OFFSET_Q16(-65536), .I_OFFSET_Q16(32768)) biased (
        .clk_in(clk), .rst_n(1'b0), .ad_busy(1'b0), .ad_dout_a(1'b0), .ad_dout_b(1'b0),
        .pwm1_h(), .pwm1_l(), .pwm2_h(), .pwm2_l(), .card_power_en(),
        .ad_cs(), .ad_sclk(), .ad_rst(), .ad_convsta(), .ad_convstb(), .ad_range());
    DCDC_top #(.V_SCALE_Q16(2147483647), .I_SCALE_Q16(2147483647)) overflow (
        .clk_in(clk), .rst_n(1'b0), .ad_busy(1'b0), .ad_dout_a(1'b0), .ad_dout_b(1'b0),
        .pwm1_h(), .pwm1_l(), .pwm2_h(), .pwm2_l(), .card_power_en(),
        .ad_cs(), .ad_sclk(), .ad_rst(), .ad_convsta(), .ad_convstb(), .ad_range());

    task automatic check(input signed [15:0] v, i,
                         input signed [31:0] expected_v, expected_i);
        frame_a = {16'h5555, v, i, 16'haaaa};
        #2;
        if (dut.voltage_raw !== v || dut.current_raw !== i ||
            dut.saturate_q16(dut.voltage_product) !== expected_v ||
            dut.saturate_q16(dut.current_product) !== expected_i)
            $fatal(1, "Nominal +/-10V conversion V=%h I=%h", dut.voltage_product, dut.current_product);
        if (biased.saturate_q16(biased.voltage_product) !== expected_v - 65536 ||
            biased.saturate_q16(biased.current_product) !== expected_i + 32768)
            $fatal(1, "Signed calibration offset conversion");
    endtask
    initial begin
        force dut.adc_data_a = frame_a;
        force biased.adc_data_a = frame_a;
        force overflow.adc_data_a = frame_a;
        #2;
        if (range_pin !== 1'b1) $fatal(1, "ADC range must remain +/-10 V");
        check(0, 0, 0, 0);
        check(7864, 3277, 3145600, 65540); // about 48 V / 1 A
        check(-7864, -3277, -3145600, -65540);
        check(32767, -32768, 13106800, -655360);
        check(-32768, 32767, -13107200, 655340);
        check(2, 2, 800, 40);
        if (overflow.saturate_q16(overflow.voltage_product) !== 32'h7fffffff ||
            overflow.saturate_q16(overflow.current_product) !== 32'h7fffffff)
            $fatal(1, "Positive saturation");
        check(-2, -2, -800, -40);
        if (overflow.saturate_q16(overflow.voltage_product) !== 32'h80000000 ||
            overflow.saturate_q16(overflow.current_product) !== 32'h80000000)
            $fatal(1, "Negative saturation");
        force dut.pwm_active_counts = duty_test_counts;
        force dut.pwm_output_enable = 1'b1;
        for (duty_test_index = 0; duty_test_index < 4096; duty_test_index = duty_test_index + 1) begin
            duty_test_counts = duty_test_index;
            #2;
            if (dut.applied_duty_q16 !== duty_test_index * 65536 / 4000)
                $fatal(1, "Exact duty conversion mismatch at %0d", duty_test_index);
        end
        release dut.pwm_active_counts;
        release dut.pwm_output_enable;
        test_passed = 1;
        $display("ADC_SCALING_TEST_PASS: +/-10V range, gain 20/1, signed Q16, offsets, control saturation and applied-duty conversion; no GP0 sample ports");
        $finish;
    end
endmodule
