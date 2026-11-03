`timescale 1ns/1ps
// Fixed-point translation of CNTL_PI_F_FUNC.
// Signed numeric value = stored integer / 2**FRAC.
// Legal parameters: FRAC >= 0, WIDTH - FRAC >= 5.
// Multiplication discards fractional bits using arithmetic right shift.
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
    localparam integer IP_W   = UP_W + WIDTH;
    localparam integer DI_W   = IP_W - FRAC;
    // Enough room for delta + i1 + up, even at full-scale inputs.
    localparam integer ACC_W  = DI_W + 2;

    localparam [1:0] IDLE = 2'd0, INTEGRAL = 2'd1,
                     SUM = 2'd2, LIMIT = 2'd3;
    localparam signed [WIDTH-1:0] TEN = 10;
    localparam signed [WIDTH-1:0] I_MAX = TEN <<< FRAC;
    localparam signed [WIDTH-1:0] I_MIN = -I_MAX;

    reg [1:0] state;
    reg signed [WIDTH-1:0] ki_hold, umax_hold, umin_hold;
    reg signed [UP_W-1:0] up;
    reg signed [ACC_W-1:0] ui, v1;
    reg signed [WIDTH-1:0] i1;
    // Equivalent to previous (Out == v1), initialized true (0 == 0).
    reg prev_unsaturated;

    assign busy = (state != IDLE);
    assign in_ready = rst_n && !clear && !busy;

    wire signed [ERR_W-1:0] error_value =
        $signed({ref_in[WIDTH-1], ref_in}) -
        $signed({fbk_in[WIDTH-1], fbk_in});
    wire signed [PROD_W-1:0] p_product = error_value * kp_in;
    wire signed [UP_W-1:0] up_next = p_product >>> FRAC;

    wire signed [IP_W-1:0] i_product = up * ki_hold;
    wire signed [DI_W-1:0] delta_i = i_product >>> FRAC;
    wire signed [ACC_W-1:0] delta_ext =
        {{(ACC_W-DI_W){delta_i[DI_W-1]}}, delta_i};
    wire signed [ACC_W-1:0] i1_ext =
        {{(ACC_W-WIDTH){i1[WIDTH-1]}}, i1};
    wire signed [ACC_W-1:0] up_ext =
        {{(ACC_W-UP_W){up[UP_W-1]}}, up};
    wire signed [ACC_W-1:0] imax_ext =
        {{(ACC_W-WIDTH){I_MAX[WIDTH-1]}}, I_MAX};
    wire signed [ACC_W-1:0] imin_ext =
        {{(ACC_W-WIDTH){I_MIN[WIDTH-1]}}, I_MIN};
    wire signed [ACC_W-1:0] umax_ext =
        {{(ACC_W-WIDTH){umax_hold[WIDTH-1]}}, umax_hold};
    wire signed [ACC_W-1:0] umin_ext =
        {{(ACC_W-WIDTH){umin_hold[WIDTH-1]}}, umin_hold};

    wire signed [ACC_W-1:0] ui_next =
        prev_unsaturated ? (i1_ext + delta_ext) : i1_ext;
    // Keep the two comparisons in C order (upper, then lower).
    wire signed [ACC_W-1:0] upper_limited =
        (v1 > umax_ext) ? umax_ext : v1;
    wire signed [ACC_W-1:0] out_next =
        (upper_limited < umin_ext) ? umin_ext : upper_limited;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            ki_hold <= 0;
            umax_hold <= 0;
            umin_hold <= 0;
            up <= 0;
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
            up <= 0;
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
                        up <= up_next;
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
                        i1 <= ui_next[WIDTH-1:0];
                    state <= SUM;
                end
                SUM: begin
                    v1 <= up_ext + ui;
                    state <= LIMIT;
                end
                LIMIT: begin
                    out <= out_next[WIDTH-1:0];
                    prev_unsaturated <= (out_next == v1);
                    out_valid <= 1'b1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
