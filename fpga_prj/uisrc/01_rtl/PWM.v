`timescale 1ns / 1ps

// Edge-aligned PWM: 100 MHz / 4000 = 25 kHz.
// duty_counts: high-time in 100 MHz ticks, 0..4000 (0..100%).
// Input must be synchronous to clk_100m and stable around the sampling edge.
module PWM (
    input  wire        clk_100m,
    input  wire        rst_n,
    input  wire [11:0] duty_counts,
    output reg         pwm_out,
    output reg         adc_trigger,
    output wire [11:0] duty_active_out,
    output wire        period_start_out
);
    localparam [11:0] PERIOD_COUNTS = 12'd4000;
    localparam [11:0] LAST_COUNT    = 12'd3999;

    reg [11:0] counter;
    reg [11:0] duty_active;
    assign duty_active_out = duty_active;

    wire period_start = (counter == LAST_COUNT);
    assign period_start_out = period_start;
    wire [11:0] duty_clamped = (duty_counts > PERIOD_COUNTS)
                                ? PERIOD_COUNTS : duty_counts;
    wire [11:0] counter_next = period_start ? 12'd0
                                            : counter + 12'd1;
    // Sample duty only at the start of a period to avoid truncated pulses.
    wire [11:0] duty_next = period_start ? duty_clamped : duty_active;
    wire [11:0] midpoint = duty_next >> 1;
    // Keep feedback sampling alive during startup at zero duty.
    wire [11:0] sample_point = (duty_next == 12'd0)
                                ? 12'd2000 : midpoint;

    always @(posedge clk_100m or negedge rst_n) begin
        if (!rst_n) begin
            // Start the first complete period on the first edge after reset.
            counter     <= LAST_COUNT;
            duty_active <= 12'd0;
            pwm_out     <= 1'b0;
            adc_trigger <= 1'b0;
        end else begin
            counter     <= counter_next;
            duty_active <= duty_next;
            pwm_out     <= (counter_next < duty_next);

            // One clk_100m tick (10 ns) per PWM period.
            // Odd widths: midpoint rounded down, error <= 5 ns.
            // Zero duty: trigger at 20 us. 100%: trigger at midpoint.
            adc_trigger <= (counter_next == sample_point);
        end
    end
endmodule
