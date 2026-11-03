
module hdmi_data_distribution_c33abe7c933e (
    input wire        I_clk,
    input wire        I_rst,
  
    input wire        I_video_vsync,
    input wire        I_video_hsync,
    input wire        I_video_period,
    input wire        I_video_preamble,
    input wire        I_video_guard_band,

    input wire[7:0]   I_video_data_ch0,
    input wire[7:0]   I_video_data_ch1,
    input wire[7:0]   I_video_data_ch2,

    input wire        I_island_preamble,
    input wire        I_island_guard_band,
    input wire        I_island_period,

    input wire[3:0]   I_island_data_ch0,
    input wire[3:0]   I_island_data_ch1,
    input wire[3:0]   I_island_data_ch2,

    output reg        O_video_valid,
    output reg        O_video_guard_band_valid,
    output reg        O_island_valid,
    output reg        O_island_preamble,
    output reg        O_island_guard_band_valid,
 
    output reg[7:0]   O_ch0_video_data,
    output reg[1:0]   O_ch0_control_data,
    output reg[3:0]   O_ch0_island_data,
 
    output reg[7:0]   O_ch1_video_data,
    output reg[1:0]   O_ch1_control_data,
    output reg[3:0]   O_ch1_island_data,
 
    output reg[7:0]   O_ch2_video_data,
    output reg[1:0]   O_ch2_control_data,
    output reg[3:0]   O_ch2_island_data
);

    always @(posedge I_clk) begin
        O_ch0_control_data        <= {I_video_vsync,I_video_hsync};
        O_ch1_control_data        <= I_video_preamble  ?  2'b01 : 
                                     I_island_preamble ?  2'b01 : 2'b00;
       
        O_ch2_control_data        <= I_video_preamble  ? 2'b00 :
                                     I_island_preamble ? 2'b01 : 2'b00;

        O_video_valid             <= I_video_period;
        O_video_guard_band_valid  <= I_video_guard_band;
        O_island_valid            <= I_island_period;
        O_island_guard_band_valid <= I_island_guard_band;

        O_ch0_video_data          <= I_video_data_ch0;
        O_ch1_video_data          <= I_video_data_ch1;
        O_ch2_video_data          <= I_video_data_ch2;

        O_ch0_island_data         <= I_island_data_ch0;
        O_ch1_island_data         <= I_island_data_ch1;
        O_ch2_island_data         <= I_island_data_ch2;
    end

endmodule
