
module hdmi_tx_controller_wrapper_c33abe7c933e   
(
    input wire       I_pixel_clk,
    input wire       I_rst,

    input wire[23:0] I_video_in_data,
    input wire       I_video_in_vs,
    input wire       I_video_in_hs,
    input wire       I_video_in_de,

///*********************  tmds data output  *****************************
    output wire[9:0] O_ch0_tmds_code_data,     
    output wire[9:0] O_ch1_tmds_code_data,     
    output wire[9:0] O_ch2_tmds_code_data,     
    output wire[9:0] O_clk_tmds_code_data      

);

    wire        S_video_valid;            
    wire        S_video_guard_band_valid; 
    wire        S_island_valid;      
    wire        S_island_guard_band_valid;
    wire        S_source_video_vsync;               
    wire        S_source_video_hsync;               
    wire        S_source_video_period;              
    wire        S_source_video_preamble;            
    wire        S_source_video_guard_band;          
    wire        S_source_island_preamble;           
    wire        S_source_island_guard_band;         
    wire        S_source_island_period;             
    wire[31:0]  S_BCH_block_4;                      
    wire[63:0]  S_BCH_block_3;
    wire[63:0]  S_BCH_block_2;
    wire[63:0]  S_BCH_block_1;
    wire[63:0]  S_BCH_block_0;                
    wire        S_frame_start;      
    wire        S_island_packet_req;
    wire        S_video_source_sof;  
    wire        S_video_source_sol;  
    wire        S_video_source_pause;
    wire        S_video_locked;              
    wire        S_video_vsync_1;             
    wire        S_video_hsync_1;             
    wire        S_video_period_1;            
    wire        S_video_preamble_1;          
    wire        S_video_guard_band_1;        
    wire        S_island_preamble_1;         
    wire        S_island_guard_band_1;       
    wire        S_island_period_1;           
    wire        S_video_vsync_2;      
    wire        S_video_hsync_2;              
    wire        S_video_preamble_2;    
    wire        S_video_guard_band_2;  
    wire        S_island_preamble_2;   
    wire        S_island_guard_band_2; 
    wire        S_tpg_en;
    wire        S_tpg_video_user;
    wire        S_tpg_video_valid;
    wire        S_tpg_video_last;
    wire[23:0]  S_tpg_video_data;
    wire        S_tpg_video_ready;
    wire        S_video_out_user;    //synthesis keep  
    wire        S_video_out_valid;   //synthesis keep  
    wire        S_video_out_last;    //synthesis keep
    wire[23:0]  S_video_out_data;    //synthesis keep  
    wire        S_video_out_ready;   //synthesis keep  
    wire[7:0]   S_video_data_ch0_0;
    wire[7:0]   S_video_data_ch1_0;
    wire[7:0]   S_video_data_ch2_0;
    wire[7:0]   S_video_data_ch0_1;
    wire[7:0]   S_video_data_ch1_1;
    wire[7:0]   S_video_data_ch2_1;
    wire[7:0]   S_video_data_ch0_2;
    wire[7:0]   S_video_data_ch1_2;
    wire[7:0]   S_video_data_ch2_2;
    wire[3:0]   S_island_data_ch0;
    wire[3:0]   S_island_data_ch1;
    wire[3:0]   S_island_data_ch2;
    wire[7:0]   S_ch0_video_data; 
    wire[3:0]   S_ch0_island_data;
    wire[1:0]   S_ch0_control_data;
    wire[7:0]   S_ch1_video_data; 
    wire[3:0]   S_ch1_island_data;
    wire[1:0]   S_ch1_control_data;
    wire[7:0]   S_ch2_video_data; 
    wire[3:0]   S_ch2_island_data;
    wire[1:0]   S_ch2_control_data;

    // assign O_video_in_vs = S_source_video_vsync;

    // assign S_tpg_en = VIDEO_TPG == "Enable" ? 1'b1 : 1'b0;
    
    // hdmi_video_tpg_gen  #(
    //     .HTOTAL  ( HTOTAL  ),
    //     .HACTIVE ( HACTIVE ),

    //     .VTOTAL  ( VTOTAL  ),
    //     .VACTIVE ( VACTIVE )
    // )u_hdmi_video_tpg_gen(
    //     .I_clk                 ( I_pixel_clk       ),
    //     .I_rst                 ( I_rst             ),

    //     .I_tpg_en              ( S_tpg_en          ),

    //     .O_video_user          ( S_tpg_video_user  ),
    //     .O_video_valid         ( S_tpg_video_valid ),
    //     .O_video_last          ( S_tpg_video_last  ),
    //     .O_video_data          ( S_tpg_video_data  ),
    //     .I_video_ready         ( S_tpg_video_ready )
    // );

    // hdmi_video_source_mux u_hdmi_video_source_mux(
    //     .I_clk             ( I_pixel_clk       ),
    //     .I_rst             ( I_rst             ),

    //     .I_tpg_en          ( S_tpg_en          ),

    //     .I_video_in_user   ( I_video_in_user   ),
    //     .I_video_in_valid  ( I_video_in_valid  ),
    //     .I_video_in_last   ( I_video_in_last   ),
    //     .I_video_in_data   ( I_video_in_data   ),
    //     .O_video_in_ready  ( O_video_in_ready  ),

    //     .I_tpg_video_user  ( S_tpg_video_user  ),
    //     .I_tpg_video_valid ( S_tpg_video_valid ),
    //     .I_tpg_video_last  ( S_tpg_video_last  ),
    //     .I_tpg_video_data  ( S_tpg_video_data  ),
    //     .O_tpg_video_ready ( S_tpg_video_ready ),

    //     .O_video_out_user  ( S_video_out_user  ),
    //     .O_video_out_valid ( S_video_out_valid ),
    //     .O_video_out_last  ( S_video_out_last  ),
    //     .O_video_out_data  ( S_video_out_data  ),
    //     .I_video_out_ready ( S_video_out_ready )
    // );

    // hdmi_island_data_gen #(
    //     .VIDEO_FORMAT      ( VIDEO_FORMAT      ),
    //     .VIDEO_VIC         ( VIDEO_VIC         ),
    //     .AUDIO_CTS         ( AUDIO_CTS         ),
    //     .AUDIO_N           ( AUDIO_N           ),
    //     .AUDIO_SAMPLE_RATE ( AUDIO_SAMPLE_RATE ),
    //     .AUDIO_CHANNEL_NUM ( "AUDIO_2_CHANNEL" )
    // )u_hdmi_island_data_gen(
    //     .I_clk                   ( I_pixel_clk                    ),
    //     .I_rst                   ( I_rst                          ),
                                                              
    //     .I_frame_start           ( S_frame_start                  ),
    //     .I_island_packet_req     ( S_island_packet_req            ),
                                                                  
    //     .I_audio_valid           ( I_audio_valid                  ),
    //     .I_audio_left_data       ( I_audio_left_data              ),
    //     .I_audio_right_data      ( I_audio_right_data             ),
                                                                  
    //     .O_BCH_block_4           ( S_BCH_block_4                  ),
    //     .O_BCH_block_3           ( S_BCH_block_3                  ),
    //     .O_BCH_block_2           ( S_BCH_block_2                  ),
    //     .O_BCH_block_1           ( S_BCH_block_1                  ),
    //     .O_BCH_block_0           ( S_BCH_block_0                  )
    // );

    // video_axi_stream_receiver u_video_axi_stream_receiver(
    //     .I_clk                       ( I_pixel_clk          ),
    //     .I_rst                       ( I_rst                ),
   
    //     .I_video_source_sof          (),
    //     .I_video_source_sol          (),
    //     .O_video_source_pause        ( S_video_source_pause ),
    //     .O_video_locked              ( S_video_locked       ),
   
    //     .I_video_in_user             ( S_video_out_user     ),
    //     .I_video_in_valid            ( S_video_out_valid    ),
    //     .I_video_in_last             ( S_video_out_last     ),
    //     .I_video_in_data             ( S_video_out_data     ),
    //     .O_video_in_ready            ( S_video_out_ready    ),
   
    //     .I_video_data_assemble_rd_en ( S_video_data_rd_en   ),
    //     .O_video_data_ch0            ( S_video_data_ch0_0   ),
    //     .O_video_data_ch1            ( S_video_data_ch1_0   ),
    //     .O_video_data_ch2            ( S_video_data_ch2_0   )
    // );

    // hdmi_video_source #(
    //     .HTOTAL  ( HTOTAL  ),
    //     .HSA     ( HSA     ),
    //     .HFP     ( HFP     ),
    //     .HBP     ( HBP     ),
    //     .HACTIVE ( HACTIVE ),
          
    //     .VTOTAL  ( VTOTAL  ),
    //     .VSA     ( VSA     ),
    //     .VFP     ( VFP     ), 
    //     .VBP     ( VBP     ),
    //     .VACTIVE ( VACTIVE )
    // ) u_hdmi_video_source(
    //     .I_clk                      ( I_pixel_clk                 ),
    //     .I_rst                      ( I_rst                       ),

    //     .I_video_en                 ( 1'b1                        ),
    //     .I_video_source_pause       ( S_video_source_pause        ),

    //     .O_vsync                    ( S_source_video_vsync        ),
    //     .O_hsync                    ( S_source_video_hsync        ),
    //     .O_video_preamble           (),
    //     .O_video_guard_band         (),
    //     .O_video_period             ( S_source_video_period       ),
    //     .O_video_sof                (),
    //     .O_video_sol                (),
    //     .O_island_preamble          (),
    //     .O_island_guard_band        (),
    //     .O_island_period            ()
    // );

    assign S_video_data_ch0_0 = I_video_in_data[7:0];
    assign S_video_data_ch1_0 = I_video_in_data[15:8];
    assign S_video_data_ch2_0 = I_video_in_data[23:16];
    
    hdmi_video_data_assemble_c33abe7c933e u_hdmi_video_data_assemble(
        .I_clk               ( I_pixel_clk                 ),
        .I_rst               ( I_rst                       ),
   
        .O_video_data_rd_en  (),
        .I_video_data_ch0    ( S_video_data_ch0_0          ),
        .I_video_data_ch1    ( S_video_data_ch1_0          ),
        .I_video_data_ch2    ( S_video_data_ch2_0          ),
     
        .I_vsync             (   I_video_in_vs             ),
        .I_hsync             (   I_video_in_hs             ),
        .I_video_preamble    (),
        .I_video_guard_band  (),
        .I_video_period      (   I_video_in_de             ),
        .I_island_preamble   (),
        .I_island_guard_band (),
        .I_island_period     (),
      
        .O_vsync             ( S_video_vsync_1             ),
        .O_hsync             ( S_video_hsync_1             ),
        .O_video_preamble    (),
        .O_video_guard_band  (),
        .O_video_period      ( S_video_period_1            ),
        .O_island_preamble   (),
        .O_island_guard_band (),
        .O_island_period     (),
        .O_video_data_ch0    ( S_video_data_ch0_1          ),
        .O_video_data_ch1    ( S_video_data_ch1_1          ),
        .O_video_data_ch2    ( S_video_data_ch2_1          )
    );

    // hdmi_island_data_assemble u_hdmi_island_data_assemble(
    //     .I_clk               ( I_pixel_clk           ),
    //     .I_rst               ( I_rst                 ),
                         
    //     .I_vsync             ( S_video_vsync_1       ),
    //     .I_hsync             ( S_video_hsync_1       ),
    //     .I_video_preamble    ( S_video_preamble_1    ),
    //     .I_video_guard_band  ( S_video_guard_band_1  ),
    //     .I_video_period      ( S_video_period_1      ),
    //     .I_video_data_ch0    ( S_video_data_ch0_1    ),
    //     .I_video_data_ch1    ( S_video_data_ch1_1    ),
    //     .I_video_data_ch2    ( S_video_data_ch2_1    ),

    //     .I_island_preamble   ( S_island_preamble_1   ),
    //     .I_island_guard_band ( S_island_guard_band_1 ),
    //     .I_island_period     ( S_island_period_1     ),
         
    //     .O_frame_start       ( S_frame_start         ),
    //     .O_island_packet_req ( S_island_packet_req   ),
            
    //     .I_BCH_block_4       ( S_BCH_block_4         ),
    //     .I_BCH_block_3       ( S_BCH_block_3         ),   
    //     .I_BCH_block_2       ( S_BCH_block_2         ),  
    //     .I_BCH_block_1       ( S_BCH_block_1         ),                   
    //     .I_BCH_block_0       ( S_BCH_block_0         ),
            
    //     .O_vsync             ( S_video_vsync_2       ),
    //     .O_hsync             ( S_video_hsync_2       ),
    //     .O_video_preamble    ( S_video_preamble_2    ),
    //     .O_video_guard_band  ( S_video_guard_band_2  ),
    //     .O_video_period      ( S_video_period_2      ),

    //     .O_video_data_ch0    ( S_video_data_ch0_2    ),
    //     .O_video_data_ch1    ( S_video_data_ch1_2    ),
    //     .O_video_data_ch2    ( S_video_data_ch2_2    ),

    //     .O_island_preamble   ( S_island_preamble_2   ),
    //     .O_island_guard_band ( S_island_guard_band_2 ),
    //     .O_island_period     ( S_island_period_2     ),

    //     .O_island_data_ch0   ( S_island_data_ch0     ),
    //     .O_island_data_ch1   ( S_island_data_ch1     ),
    //     .O_island_data_ch2   ( S_island_data_ch2     )
    // );

    hdmi_data_distribution_c33abe7c933e u_hdmi_data_distribution(
        .I_clk                     ( I_pixel_clk              ),
        .I_rst                     ( I_rst                    ),
  
        .I_video_vsync             ( S_video_vsync_1          ),
        .I_video_hsync             ( S_video_hsync_1          ),
        .I_video_period            ( S_video_period_1         ),
        .I_video_preamble          (),
        .I_video_guard_band        (),

        .I_video_data_ch0          ( S_video_data_ch0_1       ),
        .I_video_data_ch1          ( S_video_data_ch1_1       ),
        .I_video_data_ch2          ( S_video_data_ch2_1       ),

        .I_island_preamble         (),
        .I_island_guard_band       (),
        .I_island_period           (),

        .I_island_data_ch0         (),
        .I_island_data_ch1         (),
        .I_island_data_ch2         (),

        .O_video_valid             ( S_video_valid             ),
        .O_video_guard_band_valid  (),
        .O_island_valid            (),
        .O_island_guard_band_valid (),
         
        .O_ch0_video_data          ( S_ch0_video_data          ),
        .O_ch0_control_data        ( S_ch0_control_data        ),
        .O_ch0_island_data         (),
         
        .O_ch1_video_data          ( S_ch1_video_data          ),
        .O_ch1_control_data        (),
        .O_ch1_island_data         (),
         
        .O_ch2_video_data          ( S_ch2_video_data          ),
        .O_ch2_control_data        (),
        .O_ch2_island_data         ()
    );

    hdmi_tmds_encode_c33abe7c933e#(
        .CHANNEL_NUM          ( 0 )
    )u0_hdmi_tmds_encode(
        .I_clk                ( I_pixel_clk               ),
        .I_rst                ( I_rst                     ),
       
        .I_video_valid        ( S_video_valid             ),
        .I_video_guard_valid  (),
        .I_island_valid       (),
        .I_island_guard_valid (),

        .I_video_data         ( S_ch0_video_data          ),
        .I_control_data       ( S_ch0_control_data        ),
        .I_island_data        (),

        .O_tmds_code_data     ( O_ch0_tmds_code_data      )
    );

    hdmi_tmds_encode_c33abe7c933e#(
        .CHANNEL_NUM          ( 1 )
    )u1_hdmi_tmds_encode(
        .I_clk                ( I_pixel_clk               ),
        .I_rst                ( I_rst                     ),
       
        .I_video_valid        ( S_video_valid             ),
        .I_video_guard_valid  (),
        .I_island_valid       (),
        .I_island_guard_valid (),

        .I_video_data         ( S_ch1_video_data          ),
        .I_control_data       (),
        .I_island_data        (),

        .O_tmds_code_data     ( O_ch1_tmds_code_data      )
    );

    hdmi_tmds_encode_c33abe7c933e#(
        .CHANNEL_NUM          ( 2 )
    )u2_hdmi_tmds_encode(
        .I_clk                ( I_pixel_clk               ),
        .I_rst                ( I_rst                     ),
       
        .I_video_valid        ( S_video_valid             ),
        .I_video_guard_valid  (),
        .I_island_valid       (),
        .I_island_guard_valid (),

        .I_video_data         ( S_ch2_video_data          ),
        .I_control_data       (),
        .I_island_data        (),

        .O_tmds_code_data     ( O_ch2_tmds_code_data      )
    );

    assign O_clk_tmds_code_data = 10'b0000011111;

endmodule
