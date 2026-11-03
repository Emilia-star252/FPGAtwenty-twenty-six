
module hdmi_video_data_assemble_c33abe7c933e (
    input wire       I_clk,
    input wire       I_rst,

    input wire       I_vsync,
    input wire       I_hsync,
    input wire       I_video_preamble,
    input wire       I_video_guard_band,
    input wire       I_video_period,
    input wire       I_island_preamble,
    input wire       I_island_guard_band,
    input wire       I_island_period,

    output wire      O_video_data_rd_en,
    input wire [7:0] I_video_data_ch0,
    input wire [7:0] I_video_data_ch1,
    input wire [7:0] I_video_data_ch2,

    output reg       O_vsync,
    output reg       O_hsync,
    output reg       O_video_preamble,
    output reg       O_video_guard_band,
    output reg       O_video_period,
    output reg [7:0] O_video_data_ch0,
    output reg [7:0] O_video_data_ch1,
    output reg [7:0] O_video_data_ch2,
    output reg       O_island_preamble,
    output reg       O_island_guard_band,
    output reg       O_island_period

);

    reg S_vsync_1d;
    reg S_hsync_1d;
    reg S_video_preamble_1d;
    reg S_video_guard_band_1d;
    reg S_video_period_1d;
    reg S_island_preamble_1d;
    reg S_island_guard_band_1d;
    reg S_island_period_1d;

    assign O_video_data_rd_en = O_video_period;

    always @(posedge I_clk) begin
        S_vsync_1d             <= I_vsync;
        S_hsync_1d             <= I_hsync;
        S_video_preamble_1d    <= I_video_preamble;
        S_video_guard_band_1d  <= I_video_guard_band;
        S_video_period_1d      <= I_video_period;
        S_island_preamble_1d   <= I_island_preamble;
        S_island_guard_band_1d <= I_island_guard_band;
        S_island_period_1d     <= I_island_period;
  
        O_vsync                <= S_vsync_1d;            
        O_hsync                <= S_hsync_1d;            
        O_video_preamble       <= S_video_preamble_1d;   
        O_video_guard_band     <= S_video_guard_band_1d; 
        O_video_period         <= S_video_period_1d;     
        O_island_preamble      <= S_island_preamble_1d;  
        O_island_guard_band    <= S_island_guard_band_1d;
        O_island_period        <= S_island_period_1d;   

        O_video_data_ch0       <= I_video_data_ch0;
        O_video_data_ch1       <= I_video_data_ch1;
        O_video_data_ch2       <= I_video_data_ch2;
    end

endmodule
