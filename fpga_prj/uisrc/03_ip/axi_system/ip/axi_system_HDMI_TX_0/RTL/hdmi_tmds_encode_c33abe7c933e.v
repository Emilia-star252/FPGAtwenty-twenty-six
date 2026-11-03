
module hdmi_tmds_encode_c33abe7c933e 
#(
    /// TMDS Channel number
    /// There are only 3 possible channel numbers in HDMI 1.4a: 0, 1, 2
    parameter CHANNEL_NUM = 0
)
(
    input wire       I_clk,
    input wire       I_rst,

    input wire       I_video_valid,
    input wire       I_video_guard_valid,
    input wire       I_island_valid,
    input wire       I_island_guard_valid,

    input wire[7:0]  I_video_data,
    input wire[1:0]  I_control_data,
    input wire[3:0]  I_island_data,

    output reg[9:0]  O_tmds_code_data
);

    reg[7:0]         S_video_data_1d;

    reg              S_video_valid_1d;
    reg              S_video_valid_2d;
    reg              S_video_valid_3d;
    reg              S_video_valid_4d;

    reg              S_video_guard_valid_1d;
    reg              S_video_guard_valid_2d;
    reg              S_video_guard_valid_3d;
    reg              S_video_guard_valid_4d;

    reg              S_island_valid_1d;
    reg              S_island_valid_2d;
    reg              S_island_valid_3d;
    reg              S_island_valid_4d;

    reg              S_island_guard_valid_1d;
    reg              S_island_guard_valid_2d;
    reg              S_island_guard_valid_3d;
    reg              S_island_guard_valid_4d;
    
    reg[3:0]         S_N_1_D;            ///using figure 5-7 names：N1{D}
    wire[8:0]        S_q_m_comb;
    reg[8:0]         S_q_m;              ///using figure 5-7 names：q_m
    reg[8:0]         S_q_m_1d;
    reg[3:0]         S_N_1_q_m_0_7;      ///using figure 5-7 names：N1{q_m[0:7]}
    reg[3:0]         S_N_0_q_m_0_7;      ///using figure 5-7 names：N0{q_m[0:7]}
    reg[9:0]         S_video_data_code;  ///using figure 5-7 names：q_out
    reg signed [4:0] S_cnt_t_1;          ///using figure 5-7 names：Cnt(t-1)

    reg[9:0]         S_control_signal_code;
    reg[9:0]         S_control_signal_code_1d;
    reg[9:0]         S_control_signal_code_2d;
    reg[9:0]         S_control_signal_code_3d;

    reg[9:0]         S_data_island_code;
    reg[9:0]         S_data_island_code_1d;
    reg[9:0]         S_data_island_code_2d;
    reg[9:0]         S_data_island_code_3d;

    reg[9:0]         S_video_data_guard_band_code;
    reg[9:0]         S_video_data_guard_band_code_1d;
    reg[9:0]         S_video_data_guard_band_code_2d;
    reg[9:0]         S_video_data_guard_band_code_3d;

    reg[9:0]         S_data_island_guard_band_code;
    reg[9:0]         S_data_island_guard_band_code_1d;
    reg[9:0]         S_data_island_guard_band_code_2d;
    reg[9:0]         S_data_island_guard_band_code_3d;

///video data encode
    ///see hdmi 1.4a Spec section 5.4.4.1 Video Data Encoding
    ///below is a direct implementation of Figure 5-7, and using the same variable names

    always @(posedge I_clk) begin
        S_video_valid_1d        <= I_video_valid;
        S_video_valid_2d        <= S_video_valid_1d;
        S_video_valid_3d        <= S_video_valid_2d;
        S_video_valid_4d        <= S_video_valid_3d;

        S_video_guard_valid_1d  <= I_video_guard_valid;
        S_video_guard_valid_2d  <= S_video_guard_valid_1d;
        S_video_guard_valid_3d  <= S_video_guard_valid_2d;
        S_video_guard_valid_4d  <= S_video_guard_valid_3d;

        S_island_valid_1d       <= I_island_valid;
        S_island_valid_2d       <= S_island_valid_1d;
        S_island_valid_3d       <= S_island_valid_2d;
        S_island_valid_4d       <= S_island_valid_3d;

        S_island_guard_valid_1d <= I_island_guard_valid;
        S_island_guard_valid_2d <= S_island_guard_valid_1d;
        S_island_guard_valid_3d <= S_island_guard_valid_2d;
        S_island_guard_valid_4d <= S_island_guard_valid_3d;

        S_video_data_1d         <= I_video_data;
    end

    always @(posedge I_clk) begin
        S_N_1_D <= I_video_data[0] + I_video_data[1] + I_video_data[2] + I_video_data[3] + 
                   I_video_data[4] + I_video_data[5] + I_video_data[6] + I_video_data[7];
    end

    ///see hdmi Spec 1.4a figure 5-7
    ///由于计算引入了自身，因此这里只能使用组合逻辑，否则时序逻辑因为延时关系会出现错误�?

    assign S_q_m_comb[0] = S_video_data_1d[0];
    assign S_q_m_comb[1] = (S_N_1_D > 'd4) || (S_N_1_D == 'd4 && S_video_data_1d[0] == 1'b0) ? (S_q_m_comb[0] ^~ S_video_data_1d[1]) : (S_q_m_comb[0] ^ S_video_data_1d[1]);
    assign S_q_m_comb[2] = (S_N_1_D > 'd4) || (S_N_1_D == 'd4 && S_video_data_1d[0] == 1'b0) ? (S_q_m_comb[1] ^~ S_video_data_1d[2]) : (S_q_m_comb[1] ^ S_video_data_1d[2]);
    assign S_q_m_comb[3] = (S_N_1_D > 'd4) || (S_N_1_D == 'd4 && S_video_data_1d[0] == 1'b0) ? (S_q_m_comb[2] ^~ S_video_data_1d[3]) : (S_q_m_comb[2] ^ S_video_data_1d[3]);
    assign S_q_m_comb[4] = (S_N_1_D > 'd4) || (S_N_1_D == 'd4 && S_video_data_1d[0] == 1'b0) ? (S_q_m_comb[3] ^~ S_video_data_1d[4]) : (S_q_m_comb[3] ^ S_video_data_1d[4]);
    assign S_q_m_comb[5] = (S_N_1_D > 'd4) || (S_N_1_D == 'd4 && S_video_data_1d[0] == 1'b0) ? (S_q_m_comb[4] ^~ S_video_data_1d[5]) : (S_q_m_comb[4] ^ S_video_data_1d[5]);
    assign S_q_m_comb[6] = (S_N_1_D > 'd4) || (S_N_1_D == 'd4 && S_video_data_1d[0] == 1'b0) ? (S_q_m_comb[5] ^~ S_video_data_1d[6]) : (S_q_m_comb[5] ^ S_video_data_1d[6]);
    assign S_q_m_comb[7] = (S_N_1_D > 'd4) || (S_N_1_D == 'd4 && S_video_data_1d[0] == 1'b0) ? (S_q_m_comb[6] ^~ S_video_data_1d[7]) : (S_q_m_comb[6] ^ S_video_data_1d[7]);
    assign S_q_m_comb[8] = (S_N_1_D > 'd4) || (S_N_1_D == 'd4 && S_video_data_1d[0] == 1'b0) ? 1'b0 : 1'b1;

    always @(posedge I_clk ) begin
         S_q_m    <= S_q_m_comb;
         S_q_m_1d <= S_q_m;
    end

    always @(posedge I_clk) begin
        S_N_1_q_m_0_7 <= S_q_m[0] + S_q_m[1] + S_q_m[2] + S_q_m[3] + S_q_m[4] + S_q_m[5] + S_q_m[6] + S_q_m[7];
        S_N_0_q_m_0_7 <= (~S_q_m[0]) + (~S_q_m[1]) + (~S_q_m[2]) + (~S_q_m[3]) + (~S_q_m[4]) + (~S_q_m[5]) + (~S_q_m[6]) + (~S_q_m[7]);
    end

    always @(posedge I_clk or posedge I_rst) begin
        if(I_rst)
            S_video_data_code <= 'd0;
        else
            if((S_cnt_t_1 == 0) || (S_N_1_q_m_0_7 == S_N_0_q_m_0_7))
                begin
                    S_video_data_code[9] <= ~S_q_m_1d[8];                             ///see hdmi Spec 1.4a figure 5-7：q_out[9]   = ~q_m[8]    
                    S_video_data_code[8] <= S_q_m_1d[8];                              ///see hdmi Spec 1.4a figure 5-7：q_out[9]   = q_m[8]    
                    S_video_data_code[7:0] <= S_q_m_1d[8] ? S_q_m_1d[7:0] : ~S_q_m_1d[7:0]; ///see hdmi Spec 1.4a figure 5-7：q_out[0:7] = (q_m[8] ? q_m[0:7] : ~q_m[0:7]) 
                end      
            else if((S_cnt_t_1 > 0 && S_N_1_q_m_0_7 > S_N_0_q_m_0_7) || (S_cnt_t_1 < 0 && S_N_0_q_m_0_7 > S_N_1_q_m_0_7))
                begin
                    S_video_data_code[9]   <= 1'b1;        ///see hdmi Spec 1.4a figure 5-7：q_out[9] = 1
                    S_video_data_code[8]   <= S_q_m_1d[8];    ///see hdmi Spec 1.4a figure 5-7：q_out[8] = q_m[8]
                    S_video_data_code[7:0] <= ~S_q_m_1d[7:0]; ///see hdmi Spec 1.4a figure 5-7：q_out[0:7] = ~q_m[0:7]
                end
            else
                begin
                    S_video_data_code[9]   <= 1'b0;        ///see hdmi Spec 1.4a figure 5-7：q_out[9] = 0
                    S_video_data_code[8]   <= S_q_m_1d[8];    ///see hdmi Spec 1.4a figure 5-7：q_out[8] = q_m[8]
                    S_video_data_code[7:0] <= S_q_m_1d[7:0];  ///see hdmi Spec 1.4a figure 5-7：q_out[0:7] = q_m[0:7]
                end
    end

    always @(posedge I_clk or posedge I_rst) begin
        if(I_rst)
            S_cnt_t_1 <= 0;
        else
            if(S_video_valid_2d)
                if((S_cnt_t_1 == 0) || (S_N_1_q_m_0_7 == S_N_0_q_m_0_7))
                    if(S_q_m_1d[8]==1'b0)
                        S_cnt_t_1 <= S_cnt_t_1 + $signed({1'b0,S_N_0_q_m_0_7}) - $signed({1'b0,S_N_1_q_m_0_7});
                    else
                        S_cnt_t_1 <= S_cnt_t_1 + $signed({1'b0,S_N_1_q_m_0_7}) - $signed({1'b0,S_N_0_q_m_0_7});
                else if((S_cnt_t_1 > 0 && S_N_1_q_m_0_7 > S_N_0_q_m_0_7) || (S_cnt_t_1 < 0 && S_N_0_q_m_0_7 > S_N_1_q_m_0_7))
                    S_cnt_t_1 <= S_cnt_t_1 + $signed({3'b0,{1'b0,S_q_m_1d[8]}<<1}) +  $signed({1'b0,S_N_0_q_m_0_7}) - $signed({1'b0,S_N_1_q_m_0_7});
                else
                    S_cnt_t_1 <= S_cnt_t_1 - $signed({3'b0,{1'b0,~S_q_m_1d[8]}<<1}) +  $signed({1'b0,S_N_1_q_m_0_7}) - $signed({1'b0,S_N_0_q_m_0_7});
            else
                S_cnt_t_1 <= 0;
    end

///Control signals encode
    ///see hdmi 1.4a Spec section 5.4.2 Control Period Coding

    always @(posedge I_clk or posedge I_rst) begin
        if(I_rst)
            S_control_signal_code <= 'd0;
        else
            case(I_control_data)
                2'b00:  S_control_signal_code <= 10'b1101010100;
                2'b01:  S_control_signal_code <= 10'b0010101011;
                2'b10:  S_control_signal_code <= 10'b0101010100;
                2'b11:  S_control_signal_code <= 10'b1010101011;
            endcase
    end

    always @(posedge I_clk) begin
        S_control_signal_code_1d <= S_control_signal_code;
        S_control_signal_code_2d <= S_control_signal_code_1d;
        S_control_signal_code_3d <= S_control_signal_code_2d;
    end

/*
///island data encode
   ///see hdmi 1.4a Spec section 5.4.3 TERC4 Coding

    always @(posedge I_clk or posedge I_rst) begin
        if(I_rst)
            S_data_island_code <= 'd0;
        else
            case(I_island_data)
                4'b0000 : S_data_island_code <= 10'b1010011100;
                4'b0001 : S_data_island_code <= 10'b1001100011;
                4'b0010 : S_data_island_code <= 10'b1011100100;
                4'b0011 : S_data_island_code <= 10'b1011100010;
                4'b0100 : S_data_island_code <= 10'b0101110001;
                4'b0101 : S_data_island_code <= 10'b0100011110;
                4'b0110 : S_data_island_code <= 10'b0110001110;
                4'b0111 : S_data_island_code <= 10'b0100111100;
                4'b1000 : S_data_island_code <= 10'b1011001100;
                4'b1001 : S_data_island_code <= 10'b0100111001;
                4'b1010 : S_data_island_code <= 10'b0110011100;
                4'b1011 : S_data_island_code <= 10'b1011000110;
                4'b1100 : S_data_island_code <= 10'b1010001110;
                4'b1101 : S_data_island_code <= 10'b1001110001;
                4'b1110 : S_data_island_code <= 10'b0101100011;
                4'b1111 : S_data_island_code <= 10'b1011000011;
            endcase
    end

    always @(posedge I_clk) begin
        S_data_island_code_1d <= S_data_island_code;
        S_data_island_code_2d <= S_data_island_code_1d;
        S_data_island_code_3d <= S_data_island_code_2d;
    end

///video data guard band encode
    ///see hdmi 1.4a Spec section 5.2.1 Video Guard Band

    always @(posedge I_clk or posedge I_rst) begin
        if(I_rst)
            S_video_data_guard_band_code <= 'd0;
        else
            case(CHANNEL_NUM)
                0:  S_video_data_guard_band_code <= 10'b1011001100;
                1:  S_video_data_guard_band_code <= 10'b0100110011;
                2:  S_video_data_guard_band_code <= 10'b1011001100;
            endcase
    end

    always @(posedge I_clk) begin
        S_video_data_guard_band_code_1d <= S_video_data_guard_band_code;
        S_video_data_guard_band_code_2d <= S_video_data_guard_band_code_1d;
        S_video_data_guard_band_code_3d <= S_video_data_guard_band_code_2d;
    end

///data island guard band encode
    ///see hdmi 1.4a Spec section 5.2.3.3 Data Island Guard Band

    always @(posedge I_clk or posedge I_rst) begin
        if(I_rst)
            S_data_island_guard_band_code <= 'd0;
        else
            case(CHANNEL_NUM)
                0:  
                    S_data_island_guard_band_code <= I_control_data == 2'b00 ? 10'b1010001110 :
                                                     I_control_data == 2'b01 ? 10'b1001110001 :
                                                     I_control_data == 2'b10 ? 10'b0101100011 :
                                                     I_control_data == 2'b11 ? 10'b1011000011 : 'd0;
                1:  S_data_island_guard_band_code <= 10'b0100110011;
                2:  S_data_island_guard_band_code <= 10'b0100110011;
            endcase
    end

    always @(posedge I_clk) begin
        S_data_island_guard_band_code_1d <= S_data_island_guard_band_code;
        S_data_island_guard_band_code_2d <= S_data_island_guard_band_code_1d;
        S_data_island_guard_band_code_3d <= S_data_island_guard_band_code_2d;
    end

*/

///all coding data output

    always @(posedge I_clk or posedge I_rst) begin
        if(I_rst)
            O_tmds_code_data <= 'd0;
        else
            if(S_video_valid_4d)
                O_tmds_code_data <= S_video_data_code;
            // else if(S_video_guard_valid_4d)
            //     O_tmds_code_data <= S_video_data_guard_band_code_3d;
            // else if(S_island_valid_4d)
            //     O_tmds_code_data <= S_data_island_code_3d;
            // else if(S_island_guard_valid_4d)
            //     O_tmds_code_data <= S_data_island_guard_band_code_3d;
            else
                O_tmds_code_data <= S_control_signal_code_3d;
    end

endmodule
