`timescale 1ns/1ps
// Fixed-point translation of CNTL_PI_F_FUNC.
// Signed numeric value = stored integer / 2**FRAC.
// Legal parameters: FRAC >= 0, WIDTH - FRAC >= 5.
// The P output uses FRAC fractional bits. Integration keeps all 3*FRAC
// product fractional bits, including the fraction discarded by the P output.
module cntl_pi_fixed #(
    parameter integer WIDTH = 32,
    parameter integer FRAC  = 16
) (
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     clear,
    input  wire                     in_valid,
    output wire                     in_ready,
    input  wire signed [WIDTH-1:0]  ref_in,
    input  wire signed [WIDTH-1:0]  fbk_in,
    input  wire signed [WIDTH-1:0]  kp_in,
    input  wire signed [WIDTH-1:0]  ki_in,
    input  wire signed [WIDTH-1:0]  umax_in,
    input  wire signed [WIDTH-1:0]  umin_in,
    output reg  signed [WIDTH-1:0]  out,
    output reg                      out_valid,
    output wire                     busy
);
    localparam integer ERR_W  = WIDTH + 1;
    localparam integer PROD_W = ERR_W + WIDTH;
    localparam integer UP_W   = PROD_W - FRAC;
    localparam integer IP_W   = PROD_W + WIDTH;
    localparam integer EXTRA_FRAC = 2 * FRAC;
    // The existing +/-30 integral clamp needs six integer/sign bits,
    // including when the interface format has only five.
    localparam integer INT_W  = ((WIDTH-FRAC < 6) ? FRAC+6 : WIDTH) + EXTRA_FRAC;
    // Enough room for delta + i1 + up, even at full-scale inputs.
    localparam integer ACC_W  = IP_W + 2;

    localparam [1:0] IDLE = 2'd0, INTEGRAL = 2'd1,
                     SUM = 2'd2, LIMIT = 2'd3;
    localparam signed [INT_W-1:0] I_LIMIT_VALUE = 30;
    localparam signed [INT_W-1:0] I_MAX = I_LIMIT_VALUE <<< (3*FRAC);
    localparam signed [INT_W-1:0] I_MIN = -I_MAX;

    reg [1:0] state;
    reg signed [WIDTH-1:0] ki_hold, umax_hold, umin_hold;
    reg signed [PROD_W-1:0] p_hold;
    wire signed [UP_W-1:0] up = p_hold >>> FRAC;
    reg signed [ACC_W-1:0] ui, v1;
    // Q(3*FRAC): default 64-bit accumulator with 48 fractional bits.
    reg signed [INT_W-1:0] i1;
    // Equivalent to previous (Out == v1), initialized true (0 == 0).
    reg prev_unsaturated;

    assign busy = (state != IDLE);
    assign in_ready = rst_n && !clear && !busy;

    wire signed [ERR_W-1:0] error_value =
        $signed({ref_in[WIDTH-1], ref_in}) -
        $signed({fbk_in[WIDTH-1], fbk_in});
    wire signed [PROD_W-1:0] p_product = error_value * kp_in;
    // Integrate the full error*Kp*Ki product; do not quantize each increment.
    wire signed [IP_W-1:0] i_product = p_hold * ki_hold;
    wire signed [ACC_W-1:0] delta_ext =
        {{(ACC_W-IP_W){i_product[IP_W-1]}}, i_product};
    wire signed [ACC_W-1:0] i1_ext =
        {{(ACC_W-INT_W){i1[INT_W-1]}}, i1};
    wire signed [ACC_W-1:0] up_ext =
        {{(ACC_W-UP_W-EXTRA_FRAC){up[UP_W-1]}}, up,
         {EXTRA_FRAC{1'b0}}};
    wire signed [ACC_W-1:0] imax_ext =
        {{(ACC_W-INT_W){I_MAX[INT_W-1]}}, I_MAX};
    wire signed [ACC_W-1:0] imin_ext =
        {{(ACC_W-INT_W){I_MIN[INT_W-1]}}, I_MIN};
    wire signed [ACC_W-1:0] umax_ext =
        {{(ACC_W-WIDTH-EXTRA_FRAC){umax_hold[WIDTH-1]}}, umax_hold, {EXTRA_FRAC{1'b0}}};
    wire signed [ACC_W-1:0] umin_ext =
        {{(ACC_W-WIDTH-EXTRA_FRAC){umin_hold[WIDTH-1]}}, umin_hold, {EXTRA_FRAC{1'b0}}};

    wire signed [ACC_W-1:0] ui_next =
        prev_unsaturated ? (i1_ext + delta_ext) : i1_ext;
    // Keep the two comparisons in C order (upper, then lower).
    wire signed [ACC_W-1:0] upper_limited =
        (v1 > umax_ext) ? umax_ext : v1;
    wire signed [ACC_W-1:0] out_next =
        (upper_limited < umin_ext) ? umin_ext : upper_limited;
    wire signed [ACC_W-1:0] out_qfrac = out_next >>> EXTRA_FRAC;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            ki_hold <= 0;
            umax_hold <= 0;
            umin_hold <= 0;
            p_hold <= 0;
            ui <= 0;
            v1 <= 0;
            i1 <= 0;
            out <= 0;
            out_valid <= 1'b0;
            prev_unsaturated <= 1'b1;
        end else if (clear) begin
            state <= IDLE;
            ki_hold <= 0;
            umax_hold <= 0;
            umin_hold <= 0;
            p_hold <= 0;
            ui <= 0;
            v1 <= 0;
            i1 <= 0;
            out <= 0;
            out_valid <= 1'b0;
            prev_unsaturated <= 1'b1;
        end else begin
            out_valid <= 1'b0;
            case (state)
                IDLE: begin
                    if (in_valid && in_ready) begin
                        p_hold <= p_product;
                        ki_hold <= ki_in;
                        umax_hold <= umax_in;
                        umin_hold <= umin_in;
                        state <= INTEGRAL;
                    end
                end
                INTEGRAL: begin
                    ui <= ui_next;
                    // C clips the stored i1 only; ui remains unclipped.
                    if (ui_next > imax_ext)
                        i1 <= I_MAX;
                    else if (ui_next < imin_ext)
                        i1 <= I_MIN;
                    else
                        i1 <= ui_next[INT_W-1:0];
                    state <= SUM;
                end
                SUM: begin
                    v1 <= up_ext + ui;
                    state <= LIMIT;
                end
                LIMIT: begin
                    out <= out_qfrac[WIDTH-1:0];
                    // Compare before output quantization: a fractional result
                    // inside the limits must not freeze the next integration.
                    prev_unsaturated <= (out_next == v1);
                    out_valid <= 1'b1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
