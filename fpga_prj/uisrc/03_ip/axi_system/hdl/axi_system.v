/************************************************************\
**	Copyright (c) 2012-2026 anlogic Inc.
**	All Right Reserved.
\************************************************************/
/************************************************************\
**	Gen time	:	2026-10-24 22:21:37
**	DI version	:	197563 2026/05/12
**	App version	:	(build number:6.2.2.200067)
\************************************************************/

module axi_system (
    input     wire              axi_clk ,
    input     wire              pll_locked ,
    input     wire              ext_reset_n ,
    input     wire              adc_sample_valid ,
    input     wire       [31:0] adc_status_in ,
    input     wire       [31:0] duty_q16_in ,
    input     wire       [31:0] control_status_in ,
    input     wire       [31:0] vref_active_q16_in ,
    input     wire              protection_stop ,
    input     wire       [47:0] voltage_product_in ,
    input     wire       [47:0] current_product_in ,
    output    wire              axi_reset_n ,
    output    wire              output_enable_cmd ,
    output    wire       [31:0] vref_cmd_q16 ,
    output    wire              fault_clear_cmd ,
    output    wire        [0:0] O_hdmi_clk_p ,
    output    wire        [2:0] O_hdmi_tx_p
); 
    wire [32:0]       w_port__ARM_Processor_System_0__master_gp0_axi_araddr ;
    wire [32:0]       w_port__AXI_Protocol_Converter_0__us_axi_araddr ;
    wire [32:0]       w_net__ARM_Processor_System_0__master_gp0_axi_araddr ; 

    wire [1:0]        w_port__ARM_Processor_System_0__master_gp0_axi_arburst ;
    wire [1:0]        w_port__AXI_Protocol_Converter_0__us_axi_arburst ;
    wire [1:0]        w_net__ARM_Processor_System_0__master_gp0_axi_arburst ; 

    wire [3:0]        w_port__ARM_Processor_System_0__master_gp0_axi_arcache ;
    wire [3:0]        w_port__AXI_Protocol_Converter_0__us_axi_arcache ;
    wire [3:0]        w_net__ARM_Processor_System_0__master_gp0_axi_arcache ; 

    wire [11:0]       w_port__ARM_Processor_System_0__master_gp0_axi_arid ;
    wire [11:0]       w_port__AXI_Protocol_Converter_0__us_axi_arid ;
    wire [11:0]       w_net__ARM_Processor_System_0__master_gp0_axi_arid ; 

    wire [3:0]        w_port__ARM_Processor_System_0__master_gp0_axi_arlen ;
    wire [7:0]        w_port__AXI_Protocol_Converter_0__us_axi_arlen ;
    wire [3:0]        w_net__ARM_Processor_System_0__master_gp0_axi_arlen ; 

    wire              w_port__ARM_Processor_System_0__master_gp0_axi_arlock ;
    wire [0:0]        w_port__AXI_Protocol_Converter_0__us_axi_arlock ;
    wire              w_net__ARM_Processor_System_0__master_gp0_axi_arlock ; 

    wire [2:0]        w_port__ARM_Processor_System_0__master_gp0_axi_arprot ;
    wire [2:0]        w_port__AXI_Protocol_Converter_0__us_axi_arprot ;
    wire [2:0]        w_net__ARM_Processor_System_0__master_gp0_axi_arprot ; 

    wire [1:0]        w_port__ARM_Processor_System_0__master_gp0_axi_arsize ;
    wire [2:0]        w_port__AXI_Protocol_Converter_0__us_axi_arsize ;
    wire [1:0]        w_net__ARM_Processor_System_0__master_gp0_axi_arsize ; 

    wire              w_port__ARM_Processor_System_0__master_gp0_axi_arvalid ;
    wire              w_port__AXI_Protocol_Converter_0__us_axi_arvalid ;
    wire              w_net__ARM_Processor_System_0__master_gp0_axi_arvalid ; 

    wire [32:0]       w_port__ARM_Processor_System_0__master_gp0_axi_awaddr ;
    wire [32:0]       w_port__AXI_Protocol_Converter_0__us_axi_awaddr ;
    wire [32:0]       w_net__ARM_Processor_System_0__master_gp0_axi_awaddr ; 

    wire [1:0]        w_port__ARM_Processor_System_0__master_gp0_axi_awburst ;
    wire [1:0]        w_port__AXI_Protocol_Converter_0__us_axi_awburst ;
    wire [1:0]        w_net__ARM_Processor_System_0__master_gp0_axi_awburst ; 

    wire [3:0]        w_port__ARM_Processor_System_0__master_gp0_axi_awcache ;
    wire [3:0]        w_port__AXI_Protocol_Converter_0__us_axi_awcache ;
    wire [3:0]        w_net__ARM_Processor_System_0__master_gp0_axi_awcache ; 

    wire [11:0]       w_port__ARM_Processor_System_0__master_gp0_axi_awid ;
    wire [11:0]       w_port__AXI_Protocol_Converter_0__us_axi_awid ;
    wire [11:0]       w_net__ARM_Processor_System_0__master_gp0_axi_awid ; 

    wire [3:0]        w_port__ARM_Processor_System_0__master_gp0_axi_awlen ;
    wire [7:0]        w_port__AXI_Protocol_Converter_0__us_axi_awlen ;
    wire [3:0]        w_net__ARM_Processor_System_0__master_gp0_axi_awlen ; 

    wire              w_port__ARM_Processor_System_0__master_gp0_axi_awlock ;
    wire [0:0]        w_port__AXI_Protocol_Converter_0__us_axi_awlock ;
    wire              w_net__ARM_Processor_System_0__master_gp0_axi_awlock ; 

    wire [2:0]        w_port__ARM_Processor_System_0__master_gp0_axi_awprot ;
    wire [2:0]        w_port__AXI_Protocol_Converter_0__us_axi_awprot ;
    wire [2:0]        w_net__ARM_Processor_System_0__master_gp0_axi_awprot ; 

    wire [1:0]        w_port__ARM_Processor_System_0__master_gp0_axi_awsize ;
    wire [2:0]        w_port__AXI_Protocol_Converter_0__us_axi_awsize ;
    wire [1:0]        w_net__ARM_Processor_System_0__master_gp0_axi_awsize ; 

    wire              w_port__ARM_Processor_System_0__master_gp0_axi_awvalid ;
    wire              w_port__AXI_Protocol_Converter_0__us_axi_awvalid ;
    wire              w_net__ARM_Processor_System_0__master_gp0_axi_awvalid ; 

    wire              w_port__ARM_Processor_System_0__master_gp0_axi_bready ;
    wire              w_port__AXI_Protocol_Converter_0__us_axi_bready ;
    wire              w_net__ARM_Processor_System_0__master_gp0_axi_bready ; 

    wire              w_port__ARM_Processor_System_0__master_gp0_axi_rready ;
    wire              w_port__AXI_Protocol_Converter_0__us_axi_rready ;
    wire              w_net__ARM_Processor_System_0__master_gp0_axi_rready ; 

    wire [31:0]       w_port__ARM_Processor_System_0__master_gp0_axi_wdata ;
    wire [31:0]       w_port__AXI_Protocol_Converter_0__us_axi_wdata ;
    wire [31:0]       w_net__ARM_Processor_System_0__master_gp0_axi_wdata ; 

    wire              w_port__ARM_Processor_System_0__master_gp0_axi_wlast ;
    wire              w_port__AXI_Protocol_Converter_0__us_axi_wlast ;
    wire              w_net__ARM_Processor_System_0__master_gp0_axi_wlast ; 

    wire [3:0]        w_port__ARM_Processor_System_0__master_gp0_axi_wstrb ;
    wire [3:0]        w_port__AXI_Protocol_Converter_0__us_axi_wstrb ;
    wire [3:0]        w_net__ARM_Processor_System_0__master_gp0_axi_wstrb ; 

    wire              w_port__ARM_Processor_System_0__master_gp0_axi_wvalid ;
    wire              w_port__AXI_Protocol_Converter_0__us_axi_wvalid ;
    wire              w_net__ARM_Processor_System_0__master_gp0_axi_wvalid ; 

    wire [32:0]       w_port__ARM_Processor_System_0__master_gp1_axi_araddr ;
    wire [32:0]       w_port__NPU_Control_Matrix_0__us0_araddr ;
    wire [32:0]       w_net__ARM_Processor_System_0__master_gp1_axi_araddr ; 

    wire [1:0]        w_port__ARM_Processor_System_0__master_gp1_axi_arburst ;
    wire [1:0]        w_port__NPU_Control_Matrix_0__us0_arburst ;
    wire [1:0]        w_net__ARM_Processor_System_0__master_gp1_axi_arburst ; 

    wire [3:0]        w_port__ARM_Processor_System_0__master_gp1_axi_arcache ;
    wire [3:0]        w_port__NPU_Control_Matrix_0__us0_arcache ;
    wire [3:0]        w_net__ARM_Processor_System_0__master_gp1_axi_arcache ; 

    wire [11:0]       w_port__ARM_Processor_System_0__master_gp1_axi_arid ;
    wire [11:0]       w_port__NPU_Control_Matrix_0__us0_arid ;
    wire [11:0]       w_net__ARM_Processor_System_0__master_gp1_axi_arid ; 

    wire [3:0]        w_port__ARM_Processor_System_0__master_gp1_axi_arlen ;
    wire [7:0]        w_port__NPU_Control_Matrix_0__us0_arlen ;
    wire [3:0]        w_net__ARM_Processor_System_0__master_gp1_axi_arlen ; 

    wire              w_port__ARM_Processor_System_0__master_gp1_axi_arlock ;
    wire [0:0]        w_port__NPU_Control_Matrix_0__us0_arlock ;
    wire              w_net__ARM_Processor_System_0__master_gp1_axi_arlock ; 

    wire [2:0]        w_port__ARM_Processor_System_0__master_gp1_axi_arprot ;
    wire [2:0]        w_port__NPU_Control_Matrix_0__us0_arprot ;
    wire [2:0]        w_net__ARM_Processor_System_0__master_gp1_axi_arprot ; 

    wire [1:0]        w_port__ARM_Processor_System_0__master_gp1_axi_arsize ;
    wire [2:0]        w_port__NPU_Control_Matrix_0__us0_arsize ;
    wire [1:0]        w_net__ARM_Processor_System_0__master_gp1_axi_arsize ; 

    wire              w_port__ARM_Processor_System_0__master_gp1_axi_arvalid ;
    wire              w_port__NPU_Control_Matrix_0__us0_arvalid ;
    wire              w_net__ARM_Processor_System_0__master_gp1_axi_arvalid ; 

    wire [32:0]       w_port__ARM_Processor_System_0__master_gp1_axi_awaddr ;
    wire [32:0]       w_port__NPU_Control_Matrix_0__us0_awaddr ;
    wire [32:0]       w_net__ARM_Processor_System_0__master_gp1_axi_awaddr ; 

    wire [1:0]        w_port__ARM_Processor_System_0__master_gp1_axi_awburst ;
    wire [1:0]        w_port__NPU_Control_Matrix_0__us0_awburst ;
    wire [1:0]        w_net__ARM_Processor_System_0__master_gp1_axi_awburst ; 

    wire [3:0]        w_port__ARM_Processor_System_0__master_gp1_axi_awcache ;
    wire [3:0]        w_port__NPU_Control_Matrix_0__us0_awcache ;
    wire [3:0]        w_net__ARM_Processor_System_0__master_gp1_axi_awcache ; 

    wire [11:0]       w_port__ARM_Processor_System_0__master_gp1_axi_awid ;
    wire [11:0]       w_port__NPU_Control_Matrix_0__us0_awid ;
    wire [11:0]       w_net__ARM_Processor_System_0__master_gp1_axi_awid ; 

    wire [3:0]        w_port__ARM_Processor_System_0__master_gp1_axi_awlen ;
    wire [7:0]        w_port__NPU_Control_Matrix_0__us0_awlen ;
    wire [3:0]        w_net__ARM_Processor_System_0__master_gp1_axi_awlen ; 

    wire              w_port__ARM_Processor_System_0__master_gp1_axi_awlock ;
    wire [0:0]        w_port__NPU_Control_Matrix_0__us0_awlock ;
    wire              w_net__ARM_Processor_System_0__master_gp1_axi_awlock ; 

    wire [2:0]        w_port__ARM_Processor_System_0__master_gp1_axi_awprot ;
    wire [2:0]        w_port__NPU_Control_Matrix_0__us0_awprot ;
    wire [2:0]        w_net__ARM_Processor_System_0__master_gp1_axi_awprot ; 

    wire [1:0]        w_port__ARM_Processor_System_0__master_gp1_axi_awsize ;
    wire [2:0]        w_port__NPU_Control_Matrix_0__us0_awsize ;
    wire [1:0]        w_net__ARM_Processor_System_0__master_gp1_axi_awsize ; 

    wire              w_port__ARM_Processor_System_0__master_gp1_axi_awvalid ;
    wire              w_port__NPU_Control_Matrix_0__us0_awvalid ;
    wire              w_net__ARM_Processor_System_0__master_gp1_axi_awvalid ; 

    wire              w_port__ARM_Processor_System_0__master_gp1_axi_bready ;
    wire              w_port__NPU_Control_Matrix_0__us0_bready ;
    wire              w_net__ARM_Processor_System_0__master_gp1_axi_bready ; 

    wire              w_port__ARM_Processor_System_0__master_gp1_axi_rready ;
    wire              w_port__NPU_Control_Matrix_0__us0_rready ;
    wire              w_net__ARM_Processor_System_0__master_gp1_axi_rready ; 

    wire [31:0]       w_port__ARM_Processor_System_0__master_gp1_axi_wdata ;
    wire [31:0]       w_port__NPU_Control_Matrix_0__us0_wdata ;
    wire [31:0]       w_net__ARM_Processor_System_0__master_gp1_axi_wdata ; 

    wire              w_port__ARM_Processor_System_0__master_gp1_axi_wlast ;
    wire              w_port__NPU_Control_Matrix_0__us0_wlast ;
    wire              w_net__ARM_Processor_System_0__master_gp1_axi_wlast ; 

    wire [3:0]        w_port__ARM_Processor_System_0__master_gp1_axi_wstrb ;
    wire [3:0]        w_port__NPU_Control_Matrix_0__us0_wstrb ;
    wire [3:0]        w_net__ARM_Processor_System_0__master_gp1_axi_wstrb ; 

    wire              w_port__ARM_Processor_System_0__master_gp1_axi_wvalid ;
    wire              w_port__NPU_Control_Matrix_0__us0_wvalid ;
    wire              w_net__ARM_Processor_System_0__master_gp1_axi_wvalid ; 

    wire              w_port__ARM_Processor_System_0__p2f_clk0 ;
    wire              w_port__HDMI_PLL_0__refclk ;
    wire              w_port__HDMI_VTG_0__ref_clk ;
    wire              w_net__ARM_Processor_System_0__p2f_clk0 ; 

    wire              w_port__ARM_Processor_System_0__p2f_rst0_n ;
    wire              w_port__Processor_System_Reset_0__external_resetn ;
    wire              w_net__ARM_Processor_System_0__p2f_rst0_n ; 

    wire              w_port__ARM_Processor_System_0__slave_hp0_axi_arready ;
    wire              w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_arready ;
    wire              w_net__ARM_Processor_System_0__slave_hp0_axi_arready ; 

    wire              w_port__ARM_Processor_System_0__slave_hp0_axi_awready ;
    wire              w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_awready ;
    wire              w_net__ARM_Processor_System_0__slave_hp0_axi_awready ; 

    wire [5:0]        w_port__ARM_Processor_System_0__slave_hp0_axi_bid ;
    wire [5:0]        w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_bid ;
    wire [5:0]        w_net__ARM_Processor_System_0__slave_hp0_axi_bid ; 

    wire [1:0]        w_port__ARM_Processor_System_0__slave_hp0_axi_bresp ;
    wire [1:0]        w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_bresp ;
    wire [1:0]        w_net__ARM_Processor_System_0__slave_hp0_axi_bresp ; 

    wire              w_port__ARM_Processor_System_0__slave_hp0_axi_bvalid ;
    wire              w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_bvalid ;
    wire              w_net__ARM_Processor_System_0__slave_hp0_axi_bvalid ; 

    wire [63:0]       w_port__ARM_Processor_System_0__slave_hp0_axi_rdata ;
    wire [63:0]       w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_rdata ;
    wire [63:0]       w_net__ARM_Processor_System_0__slave_hp0_axi_rdata ; 

    wire [5:0]        w_port__ARM_Processor_System_0__slave_hp0_axi_rid ;
    wire [5:0]        w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_rid ;
    wire [5:0]        w_net__ARM_Processor_System_0__slave_hp0_axi_rid ; 

    wire              w_port__ARM_Processor_System_0__slave_hp0_axi_rlast ;
    wire              w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_rlast ;
    wire              w_net__ARM_Processor_System_0__slave_hp0_axi_rlast ; 

    wire [1:0]        w_port__ARM_Processor_System_0__slave_hp0_axi_rresp ;
    wire [1:0]        w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_rresp ;
    wire [1:0]        w_net__ARM_Processor_System_0__slave_hp0_axi_rresp ; 

    wire              w_port__ARM_Processor_System_0__slave_hp0_axi_rvalid ;
    wire              w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_rvalid ;
    wire              w_net__ARM_Processor_System_0__slave_hp0_axi_rvalid ; 

    wire              w_port__ARM_Processor_System_0__slave_hp0_axi_wready ;
    wire              w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_wready ;
    wire              w_net__ARM_Processor_System_0__slave_hp0_axi_wready ; 

    wire              w_port__ARM_Processor_System_0__slave_hp1_axi_arready ;
    wire              w_port__HP1_Protocol_Converter_0__ds_axi_arready ;
    wire              w_net__ARM_Processor_System_0__slave_hp1_axi_arready ; 

    wire              w_port__ARM_Processor_System_0__slave_hp1_axi_awready ;
    wire              w_port__HP1_Protocol_Converter_0__ds_axi_awready ;
    wire              w_net__ARM_Processor_System_0__slave_hp1_axi_awready ; 

    wire [5:0]        w_port__ARM_Processor_System_0__slave_hp1_axi_bid ;
    wire [5:0]        w_port__HP1_Protocol_Converter_0__ds_axi_bid ;
    wire [5:0]        w_net__ARM_Processor_System_0__slave_hp1_axi_bid ; 

    wire [1:0]        w_port__ARM_Processor_System_0__slave_hp1_axi_bresp ;
    wire [1:0]        w_port__HP1_Protocol_Converter_0__ds_axi_bresp ;
    wire [1:0]        w_net__ARM_Processor_System_0__slave_hp1_axi_bresp ; 

    wire              w_port__ARM_Processor_System_0__slave_hp1_axi_bvalid ;
    wire              w_port__HP1_Protocol_Converter_0__ds_axi_bvalid ;
    wire              w_net__ARM_Processor_System_0__slave_hp1_axi_bvalid ; 

    wire [63:0]       w_port__ARM_Processor_System_0__slave_hp1_axi_rdata ;
    wire [63:0]       w_port__HP1_Protocol_Converter_0__ds_axi_rdata ;
    wire [63:0]       w_net__ARM_Processor_System_0__slave_hp1_axi_rdata ; 

    wire [5:0]        w_port__ARM_Processor_System_0__slave_hp1_axi_rid ;
    wire [5:0]        w_port__HP1_Protocol_Converter_0__ds_axi_rid ;
    wire [5:0]        w_net__ARM_Processor_System_0__slave_hp1_axi_rid ; 

    wire              w_port__ARM_Processor_System_0__slave_hp1_axi_rlast ;
    wire              w_port__HP1_Protocol_Converter_0__ds_axi_rlast ;
    wire              w_net__ARM_Processor_System_0__slave_hp1_axi_rlast ; 

    wire [1:0]        w_port__ARM_Processor_System_0__slave_hp1_axi_rresp ;
    wire [1:0]        w_port__HP1_Protocol_Converter_0__ds_axi_rresp ;
    wire [1:0]        w_net__ARM_Processor_System_0__slave_hp1_axi_rresp ; 

    wire              w_port__ARM_Processor_System_0__slave_hp1_axi_rvalid ;
    wire              w_port__HP1_Protocol_Converter_0__ds_axi_rvalid ;
    wire              w_net__ARM_Processor_System_0__slave_hp1_axi_rvalid ; 

    wire              w_port__ARM_Processor_System_0__slave_hp1_axi_wready ;
    wire              w_port__HP1_Protocol_Converter_0__ds_axi_wready ;
    wire              w_net__ARM_Processor_System_0__slave_hp1_axi_wready ; 

    wire              w_port__AXI4_Stream_to_Video_Out_0__locked ;
    wire              w_port__HDMI_Reset_0__video_locked ;
    wire              w_net__AXI4_Stream_to_Video_Out_0__locked ; 

    wire              w_port__AXI4_Stream_to_Video_Out_0__s_axis_video_tready ;
    wire              w_port__VDMA_0__m_axis_mm2s_tready ;
    wire              w_net__AXI4_Stream_to_Video_Out_0__s_axis_video_tready ; 

    wire              w_port__AXI4_Stream_to_Video_Out_0__vid_active_video ;
    wire              w_port__HDMI_TX_0__I_video_in_de ;
    wire              w_net__AXI4_Stream_to_Video_Out_0__vid_active_video ; 

    wire [23:0]       w_port__AXI4_Stream_to_Video_Out_0__vid_data ;
    wire [23:0]       w_port__HDMI_TX_0__I_video_in_data ;
    wire [23:0]       w_net__AXI4_Stream_to_Video_Out_0__vid_data ; 

    wire              w_port__AXI4_Stream_to_Video_Out_0__vid_hsync ;
    wire              w_port__HDMI_TX_0__I_video_in_hs ;
    wire              w_net__AXI4_Stream_to_Video_Out_0__vid_hsync ; 

    wire              w_port__AXI4_Stream_to_Video_Out_0__vid_vsync ;
    wire              w_port__HDMI_TX_0__I_video_in_vs ;
    wire              w_net__AXI4_Stream_to_Video_Out_0__vid_vsync ; 

    wire              w_port__AXI4_Stream_to_Video_Out_0__vtg_ce ;
    wire              w_port__HDMI_VTG_0__vtg_ce ;
    wire              w_net__AXI4_Stream_to_Video_Out_0__vtg_ce ; 

    wire [31:0]       w_port__AXIS_Data_FIFO_0__ds_tdata ;
    wire [31:0]       w_port__adc_fdma_writer_0__s_axis_s2mm_tdata ;
    wire [31:0]       w_net__AXIS_Data_FIFO_0__ds_tdata ; 

    wire [3:0]        w_port__AXIS_Data_FIFO_0__ds_tkeep ;
    wire [3:0]        w_port__adc_fdma_writer_0__s_axis_s2mm_tkeep ;
    wire [3:0]        w_net__AXIS_Data_FIFO_0__ds_tkeep ; 

    wire              w_port__AXIS_Data_FIFO_0__ds_tlast ;
    wire              w_port__adc_fdma_writer_0__s_axis_s2mm_tlast ;
    wire              w_net__AXIS_Data_FIFO_0__ds_tlast ; 

    wire              w_port__AXIS_Data_FIFO_0__ds_tvalid ;
    wire              w_port__adc_fdma_writer_0__s_axis_s2mm_tvalid ;
    wire              w_port__adc_axis_source_0__fifo_out_tvalid ;
    wire              w_net__AXIS_Data_FIFO_0__ds_tvalid ; 

    wire              w_port__AXIS_Data_FIFO_0__us_tready ;
    wire              w_port__adc_axis_source_0__m_axis_tready ;
    wire              w_net__AXIS_Data_FIFO_0__us_tready ; 

    wire [32:0]       w_port__AXI_Lite_Matrix_0__ds0_araddr ;
    wire [7:0]        w_port__axi4lite_slave_0__s_axi_araddr ;
    wire [32:0]       w_net__AXI_Lite_Matrix_0__ds0_araddr ; 

    wire              w_port__AXI_Lite_Matrix_0__ds0_arvalid ;
    wire              w_port__axi4lite_slave_0__s_axi_arvalid ;
    wire              w_net__AXI_Lite_Matrix_0__ds0_arvalid ; 

    wire [32:0]       w_port__AXI_Lite_Matrix_0__ds0_awaddr ;
    wire [7:0]        w_port__axi4lite_slave_0__s_axi_awaddr ;
    wire [32:0]       w_net__AXI_Lite_Matrix_0__ds0_awaddr ; 

    wire              w_port__AXI_Lite_Matrix_0__ds0_awvalid ;
    wire              w_port__axi4lite_slave_0__s_axi_awvalid ;
    wire              w_net__AXI_Lite_Matrix_0__ds0_awvalid ; 

    wire              w_port__AXI_Lite_Matrix_0__ds0_bready ;
    wire              w_port__axi4lite_slave_0__s_axi_bready ;
    wire              w_net__AXI_Lite_Matrix_0__ds0_bready ; 

    wire              w_port__AXI_Lite_Matrix_0__ds0_rready ;
    wire              w_port__axi4lite_slave_0__s_axi_rready ;
    wire              w_net__AXI_Lite_Matrix_0__ds0_rready ; 

    wire [31:0]       w_port__AXI_Lite_Matrix_0__ds0_wdata ;
    wire [31:0]       w_port__axi4lite_slave_0__s_axi_wdata ;
    wire [31:0]       w_net__AXI_Lite_Matrix_0__ds0_wdata ; 

    wire [3:0]        w_port__AXI_Lite_Matrix_0__ds0_wstrb ;
    wire [3:0]        w_port__axi4lite_slave_0__s_axi_wstrb ;
    wire [3:0]        w_net__AXI_Lite_Matrix_0__ds0_wstrb ; 

    wire              w_port__AXI_Lite_Matrix_0__ds0_wvalid ;
    wire              w_port__axi4lite_slave_0__s_axi_wvalid ;
    wire              w_net__AXI_Lite_Matrix_0__ds0_wvalid ; 

    wire [32:0]       w_port__AXI_Lite_Matrix_0__ds1_araddr ;
    wire [9:0]        w_port__adc_fdma_writer_0__s_axi_lite_araddr ;
    wire [32:0]       w_net__AXI_Lite_Matrix_0__ds1_araddr ; 

    wire              w_port__AXI_Lite_Matrix_0__ds1_arvalid ;
    wire              w_port__adc_fdma_writer_0__s_axi_lite_arvalid ;
    wire              w_net__AXI_Lite_Matrix_0__ds1_arvalid ; 

    wire [32:0]       w_port__AXI_Lite_Matrix_0__ds1_awaddr ;
    wire [9:0]        w_port__adc_fdma_writer_0__s_axi_lite_awaddr ;
    wire [32:0]       w_net__AXI_Lite_Matrix_0__ds1_awaddr ; 

    wire              w_port__AXI_Lite_Matrix_0__ds1_awvalid ;
    wire              w_port__adc_fdma_writer_0__s_axi_lite_awvalid ;
    wire              w_net__AXI_Lite_Matrix_0__ds1_awvalid ; 

    wire              w_port__AXI_Lite_Matrix_0__ds1_bready ;
    wire              w_port__adc_fdma_writer_0__s_axi_lite_bready ;
    wire              w_net__AXI_Lite_Matrix_0__ds1_bready ; 

    wire              w_port__AXI_Lite_Matrix_0__ds1_rready ;
    wire              w_port__adc_fdma_writer_0__s_axi_lite_rready ;
    wire              w_net__AXI_Lite_Matrix_0__ds1_rready ; 

    wire [31:0]       w_port__AXI_Lite_Matrix_0__ds1_wdata ;
    wire [31:0]       w_port__adc_fdma_writer_0__s_axi_lite_wdata ;
    wire [31:0]       w_net__AXI_Lite_Matrix_0__ds1_wdata ; 

    wire [3:0]        w_port__AXI_Lite_Matrix_0__ds1_wstrb ;
    wire [3:0]        w_port__adc_fdma_writer_0__s_axi_lite_wstrb ;
    wire [3:0]        w_net__AXI_Lite_Matrix_0__ds1_wstrb ; 

    wire              w_port__AXI_Lite_Matrix_0__ds1_wvalid ;
    wire              w_port__adc_fdma_writer_0__s_axi_lite_wvalid ;
    wire              w_net__AXI_Lite_Matrix_0__ds1_wvalid ; 

    wire [32:0]       w_port__AXI_Lite_Matrix_0__ds2_araddr ;
    wire [12:0]       w_port__HDMI_VTG_0__s_axi_araddr ;
    wire [32:0]       w_net__AXI_Lite_Matrix_0__ds2_araddr ; 

    wire              w_port__AXI_Lite_Matrix_0__ds2_arvalid ;
    wire              w_port__HDMI_VTG_0__s_axi_arvalid ;
    wire              w_net__AXI_Lite_Matrix_0__ds2_arvalid ; 

    wire [32:0]       w_port__AXI_Lite_Matrix_0__ds2_awaddr ;
    wire [12:0]       w_port__HDMI_VTG_0__s_axi_awaddr ;
    wire [32:0]       w_net__AXI_Lite_Matrix_0__ds2_awaddr ; 

    wire              w_port__AXI_Lite_Matrix_0__ds2_awvalid ;
    wire              w_port__HDMI_VTG_0__s_axi_awvalid ;
    wire              w_net__AXI_Lite_Matrix_0__ds2_awvalid ; 

    wire              w_port__AXI_Lite_Matrix_0__ds2_bready ;
    wire              w_port__HDMI_VTG_0__s_axi_bready ;
    wire              w_net__AXI_Lite_Matrix_0__ds2_bready ; 

    wire              w_port__AXI_Lite_Matrix_0__ds2_rready ;
    wire              w_port__HDMI_VTG_0__s_axi_rready ;
    wire              w_net__AXI_Lite_Matrix_0__ds2_rready ; 

    wire [31:0]       w_port__AXI_Lite_Matrix_0__ds2_wdata ;
    wire [31:0]       w_port__HDMI_VTG_0__s_axi_wdata ;
    wire [31:0]       w_net__AXI_Lite_Matrix_0__ds2_wdata ; 

    wire [3:0]        w_port__AXI_Lite_Matrix_0__ds2_wstrb ;
    wire [3:0]        w_port__HDMI_VTG_0__s_axi_wstrb ;
    wire [3:0]        w_net__AXI_Lite_Matrix_0__ds2_wstrb ; 

    wire              w_port__AXI_Lite_Matrix_0__ds2_wvalid ;
    wire              w_port__HDMI_VTG_0__s_axi_wvalid ;
    wire              w_net__AXI_Lite_Matrix_0__ds2_wvalid ; 

    wire [32:0]       w_port__AXI_Lite_Matrix_0__ds3_araddr ;
    wire [8:0]        w_port__VDMA_0__axi_lite_araddr ;
    wire [32:0]       w_net__AXI_Lite_Matrix_0__ds3_araddr ; 

    wire              w_port__AXI_Lite_Matrix_0__ds3_arvalid ;
    wire              w_port__VDMA_0__axi_lite_arvalid ;
    wire              w_net__AXI_Lite_Matrix_0__ds3_arvalid ; 

    wire [32:0]       w_port__AXI_Lite_Matrix_0__ds3_awaddr ;
    wire [8:0]        w_port__VDMA_0__axi_lite_awaddr ;
    wire [32:0]       w_net__AXI_Lite_Matrix_0__ds3_awaddr ; 

    wire              w_port__AXI_Lite_Matrix_0__ds3_awvalid ;
    wire              w_port__VDMA_0__axi_lite_awvalid ;
    wire              w_net__AXI_Lite_Matrix_0__ds3_awvalid ; 

    wire              w_port__AXI_Lite_Matrix_0__ds3_bready ;
    wire              w_port__VDMA_0__axi_lite_bready ;
    wire              w_net__AXI_Lite_Matrix_0__ds3_bready ; 

    wire              w_port__AXI_Lite_Matrix_0__ds3_rready ;
    wire              w_port__VDMA_0__axi_lite_rready ;
    wire              w_net__AXI_Lite_Matrix_0__ds3_rready ; 

    wire [31:0]       w_port__AXI_Lite_Matrix_0__ds3_wdata ;
    wire [31:0]       w_port__VDMA_0__axi_lite_wdata ;
    wire [31:0]       w_net__AXI_Lite_Matrix_0__ds3_wdata ; 

    wire              w_port__AXI_Lite_Matrix_0__ds3_wvalid ;
    wire              w_port__VDMA_0__axi_lite_wvalid ;
    wire              w_net__AXI_Lite_Matrix_0__ds3_wvalid ; 

    wire              w_port__AXI_Lite_Matrix_0__us0_arready ;
    wire              w_port__AXI_Protocol_Converter_0__ds_axi_arready ;
    wire              w_net__AXI_Lite_Matrix_0__us0_arready ; 

    wire              w_port__AXI_Lite_Matrix_0__us0_awready ;
    wire              w_port__AXI_Protocol_Converter_0__ds_axi_awready ;
    wire              w_net__AXI_Lite_Matrix_0__us0_awready ; 

    wire [1:0]        w_port__AXI_Lite_Matrix_0__us0_bresp ;
    wire [1:0]        w_port__AXI_Protocol_Converter_0__ds_axi_bresp ;
    wire [1:0]        w_net__AXI_Lite_Matrix_0__us0_bresp ; 

    wire              w_port__AXI_Lite_Matrix_0__us0_bvalid ;
    wire              w_port__AXI_Protocol_Converter_0__ds_axi_bvalid ;
    wire              w_net__AXI_Lite_Matrix_0__us0_bvalid ; 

    wire [31:0]       w_port__AXI_Lite_Matrix_0__us0_rdata ;
    wire [31:0]       w_port__AXI_Protocol_Converter_0__ds_axi_rdata ;
    wire [31:0]       w_net__AXI_Lite_Matrix_0__us0_rdata ; 

    wire [1:0]        w_port__AXI_Lite_Matrix_0__us0_rresp ;
    wire [1:0]        w_port__AXI_Protocol_Converter_0__ds_axi_rresp ;
    wire [1:0]        w_net__AXI_Lite_Matrix_0__us0_rresp ; 

    wire              w_port__AXI_Lite_Matrix_0__us0_rvalid ;
    wire              w_port__AXI_Protocol_Converter_0__ds_axi_rvalid ;
    wire              w_net__AXI_Lite_Matrix_0__us0_rvalid ; 

    wire              w_port__AXI_Lite_Matrix_0__us0_wready ;
    wire              w_port__AXI_Protocol_Converter_0__ds_axi_wready ;
    wire              w_net__AXI_Lite_Matrix_0__us0_wready ; 

    wire [32:0]       w_port__AXI_Protocol_Converter_0__ds_axi_araddr ;
    wire [32:0]       w_port__AXI_Lite_Matrix_0__us0_araddr ;
    wire [32:0]       w_net__AXI_Protocol_Converter_0__ds_axi_araddr ; 

    wire [2:0]        w_port__AXI_Protocol_Converter_0__ds_axi_arprot ;
    wire [2:0]        w_port__AXI_Lite_Matrix_0__us0_arprot ;
    wire [2:0]        w_net__AXI_Protocol_Converter_0__ds_axi_arprot ; 

    wire              w_port__AXI_Protocol_Converter_0__ds_axi_arvalid ;
    wire              w_port__AXI_Lite_Matrix_0__us0_arvalid ;
    wire              w_net__AXI_Protocol_Converter_0__ds_axi_arvalid ; 

    wire [32:0]       w_port__AXI_Protocol_Converter_0__ds_axi_awaddr ;
    wire [32:0]       w_port__AXI_Lite_Matrix_0__us0_awaddr ;
    wire [32:0]       w_net__AXI_Protocol_Converter_0__ds_axi_awaddr ; 

    wire [2:0]        w_port__AXI_Protocol_Converter_0__ds_axi_awprot ;
    wire [2:0]        w_port__AXI_Lite_Matrix_0__us0_awprot ;
    wire [2:0]        w_net__AXI_Protocol_Converter_0__ds_axi_awprot ; 

    wire              w_port__AXI_Protocol_Converter_0__ds_axi_awvalid ;
    wire              w_port__AXI_Lite_Matrix_0__us0_awvalid ;
    wire              w_net__AXI_Protocol_Converter_0__ds_axi_awvalid ; 

    wire              w_port__AXI_Protocol_Converter_0__ds_axi_bready ;
    wire              w_port__AXI_Lite_Matrix_0__us0_bready ;
    wire              w_net__AXI_Protocol_Converter_0__ds_axi_bready ; 

    wire              w_port__AXI_Protocol_Converter_0__ds_axi_rready ;
    wire              w_port__AXI_Lite_Matrix_0__us0_rready ;
    wire              w_net__AXI_Protocol_Converter_0__ds_axi_rready ; 

    wire [31:0]       w_port__AXI_Protocol_Converter_0__ds_axi_wdata ;
    wire [31:0]       w_port__AXI_Lite_Matrix_0__us0_wdata ;
    wire [31:0]       w_net__AXI_Protocol_Converter_0__ds_axi_wdata ; 

    wire [3:0]        w_port__AXI_Protocol_Converter_0__ds_axi_wstrb ;
    wire [3:0]        w_port__AXI_Lite_Matrix_0__us0_wstrb ;
    wire [3:0]        w_net__AXI_Protocol_Converter_0__ds_axi_wstrb ; 

    wire              w_port__AXI_Protocol_Converter_0__ds_axi_wvalid ;
    wire              w_port__AXI_Lite_Matrix_0__us0_wvalid ;
    wire              w_net__AXI_Protocol_Converter_0__ds_axi_wvalid ; 

    wire              w_port__AXI_Protocol_Converter_0__us_axi_arready ;
    wire              w_port__ARM_Processor_System_0__master_gp0_axi_arready ;
    wire              w_net__AXI_Protocol_Converter_0__us_axi_arready ; 

    wire              w_port__AXI_Protocol_Converter_0__us_axi_awready ;
    wire              w_port__ARM_Processor_System_0__master_gp0_axi_awready ;
    wire              w_net__AXI_Protocol_Converter_0__us_axi_awready ; 

    wire [11:0]       w_port__AXI_Protocol_Converter_0__us_axi_bid ;
    wire [11:0]       w_port__ARM_Processor_System_0__master_gp0_axi_bid ;
    wire [11:0]       w_net__AXI_Protocol_Converter_0__us_axi_bid ; 

    wire [1:0]        w_port__AXI_Protocol_Converter_0__us_axi_bresp ;
    wire [1:0]        w_port__ARM_Processor_System_0__master_gp0_axi_bresp ;
    wire [1:0]        w_net__AXI_Protocol_Converter_0__us_axi_bresp ; 

    wire              w_port__AXI_Protocol_Converter_0__us_axi_bvalid ;
    wire              w_port__ARM_Processor_System_0__master_gp0_axi_bvalid ;
    wire              w_net__AXI_Protocol_Converter_0__us_axi_bvalid ; 

    wire [31:0]       w_port__AXI_Protocol_Converter_0__us_axi_rdata ;
    wire [31:0]       w_port__ARM_Processor_System_0__master_gp0_axi_rdata ;
    wire [31:0]       w_net__AXI_Protocol_Converter_0__us_axi_rdata ; 

    wire [11:0]       w_port__AXI_Protocol_Converter_0__us_axi_rid ;
    wire [11:0]       w_port__ARM_Processor_System_0__master_gp0_axi_rid ;
    wire [11:0]       w_net__AXI_Protocol_Converter_0__us_axi_rid ; 

    wire              w_port__AXI_Protocol_Converter_0__us_axi_rlast ;
    wire              w_port__ARM_Processor_System_0__master_gp0_axi_rlast ;
    wire              w_net__AXI_Protocol_Converter_0__us_axi_rlast ; 

    wire [1:0]        w_port__AXI_Protocol_Converter_0__us_axi_rresp ;
    wire [1:0]        w_port__ARM_Processor_System_0__master_gp0_axi_rresp ;
    wire [1:0]        w_net__AXI_Protocol_Converter_0__us_axi_rresp ; 

    wire              w_port__AXI_Protocol_Converter_0__us_axi_rvalid ;
    wire              w_port__ARM_Processor_System_0__master_gp0_axi_rvalid ;
    wire              w_net__AXI_Protocol_Converter_0__us_axi_rvalid ; 

    wire              w_port__AXI_Protocol_Converter_0__us_axi_wready ;
    wire              w_port__ARM_Processor_System_0__master_gp0_axi_wready ;
    wire              w_net__AXI_Protocol_Converter_0__us_axi_wready ; 

    wire [3:0]        w_port__Constant_0_0__dout ;
    wire [3:0]        w_port__AXI_Protocol_Converter_0__us_axi_awqos ;
    wire [3:0]        w_port__AXI_Protocol_Converter_0__us_axi_arqos ;
    wire [3:0]        w_net__Constant_0_0__dout ; 

    wire [0:0]        w_port__Constant_0__dout ;
    wire              w_port__Processor_System_Reset_0__system_rst ;
    wire [31:0]       w_port__axi4lite_slave_0__s_axis_tdata ;
    wire [3:0]        w_port__axi4lite_slave_0__s_axis_tkeep ;
    wire              w_port__axi4lite_slave_0__s_axis_tlast ;
    wire              w_port__axi4lite_slave_0__s_axis_tvalid ;
    wire [32:0]       w_port__HP1_AXI_Matrix_0__us0_araddr ;
    wire [1:0]        w_port__HP1_AXI_Matrix_0__us0_arburst ;
    wire [3:0]        w_port__HP1_AXI_Matrix_0__us0_arcache ;
    wire [4:0]        w_port__HP1_AXI_Matrix_0__us0_arid ;
    wire [7:0]        w_port__HP1_AXI_Matrix_0__us0_arlen ;
    wire [0:0]        w_port__HP1_AXI_Matrix_0__us0_arlock ;
    wire [2:0]        w_port__HP1_AXI_Matrix_0__us0_arprot ;
    wire [3:0]        w_port__HP1_AXI_Matrix_0__us0_arqos ;
    wire [2:0]        w_port__HP1_AXI_Matrix_0__us0_arsize ;
    wire              w_port__HP1_AXI_Matrix_0__us0_arvalid ;
    wire              w_port__HP1_AXI_Matrix_0__us0_rready ;
    wire              w_port__VDMA_0__m_axi_s2mm_awready ;
    wire              w_port__VDMA_0__m_axi_s2mm_wready ;
    wire [1:0]        w_port__VDMA_0__m_axi_s2mm_bresp ;
    wire              w_port__VDMA_0__m_axi_s2mm_bvalid ;
    wire [63:0]       w_port__VDMA_0__s_axis_s2mm_tdata ;
    wire [7:0]        w_port__VDMA_0__s_axis_s2mm_tkeep ;
    wire [0:0]        w_port__VDMA_0__s_axis_s2mm_tuser ;
    wire              w_port__VDMA_0__s_axis_s2mm_tvalid ;
    wire              w_port__VDMA_0__s_axis_s2mm_tlast ;
    wire              w_port__VDMA_0__mm2s_fsync ;
    wire              w_port__VDMA_0__s2mm_fsync ;
    wire              w_port__AXI4_Stream_to_Video_Out_0__fid ;
    wire              w_port__AXI4_Stream_to_Video_Out_0__vtg_field_id ;
    wire [0:0]        w_port__HDMI_IRQ_Concat_0__In2 ;
    wire [5:0]        w_port__HDMI_HP0_Protocol_Converter_0__us_axi_awid ;
    wire [32:0]       w_port__HDMI_HP0_Protocol_Converter_0__us_axi_awaddr ;
    wire [7:0]        w_port__HDMI_HP0_Protocol_Converter_0__us_axi_awlen ;
    wire [2:0]        w_port__HDMI_HP0_Protocol_Converter_0__us_axi_awsize ;
    wire [1:0]        w_port__HDMI_HP0_Protocol_Converter_0__us_axi_awburst ;
    wire [0:0]        w_port__HDMI_HP0_Protocol_Converter_0__us_axi_awlock ;
    wire [3:0]        w_port__HDMI_HP0_Protocol_Converter_0__us_axi_awcache ;
    wire [2:0]        w_port__HDMI_HP0_Protocol_Converter_0__us_axi_awprot ;
    wire [3:0]        w_port__HDMI_HP0_Protocol_Converter_0__us_axi_awqos ;
    wire              w_port__HDMI_HP0_Protocol_Converter_0__us_axi_awvalid ;
    wire [63:0]       w_port__HDMI_HP0_Protocol_Converter_0__us_axi_wdata ;
    wire [7:0]        w_port__HDMI_HP0_Protocol_Converter_0__us_axi_wstrb ;
    wire              w_port__HDMI_HP0_Protocol_Converter_0__us_axi_wlast ;
    wire              w_port__HDMI_HP0_Protocol_Converter_0__us_axi_wvalid ;
    wire              w_port__HDMI_HP0_Protocol_Converter_0__us_axi_bready ;
    wire [5:0]        w_port__HDMI_HP0_Protocol_Converter_0__us_axi_arid ;
    wire [0:0]        w_port__HDMI_HP0_Protocol_Converter_0__us_axi_arlock ;
    wire [3:0]        w_port__HDMI_HP0_Protocol_Converter_0__us_axi_arqos ;
    wire [0:0]        w_port__HDMI_IRQ_Concat_0__In3 ;
    wire [0:0]        w_port__HDMI_IRQ_Concat_0__In4 ;
    wire [0:0]        w_port__HDMI_IRQ_Concat_0__In5 ;
    wire [0:0]        w_port__HDMI_IRQ_Concat_0__In6 ;
    wire [0:0]        w_port__HDMI_IRQ_Concat_0__In7 ;
    wire [0:0]        w_port__HDMI_IRQ_Concat_0__In8 ;
    wire [0:0]        w_port__HDMI_IRQ_Concat_0__In9 ;
    wire [0:0]        w_port__HDMI_IRQ_Concat_0__In10 ;
    wire [0:0]        w_port__HDMI_IRQ_Concat_0__In11 ;
    wire [0:0]        w_port__HDMI_IRQ_Concat_0__In12 ;
    wire [0:0]        w_port__HDMI_IRQ_Concat_0__In13 ;
    wire [0:0]        w_port__HDMI_IRQ_Concat_0__In14 ;
    wire [3:0]        w_port__NPU_Control_Matrix_0__us0_arqos ;
    wire [3:0]        w_port__NPU_Control_Matrix_0__us0_awqos ;
    wire [0:0]        w_net__Constant_0__dout ; 

    wire [32:0]       w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_araddr ;
    wire [32:0]       w_port__ARM_Processor_System_0__slave_hp0_axi_araddr ;
    wire [32:0]       w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_araddr ; 

    wire [1:0]        w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_arburst ;
    wire [1:0]        w_port__ARM_Processor_System_0__slave_hp0_axi_arburst ;
    wire [1:0]        w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_arburst ; 

    wire [3:0]        w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_arcache ;
    wire [3:0]        w_port__ARM_Processor_System_0__slave_hp0_axi_arcache ;
    wire [3:0]        w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_arcache ; 

    wire [5:0]        w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_arid ;
    wire [5:0]        w_port__ARM_Processor_System_0__slave_hp0_axi_arid ;
    wire [5:0]        w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_arid ; 

    wire [3:0]        w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_arlen ;
    wire [3:0]        w_port__ARM_Processor_System_0__slave_hp0_axi_arlen ;
    wire [3:0]        w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_arlen ; 

    wire [1:0]        w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_arlock ;
    wire              w_port__ARM_Processor_System_0__slave_hp0_axi_arlock ;
    wire [1:0]        w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_arlock ; 

    wire [2:0]        w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_arprot ;
    wire [2:0]        w_port__ARM_Processor_System_0__slave_hp0_axi_arprot ;
    wire [2:0]        w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_arprot ; 

    wire [3:0]        w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_arqos ;
    wire [3:0]        w_port__ARM_Processor_System_0__slave_hp0_axi_arqos ;
    wire [3:0]        w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_arqos ; 

    wire [2:0]        w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_arsize ;
    wire [1:0]        w_port__ARM_Processor_System_0__slave_hp0_axi_arsize ;
    wire [2:0]        w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_arsize ; 

    wire              w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_arvalid ;
    wire              w_port__ARM_Processor_System_0__slave_hp0_axi_arvalid ;
    wire              w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_arvalid ; 

    wire [32:0]       w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_awaddr ;
    wire [32:0]       w_port__ARM_Processor_System_0__slave_hp0_axi_awaddr ;
    wire [32:0]       w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_awaddr ; 

    wire [1:0]        w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_awburst ;
    wire [1:0]        w_port__ARM_Processor_System_0__slave_hp0_axi_awburst ;
    wire [1:0]        w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_awburst ; 

    wire [3:0]        w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_awcache ;
    wire [3:0]        w_port__ARM_Processor_System_0__slave_hp0_axi_awcache ;
    wire [3:0]        w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_awcache ; 

    wire [5:0]        w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_awid ;
    wire [5:0]        w_port__ARM_Processor_System_0__slave_hp0_axi_awid ;
    wire [5:0]        w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_awid ; 

    wire [3:0]        w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_awlen ;
    wire [3:0]        w_port__ARM_Processor_System_0__slave_hp0_axi_awlen ;
    wire [3:0]        w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_awlen ; 

    wire [1:0]        w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_awlock ;
    wire              w_port__ARM_Processor_System_0__slave_hp0_axi_awlock ;
    wire [1:0]        w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_awlock ; 

    wire [2:0]        w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_awprot ;
    wire [2:0]        w_port__ARM_Processor_System_0__slave_hp0_axi_awprot ;
    wire [2:0]        w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_awprot ; 

    wire [3:0]        w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_awqos ;
    wire [3:0]        w_port__ARM_Processor_System_0__slave_hp0_axi_awqos ;
    wire [3:0]        w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_awqos ; 

    wire [2:0]        w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_awsize ;
    wire [1:0]        w_port__ARM_Processor_System_0__slave_hp0_axi_awsize ;
    wire [2:0]        w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_awsize ; 

    wire              w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_awvalid ;
    wire              w_port__ARM_Processor_System_0__slave_hp0_axi_awvalid ;
    wire              w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_awvalid ; 

    wire              w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_bready ;
    wire              w_port__ARM_Processor_System_0__slave_hp0_axi_bready ;
    wire              w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_bready ; 

    wire              w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_rready ;
    wire              w_port__ARM_Processor_System_0__slave_hp0_axi_rready ;
    wire              w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_rready ; 

    wire [63:0]       w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_wdata ;
    wire [63:0]       w_port__ARM_Processor_System_0__slave_hp0_axi_wdata ;
    wire [63:0]       w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_wdata ; 

    wire              w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_wlast ;
    wire              w_port__ARM_Processor_System_0__slave_hp0_axi_wlast ;
    wire              w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_wlast ; 

    wire [7:0]        w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_wstrb ;
    wire [7:0]        w_port__ARM_Processor_System_0__slave_hp0_axi_wstrb ;
    wire [7:0]        w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_wstrb ; 

    wire              w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_wvalid ;
    wire              w_port__ARM_Processor_System_0__slave_hp0_axi_wvalid ;
    wire              w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_wvalid ; 

    wire              w_port__HDMI_HP0_Protocol_Converter_0__us_axi_arready ;
    wire              w_port__VDMA_0__m_axi_mm2s_arready ;
    wire              w_net__HDMI_HP0_Protocol_Converter_0__us_axi_arready ; 

    wire [63:0]       w_port__HDMI_HP0_Protocol_Converter_0__us_axi_rdata ;
    wire [63:0]       w_port__VDMA_0__m_axi_mm2s_rdata ;
    wire [63:0]       w_net__HDMI_HP0_Protocol_Converter_0__us_axi_rdata ; 

    wire              w_port__HDMI_HP0_Protocol_Converter_0__us_axi_rlast ;
    wire              w_port__VDMA_0__m_axi_mm2s_rlast ;
    wire              w_net__HDMI_HP0_Protocol_Converter_0__us_axi_rlast ; 

    wire [1:0]        w_port__HDMI_HP0_Protocol_Converter_0__us_axi_rresp ;
    wire [1:0]        w_port__VDMA_0__m_axi_mm2s_rresp ;
    wire [1:0]        w_net__HDMI_HP0_Protocol_Converter_0__us_axi_rresp ; 

    wire              w_port__HDMI_HP0_Protocol_Converter_0__us_axi_rvalid ;
    wire              w_port__VDMA_0__m_axi_mm2s_rvalid ;
    wire              w_net__HDMI_HP0_Protocol_Converter_0__us_axi_rvalid ; 

    wire [15:0]       w_port__HDMI_IRQ_Concat_0__Dout ;
    wire [15:0]       w_port__ARM_Processor_System_0__f2p_irq ;
    wire [15:0]       w_net__HDMI_IRQ_Concat_0__Dout ; 

    wire              w_port__HDMI_PLL_0__clk1_out ;
    wire              w_port__VDMA_0__m_axi_mm2s_aclk ;
    wire              w_port__ARM_Processor_System_0__slave_hp0_axi_aclk ;
    wire              w_port__HDMI_HP0_Protocol_Converter_0__aclk ;
    wire              w_port__HDMI_Reset_0__mem_clk ;
    wire              w_net__HDMI_PLL_0__clk1_out ; 

    wire              w_port__HDMI_PLL_0__clk2_out ;
    wire              w_port__VDMA_0__m_axis_mm2s_aclk ;
    wire              w_port__AXI4_Stream_to_Video_Out_0__aclk ;
    wire              w_port__HDMI_Reset_0__axis_clk ;
    wire              w_net__HDMI_PLL_0__clk2_out ; 

    wire              w_port__HDMI_PLL_0__lock ;
    wire              w_port__HDMI_Reset_0__display_pll_locked ;
    wire              w_port__AXI4_Stream_to_Video_Out_0__aclken ;
    wire              w_net__HDMI_PLL_0__lock ; 

    wire              w_port__HDMI_PLL_1__clk0_out ;
    wire              w_port__HDMI_TX_0__I_serial_clk ;
    wire              w_net__HDMI_PLL_1__clk0_out ; 

    wire              w_port__HDMI_PLL_1__lock ;
    wire              w_port__HDMI_Reset_0__serial_pll_locked ;
    wire              w_net__HDMI_PLL_1__lock ; 

    wire              w_port__HDMI_Reset_0__axis_reset_n ;
    wire              w_port__AXI4_Stream_to_Video_Out_0__aresetn ;
    wire              w_net__HDMI_Reset_0__axis_reset_n ; 

    wire              w_port__HDMI_Reset_0__ctrl_reset_n ;
    wire              w_port__VDMA_0__resetn ;
    wire              w_net__HDMI_Reset_0__ctrl_reset_n ; 

    wire              w_port__HDMI_Reset_0__mem_reset_n ;
    wire              w_port__HDMI_HP0_Protocol_Converter_0__aresetn ;
    wire              w_net__HDMI_Reset_0__mem_reset_n ; 

    wire              w_port__HDMI_Reset_0__pixel_reset ;
    wire              w_port__AXI4_Stream_to_Video_Out_0__vid_io_out_reset ;
    wire              w_net__HDMI_Reset_0__pixel_reset ; 

    wire              w_port__HDMI_Reset_0__serial_pll_reset ;
    wire              w_port__HDMI_PLL_1__reset ;
    wire              w_net__HDMI_Reset_0__serial_pll_reset ; 

    wire              w_port__HDMI_Reset_0__tx_reset ;
    wire              w_port__HDMI_TX_0__I_rst ;
    wire              w_net__HDMI_Reset_0__tx_reset ; 

    wire              w_port__HDMI_TX_0__O_hdmi_clk_p ;
    wire              w_net__HDMI_TX_0__O_hdmi_clk_p ; 

    wire [2:0]        w_port__HDMI_TX_0__O_hdmi_tx_p ;
    wire [2:0]        w_net__HDMI_TX_0__O_hdmi_tx_p ; 

    wire              w_port__HDMI_VTG_0__s_axi_arready ;
    wire              w_port__AXI_Lite_Matrix_0__ds2_arready ;
    wire              w_net__HDMI_VTG_0__s_axi_arready ; 

    wire              w_port__HDMI_VTG_0__s_axi_awready ;
    wire              w_port__AXI_Lite_Matrix_0__ds2_awready ;
    wire              w_net__HDMI_VTG_0__s_axi_awready ; 

    wire [1:0]        w_port__HDMI_VTG_0__s_axi_bresp ;
    wire [1:0]        w_port__AXI_Lite_Matrix_0__ds2_bresp ;
    wire [1:0]        w_net__HDMI_VTG_0__s_axi_bresp ; 

    wire              w_port__HDMI_VTG_0__s_axi_bvalid ;
    wire              w_port__AXI_Lite_Matrix_0__ds2_bvalid ;
    wire              w_net__HDMI_VTG_0__s_axi_bvalid ; 

    wire [31:0]       w_port__HDMI_VTG_0__s_axi_rdata ;
    wire [31:0]       w_port__AXI_Lite_Matrix_0__ds2_rdata ;
    wire [31:0]       w_net__HDMI_VTG_0__s_axi_rdata ; 

    wire [1:0]        w_port__HDMI_VTG_0__s_axi_rresp ;
    wire [1:0]        w_port__AXI_Lite_Matrix_0__ds2_rresp ;
    wire [1:0]        w_net__HDMI_VTG_0__s_axi_rresp ; 

    wire              w_port__HDMI_VTG_0__s_axi_rvalid ;
    wire              w_port__AXI_Lite_Matrix_0__ds2_rvalid ;
    wire              w_net__HDMI_VTG_0__s_axi_rvalid ; 

    wire              w_port__HDMI_VTG_0__s_axi_wready ;
    wire              w_port__AXI_Lite_Matrix_0__ds2_wready ;
    wire              w_net__HDMI_VTG_0__s_axi_wready ; 

    wire              w_port__HDMI_VTG_0__vtg_active_video ;
    wire              w_port__AXI4_Stream_to_Video_Out_0__vtg_active_video ;
    wire              w_net__HDMI_VTG_0__vtg_active_video ; 

    wire              w_port__HDMI_VTG_0__vtg_hblank ;
    wire              w_port__AXI4_Stream_to_Video_Out_0__vtg_hblank ;
    wire              w_net__HDMI_VTG_0__vtg_hblank ; 

    wire              w_port__HDMI_VTG_0__vtg_hsync ;
    wire              w_port__AXI4_Stream_to_Video_Out_0__vtg_hsync ;
    wire              w_net__HDMI_VTG_0__vtg_hsync ; 

    wire              w_port__HDMI_VTG_0__vtg_pclk ;
    wire              w_port__AXI4_Stream_to_Video_Out_0__vid_io_out_clk ;
    wire              w_port__HDMI_PLL_1__refclk ;
    wire              w_port__HDMI_TX_0__I_pixel_clk ;
    wire              w_port__HDMI_Reset_0__pixel_clk ;
    wire              w_net__HDMI_VTG_0__vtg_pclk ; 

    wire              w_port__HDMI_VTG_0__vtg_pclk_locked ;
    wire              w_port__AXI4_Stream_to_Video_Out_0__vid_io_out_ce ;
    wire              w_port__HDMI_Reset_0__pixel_pll_locked ;
    wire              w_net__HDMI_VTG_0__vtg_pclk_locked ; 

    wire              w_port__HDMI_VTG_0__vtg_vblank ;
    wire              w_port__AXI4_Stream_to_Video_Out_0__vtg_vblank ;
    wire              w_net__HDMI_VTG_0__vtg_vblank ; 

    wire              w_port__HDMI_VTG_0__vtg_vsync ;
    wire              w_port__AXI4_Stream_to_Video_Out_0__vtg_vsync ;
    wire              w_net__HDMI_VTG_0__vtg_vsync ; 

    wire [32:0]       w_port__HP1_AXI_Matrix_0__ds0_araddr ;
    wire [32:0]       w_port__HP1_Protocol_Converter_0__us_axi_araddr ;
    wire [32:0]       w_net__HP1_AXI_Matrix_0__ds0_araddr ; 

    wire [1:0]        w_port__HP1_AXI_Matrix_0__ds0_arburst ;
    wire [1:0]        w_port__HP1_Protocol_Converter_0__us_axi_arburst ;
    wire [1:0]        w_net__HP1_AXI_Matrix_0__ds0_arburst ; 

    wire [3:0]        w_port__HP1_AXI_Matrix_0__ds0_arcache ;
    wire [3:0]        w_port__HP1_Protocol_Converter_0__us_axi_arcache ;
    wire [3:0]        w_net__HP1_AXI_Matrix_0__ds0_arcache ; 

    wire [5:0]        w_port__HP1_AXI_Matrix_0__ds0_arid ;
    wire [5:0]        w_port__HP1_Protocol_Converter_0__us_axi_arid ;
    wire [5:0]        w_net__HP1_AXI_Matrix_0__ds0_arid ; 

    wire [7:0]        w_port__HP1_AXI_Matrix_0__ds0_arlen ;
    wire [7:0]        w_port__HP1_Protocol_Converter_0__us_axi_arlen ;
    wire [7:0]        w_net__HP1_AXI_Matrix_0__ds0_arlen ; 

    wire [0:0]        w_port__HP1_AXI_Matrix_0__ds0_arlock ;
    wire [0:0]        w_port__HP1_Protocol_Converter_0__us_axi_arlock ;
    wire [0:0]        w_net__HP1_AXI_Matrix_0__ds0_arlock ; 

    wire [2:0]        w_port__HP1_AXI_Matrix_0__ds0_arprot ;
    wire [2:0]        w_port__HP1_Protocol_Converter_0__us_axi_arprot ;
    wire [2:0]        w_net__HP1_AXI_Matrix_0__ds0_arprot ; 

    wire [3:0]        w_port__HP1_AXI_Matrix_0__ds0_arqos ;
    wire [3:0]        w_port__HP1_Protocol_Converter_0__us_axi_arqos ;
    wire [3:0]        w_net__HP1_AXI_Matrix_0__ds0_arqos ; 

    wire [2:0]        w_port__HP1_AXI_Matrix_0__ds0_arsize ;
    wire [2:0]        w_port__HP1_Protocol_Converter_0__us_axi_arsize ;
    wire [2:0]        w_net__HP1_AXI_Matrix_0__ds0_arsize ; 

    wire              w_port__HP1_AXI_Matrix_0__ds0_arvalid ;
    wire              w_port__HP1_Protocol_Converter_0__us_axi_arvalid ;
    wire              w_net__HP1_AXI_Matrix_0__ds0_arvalid ; 

    wire [32:0]       w_port__HP1_AXI_Matrix_0__ds0_awaddr ;
    wire [32:0]       w_port__HP1_Protocol_Converter_0__us_axi_awaddr ;
    wire [32:0]       w_net__HP1_AXI_Matrix_0__ds0_awaddr ; 

    wire [1:0]        w_port__HP1_AXI_Matrix_0__ds0_awburst ;
    wire [1:0]        w_port__HP1_Protocol_Converter_0__us_axi_awburst ;
    wire [1:0]        w_net__HP1_AXI_Matrix_0__ds0_awburst ; 

    wire [3:0]        w_port__HP1_AXI_Matrix_0__ds0_awcache ;
    wire [3:0]        w_port__HP1_Protocol_Converter_0__us_axi_awcache ;
    wire [3:0]        w_net__HP1_AXI_Matrix_0__ds0_awcache ; 

    wire [5:0]        w_port__HP1_AXI_Matrix_0__ds0_awid ;
    wire [5:0]        w_port__HP1_Protocol_Converter_0__us_axi_awid ;
    wire [5:0]        w_net__HP1_AXI_Matrix_0__ds0_awid ; 

    wire [7:0]        w_port__HP1_AXI_Matrix_0__ds0_awlen ;
    wire [7:0]        w_port__HP1_Protocol_Converter_0__us_axi_awlen ;
    wire [7:0]        w_net__HP1_AXI_Matrix_0__ds0_awlen ; 

    wire [0:0]        w_port__HP1_AXI_Matrix_0__ds0_awlock ;
    wire [0:0]        w_port__HP1_Protocol_Converter_0__us_axi_awlock ;
    wire [0:0]        w_net__HP1_AXI_Matrix_0__ds0_awlock ; 

    wire [2:0]        w_port__HP1_AXI_Matrix_0__ds0_awprot ;
    wire [2:0]        w_port__HP1_Protocol_Converter_0__us_axi_awprot ;
    wire [2:0]        w_net__HP1_AXI_Matrix_0__ds0_awprot ; 

    wire [3:0]        w_port__HP1_AXI_Matrix_0__ds0_awqos ;
    wire [3:0]        w_port__HP1_Protocol_Converter_0__us_axi_awqos ;
    wire [3:0]        w_net__HP1_AXI_Matrix_0__ds0_awqos ; 

    wire [2:0]        w_port__HP1_AXI_Matrix_0__ds0_awsize ;
    wire [2:0]        w_port__HP1_Protocol_Converter_0__us_axi_awsize ;
    wire [2:0]        w_net__HP1_AXI_Matrix_0__ds0_awsize ; 

    wire              w_port__HP1_AXI_Matrix_0__ds0_awvalid ;
    wire              w_port__HP1_Protocol_Converter_0__us_axi_awvalid ;
    wire              w_net__HP1_AXI_Matrix_0__ds0_awvalid ; 

    wire              w_port__HP1_AXI_Matrix_0__ds0_bready ;
    wire              w_port__HP1_Protocol_Converter_0__us_axi_bready ;
    wire              w_net__HP1_AXI_Matrix_0__ds0_bready ; 

    wire              w_port__HP1_AXI_Matrix_0__ds0_rready ;
    wire              w_port__HP1_Protocol_Converter_0__us_axi_rready ;
    wire              w_net__HP1_AXI_Matrix_0__ds0_rready ; 

    wire [63:0]       w_port__HP1_AXI_Matrix_0__ds0_wdata ;
    wire [63:0]       w_port__HP1_Protocol_Converter_0__us_axi_wdata ;
    wire [63:0]       w_net__HP1_AXI_Matrix_0__ds0_wdata ; 

    wire              w_port__HP1_AXI_Matrix_0__ds0_wlast ;
    wire              w_port__HP1_Protocol_Converter_0__us_axi_wlast ;
    wire              w_net__HP1_AXI_Matrix_0__ds0_wlast ; 

    wire [7:0]        w_port__HP1_AXI_Matrix_0__ds0_wstrb ;
    wire [7:0]        w_port__HP1_Protocol_Converter_0__us_axi_wstrb ;
    wire [7:0]        w_net__HP1_AXI_Matrix_0__ds0_wstrb ; 

    wire              w_port__HP1_AXI_Matrix_0__ds0_wvalid ;
    wire              w_port__HP1_Protocol_Converter_0__us_axi_wvalid ;
    wire              w_net__HP1_AXI_Matrix_0__ds0_wvalid ; 

    wire              w_port__HP1_AXI_Matrix_0__us0_awready ;
    wire              w_port__adc_fdma_writer_0__m_axi_s2mm_awready ;
    wire              w_net__HP1_AXI_Matrix_0__us0_awready ; 

    wire [4:0]        w_port__HP1_AXI_Matrix_0__us0_bid ;
    wire [4:0]        w_port__adc_fdma_writer_0__m_axi_s2mm_bid ;
    wire [4:0]        w_net__HP1_AXI_Matrix_0__us0_bid ; 

    wire [1:0]        w_port__HP1_AXI_Matrix_0__us0_bresp ;
    wire [1:0]        w_port__adc_fdma_writer_0__m_axi_s2mm_bresp ;
    wire [1:0]        w_net__HP1_AXI_Matrix_0__us0_bresp ; 

    wire              w_port__HP1_AXI_Matrix_0__us0_bvalid ;
    wire              w_port__adc_fdma_writer_0__m_axi_s2mm_bvalid ;
    wire              w_net__HP1_AXI_Matrix_0__us0_bvalid ; 

    wire              w_port__HP1_AXI_Matrix_0__us0_wready ;
    wire              w_port__adc_fdma_writer_0__m_axi_s2mm_wready ;
    wire              w_net__HP1_AXI_Matrix_0__us0_wready ; 

    wire              w_port__HP1_AXI_Matrix_0__us1_arready ;
    wire              w_port__NPU_HP1_Adapter_0__m_axi_arready ;
    wire              w_net__HP1_AXI_Matrix_0__us1_arready ; 

    wire              w_port__HP1_AXI_Matrix_0__us1_awready ;
    wire              w_port__NPU_HP1_Adapter_0__m_axi_awready ;
    wire              w_net__HP1_AXI_Matrix_0__us1_awready ; 

    wire [4:0]        w_port__HP1_AXI_Matrix_0__us1_bid ;
    wire [4:0]        w_port__NPU_HP1_Adapter_0__m_axi_bid ;
    wire [4:0]        w_net__HP1_AXI_Matrix_0__us1_bid ; 

    wire [1:0]        w_port__HP1_AXI_Matrix_0__us1_bresp ;
    wire [1:0]        w_port__NPU_HP1_Adapter_0__m_axi_bresp ;
    wire [1:0]        w_net__HP1_AXI_Matrix_0__us1_bresp ; 

    wire              w_port__HP1_AXI_Matrix_0__us1_bvalid ;
    wire              w_port__NPU_HP1_Adapter_0__m_axi_bvalid ;
    wire              w_net__HP1_AXI_Matrix_0__us1_bvalid ; 

    wire [63:0]       w_port__HP1_AXI_Matrix_0__us1_rdata ;
    wire [63:0]       w_port__NPU_HP1_Adapter_0__m_axi_rdata ;
    wire [63:0]       w_net__HP1_AXI_Matrix_0__us1_rdata ; 

    wire [4:0]        w_port__HP1_AXI_Matrix_0__us1_rid ;
    wire [4:0]        w_port__NPU_HP1_Adapter_0__m_axi_rid ;
    wire [4:0]        w_net__HP1_AXI_Matrix_0__us1_rid ; 

    wire              w_port__HP1_AXI_Matrix_0__us1_rlast ;
    wire              w_port__NPU_HP1_Adapter_0__m_axi_rlast ;
    wire              w_net__HP1_AXI_Matrix_0__us1_rlast ; 

    wire [1:0]        w_port__HP1_AXI_Matrix_0__us1_rresp ;
    wire [1:0]        w_port__NPU_HP1_Adapter_0__m_axi_rresp ;
    wire [1:0]        w_net__HP1_AXI_Matrix_0__us1_rresp ; 

    wire              w_port__HP1_AXI_Matrix_0__us1_rvalid ;
    wire              w_port__NPU_HP1_Adapter_0__m_axi_rvalid ;
    wire              w_net__HP1_AXI_Matrix_0__us1_rvalid ; 

    wire              w_port__HP1_AXI_Matrix_0__us1_wready ;
    wire              w_port__NPU_HP1_Adapter_0__m_axi_wready ;
    wire              w_net__HP1_AXI_Matrix_0__us1_wready ; 

    wire [32:0]       w_port__HP1_Protocol_Converter_0__ds_axi_araddr ;
    wire [32:0]       w_port__ARM_Processor_System_0__slave_hp1_axi_araddr ;
    wire [32:0]       w_net__HP1_Protocol_Converter_0__ds_axi_araddr ; 

    wire [1:0]        w_port__HP1_Protocol_Converter_0__ds_axi_arburst ;
    wire [1:0]        w_port__ARM_Processor_System_0__slave_hp1_axi_arburst ;
    wire [1:0]        w_net__HP1_Protocol_Converter_0__ds_axi_arburst ; 

    wire [3:0]        w_port__HP1_Protocol_Converter_0__ds_axi_arcache ;
    wire [3:0]        w_port__ARM_Processor_System_0__slave_hp1_axi_arcache ;
    wire [3:0]        w_net__HP1_Protocol_Converter_0__ds_axi_arcache ; 

    wire [5:0]        w_port__HP1_Protocol_Converter_0__ds_axi_arid ;
    wire [5:0]        w_port__ARM_Processor_System_0__slave_hp1_axi_arid ;
    wire [5:0]        w_net__HP1_Protocol_Converter_0__ds_axi_arid ; 

    wire [3:0]        w_port__HP1_Protocol_Converter_0__ds_axi_arlen ;
    wire [3:0]        w_port__ARM_Processor_System_0__slave_hp1_axi_arlen ;
    wire [3:0]        w_net__HP1_Protocol_Converter_0__ds_axi_arlen ; 

    wire [1:0]        w_port__HP1_Protocol_Converter_0__ds_axi_arlock ;
    wire              w_port__ARM_Processor_System_0__slave_hp1_axi_arlock ;
    wire [1:0]        w_net__HP1_Protocol_Converter_0__ds_axi_arlock ; 

    wire [2:0]        w_port__HP1_Protocol_Converter_0__ds_axi_arprot ;
    wire [2:0]        w_port__ARM_Processor_System_0__slave_hp1_axi_arprot ;
    wire [2:0]        w_net__HP1_Protocol_Converter_0__ds_axi_arprot ; 

    wire [3:0]        w_port__HP1_Protocol_Converter_0__ds_axi_arqos ;
    wire [3:0]        w_port__ARM_Processor_System_0__slave_hp1_axi_arqos ;
    wire [3:0]        w_net__HP1_Protocol_Converter_0__ds_axi_arqos ; 

    wire [2:0]        w_port__HP1_Protocol_Converter_0__ds_axi_arsize ;
    wire [1:0]        w_port__ARM_Processor_System_0__slave_hp1_axi_arsize ;
    wire [2:0]        w_net__HP1_Protocol_Converter_0__ds_axi_arsize ; 

    wire              w_port__HP1_Protocol_Converter_0__ds_axi_arvalid ;
    wire              w_port__ARM_Processor_System_0__slave_hp1_axi_arvalid ;
    wire              w_net__HP1_Protocol_Converter_0__ds_axi_arvalid ; 

    wire [32:0]       w_port__HP1_Protocol_Converter_0__ds_axi_awaddr ;
    wire [32:0]       w_port__ARM_Processor_System_0__slave_hp1_axi_awaddr ;
    wire [32:0]       w_net__HP1_Protocol_Converter_0__ds_axi_awaddr ; 

    wire [1:0]        w_port__HP1_Protocol_Converter_0__ds_axi_awburst ;
    wire [1:0]        w_port__ARM_Processor_System_0__slave_hp1_axi_awburst ;
    wire [1:0]        w_net__HP1_Protocol_Converter_0__ds_axi_awburst ; 

    wire [3:0]        w_port__HP1_Protocol_Converter_0__ds_axi_awcache ;
    wire [3:0]        w_port__ARM_Processor_System_0__slave_hp1_axi_awcache ;
    wire [3:0]        w_net__HP1_Protocol_Converter_0__ds_axi_awcache ; 

    wire [5:0]        w_port__HP1_Protocol_Converter_0__ds_axi_awid ;
    wire [5:0]        w_port__ARM_Processor_System_0__slave_hp1_axi_awid ;
    wire [5:0]        w_net__HP1_Protocol_Converter_0__ds_axi_awid ; 

    wire [3:0]        w_port__HP1_Protocol_Converter_0__ds_axi_awlen ;
    wire [3:0]        w_port__ARM_Processor_System_0__slave_hp1_axi_awlen ;
    wire [3:0]        w_net__HP1_Protocol_Converter_0__ds_axi_awlen ; 

    wire [1:0]        w_port__HP1_Protocol_Converter_0__ds_axi_awlock ;
    wire              w_port__ARM_Processor_System_0__slave_hp1_axi_awlock ;
    wire [1:0]        w_net__HP1_Protocol_Converter_0__ds_axi_awlock ; 

    wire [2:0]        w_port__HP1_Protocol_Converter_0__ds_axi_awprot ;
    wire [2:0]        w_port__ARM_Processor_System_0__slave_hp1_axi_awprot ;
    wire [2:0]        w_net__HP1_Protocol_Converter_0__ds_axi_awprot ; 

    wire [3:0]        w_port__HP1_Protocol_Converter_0__ds_axi_awqos ;
    wire [3:0]        w_port__ARM_Processor_System_0__slave_hp1_axi_awqos ;
    wire [3:0]        w_net__HP1_Protocol_Converter_0__ds_axi_awqos ; 

    wire [2:0]        w_port__HP1_Protocol_Converter_0__ds_axi_awsize ;
    wire [1:0]        w_port__ARM_Processor_System_0__slave_hp1_axi_awsize ;
    wire [2:0]        w_net__HP1_Protocol_Converter_0__ds_axi_awsize ; 

    wire              w_port__HP1_Protocol_Converter_0__ds_axi_awvalid ;
    wire              w_port__ARM_Processor_System_0__slave_hp1_axi_awvalid ;
    wire              w_net__HP1_Protocol_Converter_0__ds_axi_awvalid ; 

    wire              w_port__HP1_Protocol_Converter_0__ds_axi_bready ;
    wire              w_port__ARM_Processor_System_0__slave_hp1_axi_bready ;
    wire              w_net__HP1_Protocol_Converter_0__ds_axi_bready ; 

    wire              w_port__HP1_Protocol_Converter_0__ds_axi_rready ;
    wire              w_port__ARM_Processor_System_0__slave_hp1_axi_rready ;
    wire              w_net__HP1_Protocol_Converter_0__ds_axi_rready ; 

    wire [63:0]       w_port__HP1_Protocol_Converter_0__ds_axi_wdata ;
    wire [63:0]       w_port__ARM_Processor_System_0__slave_hp1_axi_wdata ;
    wire [63:0]       w_net__HP1_Protocol_Converter_0__ds_axi_wdata ; 

    wire              w_port__HP1_Protocol_Converter_0__ds_axi_wlast ;
    wire              w_port__ARM_Processor_System_0__slave_hp1_axi_wlast ;
    wire              w_net__HP1_Protocol_Converter_0__ds_axi_wlast ; 

    wire [7:0]        w_port__HP1_Protocol_Converter_0__ds_axi_wstrb ;
    wire [7:0]        w_port__ARM_Processor_System_0__slave_hp1_axi_wstrb ;
    wire [7:0]        w_net__HP1_Protocol_Converter_0__ds_axi_wstrb ; 

    wire              w_port__HP1_Protocol_Converter_0__ds_axi_wvalid ;
    wire              w_port__ARM_Processor_System_0__slave_hp1_axi_wvalid ;
    wire              w_net__HP1_Protocol_Converter_0__ds_axi_wvalid ; 

    wire              w_port__HP1_Protocol_Converter_0__us_axi_arready ;
    wire              w_port__HP1_AXI_Matrix_0__ds0_arready ;
    wire              w_net__HP1_Protocol_Converter_0__us_axi_arready ; 

    wire              w_port__HP1_Protocol_Converter_0__us_axi_awready ;
    wire              w_port__HP1_AXI_Matrix_0__ds0_awready ;
    wire              w_net__HP1_Protocol_Converter_0__us_axi_awready ; 

    wire [5:0]        w_port__HP1_Protocol_Converter_0__us_axi_bid ;
    wire [5:0]        w_port__HP1_AXI_Matrix_0__ds0_bid ;
    wire [5:0]        w_net__HP1_Protocol_Converter_0__us_axi_bid ; 

    wire [1:0]        w_port__HP1_Protocol_Converter_0__us_axi_bresp ;
    wire [1:0]        w_port__HP1_AXI_Matrix_0__ds0_bresp ;
    wire [1:0]        w_net__HP1_Protocol_Converter_0__us_axi_bresp ; 

    wire              w_port__HP1_Protocol_Converter_0__us_axi_bvalid ;
    wire              w_port__HP1_AXI_Matrix_0__ds0_bvalid ;
    wire              w_net__HP1_Protocol_Converter_0__us_axi_bvalid ; 

    wire [63:0]       w_port__HP1_Protocol_Converter_0__us_axi_rdata ;
    wire [63:0]       w_port__HP1_AXI_Matrix_0__ds0_rdata ;
    wire [63:0]       w_net__HP1_Protocol_Converter_0__us_axi_rdata ; 

    wire [5:0]        w_port__HP1_Protocol_Converter_0__us_axi_rid ;
    wire [5:0]        w_port__HP1_AXI_Matrix_0__ds0_rid ;
    wire [5:0]        w_net__HP1_Protocol_Converter_0__us_axi_rid ; 

    wire              w_port__HP1_Protocol_Converter_0__us_axi_rlast ;
    wire              w_port__HP1_AXI_Matrix_0__ds0_rlast ;
    wire              w_net__HP1_Protocol_Converter_0__us_axi_rlast ; 

    wire [1:0]        w_port__HP1_Protocol_Converter_0__us_axi_rresp ;
    wire [1:0]        w_port__HP1_AXI_Matrix_0__ds0_rresp ;
    wire [1:0]        w_net__HP1_Protocol_Converter_0__us_axi_rresp ; 

    wire              w_port__HP1_Protocol_Converter_0__us_axi_rvalid ;
    wire              w_port__HP1_AXI_Matrix_0__ds0_rvalid ;
    wire              w_net__HP1_Protocol_Converter_0__us_axi_rvalid ; 

    wire              w_port__HP1_Protocol_Converter_0__us_axi_wready ;
    wire              w_port__HP1_AXI_Matrix_0__ds0_wready ;
    wire              w_net__HP1_Protocol_Converter_0__us_axi_wready ; 

    wire [32:0]       w_port__NPU_Control_Converter_0__ds_axi_araddr ;
    wire [32:0]       w_port__Video_NPU_0__s_axilite_araddr_i ;
    wire [32:0]       w_net__NPU_Control_Converter_0__ds_axi_araddr ; 

    wire [2:0]        w_port__NPU_Control_Converter_0__ds_axi_arprot ;
    wire [2:0]        w_port__Video_NPU_0__s_axilite_arprot_i ;
    wire [2:0]        w_net__NPU_Control_Converter_0__ds_axi_arprot ; 

    wire              w_port__NPU_Control_Converter_0__ds_axi_arvalid ;
    wire              w_port__Video_NPU_0__s_axilite_arvalid_i ;
    wire              w_net__NPU_Control_Converter_0__ds_axi_arvalid ; 

    wire [32:0]       w_port__NPU_Control_Converter_0__ds_axi_awaddr ;
    wire [32:0]       w_port__Video_NPU_0__s_axilite_awaddr_i ;
    wire [32:0]       w_net__NPU_Control_Converter_0__ds_axi_awaddr ; 

    wire [2:0]        w_port__NPU_Control_Converter_0__ds_axi_awprot ;
    wire [2:0]        w_port__Video_NPU_0__s_axilite_awprot_i ;
    wire [2:0]        w_net__NPU_Control_Converter_0__ds_axi_awprot ; 

    wire              w_port__NPU_Control_Converter_0__ds_axi_awvalid ;
    wire              w_port__Video_NPU_0__s_axilite_awvalid_i ;
    wire              w_net__NPU_Control_Converter_0__ds_axi_awvalid ; 

    wire              w_port__NPU_Control_Converter_0__ds_axi_bready ;
    wire              w_port__Video_NPU_0__s_axilite_bready_i ;
    wire              w_net__NPU_Control_Converter_0__ds_axi_bready ; 

    wire              w_port__NPU_Control_Converter_0__ds_axi_rready ;
    wire              w_port__Video_NPU_0__s_axilite_rready_i ;
    wire              w_net__NPU_Control_Converter_0__ds_axi_rready ; 

    wire [31:0]       w_port__NPU_Control_Converter_0__ds_axi_wdata ;
    wire [31:0]       w_port__Video_NPU_0__s_axilite_wdata_i ;
    wire [31:0]       w_net__NPU_Control_Converter_0__ds_axi_wdata ; 

    wire [3:0]        w_port__NPU_Control_Converter_0__ds_axi_wstrb ;
    wire [3:0]        w_port__Video_NPU_0__s_axilite_wstrb_i ;
    wire [3:0]        w_net__NPU_Control_Converter_0__ds_axi_wstrb ; 

    wire              w_port__NPU_Control_Converter_0__ds_axi_wvalid ;
    wire              w_port__Video_NPU_0__s_axilite_wvalid_i ;
    wire              w_net__NPU_Control_Converter_0__ds_axi_wvalid ; 

    wire              w_port__NPU_Control_Converter_0__us_axi_arready ;
    wire              w_port__NPU_Control_Matrix_0__ds0_arready ;
    wire              w_net__NPU_Control_Converter_0__us_axi_arready ; 

    wire              w_port__NPU_Control_Converter_0__us_axi_awready ;
    wire              w_port__NPU_Control_Matrix_0__ds0_awready ;
    wire              w_net__NPU_Control_Converter_0__us_axi_awready ; 

    wire [12:0]       w_port__NPU_Control_Converter_0__us_axi_bid ;
    wire [12:0]       w_port__NPU_Control_Matrix_0__ds0_bid ;
    wire [12:0]       w_net__NPU_Control_Converter_0__us_axi_bid ; 

    wire [1:0]        w_port__NPU_Control_Converter_0__us_axi_bresp ;
    wire [1:0]        w_port__NPU_Control_Matrix_0__ds0_bresp ;
    wire [1:0]        w_net__NPU_Control_Converter_0__us_axi_bresp ; 

    wire              w_port__NPU_Control_Converter_0__us_axi_bvalid ;
    wire              w_port__NPU_Control_Matrix_0__ds0_bvalid ;
    wire              w_net__NPU_Control_Converter_0__us_axi_bvalid ; 

    wire [31:0]       w_port__NPU_Control_Converter_0__us_axi_rdata ;
    wire [31:0]       w_port__NPU_Control_Matrix_0__ds0_rdata ;
    wire [31:0]       w_net__NPU_Control_Converter_0__us_axi_rdata ; 

    wire [12:0]       w_port__NPU_Control_Converter_0__us_axi_rid ;
    wire [12:0]       w_port__NPU_Control_Matrix_0__ds0_rid ;
    wire [12:0]       w_net__NPU_Control_Converter_0__us_axi_rid ; 

    wire              w_port__NPU_Control_Converter_0__us_axi_rlast ;
    wire              w_port__NPU_Control_Matrix_0__ds0_rlast ;
    wire              w_net__NPU_Control_Converter_0__us_axi_rlast ; 

    wire [1:0]        w_port__NPU_Control_Converter_0__us_axi_rresp ;
    wire [1:0]        w_port__NPU_Control_Matrix_0__ds0_rresp ;
    wire [1:0]        w_net__NPU_Control_Converter_0__us_axi_rresp ; 

    wire              w_port__NPU_Control_Converter_0__us_axi_rvalid ;
    wire              w_port__NPU_Control_Matrix_0__ds0_rvalid ;
    wire              w_net__NPU_Control_Converter_0__us_axi_rvalid ; 

    wire              w_port__NPU_Control_Converter_0__us_axi_wready ;
    wire              w_port__NPU_Control_Matrix_0__ds0_wready ;
    wire              w_net__NPU_Control_Converter_0__us_axi_wready ; 

    wire [32:0]       w_port__NPU_Control_Matrix_0__ds0_araddr ;
    wire [32:0]       w_port__NPU_Control_Converter_0__us_axi_araddr ;
    wire [32:0]       w_net__NPU_Control_Matrix_0__ds0_araddr ; 

    wire [1:0]        w_port__NPU_Control_Matrix_0__ds0_arburst ;
    wire [1:0]        w_port__NPU_Control_Converter_0__us_axi_arburst ;
    wire [1:0]        w_net__NPU_Control_Matrix_0__ds0_arburst ; 

    wire [3:0]        w_port__NPU_Control_Matrix_0__ds0_arcache ;
    wire [3:0]        w_port__NPU_Control_Converter_0__us_axi_arcache ;
    wire [3:0]        w_net__NPU_Control_Matrix_0__ds0_arcache ; 

    wire [12:0]       w_port__NPU_Control_Matrix_0__ds0_arid ;
    wire [12:0]       w_port__NPU_Control_Converter_0__us_axi_arid ;
    wire [12:0]       w_net__NPU_Control_Matrix_0__ds0_arid ; 

    wire [7:0]        w_port__NPU_Control_Matrix_0__ds0_arlen ;
    wire [7:0]        w_port__NPU_Control_Converter_0__us_axi_arlen ;
    wire [7:0]        w_net__NPU_Control_Matrix_0__ds0_arlen ; 

    wire [0:0]        w_port__NPU_Control_Matrix_0__ds0_arlock ;
    wire [0:0]        w_port__NPU_Control_Converter_0__us_axi_arlock ;
    wire [0:0]        w_net__NPU_Control_Matrix_0__ds0_arlock ; 

    wire [2:0]        w_port__NPU_Control_Matrix_0__ds0_arprot ;
    wire [2:0]        w_port__NPU_Control_Converter_0__us_axi_arprot ;
    wire [2:0]        w_net__NPU_Control_Matrix_0__ds0_arprot ; 

    wire [3:0]        w_port__NPU_Control_Matrix_0__ds0_arqos ;
    wire [3:0]        w_port__NPU_Control_Converter_0__us_axi_arqos ;
    wire [3:0]        w_net__NPU_Control_Matrix_0__ds0_arqos ; 

    wire [2:0]        w_port__NPU_Control_Matrix_0__ds0_arsize ;
    wire [2:0]        w_port__NPU_Control_Converter_0__us_axi_arsize ;
    wire [2:0]        w_net__NPU_Control_Matrix_0__ds0_arsize ; 

    wire              w_port__NPU_Control_Matrix_0__ds0_arvalid ;
    wire              w_port__NPU_Control_Converter_0__us_axi_arvalid ;
    wire              w_net__NPU_Control_Matrix_0__ds0_arvalid ; 

    wire [32:0]       w_port__NPU_Control_Matrix_0__ds0_awaddr ;
    wire [32:0]       w_port__NPU_Control_Converter_0__us_axi_awaddr ;
    wire [32:0]       w_net__NPU_Control_Matrix_0__ds0_awaddr ; 

    wire [1:0]        w_port__NPU_Control_Matrix_0__ds0_awburst ;
    wire [1:0]        w_port__NPU_Control_Converter_0__us_axi_awburst ;
    wire [1:0]        w_net__NPU_Control_Matrix_0__ds0_awburst ; 

    wire [3:0]        w_port__NPU_Control_Matrix_0__ds0_awcache ;
    wire [3:0]        w_port__NPU_Control_Converter_0__us_axi_awcache ;
    wire [3:0]        w_net__NPU_Control_Matrix_0__ds0_awcache ; 

    wire [12:0]       w_port__NPU_Control_Matrix_0__ds0_awid ;
    wire [12:0]       w_port__NPU_Control_Converter_0__us_axi_awid ;
    wire [12:0]       w_net__NPU_Control_Matrix_0__ds0_awid ; 

    wire [7:0]        w_port__NPU_Control_Matrix_0__ds0_awlen ;
    wire [7:0]        w_port__NPU_Control_Converter_0__us_axi_awlen ;
    wire [7:0]        w_net__NPU_Control_Matrix_0__ds0_awlen ; 

    wire [0:0]        w_port__NPU_Control_Matrix_0__ds0_awlock ;
    wire [0:0]        w_port__NPU_Control_Converter_0__us_axi_awlock ;
    wire [0:0]        w_net__NPU_Control_Matrix_0__ds0_awlock ; 

    wire [2:0]        w_port__NPU_Control_Matrix_0__ds0_awprot ;
    wire [2:0]        w_port__NPU_Control_Converter_0__us_axi_awprot ;
    wire [2:0]        w_net__NPU_Control_Matrix_0__ds0_awprot ; 

    wire [3:0]        w_port__NPU_Control_Matrix_0__ds0_awqos ;
    wire [3:0]        w_port__NPU_Control_Converter_0__us_axi_awqos ;
    wire [3:0]        w_net__NPU_Control_Matrix_0__ds0_awqos ; 

    wire [2:0]        w_port__NPU_Control_Matrix_0__ds0_awsize ;
    wire [2:0]        w_port__NPU_Control_Converter_0__us_axi_awsize ;
    wire [2:0]        w_net__NPU_Control_Matrix_0__ds0_awsize ; 

    wire              w_port__NPU_Control_Matrix_0__ds0_awvalid ;
    wire              w_port__NPU_Control_Converter_0__us_axi_awvalid ;
    wire              w_net__NPU_Control_Matrix_0__ds0_awvalid ; 

    wire              w_port__NPU_Control_Matrix_0__ds0_bready ;
    wire              w_port__NPU_Control_Converter_0__us_axi_bready ;
    wire              w_net__NPU_Control_Matrix_0__ds0_bready ; 

    wire              w_port__NPU_Control_Matrix_0__ds0_rready ;
    wire              w_port__NPU_Control_Converter_0__us_axi_rready ;
    wire              w_net__NPU_Control_Matrix_0__ds0_rready ; 

    wire [31:0]       w_port__NPU_Control_Matrix_0__ds0_wdata ;
    wire [31:0]       w_port__NPU_Control_Converter_0__us_axi_wdata ;
    wire [31:0]       w_net__NPU_Control_Matrix_0__ds0_wdata ; 

    wire              w_port__NPU_Control_Matrix_0__ds0_wlast ;
    wire              w_port__NPU_Control_Converter_0__us_axi_wlast ;
    wire              w_net__NPU_Control_Matrix_0__ds0_wlast ; 

    wire [3:0]        w_port__NPU_Control_Matrix_0__ds0_wstrb ;
    wire [3:0]        w_port__NPU_Control_Converter_0__us_axi_wstrb ;
    wire [3:0]        w_net__NPU_Control_Matrix_0__ds0_wstrb ; 

    wire              w_port__NPU_Control_Matrix_0__ds0_wvalid ;
    wire              w_port__NPU_Control_Converter_0__us_axi_wvalid ;
    wire              w_net__NPU_Control_Matrix_0__ds0_wvalid ; 

    wire              w_port__NPU_Control_Matrix_0__us0_arready ;
    wire              w_port__ARM_Processor_System_0__master_gp1_axi_arready ;
    wire              w_net__NPU_Control_Matrix_0__us0_arready ; 

    wire              w_port__NPU_Control_Matrix_0__us0_awready ;
    wire              w_port__ARM_Processor_System_0__master_gp1_axi_awready ;
    wire              w_net__NPU_Control_Matrix_0__us0_awready ; 

    wire [11:0]       w_port__NPU_Control_Matrix_0__us0_bid ;
    wire [11:0]       w_port__ARM_Processor_System_0__master_gp1_axi_bid ;
    wire [11:0]       w_net__NPU_Control_Matrix_0__us0_bid ; 

    wire [1:0]        w_port__NPU_Control_Matrix_0__us0_bresp ;
    wire [1:0]        w_port__ARM_Processor_System_0__master_gp1_axi_bresp ;
    wire [1:0]        w_net__NPU_Control_Matrix_0__us0_bresp ; 

    wire              w_port__NPU_Control_Matrix_0__us0_bvalid ;
    wire              w_port__ARM_Processor_System_0__master_gp1_axi_bvalid ;
    wire              w_net__NPU_Control_Matrix_0__us0_bvalid ; 

    wire [31:0]       w_port__NPU_Control_Matrix_0__us0_rdata ;
    wire [31:0]       w_port__ARM_Processor_System_0__master_gp1_axi_rdata ;
    wire [31:0]       w_net__NPU_Control_Matrix_0__us0_rdata ; 

    wire [11:0]       w_port__NPU_Control_Matrix_0__us0_rid ;
    wire [11:0]       w_port__ARM_Processor_System_0__master_gp1_axi_rid ;
    wire [11:0]       w_net__NPU_Control_Matrix_0__us0_rid ; 

    wire              w_port__NPU_Control_Matrix_0__us0_rlast ;
    wire              w_port__ARM_Processor_System_0__master_gp1_axi_rlast ;
    wire              w_net__NPU_Control_Matrix_0__us0_rlast ; 

    wire [1:0]        w_port__NPU_Control_Matrix_0__us0_rresp ;
    wire [1:0]        w_port__ARM_Processor_System_0__master_gp1_axi_rresp ;
    wire [1:0]        w_net__NPU_Control_Matrix_0__us0_rresp ; 

    wire              w_port__NPU_Control_Matrix_0__us0_rvalid ;
    wire              w_port__ARM_Processor_System_0__master_gp1_axi_rvalid ;
    wire              w_net__NPU_Control_Matrix_0__us0_rvalid ; 

    wire              w_port__NPU_Control_Matrix_0__us0_wready ;
    wire              w_port__ARM_Processor_System_0__master_gp1_axi_wready ;
    wire              w_net__NPU_Control_Matrix_0__us0_wready ; 

    wire [32:0]       w_port__NPU_HP1_Adapter_0__m_axi_araddr ;
    wire [32:0]       w_port__HP1_AXI_Matrix_0__us1_araddr ;
    wire [32:0]       w_net__NPU_HP1_Adapter_0__m_axi_araddr ; 

    wire [1:0]        w_port__NPU_HP1_Adapter_0__m_axi_arburst ;
    wire [1:0]        w_port__HP1_AXI_Matrix_0__us1_arburst ;
    wire [1:0]        w_net__NPU_HP1_Adapter_0__m_axi_arburst ; 

    wire [3:0]        w_port__NPU_HP1_Adapter_0__m_axi_arcache ;
    wire [3:0]        w_port__HP1_AXI_Matrix_0__us1_arcache ;
    wire [3:0]        w_net__NPU_HP1_Adapter_0__m_axi_arcache ; 

    wire [4:0]        w_port__NPU_HP1_Adapter_0__m_axi_arid ;
    wire [4:0]        w_port__HP1_AXI_Matrix_0__us1_arid ;
    wire [4:0]        w_net__NPU_HP1_Adapter_0__m_axi_arid ; 

    wire [7:0]        w_port__NPU_HP1_Adapter_0__m_axi_arlen ;
    wire [7:0]        w_port__HP1_AXI_Matrix_0__us1_arlen ;
    wire [7:0]        w_net__NPU_HP1_Adapter_0__m_axi_arlen ; 

    wire              w_port__NPU_HP1_Adapter_0__m_axi_arlock ;
    wire [0:0]        w_port__HP1_AXI_Matrix_0__us1_arlock ;
    wire              w_net__NPU_HP1_Adapter_0__m_axi_arlock ; 

    wire [2:0]        w_port__NPU_HP1_Adapter_0__m_axi_arprot ;
    wire [2:0]        w_port__HP1_AXI_Matrix_0__us1_arprot ;
    wire [2:0]        w_net__NPU_HP1_Adapter_0__m_axi_arprot ; 

    wire [3:0]        w_port__NPU_HP1_Adapter_0__m_axi_arqos ;
    wire [3:0]        w_port__HP1_AXI_Matrix_0__us1_arqos ;
    wire [3:0]        w_net__NPU_HP1_Adapter_0__m_axi_arqos ; 

    wire [2:0]        w_port__NPU_HP1_Adapter_0__m_axi_arsize ;
    wire [2:0]        w_port__HP1_AXI_Matrix_0__us1_arsize ;
    wire [2:0]        w_net__NPU_HP1_Adapter_0__m_axi_arsize ; 

    wire              w_port__NPU_HP1_Adapter_0__m_axi_arvalid ;
    wire              w_port__HP1_AXI_Matrix_0__us1_arvalid ;
    wire              w_net__NPU_HP1_Adapter_0__m_axi_arvalid ; 

    wire [32:0]       w_port__NPU_HP1_Adapter_0__m_axi_awaddr ;
    wire [32:0]       w_port__HP1_AXI_Matrix_0__us1_awaddr ;
    wire [32:0]       w_net__NPU_HP1_Adapter_0__m_axi_awaddr ; 

    wire [1:0]        w_port__NPU_HP1_Adapter_0__m_axi_awburst ;
    wire [1:0]        w_port__HP1_AXI_Matrix_0__us1_awburst ;
    wire [1:0]        w_net__NPU_HP1_Adapter_0__m_axi_awburst ; 

    wire [3:0]        w_port__NPU_HP1_Adapter_0__m_axi_awcache ;
    wire [3:0]        w_port__HP1_AXI_Matrix_0__us1_awcache ;
    wire [3:0]        w_net__NPU_HP1_Adapter_0__m_axi_awcache ; 

    wire [4:0]        w_port__NPU_HP1_Adapter_0__m_axi_awid ;
    wire [4:0]        w_port__HP1_AXI_Matrix_0__us1_awid ;
    wire [4:0]        w_net__NPU_HP1_Adapter_0__m_axi_awid ; 

    wire [7:0]        w_port__NPU_HP1_Adapter_0__m_axi_awlen ;
    wire [7:0]        w_port__HP1_AXI_Matrix_0__us1_awlen ;
    wire [7:0]        w_net__NPU_HP1_Adapter_0__m_axi_awlen ; 

    wire              w_port__NPU_HP1_Adapter_0__m_axi_awlock ;
    wire [0:0]        w_port__HP1_AXI_Matrix_0__us1_awlock ;
    wire              w_net__NPU_HP1_Adapter_0__m_axi_awlock ; 

    wire [2:0]        w_port__NPU_HP1_Adapter_0__m_axi_awprot ;
    wire [2:0]        w_port__HP1_AXI_Matrix_0__us1_awprot ;
    wire [2:0]        w_net__NPU_HP1_Adapter_0__m_axi_awprot ; 

    wire [3:0]        w_port__NPU_HP1_Adapter_0__m_axi_awqos ;
    wire [3:0]        w_port__HP1_AXI_Matrix_0__us1_awqos ;
    wire [3:0]        w_net__NPU_HP1_Adapter_0__m_axi_awqos ; 

    wire [2:0]        w_port__NPU_HP1_Adapter_0__m_axi_awsize ;
    wire [2:0]        w_port__HP1_AXI_Matrix_0__us1_awsize ;
    wire [2:0]        w_net__NPU_HP1_Adapter_0__m_axi_awsize ; 

    wire              w_port__NPU_HP1_Adapter_0__m_axi_awvalid ;
    wire              w_port__HP1_AXI_Matrix_0__us1_awvalid ;
    wire              w_net__NPU_HP1_Adapter_0__m_axi_awvalid ; 

    wire              w_port__NPU_HP1_Adapter_0__m_axi_bready ;
    wire              w_port__HP1_AXI_Matrix_0__us1_bready ;
    wire              w_net__NPU_HP1_Adapter_0__m_axi_bready ; 

    wire              w_port__NPU_HP1_Adapter_0__m_axi_rready ;
    wire              w_port__HP1_AXI_Matrix_0__us1_rready ;
    wire              w_net__NPU_HP1_Adapter_0__m_axi_rready ; 

    wire [63:0]       w_port__NPU_HP1_Adapter_0__m_axi_wdata ;
    wire [63:0]       w_port__HP1_AXI_Matrix_0__us1_wdata ;
    wire [63:0]       w_net__NPU_HP1_Adapter_0__m_axi_wdata ; 

    wire              w_port__NPU_HP1_Adapter_0__m_axi_wlast ;
    wire              w_port__HP1_AXI_Matrix_0__us1_wlast ;
    wire              w_net__NPU_HP1_Adapter_0__m_axi_wlast ; 

    wire [7:0]        w_port__NPU_HP1_Adapter_0__m_axi_wstrb ;
    wire [7:0]        w_port__HP1_AXI_Matrix_0__us1_wstrb ;
    wire [7:0]        w_net__NPU_HP1_Adapter_0__m_axi_wstrb ; 

    wire              w_port__NPU_HP1_Adapter_0__m_axi_wvalid ;
    wire              w_port__HP1_AXI_Matrix_0__us1_wvalid ;
    wire              w_net__NPU_HP1_Adapter_0__m_axi_wvalid ; 

    wire              w_port__NPU_HP1_Adapter_0__s_axi_arready ;
    wire              w_port__Video_NPU_0__m_axi_arready_soft_i ;
    wire              w_net__NPU_HP1_Adapter_0__s_axi_arready ; 

    wire              w_port__NPU_HP1_Adapter_0__s_axi_awready ;
    wire              w_port__Video_NPU_0__m_axi_awready_soft_i ;
    wire              w_net__NPU_HP1_Adapter_0__s_axi_awready ; 

    wire [5:0]        w_port__NPU_HP1_Adapter_0__s_axi_bid ;
    wire [5:0]        w_port__Video_NPU_0__m_axi_bid_soft_i ;
    wire [5:0]        w_net__NPU_HP1_Adapter_0__s_axi_bid ; 

    wire [1:0]        w_port__NPU_HP1_Adapter_0__s_axi_bresp ;
    wire [1:0]        w_port__Video_NPU_0__m_axi_bresp_soft_i ;
    wire [1:0]        w_net__NPU_HP1_Adapter_0__s_axi_bresp ; 

    wire              w_port__NPU_HP1_Adapter_0__s_axi_bvalid ;
    wire              w_port__Video_NPU_0__m_axi_bvalid_soft_i ;
    wire              w_net__NPU_HP1_Adapter_0__s_axi_bvalid ; 

    wire [63:0]       w_port__NPU_HP1_Adapter_0__s_axi_rdata ;
    wire [63:0]       w_port__Video_NPU_0__m_axi_rdata_soft_i ;
    wire [63:0]       w_net__NPU_HP1_Adapter_0__s_axi_rdata ; 

    wire [5:0]        w_port__NPU_HP1_Adapter_0__s_axi_rid ;
    wire [5:0]        w_port__Video_NPU_0__m_axi_rid_soft_i ;
    wire [5:0]        w_net__NPU_HP1_Adapter_0__s_axi_rid ; 

    wire              w_port__NPU_HP1_Adapter_0__s_axi_rlast ;
    wire              w_port__Video_NPU_0__m_axi_rlast_soft_i ;
    wire              w_net__NPU_HP1_Adapter_0__s_axi_rlast ; 

    wire [1:0]        w_port__NPU_HP1_Adapter_0__s_axi_rresp ;
    wire [1:0]        w_port__Video_NPU_0__m_axi_rresp_soft_i ;
    wire [1:0]        w_net__NPU_HP1_Adapter_0__s_axi_rresp ; 

    wire              w_port__NPU_HP1_Adapter_0__s_axi_rvalid ;
    wire              w_port__Video_NPU_0__m_axi_rvalid_soft_i ;
    wire              w_net__NPU_HP1_Adapter_0__s_axi_rvalid ; 

    wire              w_port__NPU_HP1_Adapter_0__s_axi_wready ;
    wire              w_port__Video_NPU_0__m_axi_wready_soft_i ;
    wire              w_net__NPU_HP1_Adapter_0__s_axi_wready ; 

    wire [0:0]        w_port__Processor_System_Reset_0__interconnect_aresetn ;
    wire              w_port__AXI_Protocol_Converter_0__aresetn ;
    wire [0:0]        w_net__Processor_System_Reset_0__interconnect_aresetn ; 

    wire [0:0]        w_port__Processor_System_Reset_0__peripheral_aresetn ;
    wire              w_port__adc_axis_source_0__rst_n ;
    wire              w_port__axi4lite_slave_0__rst_n ;
    wire              w_port__AXI_Lite_Matrix_0__aresetn ;
    wire              w_port__adc_fdma_writer_0__axi_resetn ;
    wire              w_port__HP1_AXI_Matrix_0__aresetn ;
    wire              w_port__HP1_Protocol_Converter_0__aresetn ;
    wire              w_port__HDMI_VTG_0__arst_n ;
    wire              w_port__HDMI_Reset_0__axi_reset_n ;
    wire              w_port__Video_NPU_0__S_AXILite_AResetn ;
    wire              w_port__Video_NPU_0__M_AXI_AResetn ;
    wire              w_port__NPU_HP1_Adapter_0__aresetn ;
    wire              w_port__NPU_Control_Matrix_0__aresetn ;
    wire              w_port__NPU_Control_Converter_0__aresetn ;
    wire [0:0]        w_net__Processor_System_Reset_0__peripheral_aresetn ; 

    wire              w_port__VDMA_0__axi_lite_arready ;
    wire              w_port__AXI_Lite_Matrix_0__ds3_arready ;
    wire              w_net__VDMA_0__axi_lite_arready ; 

    wire              w_port__VDMA_0__axi_lite_awready ;
    wire              w_port__AXI_Lite_Matrix_0__ds3_awready ;
    wire              w_net__VDMA_0__axi_lite_awready ; 

    wire [1:0]        w_port__VDMA_0__axi_lite_bresp ;
    wire [1:0]        w_port__AXI_Lite_Matrix_0__ds3_bresp ;
    wire [1:0]        w_net__VDMA_0__axi_lite_bresp ; 

    wire              w_port__VDMA_0__axi_lite_bvalid ;
    wire              w_port__AXI_Lite_Matrix_0__ds3_bvalid ;
    wire              w_net__VDMA_0__axi_lite_bvalid ; 

    wire [31:0]       w_port__VDMA_0__axi_lite_rdata ;
    wire [31:0]       w_port__AXI_Lite_Matrix_0__ds3_rdata ;
    wire [31:0]       w_net__VDMA_0__axi_lite_rdata ; 

    wire [1:0]        w_port__VDMA_0__axi_lite_rresp ;
    wire [1:0]        w_port__AXI_Lite_Matrix_0__ds3_rresp ;
    wire [1:0]        w_net__VDMA_0__axi_lite_rresp ; 

    wire              w_port__VDMA_0__axi_lite_rvalid ;
    wire              w_port__AXI_Lite_Matrix_0__ds3_rvalid ;
    wire              w_net__VDMA_0__axi_lite_rvalid ; 

    wire              w_port__VDMA_0__axi_lite_wready ;
    wire              w_port__AXI_Lite_Matrix_0__ds3_wready ;
    wire              w_net__VDMA_0__axi_lite_wready ; 

    wire [31:0]       w_port__VDMA_0__m_axi_mm2s_araddr ;
    wire [32:0]       w_port__HDMI_HP0_Protocol_Converter_0__us_axi_araddr ;
    wire [31:0]       w_net__VDMA_0__m_axi_mm2s_araddr ; 

    wire [1:0]        w_port__VDMA_0__m_axi_mm2s_arburst ;
    wire [1:0]        w_port__HDMI_HP0_Protocol_Converter_0__us_axi_arburst ;
    wire [1:0]        w_net__VDMA_0__m_axi_mm2s_arburst ; 

    wire [3:0]        w_port__VDMA_0__m_axi_mm2s_arcache ;
    wire [3:0]        w_port__HDMI_HP0_Protocol_Converter_0__us_axi_arcache ;
    wire [3:0]        w_net__VDMA_0__m_axi_mm2s_arcache ; 

    wire [7:0]        w_port__VDMA_0__m_axi_mm2s_arlen ;
    wire [7:0]        w_port__HDMI_HP0_Protocol_Converter_0__us_axi_arlen ;
    wire [7:0]        w_net__VDMA_0__m_axi_mm2s_arlen ; 

    wire [2:0]        w_port__VDMA_0__m_axi_mm2s_arprot ;
    wire [2:0]        w_port__HDMI_HP0_Protocol_Converter_0__us_axi_arprot ;
    wire [2:0]        w_net__VDMA_0__m_axi_mm2s_arprot ; 

    wire [2:0]        w_port__VDMA_0__m_axi_mm2s_arsize ;
    wire [2:0]        w_port__HDMI_HP0_Protocol_Converter_0__us_axi_arsize ;
    wire [2:0]        w_net__VDMA_0__m_axi_mm2s_arsize ; 

    wire              w_port__VDMA_0__m_axi_mm2s_arvalid ;
    wire              w_port__HDMI_HP0_Protocol_Converter_0__us_axi_arvalid ;
    wire              w_net__VDMA_0__m_axi_mm2s_arvalid ; 

    wire              w_port__VDMA_0__m_axi_mm2s_rready ;
    wire              w_port__HDMI_HP0_Protocol_Converter_0__us_axi_rready ;
    wire              w_net__VDMA_0__m_axi_mm2s_rready ; 

    wire [23:0]       w_port__VDMA_0__m_axis_mm2s_tdata ;
    wire [23:0]       w_port__AXI4_Stream_to_Video_Out_0__s_axis_video_tdata ;
    wire [23:0]       w_net__VDMA_0__m_axis_mm2s_tdata ; 

    wire              w_port__VDMA_0__m_axis_mm2s_tlast ;
    wire              w_port__AXI4_Stream_to_Video_Out_0__s_axis_video_tlast ;
    wire              w_net__VDMA_0__m_axis_mm2s_tlast ; 

    wire [0:0]        w_port__VDMA_0__m_axis_mm2s_tuser ;
    wire              w_port__AXI4_Stream_to_Video_Out_0__s_axis_video_tuser ;
    wire [0:0]        w_net__VDMA_0__m_axis_mm2s_tuser ; 

    wire              w_port__VDMA_0__m_axis_mm2s_tvalid ;
    wire              w_port__AXI4_Stream_to_Video_Out_0__s_axis_video_tvalid ;
    wire              w_net__VDMA_0__m_axis_mm2s_tvalid ; 

    wire              w_port__VDMA_0__mm2s_introut ;
    wire [0:0]        w_port__HDMI_IRQ_Concat_0__In0 ;
    wire              w_net__VDMA_0__mm2s_introut ; 

    wire              w_port__VDMA_0__s2mm_introut ;
    wire [0:0]        w_port__HDMI_IRQ_Concat_0__In1 ;
    wire              w_net__VDMA_0__s2mm_introut ; 

    wire [32:0]       w_port__Video_NPU_0__m_axi_araddr_soft_o ;
    wire [32:0]       w_port__NPU_HP1_Adapter_0__s_axi_araddr ;
    wire [32:0]       w_net__Video_NPU_0__m_axi_araddr_soft_o ; 

    wire [1:0]        w_port__Video_NPU_0__m_axi_arburst_soft_o ;
    wire [1:0]        w_port__NPU_HP1_Adapter_0__s_axi_arburst ;
    wire [1:0]        w_net__Video_NPU_0__m_axi_arburst_soft_o ; 

    wire [3:0]        w_port__Video_NPU_0__m_axi_arcache_soft_o ;
    wire [3:0]        w_port__NPU_HP1_Adapter_0__s_axi_arcache ;
    wire [3:0]        w_net__Video_NPU_0__m_axi_arcache_soft_o ; 

    wire [5:0]        w_port__Video_NPU_0__m_axi_arid_soft_o ;
    wire [5:0]        w_port__NPU_HP1_Adapter_0__s_axi_arid ;
    wire [5:0]        w_net__Video_NPU_0__m_axi_arid_soft_o ; 

    wire [3:0]        w_port__Video_NPU_0__m_axi_arlen_soft_o ;
    wire [3:0]        w_port__NPU_HP1_Adapter_0__s_axi_arlen ;
    wire [3:0]        w_net__Video_NPU_0__m_axi_arlen_soft_o ; 

    wire              w_port__Video_NPU_0__m_axi_arlock_soft_o ;
    wire              w_port__NPU_HP1_Adapter_0__s_axi_arlock ;
    wire              w_net__Video_NPU_0__m_axi_arlock_soft_o ; 

    wire [2:0]        w_port__Video_NPU_0__m_axi_arprot_soft_o ;
    wire [2:0]        w_port__NPU_HP1_Adapter_0__s_axi_arprot ;
    wire [2:0]        w_net__Video_NPU_0__m_axi_arprot_soft_o ; 

    wire [1:0]        w_port__Video_NPU_0__m_axi_arsize_soft_o ;
    wire [1:0]        w_port__NPU_HP1_Adapter_0__s_axi_arsize ;
    wire [1:0]        w_net__Video_NPU_0__m_axi_arsize_soft_o ; 

    wire              w_port__Video_NPU_0__m_axi_arvalid_soft_o ;
    wire              w_port__NPU_HP1_Adapter_0__s_axi_arvalid ;
    wire              w_net__Video_NPU_0__m_axi_arvalid_soft_o ; 

    wire [32:0]       w_port__Video_NPU_0__m_axi_awaddr_soft_o ;
    wire [32:0]       w_port__NPU_HP1_Adapter_0__s_axi_awaddr ;
    wire [32:0]       w_net__Video_NPU_0__m_axi_awaddr_soft_o ; 

    wire [1:0]        w_port__Video_NPU_0__m_axi_awburst_soft_o ;
    wire [1:0]        w_port__NPU_HP1_Adapter_0__s_axi_awburst ;
    wire [1:0]        w_net__Video_NPU_0__m_axi_awburst_soft_o ; 

    wire [3:0]        w_port__Video_NPU_0__m_axi_awcache_soft_o ;
    wire [3:0]        w_port__NPU_HP1_Adapter_0__s_axi_awcache ;
    wire [3:0]        w_net__Video_NPU_0__m_axi_awcache_soft_o ; 

    wire [5:0]        w_port__Video_NPU_0__m_axi_awid_soft_o ;
    wire [5:0]        w_port__NPU_HP1_Adapter_0__s_axi_awid ;
    wire [5:0]        w_net__Video_NPU_0__m_axi_awid_soft_o ; 

    wire [3:0]        w_port__Video_NPU_0__m_axi_awlen_soft_o ;
    wire [3:0]        w_port__NPU_HP1_Adapter_0__s_axi_awlen ;
    wire [3:0]        w_net__Video_NPU_0__m_axi_awlen_soft_o ; 

    wire              w_port__Video_NPU_0__m_axi_awlock_soft_o ;
    wire              w_port__NPU_HP1_Adapter_0__s_axi_awlock ;
    wire              w_net__Video_NPU_0__m_axi_awlock_soft_o ; 

    wire [2:0]        w_port__Video_NPU_0__m_axi_awprot_soft_o ;
    wire [2:0]        w_port__NPU_HP1_Adapter_0__s_axi_awprot ;
    wire [2:0]        w_net__Video_NPU_0__m_axi_awprot_soft_o ; 

    wire [1:0]        w_port__Video_NPU_0__m_axi_awsize_soft_o ;
    wire [1:0]        w_port__NPU_HP1_Adapter_0__s_axi_awsize ;
    wire [1:0]        w_net__Video_NPU_0__m_axi_awsize_soft_o ; 

    wire              w_port__Video_NPU_0__m_axi_awvalid_soft_o ;
    wire              w_port__NPU_HP1_Adapter_0__s_axi_awvalid ;
    wire              w_net__Video_NPU_0__m_axi_awvalid_soft_o ; 

    wire              w_port__Video_NPU_0__m_axi_bready_soft_o ;
    wire              w_port__NPU_HP1_Adapter_0__s_axi_bready ;
    wire              w_net__Video_NPU_0__m_axi_bready_soft_o ; 

    wire              w_port__Video_NPU_0__m_axi_rready_soft_o ;
    wire              w_port__NPU_HP1_Adapter_0__s_axi_rready ;
    wire              w_net__Video_NPU_0__m_axi_rready_soft_o ; 

    wire [63:0]       w_port__Video_NPU_0__m_axi_wdata_soft_o ;
    wire [63:0]       w_port__NPU_HP1_Adapter_0__s_axi_wdata ;
    wire [63:0]       w_net__Video_NPU_0__m_axi_wdata_soft_o ; 

    wire              w_port__Video_NPU_0__m_axi_wlast_soft_o ;
    wire              w_port__NPU_HP1_Adapter_0__s_axi_wlast ;
    wire              w_net__Video_NPU_0__m_axi_wlast_soft_o ; 

    wire [7:0]        w_port__Video_NPU_0__m_axi_wstrb_soft_o ;
    wire [7:0]        w_port__NPU_HP1_Adapter_0__s_axi_wstrb ;
    wire [7:0]        w_net__Video_NPU_0__m_axi_wstrb_soft_o ; 

    wire              w_port__Video_NPU_0__m_axi_wvalid_soft_o ;
    wire              w_port__NPU_HP1_Adapter_0__s_axi_wvalid ;
    wire              w_net__Video_NPU_0__m_axi_wvalid_soft_o ; 

    wire              w_port__Video_NPU_0__npu_soft_intr ;
    wire [0:0]        w_port__HDMI_IRQ_Concat_0__In15 ;
    wire              w_net__Video_NPU_0__npu_soft_intr ; 

    wire              w_port__Video_NPU_0__s_axilite_arready_o ;
    wire              w_port__NPU_Control_Converter_0__ds_axi_arready ;
    wire              w_net__Video_NPU_0__s_axilite_arready_o ; 

    wire              w_port__Video_NPU_0__s_axilite_awready_o ;
    wire              w_port__NPU_Control_Converter_0__ds_axi_awready ;
    wire              w_net__Video_NPU_0__s_axilite_awready_o ; 

    wire [1:0]        w_port__Video_NPU_0__s_axilite_bresp_o ;
    wire [1:0]        w_port__NPU_Control_Converter_0__ds_axi_bresp ;
    wire [1:0]        w_net__Video_NPU_0__s_axilite_bresp_o ; 

    wire              w_port__Video_NPU_0__s_axilite_bvalid_o ;
    wire              w_port__NPU_Control_Converter_0__ds_axi_bvalid ;
    wire              w_net__Video_NPU_0__s_axilite_bvalid_o ; 

    wire [31:0]       w_port__Video_NPU_0__s_axilite_rdata_o ;
    wire [31:0]       w_port__NPU_Control_Converter_0__ds_axi_rdata ;
    wire [31:0]       w_net__Video_NPU_0__s_axilite_rdata_o ; 

    wire [1:0]        w_port__Video_NPU_0__s_axilite_rresp_o ;
    wire [1:0]        w_port__NPU_Control_Converter_0__ds_axi_rresp ;
    wire [1:0]        w_net__Video_NPU_0__s_axilite_rresp_o ; 

    wire              w_port__Video_NPU_0__s_axilite_rvalid_o ;
    wire              w_port__NPU_Control_Converter_0__ds_axi_rvalid ;
    wire              w_net__Video_NPU_0__s_axilite_rvalid_o ; 

    wire              w_port__Video_NPU_0__s_axilite_wready_o ;
    wire              w_port__NPU_Control_Converter_0__ds_axi_wready ;
    wire              w_net__Video_NPU_0__s_axilite_wready_o ; 

    wire [31:0]       w_port__adc_axis_source_0__drop_count ;
    wire [31:0]       w_port__axi4lite_slave_0__fifo_drop_count_in ;
    wire [31:0]       w_net__adc_axis_source_0__drop_count ; 

    wire [31:0]       w_port__adc_axis_source_0__fifo_level ;
    wire [31:0]       w_port__axi4lite_slave_0__fifo_level_in ;
    wire [31:0]       w_net__adc_axis_source_0__fifo_level ; 

    wire              w_port__adc_axis_source_0__fifo_reset_n ;
    wire              w_port__axi4lite_slave_0__fifo_ready_in ;
    wire              w_port__AXIS_Data_FIFO_0__us_aresetn ;
    wire              w_net__adc_axis_source_0__fifo_reset_n ; 

    wire [31:0]       w_port__adc_axis_source_0__m_axis_tdata ;
    wire [31:0]       w_port__AXIS_Data_FIFO_0__us_tdata ;
    wire [31:0]       w_net__adc_axis_source_0__m_axis_tdata ; 

    wire [3:0]        w_port__adc_axis_source_0__m_axis_tkeep ;
    wire [3:0]        w_port__AXIS_Data_FIFO_0__us_tkeep ;
    wire [3:0]        w_net__adc_axis_source_0__m_axis_tkeep ; 

    wire              w_port__adc_axis_source_0__m_axis_tlast ;
    wire              w_port__AXIS_Data_FIFO_0__us_tlast ;
    wire              w_net__adc_axis_source_0__m_axis_tlast ; 

    wire              w_port__adc_axis_source_0__m_axis_tvalid ;
    wire              w_port__AXIS_Data_FIFO_0__us_tvalid ;
    wire              w_net__adc_axis_source_0__m_axis_tvalid ; 

    wire [32:0]       w_port__adc_fdma_writer_0__m_axi_s2mm_awaddr ;
    wire [32:0]       w_port__HP1_AXI_Matrix_0__us0_awaddr ;
    wire [32:0]       w_net__adc_fdma_writer_0__m_axi_s2mm_awaddr ; 

    wire [1:0]        w_port__adc_fdma_writer_0__m_axi_s2mm_awburst ;
    wire [1:0]        w_port__HP1_AXI_Matrix_0__us0_awburst ;
    wire [1:0]        w_net__adc_fdma_writer_0__m_axi_s2mm_awburst ; 

    wire [3:0]        w_port__adc_fdma_writer_0__m_axi_s2mm_awcache ;
    wire [3:0]        w_port__HP1_AXI_Matrix_0__us0_awcache ;
    wire [3:0]        w_net__adc_fdma_writer_0__m_axi_s2mm_awcache ; 

    wire [4:0]        w_port__adc_fdma_writer_0__m_axi_s2mm_awid ;
    wire [4:0]        w_port__HP1_AXI_Matrix_0__us0_awid ;
    wire [4:0]        w_net__adc_fdma_writer_0__m_axi_s2mm_awid ; 

    wire [7:0]        w_port__adc_fdma_writer_0__m_axi_s2mm_awlen ;
    wire [7:0]        w_port__HP1_AXI_Matrix_0__us0_awlen ;
    wire [7:0]        w_net__adc_fdma_writer_0__m_axi_s2mm_awlen ; 

    wire              w_port__adc_fdma_writer_0__m_axi_s2mm_awlock ;
    wire [0:0]        w_port__HP1_AXI_Matrix_0__us0_awlock ;
    wire              w_net__adc_fdma_writer_0__m_axi_s2mm_awlock ; 

    wire [2:0]        w_port__adc_fdma_writer_0__m_axi_s2mm_awprot ;
    wire [2:0]        w_port__HP1_AXI_Matrix_0__us0_awprot ;
    wire [2:0]        w_net__adc_fdma_writer_0__m_axi_s2mm_awprot ; 

    wire [3:0]        w_port__adc_fdma_writer_0__m_axi_s2mm_awqos ;
    wire [3:0]        w_port__HP1_AXI_Matrix_0__us0_awqos ;
    wire [3:0]        w_net__adc_fdma_writer_0__m_axi_s2mm_awqos ; 

    wire [2:0]        w_port__adc_fdma_writer_0__m_axi_s2mm_awsize ;
    wire [2:0]        w_port__HP1_AXI_Matrix_0__us0_awsize ;
    wire [2:0]        w_net__adc_fdma_writer_0__m_axi_s2mm_awsize ; 

    wire              w_port__adc_fdma_writer_0__m_axi_s2mm_awvalid ;
    wire              w_port__HP1_AXI_Matrix_0__us0_awvalid ;
    wire              w_net__adc_fdma_writer_0__m_axi_s2mm_awvalid ; 

    wire              w_port__adc_fdma_writer_0__m_axi_s2mm_bready ;
    wire              w_port__HP1_AXI_Matrix_0__us0_bready ;
    wire              w_net__adc_fdma_writer_0__m_axi_s2mm_bready ; 

    wire [63:0]       w_port__adc_fdma_writer_0__m_axi_s2mm_wdata ;
    wire [63:0]       w_port__HP1_AXI_Matrix_0__us0_wdata ;
    wire [63:0]       w_net__adc_fdma_writer_0__m_axi_s2mm_wdata ; 

    wire              w_port__adc_fdma_writer_0__m_axi_s2mm_wlast ;
    wire              w_port__HP1_AXI_Matrix_0__us0_wlast ;
    wire              w_net__adc_fdma_writer_0__m_axi_s2mm_wlast ; 

    wire [7:0]        w_port__adc_fdma_writer_0__m_axi_s2mm_wstrb ;
    wire [7:0]        w_port__HP1_AXI_Matrix_0__us0_wstrb ;
    wire [7:0]        w_net__adc_fdma_writer_0__m_axi_s2mm_wstrb ; 

    wire              w_port__adc_fdma_writer_0__m_axi_s2mm_wvalid ;
    wire              w_port__HP1_AXI_Matrix_0__us0_wvalid ;
    wire              w_net__adc_fdma_writer_0__m_axi_s2mm_wvalid ; 

    wire              w_port__adc_fdma_writer_0__s_axi_lite_arready ;
    wire              w_port__AXI_Lite_Matrix_0__ds1_arready ;
    wire              w_net__adc_fdma_writer_0__s_axi_lite_arready ; 

    wire              w_port__adc_fdma_writer_0__s_axi_lite_awready ;
    wire              w_port__AXI_Lite_Matrix_0__ds1_awready ;
    wire              w_net__adc_fdma_writer_0__s_axi_lite_awready ; 

    wire [1:0]        w_port__adc_fdma_writer_0__s_axi_lite_bresp ;
    wire [1:0]        w_port__AXI_Lite_Matrix_0__ds1_bresp ;
    wire [1:0]        w_net__adc_fdma_writer_0__s_axi_lite_bresp ; 

    wire              w_port__adc_fdma_writer_0__s_axi_lite_bvalid ;
    wire              w_port__AXI_Lite_Matrix_0__ds1_bvalid ;
    wire              w_net__adc_fdma_writer_0__s_axi_lite_bvalid ; 

    wire [31:0]       w_port__adc_fdma_writer_0__s_axi_lite_rdata ;
    wire [31:0]       w_port__AXI_Lite_Matrix_0__ds1_rdata ;
    wire [31:0]       w_net__adc_fdma_writer_0__s_axi_lite_rdata ; 

    wire [1:0]        w_port__adc_fdma_writer_0__s_axi_lite_rresp ;
    wire [1:0]        w_port__AXI_Lite_Matrix_0__ds1_rresp ;
    wire [1:0]        w_net__adc_fdma_writer_0__s_axi_lite_rresp ; 

    wire              w_port__adc_fdma_writer_0__s_axi_lite_rvalid ;
    wire              w_port__AXI_Lite_Matrix_0__ds1_rvalid ;
    wire              w_net__adc_fdma_writer_0__s_axi_lite_rvalid ; 

    wire              w_port__adc_fdma_writer_0__s_axi_lite_wready ;
    wire              w_port__AXI_Lite_Matrix_0__ds1_wready ;
    wire              w_net__adc_fdma_writer_0__s_axi_lite_wready ; 

    wire              w_port__adc_fdma_writer_0__s_axis_s2mm_tready ;
    wire              w_port__AXIS_Data_FIFO_0__ds_tready ;
    wire              w_port__adc_axis_source_0__fifo_out_tready ;
    wire              w_net__adc_fdma_writer_0__s_axis_s2mm_tready ; 

    wire              w_port__adc_axis_source_0__adc_sample_valid ;
    wire              w_port__axi4lite_slave_0__adc_sample_valid ;
    wire              w_net__adc_sample_valid ; 

    wire [31:0]       w_port__axi4lite_slave_0__adc_status_in ;
    wire [31:0]       w_net__adc_status_in ; 

    wire              w_port__axi4lite_slave_0__capture_enable ;
    wire              w_port__adc_axis_source_0__capture_enable ;
    wire              w_net__axi4lite_slave_0__capture_enable ; 

    wire              w_port__axi4lite_slave_0__fault_clear_cmd ;
    wire              w_net__axi4lite_slave_0__fault_clear_cmd ; 

    wire              w_port__axi4lite_slave_0__fifo_clear ;
    wire              w_port__adc_axis_source_0__fifo_clear ;
    wire              w_net__axi4lite_slave_0__fifo_clear ; 

    wire              w_port__axi4lite_slave_0__output_enable_cmd ;
    wire              w_net__axi4lite_slave_0__output_enable_cmd ; 

    wire              w_port__axi4lite_slave_0__s_axi_arready ;
    wire              w_port__AXI_Lite_Matrix_0__ds0_arready ;
    wire              w_net__axi4lite_slave_0__s_axi_arready ; 

    wire              w_port__axi4lite_slave_0__s_axi_awready ;
    wire              w_port__AXI_Lite_Matrix_0__ds0_awready ;
    wire              w_net__axi4lite_slave_0__s_axi_awready ; 

    wire [1:0]        w_port__axi4lite_slave_0__s_axi_bresp ;
    wire [1:0]        w_port__AXI_Lite_Matrix_0__ds0_bresp ;
    wire [1:0]        w_net__axi4lite_slave_0__s_axi_bresp ; 

    wire              w_port__axi4lite_slave_0__s_axi_bvalid ;
    wire              w_port__AXI_Lite_Matrix_0__ds0_bvalid ;
    wire              w_net__axi4lite_slave_0__s_axi_bvalid ; 

    wire [31:0]       w_port__axi4lite_slave_0__s_axi_rdata ;
    wire [31:0]       w_port__AXI_Lite_Matrix_0__ds0_rdata ;
    wire [31:0]       w_net__axi4lite_slave_0__s_axi_rdata ; 

    wire [1:0]        w_port__axi4lite_slave_0__s_axi_rresp ;
    wire [1:0]        w_port__AXI_Lite_Matrix_0__ds0_rresp ;
    wire [1:0]        w_net__axi4lite_slave_0__s_axi_rresp ; 

    wire              w_port__axi4lite_slave_0__s_axi_rvalid ;
    wire              w_port__AXI_Lite_Matrix_0__ds0_rvalid ;
    wire              w_net__axi4lite_slave_0__s_axi_rvalid ; 

    wire              w_port__axi4lite_slave_0__s_axi_wready ;
    wire              w_port__AXI_Lite_Matrix_0__ds0_wready ;
    wire              w_net__axi4lite_slave_0__s_axi_wready ; 

    wire [31:0]       w_port__axi4lite_slave_0__vref_cmd_q16 ;
    wire [31:0]       w_net__axi4lite_slave_0__vref_cmd_q16 ; 

    wire              w_port__ARM_Processor_System_0__master_gp0_axi_aclk ;
    wire              w_port__Processor_System_Reset_0__clk ;
    wire              w_port__AXI_Protocol_Converter_0__aclk ;
    wire              w_port__AXIS_Data_FIFO_0__us_aclk ;
    wire              w_port__axi4lite_slave_0__clk ;
    wire              w_port__adc_axis_source_0__clk ;
    wire              w_port__AXI_Lite_Matrix_0__aclk ;
    wire              w_port__ARM_Processor_System_0__slave_hp1_axi_aclk ;
    wire              w_port__adc_fdma_writer_0__s_axi_lite_aclk ;
    wire              w_port__HP1_AXI_Matrix_0__aclk ;
    wire              w_port__HP1_Protocol_Converter_0__aclk ;
    wire              w_port__VDMA_0__s_axi_lite_aclk ;
    wire              w_port__VDMA_0__s_axis_s2mm_aclk ;
    wire              w_port__VDMA_0__m_axi_s2mm_aclk ;
    wire              w_port__HDMI_VTG_0__aclk ;
    wire              w_port__HDMI_Reset_0__ctrl_clk ;
    wire              w_port__ARM_Processor_System_0__master_gp1_axi_aclk ;
    wire              w_port__Video_NPU_0__S_AXILite_ACLK ;
    wire              w_port__Video_NPU_0__M_AXI_ACLK ;
    wire              w_port__NPU_HP1_Adapter_0__aclk ;
    wire              w_port__NPU_Control_Matrix_0__aclk ;
    wire              w_port__NPU_Control_Converter_0__aclk ;
    wire              w_net__axi_clk ; 

    wire [31:0]       w_port__axi4lite_slave_0__control_status_in ;
    wire [31:0]       w_net__control_status_in ; 

    wire [47:0]       w_port__adc_axis_source_0__current_product_in ;
    wire [47:0]       w_net__current_product_in ; 

    wire [31:0]       w_port__adc_axis_source_0__duty_q16_in ;
    wire [31:0]       w_net__duty_q16_in ; 

    wire              w_port__Processor_System_Reset_0__aux_resetn ;
    wire              w_net__ext_reset_n ; 

    wire              w_port__Processor_System_Reset_0__pll_locked ;
    wire              w_net__pll_locked ; 

    wire              w_port__axi4lite_slave_0__protection_stop ;
    wire              w_net__protection_stop ; 

    wire [47:0]       w_port__adc_axis_source_0__voltage_product_in ;
    wire [47:0]       w_net__voltage_product_in ; 

    wire [31:0]       w_port__axi4lite_slave_0__vref_active_q16_in ;
    wire [31:0]       w_net__vref_active_q16_in ; 

    assign w_net__ARM_Processor_System_0__master_gp0_axi_araddr = w_port__ARM_Processor_System_0__master_gp0_axi_araddr ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_araddr = w_net__ARM_Processor_System_0__master_gp0_axi_araddr ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_arburst = w_port__ARM_Processor_System_0__master_gp0_axi_arburst ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_arburst = w_net__ARM_Processor_System_0__master_gp0_axi_arburst ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_arcache = w_port__ARM_Processor_System_0__master_gp0_axi_arcache ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_arcache = w_net__ARM_Processor_System_0__master_gp0_axi_arcache ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_arid = w_port__ARM_Processor_System_0__master_gp0_axi_arid ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_arid = w_net__ARM_Processor_System_0__master_gp0_axi_arid ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_arlen = w_port__ARM_Processor_System_0__master_gp0_axi_arlen ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_arlen = {4'b0,w_net__ARM_Processor_System_0__master_gp0_axi_arlen} ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_arlock = w_port__ARM_Processor_System_0__master_gp0_axi_arlock ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_arlock = w_net__ARM_Processor_System_0__master_gp0_axi_arlock ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_arprot = w_port__ARM_Processor_System_0__master_gp0_axi_arprot ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_arprot = w_net__ARM_Processor_System_0__master_gp0_axi_arprot ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_arsize = w_port__ARM_Processor_System_0__master_gp0_axi_arsize ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_arsize = {1'b0,w_net__ARM_Processor_System_0__master_gp0_axi_arsize} ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_arvalid = w_port__ARM_Processor_System_0__master_gp0_axi_arvalid ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_arvalid = w_net__ARM_Processor_System_0__master_gp0_axi_arvalid ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_awaddr = w_port__ARM_Processor_System_0__master_gp0_axi_awaddr ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_awaddr = w_net__ARM_Processor_System_0__master_gp0_axi_awaddr ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_awburst = w_port__ARM_Processor_System_0__master_gp0_axi_awburst ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_awburst = w_net__ARM_Processor_System_0__master_gp0_axi_awburst ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_awcache = w_port__ARM_Processor_System_0__master_gp0_axi_awcache ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_awcache = w_net__ARM_Processor_System_0__master_gp0_axi_awcache ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_awid = w_port__ARM_Processor_System_0__master_gp0_axi_awid ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_awid = w_net__ARM_Processor_System_0__master_gp0_axi_awid ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_awlen = w_port__ARM_Processor_System_0__master_gp0_axi_awlen ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_awlen = {4'b0,w_net__ARM_Processor_System_0__master_gp0_axi_awlen} ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_awlock = w_port__ARM_Processor_System_0__master_gp0_axi_awlock ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_awlock = w_net__ARM_Processor_System_0__master_gp0_axi_awlock ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_awprot = w_port__ARM_Processor_System_0__master_gp0_axi_awprot ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_awprot = w_net__ARM_Processor_System_0__master_gp0_axi_awprot ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_awsize = w_port__ARM_Processor_System_0__master_gp0_axi_awsize ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_awsize = {1'b0,w_net__ARM_Processor_System_0__master_gp0_axi_awsize} ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_awvalid = w_port__ARM_Processor_System_0__master_gp0_axi_awvalid ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_awvalid = w_net__ARM_Processor_System_0__master_gp0_axi_awvalid ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_bready = w_port__ARM_Processor_System_0__master_gp0_axi_bready ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_bready = w_net__ARM_Processor_System_0__master_gp0_axi_bready ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_rready = w_port__ARM_Processor_System_0__master_gp0_axi_rready ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_rready = w_net__ARM_Processor_System_0__master_gp0_axi_rready ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_wdata = w_port__ARM_Processor_System_0__master_gp0_axi_wdata ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_wdata = w_net__ARM_Processor_System_0__master_gp0_axi_wdata ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_wlast = w_port__ARM_Processor_System_0__master_gp0_axi_wlast ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_wlast = w_net__ARM_Processor_System_0__master_gp0_axi_wlast ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_wstrb = w_port__ARM_Processor_System_0__master_gp0_axi_wstrb ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_wstrb = w_net__ARM_Processor_System_0__master_gp0_axi_wstrb ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_wvalid = w_port__ARM_Processor_System_0__master_gp0_axi_wvalid ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_wvalid = w_net__ARM_Processor_System_0__master_gp0_axi_wvalid ;

    assign w_net__ARM_Processor_System_0__master_gp1_axi_araddr = w_port__ARM_Processor_System_0__master_gp1_axi_araddr ;
    assign w_port__NPU_Control_Matrix_0__us0_araddr = w_net__ARM_Processor_System_0__master_gp1_axi_araddr ;

    assign w_net__ARM_Processor_System_0__master_gp1_axi_arburst = w_port__ARM_Processor_System_0__master_gp1_axi_arburst ;
    assign w_port__NPU_Control_Matrix_0__us0_arburst = w_net__ARM_Processor_System_0__master_gp1_axi_arburst ;

    assign w_net__ARM_Processor_System_0__master_gp1_axi_arcache = w_port__ARM_Processor_System_0__master_gp1_axi_arcache ;
    assign w_port__NPU_Control_Matrix_0__us0_arcache = w_net__ARM_Processor_System_0__master_gp1_axi_arcache ;

    assign w_net__ARM_Processor_System_0__master_gp1_axi_arid = w_port__ARM_Processor_System_0__master_gp1_axi_arid ;
    assign w_port__NPU_Control_Matrix_0__us0_arid = w_net__ARM_Processor_System_0__master_gp1_axi_arid ;

    assign w_net__ARM_Processor_System_0__master_gp1_axi_arlen = w_port__ARM_Processor_System_0__master_gp1_axi_arlen ;
    assign w_port__NPU_Control_Matrix_0__us0_arlen = {4'b0,w_net__ARM_Processor_System_0__master_gp1_axi_arlen} ;

    assign w_net__ARM_Processor_System_0__master_gp1_axi_arlock = w_port__ARM_Processor_System_0__master_gp1_axi_arlock ;
    assign w_port__NPU_Control_Matrix_0__us0_arlock = w_net__ARM_Processor_System_0__master_gp1_axi_arlock ;

    assign w_net__ARM_Processor_System_0__master_gp1_axi_arprot = w_port__ARM_Processor_System_0__master_gp1_axi_arprot ;
    assign w_port__NPU_Control_Matrix_0__us0_arprot = w_net__ARM_Processor_System_0__master_gp1_axi_arprot ;

    assign w_net__ARM_Processor_System_0__master_gp1_axi_arsize = w_port__ARM_Processor_System_0__master_gp1_axi_arsize ;
    assign w_port__NPU_Control_Matrix_0__us0_arsize = {1'b0,w_net__ARM_Processor_System_0__master_gp1_axi_arsize} ;

    assign w_net__ARM_Processor_System_0__master_gp1_axi_arvalid = w_port__ARM_Processor_System_0__master_gp1_axi_arvalid ;
    assign w_port__NPU_Control_Matrix_0__us0_arvalid = w_net__ARM_Processor_System_0__master_gp1_axi_arvalid ;

    assign w_net__ARM_Processor_System_0__master_gp1_axi_awaddr = w_port__ARM_Processor_System_0__master_gp1_axi_awaddr ;
    assign w_port__NPU_Control_Matrix_0__us0_awaddr = w_net__ARM_Processor_System_0__master_gp1_axi_awaddr ;

    assign w_net__ARM_Processor_System_0__master_gp1_axi_awburst = w_port__ARM_Processor_System_0__master_gp1_axi_awburst ;
    assign w_port__NPU_Control_Matrix_0__us0_awburst = w_net__ARM_Processor_System_0__master_gp1_axi_awburst ;

    assign w_net__ARM_Processor_System_0__master_gp1_axi_awcache = w_port__ARM_Processor_System_0__master_gp1_axi_awcache ;
    assign w_port__NPU_Control_Matrix_0__us0_awcache = w_net__ARM_Processor_System_0__master_gp1_axi_awcache ;

    assign w_net__ARM_Processor_System_0__master_gp1_axi_awid = w_port__ARM_Processor_System_0__master_gp1_axi_awid ;
    assign w_port__NPU_Control_Matrix_0__us0_awid = w_net__ARM_Processor_System_0__master_gp1_axi_awid ;

    assign w_net__ARM_Processor_System_0__master_gp1_axi_awlen = w_port__ARM_Processor_System_0__master_gp1_axi_awlen ;
    assign w_port__NPU_Control_Matrix_0__us0_awlen = {4'b0,w_net__ARM_Processor_System_0__master_gp1_axi_awlen} ;

    assign w_net__ARM_Processor_System_0__master_gp1_axi_awlock = w_port__ARM_Processor_System_0__master_gp1_axi_awlock ;
    assign w_port__NPU_Control_Matrix_0__us0_awlock = w_net__ARM_Processor_System_0__master_gp1_axi_awlock ;

    assign w_net__ARM_Processor_System_0__master_gp1_axi_awprot = w_port__ARM_Processor_System_0__master_gp1_axi_awprot ;
    assign w_port__NPU_Control_Matrix_0__us0_awprot = w_net__ARM_Processor_System_0__master_gp1_axi_awprot ;

    assign w_net__ARM_Processor_System_0__master_gp1_axi_awsize = w_port__ARM_Processor_System_0__master_gp1_axi_awsize ;
    assign w_port__NPU_Control_Matrix_0__us0_awsize = {1'b0,w_net__ARM_Processor_System_0__master_gp1_axi_awsize} ;

    assign w_net__ARM_Processor_System_0__master_gp1_axi_awvalid = w_port__ARM_Processor_System_0__master_gp1_axi_awvalid ;
    assign w_port__NPU_Control_Matrix_0__us0_awvalid = w_net__ARM_Processor_System_0__master_gp1_axi_awvalid ;

    assign w_net__ARM_Processor_System_0__master_gp1_axi_bready = w_port__ARM_Processor_System_0__master_gp1_axi_bready ;
    assign w_port__NPU_Control_Matrix_0__us0_bready = w_net__ARM_Processor_System_0__master_gp1_axi_bready ;

    assign w_net__ARM_Processor_System_0__master_gp1_axi_rready = w_port__ARM_Processor_System_0__master_gp1_axi_rready ;
    assign w_port__NPU_Control_Matrix_0__us0_rready = w_net__ARM_Processor_System_0__master_gp1_axi_rready ;

    assign w_net__ARM_Processor_System_0__master_gp1_axi_wdata = w_port__ARM_Processor_System_0__master_gp1_axi_wdata ;
    assign w_port__NPU_Control_Matrix_0__us0_wdata = w_net__ARM_Processor_System_0__master_gp1_axi_wdata ;

    assign w_net__ARM_Processor_System_0__master_gp1_axi_wlast = w_port__ARM_Processor_System_0__master_gp1_axi_wlast ;
    assign w_port__NPU_Control_Matrix_0__us0_wlast = w_net__ARM_Processor_System_0__master_gp1_axi_wlast ;

    assign w_net__ARM_Processor_System_0__master_gp1_axi_wstrb = w_port__ARM_Processor_System_0__master_gp1_axi_wstrb ;
    assign w_port__NPU_Control_Matrix_0__us0_wstrb = w_net__ARM_Processor_System_0__master_gp1_axi_wstrb ;

    assign w_net__ARM_Processor_System_0__master_gp1_axi_wvalid = w_port__ARM_Processor_System_0__master_gp1_axi_wvalid ;
    assign w_port__NPU_Control_Matrix_0__us0_wvalid = w_net__ARM_Processor_System_0__master_gp1_axi_wvalid ;

    assign w_net__ARM_Processor_System_0__p2f_clk0 = w_port__ARM_Processor_System_0__p2f_clk0 ;
    assign w_port__HDMI_PLL_0__refclk = w_net__ARM_Processor_System_0__p2f_clk0 ;
    assign w_port__HDMI_VTG_0__ref_clk = w_net__ARM_Processor_System_0__p2f_clk0 ;

    assign w_net__ARM_Processor_System_0__p2f_rst0_n = w_port__ARM_Processor_System_0__p2f_rst0_n ;
    assign w_port__Processor_System_Reset_0__external_resetn = w_net__ARM_Processor_System_0__p2f_rst0_n ;

    assign w_net__ARM_Processor_System_0__slave_hp0_axi_arready = w_port__ARM_Processor_System_0__slave_hp0_axi_arready ;
    assign w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_arready = w_net__ARM_Processor_System_0__slave_hp0_axi_arready ;

    assign w_net__ARM_Processor_System_0__slave_hp0_axi_awready = w_port__ARM_Processor_System_0__slave_hp0_axi_awready ;
    assign w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_awready = w_net__ARM_Processor_System_0__slave_hp0_axi_awready ;

    assign w_net__ARM_Processor_System_0__slave_hp0_axi_bid = w_port__ARM_Processor_System_0__slave_hp0_axi_bid ;
    assign w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_bid = w_net__ARM_Processor_System_0__slave_hp0_axi_bid ;

    assign w_net__ARM_Processor_System_0__slave_hp0_axi_bresp = w_port__ARM_Processor_System_0__slave_hp0_axi_bresp ;
    assign w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_bresp = w_net__ARM_Processor_System_0__slave_hp0_axi_bresp ;

    assign w_net__ARM_Processor_System_0__slave_hp0_axi_bvalid = w_port__ARM_Processor_System_0__slave_hp0_axi_bvalid ;
    assign w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_bvalid = w_net__ARM_Processor_System_0__slave_hp0_axi_bvalid ;

    assign w_net__ARM_Processor_System_0__slave_hp0_axi_rdata = w_port__ARM_Processor_System_0__slave_hp0_axi_rdata ;
    assign w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_rdata = w_net__ARM_Processor_System_0__slave_hp0_axi_rdata ;

    assign w_net__ARM_Processor_System_0__slave_hp0_axi_rid = w_port__ARM_Processor_System_0__slave_hp0_axi_rid ;
    assign w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_rid = w_net__ARM_Processor_System_0__slave_hp0_axi_rid ;

    assign w_net__ARM_Processor_System_0__slave_hp0_axi_rlast = w_port__ARM_Processor_System_0__slave_hp0_axi_rlast ;
    assign w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_rlast = w_net__ARM_Processor_System_0__slave_hp0_axi_rlast ;

    assign w_net__ARM_Processor_System_0__slave_hp0_axi_rresp = w_port__ARM_Processor_System_0__slave_hp0_axi_rresp ;
    assign w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_rresp = w_net__ARM_Processor_System_0__slave_hp0_axi_rresp ;

    assign w_net__ARM_Processor_System_0__slave_hp0_axi_rvalid = w_port__ARM_Processor_System_0__slave_hp0_axi_rvalid ;
    assign w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_rvalid = w_net__ARM_Processor_System_0__slave_hp0_axi_rvalid ;

    assign w_net__ARM_Processor_System_0__slave_hp0_axi_wready = w_port__ARM_Processor_System_0__slave_hp0_axi_wready ;
    assign w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_wready = w_net__ARM_Processor_System_0__slave_hp0_axi_wready ;

    assign w_net__ARM_Processor_System_0__slave_hp1_axi_arready = w_port__ARM_Processor_System_0__slave_hp1_axi_arready ;
    assign w_port__HP1_Protocol_Converter_0__ds_axi_arready = w_net__ARM_Processor_System_0__slave_hp1_axi_arready ;

    assign w_net__ARM_Processor_System_0__slave_hp1_axi_awready = w_port__ARM_Processor_System_0__slave_hp1_axi_awready ;
    assign w_port__HP1_Protocol_Converter_0__ds_axi_awready = w_net__ARM_Processor_System_0__slave_hp1_axi_awready ;

    assign w_net__ARM_Processor_System_0__slave_hp1_axi_bid = w_port__ARM_Processor_System_0__slave_hp1_axi_bid ;
    assign w_port__HP1_Protocol_Converter_0__ds_axi_bid = w_net__ARM_Processor_System_0__slave_hp1_axi_bid ;

    assign w_net__ARM_Processor_System_0__slave_hp1_axi_bresp = w_port__ARM_Processor_System_0__slave_hp1_axi_bresp ;
    assign w_port__HP1_Protocol_Converter_0__ds_axi_bresp = w_net__ARM_Processor_System_0__slave_hp1_axi_bresp ;

    assign w_net__ARM_Processor_System_0__slave_hp1_axi_bvalid = w_port__ARM_Processor_System_0__slave_hp1_axi_bvalid ;
    assign w_port__HP1_Protocol_Converter_0__ds_axi_bvalid = w_net__ARM_Processor_System_0__slave_hp1_axi_bvalid ;

    assign w_net__ARM_Processor_System_0__slave_hp1_axi_rdata = w_port__ARM_Processor_System_0__slave_hp1_axi_rdata ;
    assign w_port__HP1_Protocol_Converter_0__ds_axi_rdata = w_net__ARM_Processor_System_0__slave_hp1_axi_rdata ;

    assign w_net__ARM_Processor_System_0__slave_hp1_axi_rid = w_port__ARM_Processor_System_0__slave_hp1_axi_rid ;
    assign w_port__HP1_Protocol_Converter_0__ds_axi_rid = w_net__ARM_Processor_System_0__slave_hp1_axi_rid ;

    assign w_net__ARM_Processor_System_0__slave_hp1_axi_rlast = w_port__ARM_Processor_System_0__slave_hp1_axi_rlast ;
    assign w_port__HP1_Protocol_Converter_0__ds_axi_rlast = w_net__ARM_Processor_System_0__slave_hp1_axi_rlast ;

    assign w_net__ARM_Processor_System_0__slave_hp1_axi_rresp = w_port__ARM_Processor_System_0__slave_hp1_axi_rresp ;
    assign w_port__HP1_Protocol_Converter_0__ds_axi_rresp = w_net__ARM_Processor_System_0__slave_hp1_axi_rresp ;

    assign w_net__ARM_Processor_System_0__slave_hp1_axi_rvalid = w_port__ARM_Processor_System_0__slave_hp1_axi_rvalid ;
    assign w_port__HP1_Protocol_Converter_0__ds_axi_rvalid = w_net__ARM_Processor_System_0__slave_hp1_axi_rvalid ;

    assign w_net__ARM_Processor_System_0__slave_hp1_axi_wready = w_port__ARM_Processor_System_0__slave_hp1_axi_wready ;
    assign w_port__HP1_Protocol_Converter_0__ds_axi_wready = w_net__ARM_Processor_System_0__slave_hp1_axi_wready ;

    assign w_net__AXI4_Stream_to_Video_Out_0__locked = w_port__AXI4_Stream_to_Video_Out_0__locked ;
    assign w_port__HDMI_Reset_0__video_locked = w_net__AXI4_Stream_to_Video_Out_0__locked ;

    assign w_net__AXI4_Stream_to_Video_Out_0__s_axis_video_tready = w_port__AXI4_Stream_to_Video_Out_0__s_axis_video_tready ;
    assign w_port__VDMA_0__m_axis_mm2s_tready = w_net__AXI4_Stream_to_Video_Out_0__s_axis_video_tready ;

    assign w_net__AXI4_Stream_to_Video_Out_0__vid_active_video = w_port__AXI4_Stream_to_Video_Out_0__vid_active_video ;
    assign w_port__HDMI_TX_0__I_video_in_de = w_net__AXI4_Stream_to_Video_Out_0__vid_active_video ;

    assign w_net__AXI4_Stream_to_Video_Out_0__vid_data = w_port__AXI4_Stream_to_Video_Out_0__vid_data ;
    assign w_port__HDMI_TX_0__I_video_in_data = w_net__AXI4_Stream_to_Video_Out_0__vid_data ;

    assign w_net__AXI4_Stream_to_Video_Out_0__vid_hsync = w_port__AXI4_Stream_to_Video_Out_0__vid_hsync ;
    assign w_port__HDMI_TX_0__I_video_in_hs = w_net__AXI4_Stream_to_Video_Out_0__vid_hsync ;

    assign w_net__AXI4_Stream_to_Video_Out_0__vid_vsync = w_port__AXI4_Stream_to_Video_Out_0__vid_vsync ;
    assign w_port__HDMI_TX_0__I_video_in_vs = w_net__AXI4_Stream_to_Video_Out_0__vid_vsync ;

    assign w_net__AXI4_Stream_to_Video_Out_0__vtg_ce = w_port__AXI4_Stream_to_Video_Out_0__vtg_ce ;
    assign w_port__HDMI_VTG_0__vtg_ce = w_net__AXI4_Stream_to_Video_Out_0__vtg_ce ;

    assign w_net__AXIS_Data_FIFO_0__ds_tdata = w_port__AXIS_Data_FIFO_0__ds_tdata ;
    assign w_port__adc_fdma_writer_0__s_axis_s2mm_tdata = w_net__AXIS_Data_FIFO_0__ds_tdata ;

    assign w_net__AXIS_Data_FIFO_0__ds_tkeep = w_port__AXIS_Data_FIFO_0__ds_tkeep ;
    assign w_port__adc_fdma_writer_0__s_axis_s2mm_tkeep = w_net__AXIS_Data_FIFO_0__ds_tkeep ;

    assign w_net__AXIS_Data_FIFO_0__ds_tlast = w_port__AXIS_Data_FIFO_0__ds_tlast ;
    assign w_port__adc_fdma_writer_0__s_axis_s2mm_tlast = w_net__AXIS_Data_FIFO_0__ds_tlast ;

    assign w_net__AXIS_Data_FIFO_0__ds_tvalid = w_port__AXIS_Data_FIFO_0__ds_tvalid ;
    assign w_port__adc_fdma_writer_0__s_axis_s2mm_tvalid = w_net__AXIS_Data_FIFO_0__ds_tvalid ;
    assign w_port__adc_axis_source_0__fifo_out_tvalid = w_net__AXIS_Data_FIFO_0__ds_tvalid ;

    assign w_net__AXIS_Data_FIFO_0__us_tready = w_port__AXIS_Data_FIFO_0__us_tready ;
    assign w_port__adc_axis_source_0__m_axis_tready = w_net__AXIS_Data_FIFO_0__us_tready ;

    assign w_net__AXI_Lite_Matrix_0__ds0_araddr = w_port__AXI_Lite_Matrix_0__ds0_araddr ;
    assign w_port__axi4lite_slave_0__s_axi_araddr = w_net__AXI_Lite_Matrix_0__ds0_araddr ;

    assign w_net__AXI_Lite_Matrix_0__ds0_arvalid = w_port__AXI_Lite_Matrix_0__ds0_arvalid ;
    assign w_port__axi4lite_slave_0__s_axi_arvalid = w_net__AXI_Lite_Matrix_0__ds0_arvalid ;

    assign w_net__AXI_Lite_Matrix_0__ds0_awaddr = w_port__AXI_Lite_Matrix_0__ds0_awaddr ;
    assign w_port__axi4lite_slave_0__s_axi_awaddr = w_net__AXI_Lite_Matrix_0__ds0_awaddr ;

    assign w_net__AXI_Lite_Matrix_0__ds0_awvalid = w_port__AXI_Lite_Matrix_0__ds0_awvalid ;
    assign w_port__axi4lite_slave_0__s_axi_awvalid = w_net__AXI_Lite_Matrix_0__ds0_awvalid ;

    assign w_net__AXI_Lite_Matrix_0__ds0_bready = w_port__AXI_Lite_Matrix_0__ds0_bready ;
    assign w_port__axi4lite_slave_0__s_axi_bready = w_net__AXI_Lite_Matrix_0__ds0_bready ;

    assign w_net__AXI_Lite_Matrix_0__ds0_rready = w_port__AXI_Lite_Matrix_0__ds0_rready ;
    assign w_port__axi4lite_slave_0__s_axi_rready = w_net__AXI_Lite_Matrix_0__ds0_rready ;

    assign w_net__AXI_Lite_Matrix_0__ds0_wdata = w_port__AXI_Lite_Matrix_0__ds0_wdata ;
    assign w_port__axi4lite_slave_0__s_axi_wdata = w_net__AXI_Lite_Matrix_0__ds0_wdata ;

    assign w_net__AXI_Lite_Matrix_0__ds0_wstrb = w_port__AXI_Lite_Matrix_0__ds0_wstrb ;
    assign w_port__axi4lite_slave_0__s_axi_wstrb = w_net__AXI_Lite_Matrix_0__ds0_wstrb ;

    assign w_net__AXI_Lite_Matrix_0__ds0_wvalid = w_port__AXI_Lite_Matrix_0__ds0_wvalid ;
    assign w_port__axi4lite_slave_0__s_axi_wvalid = w_net__AXI_Lite_Matrix_0__ds0_wvalid ;

    assign w_net__AXI_Lite_Matrix_0__ds1_araddr = w_port__AXI_Lite_Matrix_0__ds1_araddr ;
    assign w_port__adc_fdma_writer_0__s_axi_lite_araddr = w_net__AXI_Lite_Matrix_0__ds1_araddr ;

    assign w_net__AXI_Lite_Matrix_0__ds1_arvalid = w_port__AXI_Lite_Matrix_0__ds1_arvalid ;
    assign w_port__adc_fdma_writer_0__s_axi_lite_arvalid = w_net__AXI_Lite_Matrix_0__ds1_arvalid ;

    assign w_net__AXI_Lite_Matrix_0__ds1_awaddr = w_port__AXI_Lite_Matrix_0__ds1_awaddr ;
    assign w_port__adc_fdma_writer_0__s_axi_lite_awaddr = w_net__AXI_Lite_Matrix_0__ds1_awaddr ;

    assign w_net__AXI_Lite_Matrix_0__ds1_awvalid = w_port__AXI_Lite_Matrix_0__ds1_awvalid ;
    assign w_port__adc_fdma_writer_0__s_axi_lite_awvalid = w_net__AXI_Lite_Matrix_0__ds1_awvalid ;

    assign w_net__AXI_Lite_Matrix_0__ds1_bready = w_port__AXI_Lite_Matrix_0__ds1_bready ;
    assign w_port__adc_fdma_writer_0__s_axi_lite_bready = w_net__AXI_Lite_Matrix_0__ds1_bready ;

    assign w_net__AXI_Lite_Matrix_0__ds1_rready = w_port__AXI_Lite_Matrix_0__ds1_rready ;
    assign w_port__adc_fdma_writer_0__s_axi_lite_rready = w_net__AXI_Lite_Matrix_0__ds1_rready ;

    assign w_net__AXI_Lite_Matrix_0__ds1_wdata = w_port__AXI_Lite_Matrix_0__ds1_wdata ;
    assign w_port__adc_fdma_writer_0__s_axi_lite_wdata = w_net__AXI_Lite_Matrix_0__ds1_wdata ;

    assign w_net__AXI_Lite_Matrix_0__ds1_wstrb = w_port__AXI_Lite_Matrix_0__ds1_wstrb ;
    assign w_port__adc_fdma_writer_0__s_axi_lite_wstrb = w_net__AXI_Lite_Matrix_0__ds1_wstrb ;

    assign w_net__AXI_Lite_Matrix_0__ds1_wvalid = w_port__AXI_Lite_Matrix_0__ds1_wvalid ;
    assign w_port__adc_fdma_writer_0__s_axi_lite_wvalid = w_net__AXI_Lite_Matrix_0__ds1_wvalid ;

    assign w_net__AXI_Lite_Matrix_0__ds2_araddr = w_port__AXI_Lite_Matrix_0__ds2_araddr ;
    assign w_port__HDMI_VTG_0__s_axi_araddr = w_net__AXI_Lite_Matrix_0__ds2_araddr ;

    assign w_net__AXI_Lite_Matrix_0__ds2_arvalid = w_port__AXI_Lite_Matrix_0__ds2_arvalid ;
    assign w_port__HDMI_VTG_0__s_axi_arvalid = w_net__AXI_Lite_Matrix_0__ds2_arvalid ;

    assign w_net__AXI_Lite_Matrix_0__ds2_awaddr = w_port__AXI_Lite_Matrix_0__ds2_awaddr ;
    assign w_port__HDMI_VTG_0__s_axi_awaddr = w_net__AXI_Lite_Matrix_0__ds2_awaddr ;

    assign w_net__AXI_Lite_Matrix_0__ds2_awvalid = w_port__AXI_Lite_Matrix_0__ds2_awvalid ;
    assign w_port__HDMI_VTG_0__s_axi_awvalid = w_net__AXI_Lite_Matrix_0__ds2_awvalid ;

    assign w_net__AXI_Lite_Matrix_0__ds2_bready = w_port__AXI_Lite_Matrix_0__ds2_bready ;
    assign w_port__HDMI_VTG_0__s_axi_bready = w_net__AXI_Lite_Matrix_0__ds2_bready ;

    assign w_net__AXI_Lite_Matrix_0__ds2_rready = w_port__AXI_Lite_Matrix_0__ds2_rready ;
    assign w_port__HDMI_VTG_0__s_axi_rready = w_net__AXI_Lite_Matrix_0__ds2_rready ;

    assign w_net__AXI_Lite_Matrix_0__ds2_wdata = w_port__AXI_Lite_Matrix_0__ds2_wdata ;
    assign w_port__HDMI_VTG_0__s_axi_wdata = w_net__AXI_Lite_Matrix_0__ds2_wdata ;

    assign w_net__AXI_Lite_Matrix_0__ds2_wstrb = w_port__AXI_Lite_Matrix_0__ds2_wstrb ;
    assign w_port__HDMI_VTG_0__s_axi_wstrb = w_net__AXI_Lite_Matrix_0__ds2_wstrb ;

    assign w_net__AXI_Lite_Matrix_0__ds2_wvalid = w_port__AXI_Lite_Matrix_0__ds2_wvalid ;
    assign w_port__HDMI_VTG_0__s_axi_wvalid = w_net__AXI_Lite_Matrix_0__ds2_wvalid ;

    assign w_net__AXI_Lite_Matrix_0__ds3_araddr = w_port__AXI_Lite_Matrix_0__ds3_araddr ;
    assign w_port__VDMA_0__axi_lite_araddr = w_net__AXI_Lite_Matrix_0__ds3_araddr ;

    assign w_net__AXI_Lite_Matrix_0__ds3_arvalid = w_port__AXI_Lite_Matrix_0__ds3_arvalid ;
    assign w_port__VDMA_0__axi_lite_arvalid = w_net__AXI_Lite_Matrix_0__ds3_arvalid ;

    assign w_net__AXI_Lite_Matrix_0__ds3_awaddr = w_port__AXI_Lite_Matrix_0__ds3_awaddr ;
    assign w_port__VDMA_0__axi_lite_awaddr = w_net__AXI_Lite_Matrix_0__ds3_awaddr ;

    assign w_net__AXI_Lite_Matrix_0__ds3_awvalid = w_port__AXI_Lite_Matrix_0__ds3_awvalid ;
    assign w_port__VDMA_0__axi_lite_awvalid = w_net__AXI_Lite_Matrix_0__ds3_awvalid ;

    assign w_net__AXI_Lite_Matrix_0__ds3_bready = w_port__AXI_Lite_Matrix_0__ds3_bready ;
    assign w_port__VDMA_0__axi_lite_bready = w_net__AXI_Lite_Matrix_0__ds3_bready ;

    assign w_net__AXI_Lite_Matrix_0__ds3_rready = w_port__AXI_Lite_Matrix_0__ds3_rready ;
    assign w_port__VDMA_0__axi_lite_rready = w_net__AXI_Lite_Matrix_0__ds3_rready ;

    assign w_net__AXI_Lite_Matrix_0__ds3_wdata = w_port__AXI_Lite_Matrix_0__ds3_wdata ;
    assign w_port__VDMA_0__axi_lite_wdata = w_net__AXI_Lite_Matrix_0__ds3_wdata ;

    assign w_net__AXI_Lite_Matrix_0__ds3_wvalid = w_port__AXI_Lite_Matrix_0__ds3_wvalid ;
    assign w_port__VDMA_0__axi_lite_wvalid = w_net__AXI_Lite_Matrix_0__ds3_wvalid ;

    assign w_net__AXI_Lite_Matrix_0__us0_arready = w_port__AXI_Lite_Matrix_0__us0_arready ;
    assign w_port__AXI_Protocol_Converter_0__ds_axi_arready = w_net__AXI_Lite_Matrix_0__us0_arready ;

    assign w_net__AXI_Lite_Matrix_0__us0_awready = w_port__AXI_Lite_Matrix_0__us0_awready ;
    assign w_port__AXI_Protocol_Converter_0__ds_axi_awready = w_net__AXI_Lite_Matrix_0__us0_awready ;

    assign w_net__AXI_Lite_Matrix_0__us0_bresp = w_port__AXI_Lite_Matrix_0__us0_bresp ;
    assign w_port__AXI_Protocol_Converter_0__ds_axi_bresp = w_net__AXI_Lite_Matrix_0__us0_bresp ;

    assign w_net__AXI_Lite_Matrix_0__us0_bvalid = w_port__AXI_Lite_Matrix_0__us0_bvalid ;
    assign w_port__AXI_Protocol_Converter_0__ds_axi_bvalid = w_net__AXI_Lite_Matrix_0__us0_bvalid ;

    assign w_net__AXI_Lite_Matrix_0__us0_rdata = w_port__AXI_Lite_Matrix_0__us0_rdata ;
    assign w_port__AXI_Protocol_Converter_0__ds_axi_rdata = w_net__AXI_Lite_Matrix_0__us0_rdata ;

    assign w_net__AXI_Lite_Matrix_0__us0_rresp = w_port__AXI_Lite_Matrix_0__us0_rresp ;
    assign w_port__AXI_Protocol_Converter_0__ds_axi_rresp = w_net__AXI_Lite_Matrix_0__us0_rresp ;

    assign w_net__AXI_Lite_Matrix_0__us0_rvalid = w_port__AXI_Lite_Matrix_0__us0_rvalid ;
    assign w_port__AXI_Protocol_Converter_0__ds_axi_rvalid = w_net__AXI_Lite_Matrix_0__us0_rvalid ;

    assign w_net__AXI_Lite_Matrix_0__us0_wready = w_port__AXI_Lite_Matrix_0__us0_wready ;
    assign w_port__AXI_Protocol_Converter_0__ds_axi_wready = w_net__AXI_Lite_Matrix_0__us0_wready ;

    assign w_net__AXI_Protocol_Converter_0__ds_axi_araddr = w_port__AXI_Protocol_Converter_0__ds_axi_araddr ;
    assign w_port__AXI_Lite_Matrix_0__us0_araddr = w_net__AXI_Protocol_Converter_0__ds_axi_araddr ;

    assign w_net__AXI_Protocol_Converter_0__ds_axi_arprot = w_port__AXI_Protocol_Converter_0__ds_axi_arprot ;
    assign w_port__AXI_Lite_Matrix_0__us0_arprot = w_net__AXI_Protocol_Converter_0__ds_axi_arprot ;

    assign w_net__AXI_Protocol_Converter_0__ds_axi_arvalid = w_port__AXI_Protocol_Converter_0__ds_axi_arvalid ;
    assign w_port__AXI_Lite_Matrix_0__us0_arvalid = w_net__AXI_Protocol_Converter_0__ds_axi_arvalid ;

    assign w_net__AXI_Protocol_Converter_0__ds_axi_awaddr = w_port__AXI_Protocol_Converter_0__ds_axi_awaddr ;
    assign w_port__AXI_Lite_Matrix_0__us0_awaddr = w_net__AXI_Protocol_Converter_0__ds_axi_awaddr ;

    assign w_net__AXI_Protocol_Converter_0__ds_axi_awprot = w_port__AXI_Protocol_Converter_0__ds_axi_awprot ;
    assign w_port__AXI_Lite_Matrix_0__us0_awprot = w_net__AXI_Protocol_Converter_0__ds_axi_awprot ;

    assign w_net__AXI_Protocol_Converter_0__ds_axi_awvalid = w_port__AXI_Protocol_Converter_0__ds_axi_awvalid ;
    assign w_port__AXI_Lite_Matrix_0__us0_awvalid = w_net__AXI_Protocol_Converter_0__ds_axi_awvalid ;

    assign w_net__AXI_Protocol_Converter_0__ds_axi_bready = w_port__AXI_Protocol_Converter_0__ds_axi_bready ;
    assign w_port__AXI_Lite_Matrix_0__us0_bready = w_net__AXI_Protocol_Converter_0__ds_axi_bready ;

    assign w_net__AXI_Protocol_Converter_0__ds_axi_rready = w_port__AXI_Protocol_Converter_0__ds_axi_rready ;
    assign w_port__AXI_Lite_Matrix_0__us0_rready = w_net__AXI_Protocol_Converter_0__ds_axi_rready ;

    assign w_net__AXI_Protocol_Converter_0__ds_axi_wdata = w_port__AXI_Protocol_Converter_0__ds_axi_wdata ;
    assign w_port__AXI_Lite_Matrix_0__us0_wdata = w_net__AXI_Protocol_Converter_0__ds_axi_wdata ;

    assign w_net__AXI_Protocol_Converter_0__ds_axi_wstrb = w_port__AXI_Protocol_Converter_0__ds_axi_wstrb ;
    assign w_port__AXI_Lite_Matrix_0__us0_wstrb = w_net__AXI_Protocol_Converter_0__ds_axi_wstrb ;

    assign w_net__AXI_Protocol_Converter_0__ds_axi_wvalid = w_port__AXI_Protocol_Converter_0__ds_axi_wvalid ;
    assign w_port__AXI_Lite_Matrix_0__us0_wvalid = w_net__AXI_Protocol_Converter_0__ds_axi_wvalid ;

    assign w_net__AXI_Protocol_Converter_0__us_axi_arready = w_port__AXI_Protocol_Converter_0__us_axi_arready ;
    assign w_port__ARM_Processor_System_0__master_gp0_axi_arready = w_net__AXI_Protocol_Converter_0__us_axi_arready ;

    assign w_net__AXI_Protocol_Converter_0__us_axi_awready = w_port__AXI_Protocol_Converter_0__us_axi_awready ;
    assign w_port__ARM_Processor_System_0__master_gp0_axi_awready = w_net__AXI_Protocol_Converter_0__us_axi_awready ;

    assign w_net__AXI_Protocol_Converter_0__us_axi_bid = w_port__AXI_Protocol_Converter_0__us_axi_bid ;
    assign w_port__ARM_Processor_System_0__master_gp0_axi_bid = w_net__AXI_Protocol_Converter_0__us_axi_bid ;

    assign w_net__AXI_Protocol_Converter_0__us_axi_bresp = w_port__AXI_Protocol_Converter_0__us_axi_bresp ;
    assign w_port__ARM_Processor_System_0__master_gp0_axi_bresp = w_net__AXI_Protocol_Converter_0__us_axi_bresp ;

    assign w_net__AXI_Protocol_Converter_0__us_axi_bvalid = w_port__AXI_Protocol_Converter_0__us_axi_bvalid ;
    assign w_port__ARM_Processor_System_0__master_gp0_axi_bvalid = w_net__AXI_Protocol_Converter_0__us_axi_bvalid ;

    assign w_net__AXI_Protocol_Converter_0__us_axi_rdata = w_port__AXI_Protocol_Converter_0__us_axi_rdata ;
    assign w_port__ARM_Processor_System_0__master_gp0_axi_rdata = w_net__AXI_Protocol_Converter_0__us_axi_rdata ;

    assign w_net__AXI_Protocol_Converter_0__us_axi_rid = w_port__AXI_Protocol_Converter_0__us_axi_rid ;
    assign w_port__ARM_Processor_System_0__master_gp0_axi_rid = w_net__AXI_Protocol_Converter_0__us_axi_rid ;

    assign w_net__AXI_Protocol_Converter_0__us_axi_rlast = w_port__AXI_Protocol_Converter_0__us_axi_rlast ;
    assign w_port__ARM_Processor_System_0__master_gp0_axi_rlast = w_net__AXI_Protocol_Converter_0__us_axi_rlast ;

    assign w_net__AXI_Protocol_Converter_0__us_axi_rresp = w_port__AXI_Protocol_Converter_0__us_axi_rresp ;
    assign w_port__ARM_Processor_System_0__master_gp0_axi_rresp = w_net__AXI_Protocol_Converter_0__us_axi_rresp ;

    assign w_net__AXI_Protocol_Converter_0__us_axi_rvalid = w_port__AXI_Protocol_Converter_0__us_axi_rvalid ;
    assign w_port__ARM_Processor_System_0__master_gp0_axi_rvalid = w_net__AXI_Protocol_Converter_0__us_axi_rvalid ;

    assign w_net__AXI_Protocol_Converter_0__us_axi_wready = w_port__AXI_Protocol_Converter_0__us_axi_wready ;
    assign w_port__ARM_Processor_System_0__master_gp0_axi_wready = w_net__AXI_Protocol_Converter_0__us_axi_wready ;

    assign w_net__Constant_0_0__dout = w_port__Constant_0_0__dout ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_awqos = w_net__Constant_0_0__dout ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_arqos = w_net__Constant_0_0__dout ;

    assign w_net__Constant_0__dout = w_port__Constant_0__dout ;
    assign w_port__Processor_System_Reset_0__system_rst = w_net__Constant_0__dout ;
    assign w_port__axi4lite_slave_0__s_axis_tdata = {31'b0,w_net__Constant_0__dout} ;
    assign w_port__axi4lite_slave_0__s_axis_tkeep = {3'b0,w_net__Constant_0__dout} ;
    assign w_port__axi4lite_slave_0__s_axis_tlast = w_net__Constant_0__dout ;
    assign w_port__axi4lite_slave_0__s_axis_tvalid = w_net__Constant_0__dout ;
    assign w_port__HP1_AXI_Matrix_0__us0_araddr = {32'b0,w_net__Constant_0__dout} ;
    assign w_port__HP1_AXI_Matrix_0__us0_arburst = {1'b0,w_net__Constant_0__dout} ;
    assign w_port__HP1_AXI_Matrix_0__us0_arcache = {3'b0,w_net__Constant_0__dout} ;
    assign w_port__HP1_AXI_Matrix_0__us0_arid = {4'b0,w_net__Constant_0__dout} ;
    assign w_port__HP1_AXI_Matrix_0__us0_arlen = {7'b0,w_net__Constant_0__dout} ;
    assign w_port__HP1_AXI_Matrix_0__us0_arlock = w_net__Constant_0__dout ;
    assign w_port__HP1_AXI_Matrix_0__us0_arprot = {2'b0,w_net__Constant_0__dout} ;
    assign w_port__HP1_AXI_Matrix_0__us0_arqos = {3'b0,w_net__Constant_0__dout} ;
    assign w_port__HP1_AXI_Matrix_0__us0_arsize = {2'b0,w_net__Constant_0__dout} ;
    assign w_port__HP1_AXI_Matrix_0__us0_arvalid = w_net__Constant_0__dout ;
    assign w_port__HP1_AXI_Matrix_0__us0_rready = w_net__Constant_0__dout ;
    assign w_port__VDMA_0__m_axi_s2mm_awready = w_net__Constant_0__dout ;
    assign w_port__VDMA_0__m_axi_s2mm_wready = w_net__Constant_0__dout ;
    assign w_port__VDMA_0__m_axi_s2mm_bresp = {1'b0,w_net__Constant_0__dout} ;
    assign w_port__VDMA_0__m_axi_s2mm_bvalid = w_net__Constant_0__dout ;
    assign w_port__VDMA_0__s_axis_s2mm_tdata = {63'b0,w_net__Constant_0__dout} ;
    assign w_port__VDMA_0__s_axis_s2mm_tkeep = {7'b0,w_net__Constant_0__dout} ;
    assign w_port__VDMA_0__s_axis_s2mm_tuser = w_net__Constant_0__dout ;
    assign w_port__VDMA_0__s_axis_s2mm_tvalid = w_net__Constant_0__dout ;
    assign w_port__VDMA_0__s_axis_s2mm_tlast = w_net__Constant_0__dout ;
    assign w_port__VDMA_0__mm2s_fsync = w_net__Constant_0__dout ;
    assign w_port__VDMA_0__s2mm_fsync = w_net__Constant_0__dout ;
    assign w_port__AXI4_Stream_to_Video_Out_0__fid = w_net__Constant_0__dout ;
    assign w_port__AXI4_Stream_to_Video_Out_0__vtg_field_id = w_net__Constant_0__dout ;
    assign w_port__HDMI_IRQ_Concat_0__In2 = w_net__Constant_0__dout ;
    assign w_port__HDMI_HP0_Protocol_Converter_0__us_axi_awid = {5'b0,w_net__Constant_0__dout} ;
    assign w_port__HDMI_HP0_Protocol_Converter_0__us_axi_awaddr = {32'b0,w_net__Constant_0__dout} ;
    assign w_port__HDMI_HP0_Protocol_Converter_0__us_axi_awlen = {7'b0,w_net__Constant_0__dout} ;
    assign w_port__HDMI_HP0_Protocol_Converter_0__us_axi_awsize = {2'b0,w_net__Constant_0__dout} ;
    assign w_port__HDMI_HP0_Protocol_Converter_0__us_axi_awburst = {1'b0,w_net__Constant_0__dout} ;
    assign w_port__HDMI_HP0_Protocol_Converter_0__us_axi_awlock = w_net__Constant_0__dout ;
    assign w_port__HDMI_HP0_Protocol_Converter_0__us_axi_awcache = {3'b0,w_net__Constant_0__dout} ;
    assign w_port__HDMI_HP0_Protocol_Converter_0__us_axi_awprot = {2'b0,w_net__Constant_0__dout} ;
    assign w_port__HDMI_HP0_Protocol_Converter_0__us_axi_awqos = {3'b0,w_net__Constant_0__dout} ;
    assign w_port__HDMI_HP0_Protocol_Converter_0__us_axi_awvalid = w_net__Constant_0__dout ;
    assign w_port__HDMI_HP0_Protocol_Converter_0__us_axi_wdata = {63'b0,w_net__Constant_0__dout} ;
    assign w_port__HDMI_HP0_Protocol_Converter_0__us_axi_wstrb = {7'b0,w_net__Constant_0__dout} ;
    assign w_port__HDMI_HP0_Protocol_Converter_0__us_axi_wlast = w_net__Constant_0__dout ;
    assign w_port__HDMI_HP0_Protocol_Converter_0__us_axi_wvalid = w_net__Constant_0__dout ;
    assign w_port__HDMI_HP0_Protocol_Converter_0__us_axi_bready = w_net__Constant_0__dout ;
    assign w_port__HDMI_HP0_Protocol_Converter_0__us_axi_arid = {5'b0,w_net__Constant_0__dout} ;
    assign w_port__HDMI_HP0_Protocol_Converter_0__us_axi_arlock = w_net__Constant_0__dout ;
    assign w_port__HDMI_HP0_Protocol_Converter_0__us_axi_arqos = {3'b0,w_net__Constant_0__dout} ;
    assign w_port__HDMI_IRQ_Concat_0__In3 = w_net__Constant_0__dout ;
    assign w_port__HDMI_IRQ_Concat_0__In4 = w_net__Constant_0__dout ;
    assign w_port__HDMI_IRQ_Concat_0__In5 = w_net__Constant_0__dout ;
    assign w_port__HDMI_IRQ_Concat_0__In6 = w_net__Constant_0__dout ;
    assign w_port__HDMI_IRQ_Concat_0__In7 = w_net__Constant_0__dout ;
    assign w_port__HDMI_IRQ_Concat_0__In8 = w_net__Constant_0__dout ;
    assign w_port__HDMI_IRQ_Concat_0__In9 = w_net__Constant_0__dout ;
    assign w_port__HDMI_IRQ_Concat_0__In10 = w_net__Constant_0__dout ;
    assign w_port__HDMI_IRQ_Concat_0__In11 = w_net__Constant_0__dout ;
    assign w_port__HDMI_IRQ_Concat_0__In12 = w_net__Constant_0__dout ;
    assign w_port__HDMI_IRQ_Concat_0__In13 = w_net__Constant_0__dout ;
    assign w_port__HDMI_IRQ_Concat_0__In14 = w_net__Constant_0__dout ;
    assign w_port__NPU_Control_Matrix_0__us0_arqos = {3'b0,w_net__Constant_0__dout} ;
    assign w_port__NPU_Control_Matrix_0__us0_awqos = {3'b0,w_net__Constant_0__dout} ;

    assign w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_araddr = w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_araddr ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_araddr = w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_araddr ;

    assign w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_arburst = w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_arburst ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_arburst = w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_arburst ;

    assign w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_arcache = w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_arcache ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_arcache = w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_arcache ;

    assign w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_arid = w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_arid ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_arid = w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_arid ;

    assign w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_arlen = w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_arlen ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_arlen = w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_arlen ;

    assign w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_arlock = w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_arlock ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_arlock = w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_arlock ;

    assign w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_arprot = w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_arprot ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_arprot = w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_arprot ;

    assign w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_arqos = w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_arqos ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_arqos = w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_arqos ;

    assign w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_arsize = w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_arsize ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_arsize = w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_arsize ;

    assign w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_arvalid = w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_arvalid ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_arvalid = w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_arvalid ;

    assign w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_awaddr = w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_awaddr ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_awaddr = w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_awaddr ;

    assign w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_awburst = w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_awburst ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_awburst = w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_awburst ;

    assign w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_awcache = w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_awcache ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_awcache = w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_awcache ;

    assign w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_awid = w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_awid ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_awid = w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_awid ;

    assign w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_awlen = w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_awlen ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_awlen = w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_awlen ;

    assign w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_awlock = w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_awlock ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_awlock = w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_awlock ;

    assign w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_awprot = w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_awprot ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_awprot = w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_awprot ;

    assign w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_awqos = w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_awqos ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_awqos = w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_awqos ;

    assign w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_awsize = w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_awsize ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_awsize = w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_awsize ;

    assign w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_awvalid = w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_awvalid ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_awvalid = w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_awvalid ;

    assign w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_bready = w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_bready ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_bready = w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_bready ;

    assign w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_rready = w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_rready ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_rready = w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_rready ;

    assign w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_wdata = w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_wdata ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_wdata = w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_wdata ;

    assign w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_wlast = w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_wlast ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_wlast = w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_wlast ;

    assign w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_wstrb = w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_wstrb ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_wstrb = w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_wstrb ;

    assign w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_wvalid = w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_wvalid ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_wvalid = w_net__HDMI_HP0_Protocol_Converter_0__ds_axi_wvalid ;

    assign w_net__HDMI_HP0_Protocol_Converter_0__us_axi_arready = w_port__HDMI_HP0_Protocol_Converter_0__us_axi_arready ;
    assign w_port__VDMA_0__m_axi_mm2s_arready = w_net__HDMI_HP0_Protocol_Converter_0__us_axi_arready ;

    assign w_net__HDMI_HP0_Protocol_Converter_0__us_axi_rdata = w_port__HDMI_HP0_Protocol_Converter_0__us_axi_rdata ;
    assign w_port__VDMA_0__m_axi_mm2s_rdata = w_net__HDMI_HP0_Protocol_Converter_0__us_axi_rdata ;

    assign w_net__HDMI_HP0_Protocol_Converter_0__us_axi_rlast = w_port__HDMI_HP0_Protocol_Converter_0__us_axi_rlast ;
    assign w_port__VDMA_0__m_axi_mm2s_rlast = w_net__HDMI_HP0_Protocol_Converter_0__us_axi_rlast ;

    assign w_net__HDMI_HP0_Protocol_Converter_0__us_axi_rresp = w_port__HDMI_HP0_Protocol_Converter_0__us_axi_rresp ;
    assign w_port__VDMA_0__m_axi_mm2s_rresp = w_net__HDMI_HP0_Protocol_Converter_0__us_axi_rresp ;

    assign w_net__HDMI_HP0_Protocol_Converter_0__us_axi_rvalid = w_port__HDMI_HP0_Protocol_Converter_0__us_axi_rvalid ;
    assign w_port__VDMA_0__m_axi_mm2s_rvalid = w_net__HDMI_HP0_Protocol_Converter_0__us_axi_rvalid ;

    assign w_net__HDMI_IRQ_Concat_0__Dout = w_port__HDMI_IRQ_Concat_0__Dout ;
    assign w_port__ARM_Processor_System_0__f2p_irq = w_net__HDMI_IRQ_Concat_0__Dout ;

    assign w_net__HDMI_PLL_0__clk1_out = w_port__HDMI_PLL_0__clk1_out ;
    assign w_port__VDMA_0__m_axi_mm2s_aclk = w_net__HDMI_PLL_0__clk1_out ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_aclk = w_net__HDMI_PLL_0__clk1_out ;
    assign w_port__HDMI_HP0_Protocol_Converter_0__aclk = w_net__HDMI_PLL_0__clk1_out ;
    assign w_port__HDMI_Reset_0__mem_clk = w_net__HDMI_PLL_0__clk1_out ;

    assign w_net__HDMI_PLL_0__clk2_out = w_port__HDMI_PLL_0__clk2_out ;
    assign w_port__VDMA_0__m_axis_mm2s_aclk = w_net__HDMI_PLL_0__clk2_out ;
    assign w_port__AXI4_Stream_to_Video_Out_0__aclk = w_net__HDMI_PLL_0__clk2_out ;
    assign w_port__HDMI_Reset_0__axis_clk = w_net__HDMI_PLL_0__clk2_out ;

    assign w_net__HDMI_PLL_0__lock = w_port__HDMI_PLL_0__lock ;
    assign w_port__HDMI_Reset_0__display_pll_locked = w_net__HDMI_PLL_0__lock ;
    assign w_port__AXI4_Stream_to_Video_Out_0__aclken = w_net__HDMI_PLL_0__lock ;

    assign w_net__HDMI_PLL_1__clk0_out = w_port__HDMI_PLL_1__clk0_out ;
    assign w_port__HDMI_TX_0__I_serial_clk = w_net__HDMI_PLL_1__clk0_out ;

    assign w_net__HDMI_PLL_1__lock = w_port__HDMI_PLL_1__lock ;
    assign w_port__HDMI_Reset_0__serial_pll_locked = w_net__HDMI_PLL_1__lock ;

    assign w_net__HDMI_Reset_0__axis_reset_n = w_port__HDMI_Reset_0__axis_reset_n ;
    assign w_port__AXI4_Stream_to_Video_Out_0__aresetn = w_net__HDMI_Reset_0__axis_reset_n ;

    assign w_net__HDMI_Reset_0__ctrl_reset_n = w_port__HDMI_Reset_0__ctrl_reset_n ;
    assign w_port__VDMA_0__resetn = w_net__HDMI_Reset_0__ctrl_reset_n ;

    assign w_net__HDMI_Reset_0__mem_reset_n = w_port__HDMI_Reset_0__mem_reset_n ;
    assign w_port__HDMI_HP0_Protocol_Converter_0__aresetn = w_net__HDMI_Reset_0__mem_reset_n ;

    assign w_net__HDMI_Reset_0__pixel_reset = w_port__HDMI_Reset_0__pixel_reset ;
    assign w_port__AXI4_Stream_to_Video_Out_0__vid_io_out_reset = w_net__HDMI_Reset_0__pixel_reset ;

    assign w_net__HDMI_Reset_0__serial_pll_reset = w_port__HDMI_Reset_0__serial_pll_reset ;
    assign w_port__HDMI_PLL_1__reset = w_net__HDMI_Reset_0__serial_pll_reset ;

    assign w_net__HDMI_Reset_0__tx_reset = w_port__HDMI_Reset_0__tx_reset ;
    assign w_port__HDMI_TX_0__I_rst = w_net__HDMI_Reset_0__tx_reset ;

    assign w_net__HDMI_TX_0__O_hdmi_clk_p = w_port__HDMI_TX_0__O_hdmi_clk_p ;
    assign O_hdmi_clk_p = w_net__HDMI_TX_0__O_hdmi_clk_p ;

    assign w_net__HDMI_TX_0__O_hdmi_tx_p = w_port__HDMI_TX_0__O_hdmi_tx_p ;
    assign O_hdmi_tx_p = w_net__HDMI_TX_0__O_hdmi_tx_p ;

    assign w_net__HDMI_VTG_0__s_axi_arready = w_port__HDMI_VTG_0__s_axi_arready ;
    assign w_port__AXI_Lite_Matrix_0__ds2_arready = w_net__HDMI_VTG_0__s_axi_arready ;

    assign w_net__HDMI_VTG_0__s_axi_awready = w_port__HDMI_VTG_0__s_axi_awready ;
    assign w_port__AXI_Lite_Matrix_0__ds2_awready = w_net__HDMI_VTG_0__s_axi_awready ;

    assign w_net__HDMI_VTG_0__s_axi_bresp = w_port__HDMI_VTG_0__s_axi_bresp ;
    assign w_port__AXI_Lite_Matrix_0__ds2_bresp = w_net__HDMI_VTG_0__s_axi_bresp ;

    assign w_net__HDMI_VTG_0__s_axi_bvalid = w_port__HDMI_VTG_0__s_axi_bvalid ;
    assign w_port__AXI_Lite_Matrix_0__ds2_bvalid = w_net__HDMI_VTG_0__s_axi_bvalid ;

    assign w_net__HDMI_VTG_0__s_axi_rdata = w_port__HDMI_VTG_0__s_axi_rdata ;
    assign w_port__AXI_Lite_Matrix_0__ds2_rdata = w_net__HDMI_VTG_0__s_axi_rdata ;

    assign w_net__HDMI_VTG_0__s_axi_rresp = w_port__HDMI_VTG_0__s_axi_rresp ;
    assign w_port__AXI_Lite_Matrix_0__ds2_rresp = w_net__HDMI_VTG_0__s_axi_rresp ;

    assign w_net__HDMI_VTG_0__s_axi_rvalid = w_port__HDMI_VTG_0__s_axi_rvalid ;
    assign w_port__AXI_Lite_Matrix_0__ds2_rvalid = w_net__HDMI_VTG_0__s_axi_rvalid ;

    assign w_net__HDMI_VTG_0__s_axi_wready = w_port__HDMI_VTG_0__s_axi_wready ;
    assign w_port__AXI_Lite_Matrix_0__ds2_wready = w_net__HDMI_VTG_0__s_axi_wready ;

    assign w_net__HDMI_VTG_0__vtg_active_video = w_port__HDMI_VTG_0__vtg_active_video ;
    assign w_port__AXI4_Stream_to_Video_Out_0__vtg_active_video = w_net__HDMI_VTG_0__vtg_active_video ;

    assign w_net__HDMI_VTG_0__vtg_hblank = w_port__HDMI_VTG_0__vtg_hblank ;
    assign w_port__AXI4_Stream_to_Video_Out_0__vtg_hblank = w_net__HDMI_VTG_0__vtg_hblank ;

    assign w_net__HDMI_VTG_0__vtg_hsync = w_port__HDMI_VTG_0__vtg_hsync ;
    assign w_port__AXI4_Stream_to_Video_Out_0__vtg_hsync = w_net__HDMI_VTG_0__vtg_hsync ;

    assign w_net__HDMI_VTG_0__vtg_pclk = w_port__HDMI_VTG_0__vtg_pclk ;
    assign w_port__AXI4_Stream_to_Video_Out_0__vid_io_out_clk = w_net__HDMI_VTG_0__vtg_pclk ;
    assign w_port__HDMI_PLL_1__refclk = w_net__HDMI_VTG_0__vtg_pclk ;
    assign w_port__HDMI_TX_0__I_pixel_clk = w_net__HDMI_VTG_0__vtg_pclk ;
    assign w_port__HDMI_Reset_0__pixel_clk = w_net__HDMI_VTG_0__vtg_pclk ;

    assign w_net__HDMI_VTG_0__vtg_pclk_locked = w_port__HDMI_VTG_0__vtg_pclk_locked ;
    assign w_port__AXI4_Stream_to_Video_Out_0__vid_io_out_ce = w_net__HDMI_VTG_0__vtg_pclk_locked ;
    assign w_port__HDMI_Reset_0__pixel_pll_locked = w_net__HDMI_VTG_0__vtg_pclk_locked ;

    assign w_net__HDMI_VTG_0__vtg_vblank = w_port__HDMI_VTG_0__vtg_vblank ;
    assign w_port__AXI4_Stream_to_Video_Out_0__vtg_vblank = w_net__HDMI_VTG_0__vtg_vblank ;

    assign w_net__HDMI_VTG_0__vtg_vsync = w_port__HDMI_VTG_0__vtg_vsync ;
    assign w_port__AXI4_Stream_to_Video_Out_0__vtg_vsync = w_net__HDMI_VTG_0__vtg_vsync ;

    assign w_net__HP1_AXI_Matrix_0__ds0_araddr = w_port__HP1_AXI_Matrix_0__ds0_araddr ;
    assign w_port__HP1_Protocol_Converter_0__us_axi_araddr = w_net__HP1_AXI_Matrix_0__ds0_araddr ;

    assign w_net__HP1_AXI_Matrix_0__ds0_arburst = w_port__HP1_AXI_Matrix_0__ds0_arburst ;
    assign w_port__HP1_Protocol_Converter_0__us_axi_arburst = w_net__HP1_AXI_Matrix_0__ds0_arburst ;

    assign w_net__HP1_AXI_Matrix_0__ds0_arcache = w_port__HP1_AXI_Matrix_0__ds0_arcache ;
    assign w_port__HP1_Protocol_Converter_0__us_axi_arcache = w_net__HP1_AXI_Matrix_0__ds0_arcache ;

    assign w_net__HP1_AXI_Matrix_0__ds0_arid = w_port__HP1_AXI_Matrix_0__ds0_arid ;
    assign w_port__HP1_Protocol_Converter_0__us_axi_arid = w_net__HP1_AXI_Matrix_0__ds0_arid ;

    assign w_net__HP1_AXI_Matrix_0__ds0_arlen = w_port__HP1_AXI_Matrix_0__ds0_arlen ;
    assign w_port__HP1_Protocol_Converter_0__us_axi_arlen = w_net__HP1_AXI_Matrix_0__ds0_arlen ;

    assign w_net__HP1_AXI_Matrix_0__ds0_arlock = w_port__HP1_AXI_Matrix_0__ds0_arlock ;
    assign w_port__HP1_Protocol_Converter_0__us_axi_arlock = w_net__HP1_AXI_Matrix_0__ds0_arlock ;

    assign w_net__HP1_AXI_Matrix_0__ds0_arprot = w_port__HP1_AXI_Matrix_0__ds0_arprot ;
    assign w_port__HP1_Protocol_Converter_0__us_axi_arprot = w_net__HP1_AXI_Matrix_0__ds0_arprot ;

    assign w_net__HP1_AXI_Matrix_0__ds0_arqos = w_port__HP1_AXI_Matrix_0__ds0_arqos ;
    assign w_port__HP1_Protocol_Converter_0__us_axi_arqos = w_net__HP1_AXI_Matrix_0__ds0_arqos ;

    assign w_net__HP1_AXI_Matrix_0__ds0_arsize = w_port__HP1_AXI_Matrix_0__ds0_arsize ;
    assign w_port__HP1_Protocol_Converter_0__us_axi_arsize = w_net__HP1_AXI_Matrix_0__ds0_arsize ;

    assign w_net__HP1_AXI_Matrix_0__ds0_arvalid = w_port__HP1_AXI_Matrix_0__ds0_arvalid ;
    assign w_port__HP1_Protocol_Converter_0__us_axi_arvalid = w_net__HP1_AXI_Matrix_0__ds0_arvalid ;

    assign w_net__HP1_AXI_Matrix_0__ds0_awaddr = w_port__HP1_AXI_Matrix_0__ds0_awaddr ;
    assign w_port__HP1_Protocol_Converter_0__us_axi_awaddr = w_net__HP1_AXI_Matrix_0__ds0_awaddr ;

    assign w_net__HP1_AXI_Matrix_0__ds0_awburst = w_port__HP1_AXI_Matrix_0__ds0_awburst ;
    assign w_port__HP1_Protocol_Converter_0__us_axi_awburst = w_net__HP1_AXI_Matrix_0__ds0_awburst ;

    assign w_net__HP1_AXI_Matrix_0__ds0_awcache = w_port__HP1_AXI_Matrix_0__ds0_awcache ;
    assign w_port__HP1_Protocol_Converter_0__us_axi_awcache = w_net__HP1_AXI_Matrix_0__ds0_awcache ;

    assign w_net__HP1_AXI_Matrix_0__ds0_awid = w_port__HP1_AXI_Matrix_0__ds0_awid ;
    assign w_port__HP1_Protocol_Converter_0__us_axi_awid = w_net__HP1_AXI_Matrix_0__ds0_awid ;

    assign w_net__HP1_AXI_Matrix_0__ds0_awlen = w_port__HP1_AXI_Matrix_0__ds0_awlen ;
    assign w_port__HP1_Protocol_Converter_0__us_axi_awlen = w_net__HP1_AXI_Matrix_0__ds0_awlen ;

    assign w_net__HP1_AXI_Matrix_0__ds0_awlock = w_port__HP1_AXI_Matrix_0__ds0_awlock ;
    assign w_port__HP1_Protocol_Converter_0__us_axi_awlock = w_net__HP1_AXI_Matrix_0__ds0_awlock ;

    assign w_net__HP1_AXI_Matrix_0__ds0_awprot = w_port__HP1_AXI_Matrix_0__ds0_awprot ;
    assign w_port__HP1_Protocol_Converter_0__us_axi_awprot = w_net__HP1_AXI_Matrix_0__ds0_awprot ;

    assign w_net__HP1_AXI_Matrix_0__ds0_awqos = w_port__HP1_AXI_Matrix_0__ds0_awqos ;
    assign w_port__HP1_Protocol_Converter_0__us_axi_awqos = w_net__HP1_AXI_Matrix_0__ds0_awqos ;

    assign w_net__HP1_AXI_Matrix_0__ds0_awsize = w_port__HP1_AXI_Matrix_0__ds0_awsize ;
    assign w_port__HP1_Protocol_Converter_0__us_axi_awsize = w_net__HP1_AXI_Matrix_0__ds0_awsize ;

    assign w_net__HP1_AXI_Matrix_0__ds0_awvalid = w_port__HP1_AXI_Matrix_0__ds0_awvalid ;
    assign w_port__HP1_Protocol_Converter_0__us_axi_awvalid = w_net__HP1_AXI_Matrix_0__ds0_awvalid ;

    assign w_net__HP1_AXI_Matrix_0__ds0_bready = w_port__HP1_AXI_Matrix_0__ds0_bready ;
    assign w_port__HP1_Protocol_Converter_0__us_axi_bready = w_net__HP1_AXI_Matrix_0__ds0_bready ;

    assign w_net__HP1_AXI_Matrix_0__ds0_rready = w_port__HP1_AXI_Matrix_0__ds0_rready ;
    assign w_port__HP1_Protocol_Converter_0__us_axi_rready = w_net__HP1_AXI_Matrix_0__ds0_rready ;

    assign w_net__HP1_AXI_Matrix_0__ds0_wdata = w_port__HP1_AXI_Matrix_0__ds0_wdata ;
    assign w_port__HP1_Protocol_Converter_0__us_axi_wdata = w_net__HP1_AXI_Matrix_0__ds0_wdata ;

    assign w_net__HP1_AXI_Matrix_0__ds0_wlast = w_port__HP1_AXI_Matrix_0__ds0_wlast ;
    assign w_port__HP1_Protocol_Converter_0__us_axi_wlast = w_net__HP1_AXI_Matrix_0__ds0_wlast ;

    assign w_net__HP1_AXI_Matrix_0__ds0_wstrb = w_port__HP1_AXI_Matrix_0__ds0_wstrb ;
    assign w_port__HP1_Protocol_Converter_0__us_axi_wstrb = w_net__HP1_AXI_Matrix_0__ds0_wstrb ;

    assign w_net__HP1_AXI_Matrix_0__ds0_wvalid = w_port__HP1_AXI_Matrix_0__ds0_wvalid ;
    assign w_port__HP1_Protocol_Converter_0__us_axi_wvalid = w_net__HP1_AXI_Matrix_0__ds0_wvalid ;

    assign w_net__HP1_AXI_Matrix_0__us0_awready = w_port__HP1_AXI_Matrix_0__us0_awready ;
    assign w_port__adc_fdma_writer_0__m_axi_s2mm_awready = w_net__HP1_AXI_Matrix_0__us0_awready ;

    assign w_net__HP1_AXI_Matrix_0__us0_bid = w_port__HP1_AXI_Matrix_0__us0_bid ;
    assign w_port__adc_fdma_writer_0__m_axi_s2mm_bid = w_net__HP1_AXI_Matrix_0__us0_bid ;

    assign w_net__HP1_AXI_Matrix_0__us0_bresp = w_port__HP1_AXI_Matrix_0__us0_bresp ;
    assign w_port__adc_fdma_writer_0__m_axi_s2mm_bresp = w_net__HP1_AXI_Matrix_0__us0_bresp ;

    assign w_net__HP1_AXI_Matrix_0__us0_bvalid = w_port__HP1_AXI_Matrix_0__us0_bvalid ;
    assign w_port__adc_fdma_writer_0__m_axi_s2mm_bvalid = w_net__HP1_AXI_Matrix_0__us0_bvalid ;

    assign w_net__HP1_AXI_Matrix_0__us0_wready = w_port__HP1_AXI_Matrix_0__us0_wready ;
    assign w_port__adc_fdma_writer_0__m_axi_s2mm_wready = w_net__HP1_AXI_Matrix_0__us0_wready ;

    assign w_net__HP1_AXI_Matrix_0__us1_arready = w_port__HP1_AXI_Matrix_0__us1_arready ;
    assign w_port__NPU_HP1_Adapter_0__m_axi_arready = w_net__HP1_AXI_Matrix_0__us1_arready ;

    assign w_net__HP1_AXI_Matrix_0__us1_awready = w_port__HP1_AXI_Matrix_0__us1_awready ;
    assign w_port__NPU_HP1_Adapter_0__m_axi_awready = w_net__HP1_AXI_Matrix_0__us1_awready ;

    assign w_net__HP1_AXI_Matrix_0__us1_bid = w_port__HP1_AXI_Matrix_0__us1_bid ;
    assign w_port__NPU_HP1_Adapter_0__m_axi_bid = w_net__HP1_AXI_Matrix_0__us1_bid ;

    assign w_net__HP1_AXI_Matrix_0__us1_bresp = w_port__HP1_AXI_Matrix_0__us1_bresp ;
    assign w_port__NPU_HP1_Adapter_0__m_axi_bresp = w_net__HP1_AXI_Matrix_0__us1_bresp ;

    assign w_net__HP1_AXI_Matrix_0__us1_bvalid = w_port__HP1_AXI_Matrix_0__us1_bvalid ;
    assign w_port__NPU_HP1_Adapter_0__m_axi_bvalid = w_net__HP1_AXI_Matrix_0__us1_bvalid ;

    assign w_net__HP1_AXI_Matrix_0__us1_rdata = w_port__HP1_AXI_Matrix_0__us1_rdata ;
    assign w_port__NPU_HP1_Adapter_0__m_axi_rdata = w_net__HP1_AXI_Matrix_0__us1_rdata ;

    assign w_net__HP1_AXI_Matrix_0__us1_rid = w_port__HP1_AXI_Matrix_0__us1_rid ;
    assign w_port__NPU_HP1_Adapter_0__m_axi_rid = w_net__HP1_AXI_Matrix_0__us1_rid ;

    assign w_net__HP1_AXI_Matrix_0__us1_rlast = w_port__HP1_AXI_Matrix_0__us1_rlast ;
    assign w_port__NPU_HP1_Adapter_0__m_axi_rlast = w_net__HP1_AXI_Matrix_0__us1_rlast ;

    assign w_net__HP1_AXI_Matrix_0__us1_rresp = w_port__HP1_AXI_Matrix_0__us1_rresp ;
    assign w_port__NPU_HP1_Adapter_0__m_axi_rresp = w_net__HP1_AXI_Matrix_0__us1_rresp ;

    assign w_net__HP1_AXI_Matrix_0__us1_rvalid = w_port__HP1_AXI_Matrix_0__us1_rvalid ;
    assign w_port__NPU_HP1_Adapter_0__m_axi_rvalid = w_net__HP1_AXI_Matrix_0__us1_rvalid ;

    assign w_net__HP1_AXI_Matrix_0__us1_wready = w_port__HP1_AXI_Matrix_0__us1_wready ;
    assign w_port__NPU_HP1_Adapter_0__m_axi_wready = w_net__HP1_AXI_Matrix_0__us1_wready ;

    assign w_net__HP1_Protocol_Converter_0__ds_axi_araddr = w_port__HP1_Protocol_Converter_0__ds_axi_araddr ;
    assign w_port__ARM_Processor_System_0__slave_hp1_axi_araddr = w_net__HP1_Protocol_Converter_0__ds_axi_araddr ;

    assign w_net__HP1_Protocol_Converter_0__ds_axi_arburst = w_port__HP1_Protocol_Converter_0__ds_axi_arburst ;
    assign w_port__ARM_Processor_System_0__slave_hp1_axi_arburst = w_net__HP1_Protocol_Converter_0__ds_axi_arburst ;

    assign w_net__HP1_Protocol_Converter_0__ds_axi_arcache = w_port__HP1_Protocol_Converter_0__ds_axi_arcache ;
    assign w_port__ARM_Processor_System_0__slave_hp1_axi_arcache = w_net__HP1_Protocol_Converter_0__ds_axi_arcache ;

    assign w_net__HP1_Protocol_Converter_0__ds_axi_arid = w_port__HP1_Protocol_Converter_0__ds_axi_arid ;
    assign w_port__ARM_Processor_System_0__slave_hp1_axi_arid = w_net__HP1_Protocol_Converter_0__ds_axi_arid ;

    assign w_net__HP1_Protocol_Converter_0__ds_axi_arlen = w_port__HP1_Protocol_Converter_0__ds_axi_arlen ;
    assign w_port__ARM_Processor_System_0__slave_hp1_axi_arlen = w_net__HP1_Protocol_Converter_0__ds_axi_arlen ;

    assign w_net__HP1_Protocol_Converter_0__ds_axi_arlock = w_port__HP1_Protocol_Converter_0__ds_axi_arlock ;
    assign w_port__ARM_Processor_System_0__slave_hp1_axi_arlock = w_net__HP1_Protocol_Converter_0__ds_axi_arlock ;

    assign w_net__HP1_Protocol_Converter_0__ds_axi_arprot = w_port__HP1_Protocol_Converter_0__ds_axi_arprot ;
    assign w_port__ARM_Processor_System_0__slave_hp1_axi_arprot = w_net__HP1_Protocol_Converter_0__ds_axi_arprot ;

    assign w_net__HP1_Protocol_Converter_0__ds_axi_arqos = w_port__HP1_Protocol_Converter_0__ds_axi_arqos ;
    assign w_port__ARM_Processor_System_0__slave_hp1_axi_arqos = w_net__HP1_Protocol_Converter_0__ds_axi_arqos ;

    assign w_net__HP1_Protocol_Converter_0__ds_axi_arsize = w_port__HP1_Protocol_Converter_0__ds_axi_arsize ;
    assign w_port__ARM_Processor_System_0__slave_hp1_axi_arsize = w_net__HP1_Protocol_Converter_0__ds_axi_arsize ;

    assign w_net__HP1_Protocol_Converter_0__ds_axi_arvalid = w_port__HP1_Protocol_Converter_0__ds_axi_arvalid ;
    assign w_port__ARM_Processor_System_0__slave_hp1_axi_arvalid = w_net__HP1_Protocol_Converter_0__ds_axi_arvalid ;

    assign w_net__HP1_Protocol_Converter_0__ds_axi_awaddr = w_port__HP1_Protocol_Converter_0__ds_axi_awaddr ;
    assign w_port__ARM_Processor_System_0__slave_hp1_axi_awaddr = w_net__HP1_Protocol_Converter_0__ds_axi_awaddr ;

    assign w_net__HP1_Protocol_Converter_0__ds_axi_awburst = w_port__HP1_Protocol_Converter_0__ds_axi_awburst ;
    assign w_port__ARM_Processor_System_0__slave_hp1_axi_awburst = w_net__HP1_Protocol_Converter_0__ds_axi_awburst ;

    assign w_net__HP1_Protocol_Converter_0__ds_axi_awcache = w_port__HP1_Protocol_Converter_0__ds_axi_awcache ;
    assign w_port__ARM_Processor_System_0__slave_hp1_axi_awcache = w_net__HP1_Protocol_Converter_0__ds_axi_awcache ;

    assign w_net__HP1_Protocol_Converter_0__ds_axi_awid = w_port__HP1_Protocol_Converter_0__ds_axi_awid ;
    assign w_port__ARM_Processor_System_0__slave_hp1_axi_awid = w_net__HP1_Protocol_Converter_0__ds_axi_awid ;

    assign w_net__HP1_Protocol_Converter_0__ds_axi_awlen = w_port__HP1_Protocol_Converter_0__ds_axi_awlen ;
    assign w_port__ARM_Processor_System_0__slave_hp1_axi_awlen = w_net__HP1_Protocol_Converter_0__ds_axi_awlen ;

    assign w_net__HP1_Protocol_Converter_0__ds_axi_awlock = w_port__HP1_Protocol_Converter_0__ds_axi_awlock ;
    assign w_port__ARM_Processor_System_0__slave_hp1_axi_awlock = w_net__HP1_Protocol_Converter_0__ds_axi_awlock ;

    assign w_net__HP1_Protocol_Converter_0__ds_axi_awprot = w_port__HP1_Protocol_Converter_0__ds_axi_awprot ;
    assign w_port__ARM_Processor_System_0__slave_hp1_axi_awprot = w_net__HP1_Protocol_Converter_0__ds_axi_awprot ;

    assign w_net__HP1_Protocol_Converter_0__ds_axi_awqos = w_port__HP1_Protocol_Converter_0__ds_axi_awqos ;
    assign w_port__ARM_Processor_System_0__slave_hp1_axi_awqos = w_net__HP1_Protocol_Converter_0__ds_axi_awqos ;

    assign w_net__HP1_Protocol_Converter_0__ds_axi_awsize = w_port__HP1_Protocol_Converter_0__ds_axi_awsize ;
    assign w_port__ARM_Processor_System_0__slave_hp1_axi_awsize = w_net__HP1_Protocol_Converter_0__ds_axi_awsize ;

    assign w_net__HP1_Protocol_Converter_0__ds_axi_awvalid = w_port__HP1_Protocol_Converter_0__ds_axi_awvalid ;
    assign w_port__ARM_Processor_System_0__slave_hp1_axi_awvalid = w_net__HP1_Protocol_Converter_0__ds_axi_awvalid ;

    assign w_net__HP1_Protocol_Converter_0__ds_axi_bready = w_port__HP1_Protocol_Converter_0__ds_axi_bready ;
    assign w_port__ARM_Processor_System_0__slave_hp1_axi_bready = w_net__HP1_Protocol_Converter_0__ds_axi_bready ;

    assign w_net__HP1_Protocol_Converter_0__ds_axi_rready = w_port__HP1_Protocol_Converter_0__ds_axi_rready ;
    assign w_port__ARM_Processor_System_0__slave_hp1_axi_rready = w_net__HP1_Protocol_Converter_0__ds_axi_rready ;

    assign w_net__HP1_Protocol_Converter_0__ds_axi_wdata = w_port__HP1_Protocol_Converter_0__ds_axi_wdata ;
    assign w_port__ARM_Processor_System_0__slave_hp1_axi_wdata = w_net__HP1_Protocol_Converter_0__ds_axi_wdata ;

    assign w_net__HP1_Protocol_Converter_0__ds_axi_wlast = w_port__HP1_Protocol_Converter_0__ds_axi_wlast ;
    assign w_port__ARM_Processor_System_0__slave_hp1_axi_wlast = w_net__HP1_Protocol_Converter_0__ds_axi_wlast ;

    assign w_net__HP1_Protocol_Converter_0__ds_axi_wstrb = w_port__HP1_Protocol_Converter_0__ds_axi_wstrb ;
    assign w_port__ARM_Processor_System_0__slave_hp1_axi_wstrb = w_net__HP1_Protocol_Converter_0__ds_axi_wstrb ;

    assign w_net__HP1_Protocol_Converter_0__ds_axi_wvalid = w_port__HP1_Protocol_Converter_0__ds_axi_wvalid ;
    assign w_port__ARM_Processor_System_0__slave_hp1_axi_wvalid = w_net__HP1_Protocol_Converter_0__ds_axi_wvalid ;

    assign w_net__HP1_Protocol_Converter_0__us_axi_arready = w_port__HP1_Protocol_Converter_0__us_axi_arready ;
    assign w_port__HP1_AXI_Matrix_0__ds0_arready = w_net__HP1_Protocol_Converter_0__us_axi_arready ;

    assign w_net__HP1_Protocol_Converter_0__us_axi_awready = w_port__HP1_Protocol_Converter_0__us_axi_awready ;
    assign w_port__HP1_AXI_Matrix_0__ds0_awready = w_net__HP1_Protocol_Converter_0__us_axi_awready ;

    assign w_net__HP1_Protocol_Converter_0__us_axi_bid = w_port__HP1_Protocol_Converter_0__us_axi_bid ;
    assign w_port__HP1_AXI_Matrix_0__ds0_bid = w_net__HP1_Protocol_Converter_0__us_axi_bid ;

    assign w_net__HP1_Protocol_Converter_0__us_axi_bresp = w_port__HP1_Protocol_Converter_0__us_axi_bresp ;
    assign w_port__HP1_AXI_Matrix_0__ds0_bresp = w_net__HP1_Protocol_Converter_0__us_axi_bresp ;

    assign w_net__HP1_Protocol_Converter_0__us_axi_bvalid = w_port__HP1_Protocol_Converter_0__us_axi_bvalid ;
    assign w_port__HP1_AXI_Matrix_0__ds0_bvalid = w_net__HP1_Protocol_Converter_0__us_axi_bvalid ;

    assign w_net__HP1_Protocol_Converter_0__us_axi_rdata = w_port__HP1_Protocol_Converter_0__us_axi_rdata ;
    assign w_port__HP1_AXI_Matrix_0__ds0_rdata = w_net__HP1_Protocol_Converter_0__us_axi_rdata ;

    assign w_net__HP1_Protocol_Converter_0__us_axi_rid = w_port__HP1_Protocol_Converter_0__us_axi_rid ;
    assign w_port__HP1_AXI_Matrix_0__ds0_rid = w_net__HP1_Protocol_Converter_0__us_axi_rid ;

    assign w_net__HP1_Protocol_Converter_0__us_axi_rlast = w_port__HP1_Protocol_Converter_0__us_axi_rlast ;
    assign w_port__HP1_AXI_Matrix_0__ds0_rlast = w_net__HP1_Protocol_Converter_0__us_axi_rlast ;

    assign w_net__HP1_Protocol_Converter_0__us_axi_rresp = w_port__HP1_Protocol_Converter_0__us_axi_rresp ;
    assign w_port__HP1_AXI_Matrix_0__ds0_rresp = w_net__HP1_Protocol_Converter_0__us_axi_rresp ;

    assign w_net__HP1_Protocol_Converter_0__us_axi_rvalid = w_port__HP1_Protocol_Converter_0__us_axi_rvalid ;
    assign w_port__HP1_AXI_Matrix_0__ds0_rvalid = w_net__HP1_Protocol_Converter_0__us_axi_rvalid ;

    assign w_net__HP1_Protocol_Converter_0__us_axi_wready = w_port__HP1_Protocol_Converter_0__us_axi_wready ;
    assign w_port__HP1_AXI_Matrix_0__ds0_wready = w_net__HP1_Protocol_Converter_0__us_axi_wready ;

    assign w_net__NPU_Control_Converter_0__ds_axi_araddr = w_port__NPU_Control_Converter_0__ds_axi_araddr ;
    assign w_port__Video_NPU_0__s_axilite_araddr_i = w_net__NPU_Control_Converter_0__ds_axi_araddr ;

    assign w_net__NPU_Control_Converter_0__ds_axi_arprot = w_port__NPU_Control_Converter_0__ds_axi_arprot ;
    assign w_port__Video_NPU_0__s_axilite_arprot_i = w_net__NPU_Control_Converter_0__ds_axi_arprot ;

    assign w_net__NPU_Control_Converter_0__ds_axi_arvalid = w_port__NPU_Control_Converter_0__ds_axi_arvalid ;
    assign w_port__Video_NPU_0__s_axilite_arvalid_i = w_net__NPU_Control_Converter_0__ds_axi_arvalid ;

    assign w_net__NPU_Control_Converter_0__ds_axi_awaddr = w_port__NPU_Control_Converter_0__ds_axi_awaddr ;
    assign w_port__Video_NPU_0__s_axilite_awaddr_i = w_net__NPU_Control_Converter_0__ds_axi_awaddr ;

    assign w_net__NPU_Control_Converter_0__ds_axi_awprot = w_port__NPU_Control_Converter_0__ds_axi_awprot ;
    assign w_port__Video_NPU_0__s_axilite_awprot_i = w_net__NPU_Control_Converter_0__ds_axi_awprot ;

    assign w_net__NPU_Control_Converter_0__ds_axi_awvalid = w_port__NPU_Control_Converter_0__ds_axi_awvalid ;
    assign w_port__Video_NPU_0__s_axilite_awvalid_i = w_net__NPU_Control_Converter_0__ds_axi_awvalid ;

    assign w_net__NPU_Control_Converter_0__ds_axi_bready = w_port__NPU_Control_Converter_0__ds_axi_bready ;
    assign w_port__Video_NPU_0__s_axilite_bready_i = w_net__NPU_Control_Converter_0__ds_axi_bready ;

    assign w_net__NPU_Control_Converter_0__ds_axi_rready = w_port__NPU_Control_Converter_0__ds_axi_rready ;
    assign w_port__Video_NPU_0__s_axilite_rready_i = w_net__NPU_Control_Converter_0__ds_axi_rready ;

    assign w_net__NPU_Control_Converter_0__ds_axi_wdata = w_port__NPU_Control_Converter_0__ds_axi_wdata ;
    assign w_port__Video_NPU_0__s_axilite_wdata_i = w_net__NPU_Control_Converter_0__ds_axi_wdata ;

    assign w_net__NPU_Control_Converter_0__ds_axi_wstrb = w_port__NPU_Control_Converter_0__ds_axi_wstrb ;
    assign w_port__Video_NPU_0__s_axilite_wstrb_i = w_net__NPU_Control_Converter_0__ds_axi_wstrb ;

    assign w_net__NPU_Control_Converter_0__ds_axi_wvalid = w_port__NPU_Control_Converter_0__ds_axi_wvalid ;
    assign w_port__Video_NPU_0__s_axilite_wvalid_i = w_net__NPU_Control_Converter_0__ds_axi_wvalid ;

    assign w_net__NPU_Control_Converter_0__us_axi_arready = w_port__NPU_Control_Converter_0__us_axi_arready ;
    assign w_port__NPU_Control_Matrix_0__ds0_arready = w_net__NPU_Control_Converter_0__us_axi_arready ;

    assign w_net__NPU_Control_Converter_0__us_axi_awready = w_port__NPU_Control_Converter_0__us_axi_awready ;
    assign w_port__NPU_Control_Matrix_0__ds0_awready = w_net__NPU_Control_Converter_0__us_axi_awready ;

    assign w_net__NPU_Control_Converter_0__us_axi_bid = w_port__NPU_Control_Converter_0__us_axi_bid ;
    assign w_port__NPU_Control_Matrix_0__ds0_bid = w_net__NPU_Control_Converter_0__us_axi_bid ;

    assign w_net__NPU_Control_Converter_0__us_axi_bresp = w_port__NPU_Control_Converter_0__us_axi_bresp ;
    assign w_port__NPU_Control_Matrix_0__ds0_bresp = w_net__NPU_Control_Converter_0__us_axi_bresp ;

    assign w_net__NPU_Control_Converter_0__us_axi_bvalid = w_port__NPU_Control_Converter_0__us_axi_bvalid ;
    assign w_port__NPU_Control_Matrix_0__ds0_bvalid = w_net__NPU_Control_Converter_0__us_axi_bvalid ;

    assign w_net__NPU_Control_Converter_0__us_axi_rdata = w_port__NPU_Control_Converter_0__us_axi_rdata ;
    assign w_port__NPU_Control_Matrix_0__ds0_rdata = w_net__NPU_Control_Converter_0__us_axi_rdata ;

    assign w_net__NPU_Control_Converter_0__us_axi_rid = w_port__NPU_Control_Converter_0__us_axi_rid ;
    assign w_port__NPU_Control_Matrix_0__ds0_rid = w_net__NPU_Control_Converter_0__us_axi_rid ;

    assign w_net__NPU_Control_Converter_0__us_axi_rlast = w_port__NPU_Control_Converter_0__us_axi_rlast ;
    assign w_port__NPU_Control_Matrix_0__ds0_rlast = w_net__NPU_Control_Converter_0__us_axi_rlast ;

    assign w_net__NPU_Control_Converter_0__us_axi_rresp = w_port__NPU_Control_Converter_0__us_axi_rresp ;
    assign w_port__NPU_Control_Matrix_0__ds0_rresp = w_net__NPU_Control_Converter_0__us_axi_rresp ;

    assign w_net__NPU_Control_Converter_0__us_axi_rvalid = w_port__NPU_Control_Converter_0__us_axi_rvalid ;
    assign w_port__NPU_Control_Matrix_0__ds0_rvalid = w_net__NPU_Control_Converter_0__us_axi_rvalid ;

    assign w_net__NPU_Control_Converter_0__us_axi_wready = w_port__NPU_Control_Converter_0__us_axi_wready ;
    assign w_port__NPU_Control_Matrix_0__ds0_wready = w_net__NPU_Control_Converter_0__us_axi_wready ;

    assign w_net__NPU_Control_Matrix_0__ds0_araddr = w_port__NPU_Control_Matrix_0__ds0_araddr ;
    assign w_port__NPU_Control_Converter_0__us_axi_araddr = w_net__NPU_Control_Matrix_0__ds0_araddr ;

    assign w_net__NPU_Control_Matrix_0__ds0_arburst = w_port__NPU_Control_Matrix_0__ds0_arburst ;
    assign w_port__NPU_Control_Converter_0__us_axi_arburst = w_net__NPU_Control_Matrix_0__ds0_arburst ;

    assign w_net__NPU_Control_Matrix_0__ds0_arcache = w_port__NPU_Control_Matrix_0__ds0_arcache ;
    assign w_port__NPU_Control_Converter_0__us_axi_arcache = w_net__NPU_Control_Matrix_0__ds0_arcache ;

    assign w_net__NPU_Control_Matrix_0__ds0_arid = w_port__NPU_Control_Matrix_0__ds0_arid ;
    assign w_port__NPU_Control_Converter_0__us_axi_arid = w_net__NPU_Control_Matrix_0__ds0_arid ;

    assign w_net__NPU_Control_Matrix_0__ds0_arlen = w_port__NPU_Control_Matrix_0__ds0_arlen ;
    assign w_port__NPU_Control_Converter_0__us_axi_arlen = w_net__NPU_Control_Matrix_0__ds0_arlen ;

    assign w_net__NPU_Control_Matrix_0__ds0_arlock = w_port__NPU_Control_Matrix_0__ds0_arlock ;
    assign w_port__NPU_Control_Converter_0__us_axi_arlock = w_net__NPU_Control_Matrix_0__ds0_arlock ;

    assign w_net__NPU_Control_Matrix_0__ds0_arprot = w_port__NPU_Control_Matrix_0__ds0_arprot ;
    assign w_port__NPU_Control_Converter_0__us_axi_arprot = w_net__NPU_Control_Matrix_0__ds0_arprot ;

    assign w_net__NPU_Control_Matrix_0__ds0_arqos = w_port__NPU_Control_Matrix_0__ds0_arqos ;
    assign w_port__NPU_Control_Converter_0__us_axi_arqos = w_net__NPU_Control_Matrix_0__ds0_arqos ;

    assign w_net__NPU_Control_Matrix_0__ds0_arsize = w_port__NPU_Control_Matrix_0__ds0_arsize ;
    assign w_port__NPU_Control_Converter_0__us_axi_arsize = w_net__NPU_Control_Matrix_0__ds0_arsize ;

    assign w_net__NPU_Control_Matrix_0__ds0_arvalid = w_port__NPU_Control_Matrix_0__ds0_arvalid ;
    assign w_port__NPU_Control_Converter_0__us_axi_arvalid = w_net__NPU_Control_Matrix_0__ds0_arvalid ;

    assign w_net__NPU_Control_Matrix_0__ds0_awaddr = w_port__NPU_Control_Matrix_0__ds0_awaddr ;
    assign w_port__NPU_Control_Converter_0__us_axi_awaddr = w_net__NPU_Control_Matrix_0__ds0_awaddr ;

    assign w_net__NPU_Control_Matrix_0__ds0_awburst = w_port__NPU_Control_Matrix_0__ds0_awburst ;
    assign w_port__NPU_Control_Converter_0__us_axi_awburst = w_net__NPU_Control_Matrix_0__ds0_awburst ;

    assign w_net__NPU_Control_Matrix_0__ds0_awcache = w_port__NPU_Control_Matrix_0__ds0_awcache ;
    assign w_port__NPU_Control_Converter_0__us_axi_awcache = w_net__NPU_Control_Matrix_0__ds0_awcache ;

    assign w_net__NPU_Control_Matrix_0__ds0_awid = w_port__NPU_Control_Matrix_0__ds0_awid ;
    assign w_port__NPU_Control_Converter_0__us_axi_awid = w_net__NPU_Control_Matrix_0__ds0_awid ;

    assign w_net__NPU_Control_Matrix_0__ds0_awlen = w_port__NPU_Control_Matrix_0__ds0_awlen ;
    assign w_port__NPU_Control_Converter_0__us_axi_awlen = w_net__NPU_Control_Matrix_0__ds0_awlen ;

    assign w_net__NPU_Control_Matrix_0__ds0_awlock = w_port__NPU_Control_Matrix_0__ds0_awlock ;
    assign w_port__NPU_Control_Converter_0__us_axi_awlock = w_net__NPU_Control_Matrix_0__ds0_awlock ;

    assign w_net__NPU_Control_Matrix_0__ds0_awprot = w_port__NPU_Control_Matrix_0__ds0_awprot ;
    assign w_port__NPU_Control_Converter_0__us_axi_awprot = w_net__NPU_Control_Matrix_0__ds0_awprot ;

    assign w_net__NPU_Control_Matrix_0__ds0_awqos = w_port__NPU_Control_Matrix_0__ds0_awqos ;
    assign w_port__NPU_Control_Converter_0__us_axi_awqos = w_net__NPU_Control_Matrix_0__ds0_awqos ;

    assign w_net__NPU_Control_Matrix_0__ds0_awsize = w_port__NPU_Control_Matrix_0__ds0_awsize ;
    assign w_port__NPU_Control_Converter_0__us_axi_awsize = w_net__NPU_Control_Matrix_0__ds0_awsize ;

    assign w_net__NPU_Control_Matrix_0__ds0_awvalid = w_port__NPU_Control_Matrix_0__ds0_awvalid ;
    assign w_port__NPU_Control_Converter_0__us_axi_awvalid = w_net__NPU_Control_Matrix_0__ds0_awvalid ;

    assign w_net__NPU_Control_Matrix_0__ds0_bready = w_port__NPU_Control_Matrix_0__ds0_bready ;
    assign w_port__NPU_Control_Converter_0__us_axi_bready = w_net__NPU_Control_Matrix_0__ds0_bready ;

    assign w_net__NPU_Control_Matrix_0__ds0_rready = w_port__NPU_Control_Matrix_0__ds0_rready ;
    assign w_port__NPU_Control_Converter_0__us_axi_rready = w_net__NPU_Control_Matrix_0__ds0_rready ;

    assign w_net__NPU_Control_Matrix_0__ds0_wdata = w_port__NPU_Control_Matrix_0__ds0_wdata ;
    assign w_port__NPU_Control_Converter_0__us_axi_wdata = w_net__NPU_Control_Matrix_0__ds0_wdata ;

    assign w_net__NPU_Control_Matrix_0__ds0_wlast = w_port__NPU_Control_Matrix_0__ds0_wlast ;
    assign w_port__NPU_Control_Converter_0__us_axi_wlast = w_net__NPU_Control_Matrix_0__ds0_wlast ;

    assign w_net__NPU_Control_Matrix_0__ds0_wstrb = w_port__NPU_Control_Matrix_0__ds0_wstrb ;
    assign w_port__NPU_Control_Converter_0__us_axi_wstrb = w_net__NPU_Control_Matrix_0__ds0_wstrb ;

    assign w_net__NPU_Control_Matrix_0__ds0_wvalid = w_port__NPU_Control_Matrix_0__ds0_wvalid ;
    assign w_port__NPU_Control_Converter_0__us_axi_wvalid = w_net__NPU_Control_Matrix_0__ds0_wvalid ;

    assign w_net__NPU_Control_Matrix_0__us0_arready = w_port__NPU_Control_Matrix_0__us0_arready ;
    assign w_port__ARM_Processor_System_0__master_gp1_axi_arready = w_net__NPU_Control_Matrix_0__us0_arready ;

    assign w_net__NPU_Control_Matrix_0__us0_awready = w_port__NPU_Control_Matrix_0__us0_awready ;
    assign w_port__ARM_Processor_System_0__master_gp1_axi_awready = w_net__NPU_Control_Matrix_0__us0_awready ;

    assign w_net__NPU_Control_Matrix_0__us0_bid = w_port__NPU_Control_Matrix_0__us0_bid ;
    assign w_port__ARM_Processor_System_0__master_gp1_axi_bid = w_net__NPU_Control_Matrix_0__us0_bid ;

    assign w_net__NPU_Control_Matrix_0__us0_bresp = w_port__NPU_Control_Matrix_0__us0_bresp ;
    assign w_port__ARM_Processor_System_0__master_gp1_axi_bresp = w_net__NPU_Control_Matrix_0__us0_bresp ;

    assign w_net__NPU_Control_Matrix_0__us0_bvalid = w_port__NPU_Control_Matrix_0__us0_bvalid ;
    assign w_port__ARM_Processor_System_0__master_gp1_axi_bvalid = w_net__NPU_Control_Matrix_0__us0_bvalid ;

    assign w_net__NPU_Control_Matrix_0__us0_rdata = w_port__NPU_Control_Matrix_0__us0_rdata ;
    assign w_port__ARM_Processor_System_0__master_gp1_axi_rdata = w_net__NPU_Control_Matrix_0__us0_rdata ;

    assign w_net__NPU_Control_Matrix_0__us0_rid = w_port__NPU_Control_Matrix_0__us0_rid ;
    assign w_port__ARM_Processor_System_0__master_gp1_axi_rid = w_net__NPU_Control_Matrix_0__us0_rid ;

    assign w_net__NPU_Control_Matrix_0__us0_rlast = w_port__NPU_Control_Matrix_0__us0_rlast ;
    assign w_port__ARM_Processor_System_0__master_gp1_axi_rlast = w_net__NPU_Control_Matrix_0__us0_rlast ;

    assign w_net__NPU_Control_Matrix_0__us0_rresp = w_port__NPU_Control_Matrix_0__us0_rresp ;
    assign w_port__ARM_Processor_System_0__master_gp1_axi_rresp = w_net__NPU_Control_Matrix_0__us0_rresp ;

    assign w_net__NPU_Control_Matrix_0__us0_rvalid = w_port__NPU_Control_Matrix_0__us0_rvalid ;
    assign w_port__ARM_Processor_System_0__master_gp1_axi_rvalid = w_net__NPU_Control_Matrix_0__us0_rvalid ;

    assign w_net__NPU_Control_Matrix_0__us0_wready = w_port__NPU_Control_Matrix_0__us0_wready ;
    assign w_port__ARM_Processor_System_0__master_gp1_axi_wready = w_net__NPU_Control_Matrix_0__us0_wready ;

    assign w_net__NPU_HP1_Adapter_0__m_axi_araddr = w_port__NPU_HP1_Adapter_0__m_axi_araddr ;
    assign w_port__HP1_AXI_Matrix_0__us1_araddr = w_net__NPU_HP1_Adapter_0__m_axi_araddr ;

    assign w_net__NPU_HP1_Adapter_0__m_axi_arburst = w_port__NPU_HP1_Adapter_0__m_axi_arburst ;
    assign w_port__HP1_AXI_Matrix_0__us1_arburst = w_net__NPU_HP1_Adapter_0__m_axi_arburst ;

    assign w_net__NPU_HP1_Adapter_0__m_axi_arcache = w_port__NPU_HP1_Adapter_0__m_axi_arcache ;
    assign w_port__HP1_AXI_Matrix_0__us1_arcache = w_net__NPU_HP1_Adapter_0__m_axi_arcache ;

    assign w_net__NPU_HP1_Adapter_0__m_axi_arid = w_port__NPU_HP1_Adapter_0__m_axi_arid ;
    assign w_port__HP1_AXI_Matrix_0__us1_arid = w_net__NPU_HP1_Adapter_0__m_axi_arid ;

    assign w_net__NPU_HP1_Adapter_0__m_axi_arlen = w_port__NPU_HP1_Adapter_0__m_axi_arlen ;
    assign w_port__HP1_AXI_Matrix_0__us1_arlen = w_net__NPU_HP1_Adapter_0__m_axi_arlen ;

    assign w_net__NPU_HP1_Adapter_0__m_axi_arlock = w_port__NPU_HP1_Adapter_0__m_axi_arlock ;
    assign w_port__HP1_AXI_Matrix_0__us1_arlock = w_net__NPU_HP1_Adapter_0__m_axi_arlock ;

    assign w_net__NPU_HP1_Adapter_0__m_axi_arprot = w_port__NPU_HP1_Adapter_0__m_axi_arprot ;
    assign w_port__HP1_AXI_Matrix_0__us1_arprot = w_net__NPU_HP1_Adapter_0__m_axi_arprot ;

    assign w_net__NPU_HP1_Adapter_0__m_axi_arqos = w_port__NPU_HP1_Adapter_0__m_axi_arqos ;
    assign w_port__HP1_AXI_Matrix_0__us1_arqos = w_net__NPU_HP1_Adapter_0__m_axi_arqos ;

    assign w_net__NPU_HP1_Adapter_0__m_axi_arsize = w_port__NPU_HP1_Adapter_0__m_axi_arsize ;
    assign w_port__HP1_AXI_Matrix_0__us1_arsize = w_net__NPU_HP1_Adapter_0__m_axi_arsize ;

    assign w_net__NPU_HP1_Adapter_0__m_axi_arvalid = w_port__NPU_HP1_Adapter_0__m_axi_arvalid ;
    assign w_port__HP1_AXI_Matrix_0__us1_arvalid = w_net__NPU_HP1_Adapter_0__m_axi_arvalid ;

    assign w_net__NPU_HP1_Adapter_0__m_axi_awaddr = w_port__NPU_HP1_Adapter_0__m_axi_awaddr ;
    assign w_port__HP1_AXI_Matrix_0__us1_awaddr = w_net__NPU_HP1_Adapter_0__m_axi_awaddr ;

    assign w_net__NPU_HP1_Adapter_0__m_axi_awburst = w_port__NPU_HP1_Adapter_0__m_axi_awburst ;
    assign w_port__HP1_AXI_Matrix_0__us1_awburst = w_net__NPU_HP1_Adapter_0__m_axi_awburst ;

    assign w_net__NPU_HP1_Adapter_0__m_axi_awcache = w_port__NPU_HP1_Adapter_0__m_axi_awcache ;
    assign w_port__HP1_AXI_Matrix_0__us1_awcache = w_net__NPU_HP1_Adapter_0__m_axi_awcache ;

    assign w_net__NPU_HP1_Adapter_0__m_axi_awid = w_port__NPU_HP1_Adapter_0__m_axi_awid ;
    assign w_port__HP1_AXI_Matrix_0__us1_awid = w_net__NPU_HP1_Adapter_0__m_axi_awid ;

    assign w_net__NPU_HP1_Adapter_0__m_axi_awlen = w_port__NPU_HP1_Adapter_0__m_axi_awlen ;
    assign w_port__HP1_AXI_Matrix_0__us1_awlen = w_net__NPU_HP1_Adapter_0__m_axi_awlen ;

    assign w_net__NPU_HP1_Adapter_0__m_axi_awlock = w_port__NPU_HP1_Adapter_0__m_axi_awlock ;
    assign w_port__HP1_AXI_Matrix_0__us1_awlock = w_net__NPU_HP1_Adapter_0__m_axi_awlock ;

    assign w_net__NPU_HP1_Adapter_0__m_axi_awprot = w_port__NPU_HP1_Adapter_0__m_axi_awprot ;
    assign w_port__HP1_AXI_Matrix_0__us1_awprot = w_net__NPU_HP1_Adapter_0__m_axi_awprot ;

    assign w_net__NPU_HP1_Adapter_0__m_axi_awqos = w_port__NPU_HP1_Adapter_0__m_axi_awqos ;
    assign w_port__HP1_AXI_Matrix_0__us1_awqos = w_net__NPU_HP1_Adapter_0__m_axi_awqos ;

    assign w_net__NPU_HP1_Adapter_0__m_axi_awsize = w_port__NPU_HP1_Adapter_0__m_axi_awsize ;
    assign w_port__HP1_AXI_Matrix_0__us1_awsize = w_net__NPU_HP1_Adapter_0__m_axi_awsize ;

    assign w_net__NPU_HP1_Adapter_0__m_axi_awvalid = w_port__NPU_HP1_Adapter_0__m_axi_awvalid ;
    assign w_port__HP1_AXI_Matrix_0__us1_awvalid = w_net__NPU_HP1_Adapter_0__m_axi_awvalid ;

    assign w_net__NPU_HP1_Adapter_0__m_axi_bready = w_port__NPU_HP1_Adapter_0__m_axi_bready ;
    assign w_port__HP1_AXI_Matrix_0__us1_bready = w_net__NPU_HP1_Adapter_0__m_axi_bready ;

    assign w_net__NPU_HP1_Adapter_0__m_axi_rready = w_port__NPU_HP1_Adapter_0__m_axi_rready ;
    assign w_port__HP1_AXI_Matrix_0__us1_rready = w_net__NPU_HP1_Adapter_0__m_axi_rready ;

    assign w_net__NPU_HP1_Adapter_0__m_axi_wdata = w_port__NPU_HP1_Adapter_0__m_axi_wdata ;
    assign w_port__HP1_AXI_Matrix_0__us1_wdata = w_net__NPU_HP1_Adapter_0__m_axi_wdata ;

    assign w_net__NPU_HP1_Adapter_0__m_axi_wlast = w_port__NPU_HP1_Adapter_0__m_axi_wlast ;
    assign w_port__HP1_AXI_Matrix_0__us1_wlast = w_net__NPU_HP1_Adapter_0__m_axi_wlast ;

    assign w_net__NPU_HP1_Adapter_0__m_axi_wstrb = w_port__NPU_HP1_Adapter_0__m_axi_wstrb ;
    assign w_port__HP1_AXI_Matrix_0__us1_wstrb = w_net__NPU_HP1_Adapter_0__m_axi_wstrb ;

    assign w_net__NPU_HP1_Adapter_0__m_axi_wvalid = w_port__NPU_HP1_Adapter_0__m_axi_wvalid ;
    assign w_port__HP1_AXI_Matrix_0__us1_wvalid = w_net__NPU_HP1_Adapter_0__m_axi_wvalid ;

    assign w_net__NPU_HP1_Adapter_0__s_axi_arready = w_port__NPU_HP1_Adapter_0__s_axi_arready ;
    assign w_port__Video_NPU_0__m_axi_arready_soft_i = w_net__NPU_HP1_Adapter_0__s_axi_arready ;

    assign w_net__NPU_HP1_Adapter_0__s_axi_awready = w_port__NPU_HP1_Adapter_0__s_axi_awready ;
    assign w_port__Video_NPU_0__m_axi_awready_soft_i = w_net__NPU_HP1_Adapter_0__s_axi_awready ;

    assign w_net__NPU_HP1_Adapter_0__s_axi_bid = w_port__NPU_HP1_Adapter_0__s_axi_bid ;
    assign w_port__Video_NPU_0__m_axi_bid_soft_i = w_net__NPU_HP1_Adapter_0__s_axi_bid ;

    assign w_net__NPU_HP1_Adapter_0__s_axi_bresp = w_port__NPU_HP1_Adapter_0__s_axi_bresp ;
    assign w_port__Video_NPU_0__m_axi_bresp_soft_i = w_net__NPU_HP1_Adapter_0__s_axi_bresp ;

    assign w_net__NPU_HP1_Adapter_0__s_axi_bvalid = w_port__NPU_HP1_Adapter_0__s_axi_bvalid ;
    assign w_port__Video_NPU_0__m_axi_bvalid_soft_i = w_net__NPU_HP1_Adapter_0__s_axi_bvalid ;

    assign w_net__NPU_HP1_Adapter_0__s_axi_rdata = w_port__NPU_HP1_Adapter_0__s_axi_rdata ;
    assign w_port__Video_NPU_0__m_axi_rdata_soft_i = w_net__NPU_HP1_Adapter_0__s_axi_rdata ;

    assign w_net__NPU_HP1_Adapter_0__s_axi_rid = w_port__NPU_HP1_Adapter_0__s_axi_rid ;
    assign w_port__Video_NPU_0__m_axi_rid_soft_i = w_net__NPU_HP1_Adapter_0__s_axi_rid ;

    assign w_net__NPU_HP1_Adapter_0__s_axi_rlast = w_port__NPU_HP1_Adapter_0__s_axi_rlast ;
    assign w_port__Video_NPU_0__m_axi_rlast_soft_i = w_net__NPU_HP1_Adapter_0__s_axi_rlast ;

    assign w_net__NPU_HP1_Adapter_0__s_axi_rresp = w_port__NPU_HP1_Adapter_0__s_axi_rresp ;
    assign w_port__Video_NPU_0__m_axi_rresp_soft_i = w_net__NPU_HP1_Adapter_0__s_axi_rresp ;

    assign w_net__NPU_HP1_Adapter_0__s_axi_rvalid = w_port__NPU_HP1_Adapter_0__s_axi_rvalid ;
    assign w_port__Video_NPU_0__m_axi_rvalid_soft_i = w_net__NPU_HP1_Adapter_0__s_axi_rvalid ;

    assign w_net__NPU_HP1_Adapter_0__s_axi_wready = w_port__NPU_HP1_Adapter_0__s_axi_wready ;
    assign w_port__Video_NPU_0__m_axi_wready_soft_i = w_net__NPU_HP1_Adapter_0__s_axi_wready ;

    assign w_net__Processor_System_Reset_0__interconnect_aresetn = w_port__Processor_System_Reset_0__interconnect_aresetn ;
    assign w_port__AXI_Protocol_Converter_0__aresetn = w_net__Processor_System_Reset_0__interconnect_aresetn ;

    assign w_net__Processor_System_Reset_0__peripheral_aresetn = w_port__Processor_System_Reset_0__peripheral_aresetn ;
    assign axi_reset_n = w_net__Processor_System_Reset_0__peripheral_aresetn ;
    assign w_port__adc_axis_source_0__rst_n = w_net__Processor_System_Reset_0__peripheral_aresetn ;
    assign w_port__axi4lite_slave_0__rst_n = w_net__Processor_System_Reset_0__peripheral_aresetn ;
    assign w_port__AXI_Lite_Matrix_0__aresetn = w_net__Processor_System_Reset_0__peripheral_aresetn ;
    assign w_port__adc_fdma_writer_0__axi_resetn = w_net__Processor_System_Reset_0__peripheral_aresetn ;
    assign w_port__HP1_AXI_Matrix_0__aresetn = w_net__Processor_System_Reset_0__peripheral_aresetn ;
    assign w_port__HP1_Protocol_Converter_0__aresetn = w_net__Processor_System_Reset_0__peripheral_aresetn ;
    assign w_port__HDMI_VTG_0__arst_n = w_net__Processor_System_Reset_0__peripheral_aresetn ;
    assign w_port__HDMI_Reset_0__axi_reset_n = w_net__Processor_System_Reset_0__peripheral_aresetn ;
    assign w_port__Video_NPU_0__S_AXILite_AResetn = w_net__Processor_System_Reset_0__peripheral_aresetn ;
    assign w_port__Video_NPU_0__M_AXI_AResetn = w_net__Processor_System_Reset_0__peripheral_aresetn ;
    assign w_port__NPU_HP1_Adapter_0__aresetn = w_net__Processor_System_Reset_0__peripheral_aresetn ;
    assign w_port__NPU_Control_Matrix_0__aresetn = w_net__Processor_System_Reset_0__peripheral_aresetn ;
    assign w_port__NPU_Control_Converter_0__aresetn = w_net__Processor_System_Reset_0__peripheral_aresetn ;

    assign w_net__VDMA_0__axi_lite_arready = w_port__VDMA_0__axi_lite_arready ;
    assign w_port__AXI_Lite_Matrix_0__ds3_arready = w_net__VDMA_0__axi_lite_arready ;

    assign w_net__VDMA_0__axi_lite_awready = w_port__VDMA_0__axi_lite_awready ;
    assign w_port__AXI_Lite_Matrix_0__ds3_awready = w_net__VDMA_0__axi_lite_awready ;

    assign w_net__VDMA_0__axi_lite_bresp = w_port__VDMA_0__axi_lite_bresp ;
    assign w_port__AXI_Lite_Matrix_0__ds3_bresp = w_net__VDMA_0__axi_lite_bresp ;

    assign w_net__VDMA_0__axi_lite_bvalid = w_port__VDMA_0__axi_lite_bvalid ;
    assign w_port__AXI_Lite_Matrix_0__ds3_bvalid = w_net__VDMA_0__axi_lite_bvalid ;

    assign w_net__VDMA_0__axi_lite_rdata = w_port__VDMA_0__axi_lite_rdata ;
    assign w_port__AXI_Lite_Matrix_0__ds3_rdata = w_net__VDMA_0__axi_lite_rdata ;

    assign w_net__VDMA_0__axi_lite_rresp = w_port__VDMA_0__axi_lite_rresp ;
    assign w_port__AXI_Lite_Matrix_0__ds3_rresp = w_net__VDMA_0__axi_lite_rresp ;

    assign w_net__VDMA_0__axi_lite_rvalid = w_port__VDMA_0__axi_lite_rvalid ;
    assign w_port__AXI_Lite_Matrix_0__ds3_rvalid = w_net__VDMA_0__axi_lite_rvalid ;

    assign w_net__VDMA_0__axi_lite_wready = w_port__VDMA_0__axi_lite_wready ;
    assign w_port__AXI_Lite_Matrix_0__ds3_wready = w_net__VDMA_0__axi_lite_wready ;

    assign w_net__VDMA_0__m_axi_mm2s_araddr = w_port__VDMA_0__m_axi_mm2s_araddr ;
    assign w_port__HDMI_HP0_Protocol_Converter_0__us_axi_araddr = {1'b0,w_net__VDMA_0__m_axi_mm2s_araddr} ;

    assign w_net__VDMA_0__m_axi_mm2s_arburst = w_port__VDMA_0__m_axi_mm2s_arburst ;
    assign w_port__HDMI_HP0_Protocol_Converter_0__us_axi_arburst = w_net__VDMA_0__m_axi_mm2s_arburst ;

    assign w_net__VDMA_0__m_axi_mm2s_arcache = w_port__VDMA_0__m_axi_mm2s_arcache ;
    assign w_port__HDMI_HP0_Protocol_Converter_0__us_axi_arcache = w_net__VDMA_0__m_axi_mm2s_arcache ;

    assign w_net__VDMA_0__m_axi_mm2s_arlen = w_port__VDMA_0__m_axi_mm2s_arlen ;
    assign w_port__HDMI_HP0_Protocol_Converter_0__us_axi_arlen = w_net__VDMA_0__m_axi_mm2s_arlen ;

    assign w_net__VDMA_0__m_axi_mm2s_arprot = w_port__VDMA_0__m_axi_mm2s_arprot ;
    assign w_port__HDMI_HP0_Protocol_Converter_0__us_axi_arprot = w_net__VDMA_0__m_axi_mm2s_arprot ;

    assign w_net__VDMA_0__m_axi_mm2s_arsize = w_port__VDMA_0__m_axi_mm2s_arsize ;
    assign w_port__HDMI_HP0_Protocol_Converter_0__us_axi_arsize = w_net__VDMA_0__m_axi_mm2s_arsize ;

    assign w_net__VDMA_0__m_axi_mm2s_arvalid = w_port__VDMA_0__m_axi_mm2s_arvalid ;
    assign w_port__HDMI_HP0_Protocol_Converter_0__us_axi_arvalid = w_net__VDMA_0__m_axi_mm2s_arvalid ;

    assign w_net__VDMA_0__m_axi_mm2s_rready = w_port__VDMA_0__m_axi_mm2s_rready ;
    assign w_port__HDMI_HP0_Protocol_Converter_0__us_axi_rready = w_net__VDMA_0__m_axi_mm2s_rready ;

    assign w_net__VDMA_0__m_axis_mm2s_tdata = w_port__VDMA_0__m_axis_mm2s_tdata ;
    assign w_port__AXI4_Stream_to_Video_Out_0__s_axis_video_tdata = w_net__VDMA_0__m_axis_mm2s_tdata ;

    assign w_net__VDMA_0__m_axis_mm2s_tlast = w_port__VDMA_0__m_axis_mm2s_tlast ;
    assign w_port__AXI4_Stream_to_Video_Out_0__s_axis_video_tlast = w_net__VDMA_0__m_axis_mm2s_tlast ;

    assign w_net__VDMA_0__m_axis_mm2s_tuser = w_port__VDMA_0__m_axis_mm2s_tuser ;
    assign w_port__AXI4_Stream_to_Video_Out_0__s_axis_video_tuser = w_net__VDMA_0__m_axis_mm2s_tuser ;

    assign w_net__VDMA_0__m_axis_mm2s_tvalid = w_port__VDMA_0__m_axis_mm2s_tvalid ;
    assign w_port__AXI4_Stream_to_Video_Out_0__s_axis_video_tvalid = w_net__VDMA_0__m_axis_mm2s_tvalid ;

    assign w_net__VDMA_0__mm2s_introut = w_port__VDMA_0__mm2s_introut ;
    assign w_port__HDMI_IRQ_Concat_0__In0 = w_net__VDMA_0__mm2s_introut ;

    assign w_net__VDMA_0__s2mm_introut = w_port__VDMA_0__s2mm_introut ;
    assign w_port__HDMI_IRQ_Concat_0__In1 = w_net__VDMA_0__s2mm_introut ;

    assign w_net__Video_NPU_0__m_axi_araddr_soft_o = w_port__Video_NPU_0__m_axi_araddr_soft_o ;
    assign w_port__NPU_HP1_Adapter_0__s_axi_araddr = w_net__Video_NPU_0__m_axi_araddr_soft_o ;

    assign w_net__Video_NPU_0__m_axi_arburst_soft_o = w_port__Video_NPU_0__m_axi_arburst_soft_o ;
    assign w_port__NPU_HP1_Adapter_0__s_axi_arburst = w_net__Video_NPU_0__m_axi_arburst_soft_o ;

    assign w_net__Video_NPU_0__m_axi_arcache_soft_o = w_port__Video_NPU_0__m_axi_arcache_soft_o ;
    assign w_port__NPU_HP1_Adapter_0__s_axi_arcache = w_net__Video_NPU_0__m_axi_arcache_soft_o ;

    assign w_net__Video_NPU_0__m_axi_arid_soft_o = w_port__Video_NPU_0__m_axi_arid_soft_o ;
    assign w_port__NPU_HP1_Adapter_0__s_axi_arid = w_net__Video_NPU_0__m_axi_arid_soft_o ;

    assign w_net__Video_NPU_0__m_axi_arlen_soft_o = w_port__Video_NPU_0__m_axi_arlen_soft_o ;
    assign w_port__NPU_HP1_Adapter_0__s_axi_arlen = w_net__Video_NPU_0__m_axi_arlen_soft_o ;

    assign w_net__Video_NPU_0__m_axi_arlock_soft_o = w_port__Video_NPU_0__m_axi_arlock_soft_o ;
    assign w_port__NPU_HP1_Adapter_0__s_axi_arlock = w_net__Video_NPU_0__m_axi_arlock_soft_o ;

    assign w_net__Video_NPU_0__m_axi_arprot_soft_o = w_port__Video_NPU_0__m_axi_arprot_soft_o ;
    assign w_port__NPU_HP1_Adapter_0__s_axi_arprot = w_net__Video_NPU_0__m_axi_arprot_soft_o ;

    assign w_net__Video_NPU_0__m_axi_arsize_soft_o = w_port__Video_NPU_0__m_axi_arsize_soft_o ;
    assign w_port__NPU_HP1_Adapter_0__s_axi_arsize = w_net__Video_NPU_0__m_axi_arsize_soft_o ;

    assign w_net__Video_NPU_0__m_axi_arvalid_soft_o = w_port__Video_NPU_0__m_axi_arvalid_soft_o ;
    assign w_port__NPU_HP1_Adapter_0__s_axi_arvalid = w_net__Video_NPU_0__m_axi_arvalid_soft_o ;

    assign w_net__Video_NPU_0__m_axi_awaddr_soft_o = w_port__Video_NPU_0__m_axi_awaddr_soft_o ;
    assign w_port__NPU_HP1_Adapter_0__s_axi_awaddr = w_net__Video_NPU_0__m_axi_awaddr_soft_o ;

    assign w_net__Video_NPU_0__m_axi_awburst_soft_o = w_port__Video_NPU_0__m_axi_awburst_soft_o ;
    assign w_port__NPU_HP1_Adapter_0__s_axi_awburst = w_net__Video_NPU_0__m_axi_awburst_soft_o ;

    assign w_net__Video_NPU_0__m_axi_awcache_soft_o = w_port__Video_NPU_0__m_axi_awcache_soft_o ;
    assign w_port__NPU_HP1_Adapter_0__s_axi_awcache = w_net__Video_NPU_0__m_axi_awcache_soft_o ;

    assign w_net__Video_NPU_0__m_axi_awid_soft_o = w_port__Video_NPU_0__m_axi_awid_soft_o ;
    assign w_port__NPU_HP1_Adapter_0__s_axi_awid = w_net__Video_NPU_0__m_axi_awid_soft_o ;

    assign w_net__Video_NPU_0__m_axi_awlen_soft_o = w_port__Video_NPU_0__m_axi_awlen_soft_o ;
    assign w_port__NPU_HP1_Adapter_0__s_axi_awlen = w_net__Video_NPU_0__m_axi_awlen_soft_o ;

    assign w_net__Video_NPU_0__m_axi_awlock_soft_o = w_port__Video_NPU_0__m_axi_awlock_soft_o ;
    assign w_port__NPU_HP1_Adapter_0__s_axi_awlock = w_net__Video_NPU_0__m_axi_awlock_soft_o ;

    assign w_net__Video_NPU_0__m_axi_awprot_soft_o = w_port__Video_NPU_0__m_axi_awprot_soft_o ;
    assign w_port__NPU_HP1_Adapter_0__s_axi_awprot = w_net__Video_NPU_0__m_axi_awprot_soft_o ;

    assign w_net__Video_NPU_0__m_axi_awsize_soft_o = w_port__Video_NPU_0__m_axi_awsize_soft_o ;
    assign w_port__NPU_HP1_Adapter_0__s_axi_awsize = w_net__Video_NPU_0__m_axi_awsize_soft_o ;

    assign w_net__Video_NPU_0__m_axi_awvalid_soft_o = w_port__Video_NPU_0__m_axi_awvalid_soft_o ;
    assign w_port__NPU_HP1_Adapter_0__s_axi_awvalid = w_net__Video_NPU_0__m_axi_awvalid_soft_o ;

    assign w_net__Video_NPU_0__m_axi_bready_soft_o = w_port__Video_NPU_0__m_axi_bready_soft_o ;
    assign w_port__NPU_HP1_Adapter_0__s_axi_bready = w_net__Video_NPU_0__m_axi_bready_soft_o ;

    assign w_net__Video_NPU_0__m_axi_rready_soft_o = w_port__Video_NPU_0__m_axi_rready_soft_o ;
    assign w_port__NPU_HP1_Adapter_0__s_axi_rready = w_net__Video_NPU_0__m_axi_rready_soft_o ;

    assign w_net__Video_NPU_0__m_axi_wdata_soft_o = w_port__Video_NPU_0__m_axi_wdata_soft_o ;
    assign w_port__NPU_HP1_Adapter_0__s_axi_wdata = w_net__Video_NPU_0__m_axi_wdata_soft_o ;

    assign w_net__Video_NPU_0__m_axi_wlast_soft_o = w_port__Video_NPU_0__m_axi_wlast_soft_o ;
    assign w_port__NPU_HP1_Adapter_0__s_axi_wlast = w_net__Video_NPU_0__m_axi_wlast_soft_o ;

    assign w_net__Video_NPU_0__m_axi_wstrb_soft_o = w_port__Video_NPU_0__m_axi_wstrb_soft_o ;
    assign w_port__NPU_HP1_Adapter_0__s_axi_wstrb = w_net__Video_NPU_0__m_axi_wstrb_soft_o ;

    assign w_net__Video_NPU_0__m_axi_wvalid_soft_o = w_port__Video_NPU_0__m_axi_wvalid_soft_o ;
    assign w_port__NPU_HP1_Adapter_0__s_axi_wvalid = w_net__Video_NPU_0__m_axi_wvalid_soft_o ;

    assign w_net__Video_NPU_0__npu_soft_intr = w_port__Video_NPU_0__npu_soft_intr ;
    assign w_port__HDMI_IRQ_Concat_0__In15 = w_net__Video_NPU_0__npu_soft_intr ;

    assign w_net__Video_NPU_0__s_axilite_arready_o = w_port__Video_NPU_0__s_axilite_arready_o ;
    assign w_port__NPU_Control_Converter_0__ds_axi_arready = w_net__Video_NPU_0__s_axilite_arready_o ;

    assign w_net__Video_NPU_0__s_axilite_awready_o = w_port__Video_NPU_0__s_axilite_awready_o ;
    assign w_port__NPU_Control_Converter_0__ds_axi_awready = w_net__Video_NPU_0__s_axilite_awready_o ;

    assign w_net__Video_NPU_0__s_axilite_bresp_o = w_port__Video_NPU_0__s_axilite_bresp_o ;
    assign w_port__NPU_Control_Converter_0__ds_axi_bresp = w_net__Video_NPU_0__s_axilite_bresp_o ;

    assign w_net__Video_NPU_0__s_axilite_bvalid_o = w_port__Video_NPU_0__s_axilite_bvalid_o ;
    assign w_port__NPU_Control_Converter_0__ds_axi_bvalid = w_net__Video_NPU_0__s_axilite_bvalid_o ;

    assign w_net__Video_NPU_0__s_axilite_rdata_o = w_port__Video_NPU_0__s_axilite_rdata_o ;
    assign w_port__NPU_Control_Converter_0__ds_axi_rdata = w_net__Video_NPU_0__s_axilite_rdata_o ;

    assign w_net__Video_NPU_0__s_axilite_rresp_o = w_port__Video_NPU_0__s_axilite_rresp_o ;
    assign w_port__NPU_Control_Converter_0__ds_axi_rresp = w_net__Video_NPU_0__s_axilite_rresp_o ;

    assign w_net__Video_NPU_0__s_axilite_rvalid_o = w_port__Video_NPU_0__s_axilite_rvalid_o ;
    assign w_port__NPU_Control_Converter_0__ds_axi_rvalid = w_net__Video_NPU_0__s_axilite_rvalid_o ;

    assign w_net__Video_NPU_0__s_axilite_wready_o = w_port__Video_NPU_0__s_axilite_wready_o ;
    assign w_port__NPU_Control_Converter_0__ds_axi_wready = w_net__Video_NPU_0__s_axilite_wready_o ;

    assign w_net__adc_axis_source_0__drop_count = w_port__adc_axis_source_0__drop_count ;
    assign w_port__axi4lite_slave_0__fifo_drop_count_in = w_net__adc_axis_source_0__drop_count ;

    assign w_net__adc_axis_source_0__fifo_level = w_port__adc_axis_source_0__fifo_level ;
    assign w_port__axi4lite_slave_0__fifo_level_in = w_net__adc_axis_source_0__fifo_level ;

    assign w_net__adc_axis_source_0__fifo_reset_n = w_port__adc_axis_source_0__fifo_reset_n ;
    assign w_port__axi4lite_slave_0__fifo_ready_in = w_net__adc_axis_source_0__fifo_reset_n ;
    assign w_port__AXIS_Data_FIFO_0__us_aresetn = w_net__adc_axis_source_0__fifo_reset_n ;

    assign w_net__adc_axis_source_0__m_axis_tdata = w_port__adc_axis_source_0__m_axis_tdata ;
    assign w_port__AXIS_Data_FIFO_0__us_tdata = w_net__adc_axis_source_0__m_axis_tdata ;

    assign w_net__adc_axis_source_0__m_axis_tkeep = w_port__adc_axis_source_0__m_axis_tkeep ;
    assign w_port__AXIS_Data_FIFO_0__us_tkeep = w_net__adc_axis_source_0__m_axis_tkeep ;

    assign w_net__adc_axis_source_0__m_axis_tlast = w_port__adc_axis_source_0__m_axis_tlast ;
    assign w_port__AXIS_Data_FIFO_0__us_tlast = w_net__adc_axis_source_0__m_axis_tlast ;

    assign w_net__adc_axis_source_0__m_axis_tvalid = w_port__adc_axis_source_0__m_axis_tvalid ;
    assign w_port__AXIS_Data_FIFO_0__us_tvalid = w_net__adc_axis_source_0__m_axis_tvalid ;

    assign w_net__adc_fdma_writer_0__m_axi_s2mm_awaddr = w_port__adc_fdma_writer_0__m_axi_s2mm_awaddr ;
    assign w_port__HP1_AXI_Matrix_0__us0_awaddr = w_net__adc_fdma_writer_0__m_axi_s2mm_awaddr ;

    assign w_net__adc_fdma_writer_0__m_axi_s2mm_awburst = w_port__adc_fdma_writer_0__m_axi_s2mm_awburst ;
    assign w_port__HP1_AXI_Matrix_0__us0_awburst = w_net__adc_fdma_writer_0__m_axi_s2mm_awburst ;

    assign w_net__adc_fdma_writer_0__m_axi_s2mm_awcache = w_port__adc_fdma_writer_0__m_axi_s2mm_awcache ;
    assign w_port__HP1_AXI_Matrix_0__us0_awcache = w_net__adc_fdma_writer_0__m_axi_s2mm_awcache ;

    assign w_net__adc_fdma_writer_0__m_axi_s2mm_awid = w_port__adc_fdma_writer_0__m_axi_s2mm_awid ;
    assign w_port__HP1_AXI_Matrix_0__us0_awid = w_net__adc_fdma_writer_0__m_axi_s2mm_awid ;

    assign w_net__adc_fdma_writer_0__m_axi_s2mm_awlen = w_port__adc_fdma_writer_0__m_axi_s2mm_awlen ;
    assign w_port__HP1_AXI_Matrix_0__us0_awlen = w_net__adc_fdma_writer_0__m_axi_s2mm_awlen ;

    assign w_net__adc_fdma_writer_0__m_axi_s2mm_awlock = w_port__adc_fdma_writer_0__m_axi_s2mm_awlock ;
    assign w_port__HP1_AXI_Matrix_0__us0_awlock = w_net__adc_fdma_writer_0__m_axi_s2mm_awlock ;

    assign w_net__adc_fdma_writer_0__m_axi_s2mm_awprot = w_port__adc_fdma_writer_0__m_axi_s2mm_awprot ;
    assign w_port__HP1_AXI_Matrix_0__us0_awprot = w_net__adc_fdma_writer_0__m_axi_s2mm_awprot ;

    assign w_net__adc_fdma_writer_0__m_axi_s2mm_awqos = w_port__adc_fdma_writer_0__m_axi_s2mm_awqos ;
    assign w_port__HP1_AXI_Matrix_0__us0_awqos = w_net__adc_fdma_writer_0__m_axi_s2mm_awqos ;

    assign w_net__adc_fdma_writer_0__m_axi_s2mm_awsize = w_port__adc_fdma_writer_0__m_axi_s2mm_awsize ;
    assign w_port__HP1_AXI_Matrix_0__us0_awsize = w_net__adc_fdma_writer_0__m_axi_s2mm_awsize ;

    assign w_net__adc_fdma_writer_0__m_axi_s2mm_awvalid = w_port__adc_fdma_writer_0__m_axi_s2mm_awvalid ;
    assign w_port__HP1_AXI_Matrix_0__us0_awvalid = w_net__adc_fdma_writer_0__m_axi_s2mm_awvalid ;

    assign w_net__adc_fdma_writer_0__m_axi_s2mm_bready = w_port__adc_fdma_writer_0__m_axi_s2mm_bready ;
    assign w_port__HP1_AXI_Matrix_0__us0_bready = w_net__adc_fdma_writer_0__m_axi_s2mm_bready ;

    assign w_net__adc_fdma_writer_0__m_axi_s2mm_wdata = w_port__adc_fdma_writer_0__m_axi_s2mm_wdata ;
    assign w_port__HP1_AXI_Matrix_0__us0_wdata = w_net__adc_fdma_writer_0__m_axi_s2mm_wdata ;

    assign w_net__adc_fdma_writer_0__m_axi_s2mm_wlast = w_port__adc_fdma_writer_0__m_axi_s2mm_wlast ;
    assign w_port__HP1_AXI_Matrix_0__us0_wlast = w_net__adc_fdma_writer_0__m_axi_s2mm_wlast ;

    assign w_net__adc_fdma_writer_0__m_axi_s2mm_wstrb = w_port__adc_fdma_writer_0__m_axi_s2mm_wstrb ;
    assign w_port__HP1_AXI_Matrix_0__us0_wstrb = w_net__adc_fdma_writer_0__m_axi_s2mm_wstrb ;

    assign w_net__adc_fdma_writer_0__m_axi_s2mm_wvalid = w_port__adc_fdma_writer_0__m_axi_s2mm_wvalid ;
    assign w_port__HP1_AXI_Matrix_0__us0_wvalid = w_net__adc_fdma_writer_0__m_axi_s2mm_wvalid ;

    assign w_net__adc_fdma_writer_0__s_axi_lite_arready = w_port__adc_fdma_writer_0__s_axi_lite_arready ;
    assign w_port__AXI_Lite_Matrix_0__ds1_arready = w_net__adc_fdma_writer_0__s_axi_lite_arready ;

    assign w_net__adc_fdma_writer_0__s_axi_lite_awready = w_port__adc_fdma_writer_0__s_axi_lite_awready ;
    assign w_port__AXI_Lite_Matrix_0__ds1_awready = w_net__adc_fdma_writer_0__s_axi_lite_awready ;

    assign w_net__adc_fdma_writer_0__s_axi_lite_bresp = w_port__adc_fdma_writer_0__s_axi_lite_bresp ;
    assign w_port__AXI_Lite_Matrix_0__ds1_bresp = w_net__adc_fdma_writer_0__s_axi_lite_bresp ;

    assign w_net__adc_fdma_writer_0__s_axi_lite_bvalid = w_port__adc_fdma_writer_0__s_axi_lite_bvalid ;
    assign w_port__AXI_Lite_Matrix_0__ds1_bvalid = w_net__adc_fdma_writer_0__s_axi_lite_bvalid ;

    assign w_net__adc_fdma_writer_0__s_axi_lite_rdata = w_port__adc_fdma_writer_0__s_axi_lite_rdata ;
    assign w_port__AXI_Lite_Matrix_0__ds1_rdata = w_net__adc_fdma_writer_0__s_axi_lite_rdata ;

    assign w_net__adc_fdma_writer_0__s_axi_lite_rresp = w_port__adc_fdma_writer_0__s_axi_lite_rresp ;
    assign w_port__AXI_Lite_Matrix_0__ds1_rresp = w_net__adc_fdma_writer_0__s_axi_lite_rresp ;

    assign w_net__adc_fdma_writer_0__s_axi_lite_rvalid = w_port__adc_fdma_writer_0__s_axi_lite_rvalid ;
    assign w_port__AXI_Lite_Matrix_0__ds1_rvalid = w_net__adc_fdma_writer_0__s_axi_lite_rvalid ;

    assign w_net__adc_fdma_writer_0__s_axi_lite_wready = w_port__adc_fdma_writer_0__s_axi_lite_wready ;
    assign w_port__AXI_Lite_Matrix_0__ds1_wready = w_net__adc_fdma_writer_0__s_axi_lite_wready ;

    assign w_net__adc_fdma_writer_0__s_axis_s2mm_tready = w_port__adc_fdma_writer_0__s_axis_s2mm_tready ;
    assign w_port__AXIS_Data_FIFO_0__ds_tready = w_net__adc_fdma_writer_0__s_axis_s2mm_tready ;
    assign w_port__adc_axis_source_0__fifo_out_tready = w_net__adc_fdma_writer_0__s_axis_s2mm_tready ;

    assign w_net__adc_sample_valid = adc_sample_valid ;
    assign w_port__adc_axis_source_0__adc_sample_valid = w_net__adc_sample_valid ;
    assign w_port__axi4lite_slave_0__adc_sample_valid = w_net__adc_sample_valid ;

    assign w_net__adc_status_in = adc_status_in ;
    assign w_port__axi4lite_slave_0__adc_status_in = w_net__adc_status_in ;

    assign w_net__axi4lite_slave_0__capture_enable = w_port__axi4lite_slave_0__capture_enable ;
    assign w_port__adc_axis_source_0__capture_enable = w_net__axi4lite_slave_0__capture_enable ;

    assign w_net__axi4lite_slave_0__fault_clear_cmd = w_port__axi4lite_slave_0__fault_clear_cmd ;
    assign fault_clear_cmd = w_net__axi4lite_slave_0__fault_clear_cmd ;

    assign w_net__axi4lite_slave_0__fifo_clear = w_port__axi4lite_slave_0__fifo_clear ;
    assign w_port__adc_axis_source_0__fifo_clear = w_net__axi4lite_slave_0__fifo_clear ;

    assign w_net__axi4lite_slave_0__output_enable_cmd = w_port__axi4lite_slave_0__output_enable_cmd ;
    assign output_enable_cmd = w_net__axi4lite_slave_0__output_enable_cmd ;

    assign w_net__axi4lite_slave_0__s_axi_arready = w_port__axi4lite_slave_0__s_axi_arready ;
    assign w_port__AXI_Lite_Matrix_0__ds0_arready = w_net__axi4lite_slave_0__s_axi_arready ;

    assign w_net__axi4lite_slave_0__s_axi_awready = w_port__axi4lite_slave_0__s_axi_awready ;
    assign w_port__AXI_Lite_Matrix_0__ds0_awready = w_net__axi4lite_slave_0__s_axi_awready ;

    assign w_net__axi4lite_slave_0__s_axi_bresp = w_port__axi4lite_slave_0__s_axi_bresp ;
    assign w_port__AXI_Lite_Matrix_0__ds0_bresp = w_net__axi4lite_slave_0__s_axi_bresp ;

    assign w_net__axi4lite_slave_0__s_axi_bvalid = w_port__axi4lite_slave_0__s_axi_bvalid ;
    assign w_port__AXI_Lite_Matrix_0__ds0_bvalid = w_net__axi4lite_slave_0__s_axi_bvalid ;

    assign w_net__axi4lite_slave_0__s_axi_rdata = w_port__axi4lite_slave_0__s_axi_rdata ;
    assign w_port__AXI_Lite_Matrix_0__ds0_rdata = w_net__axi4lite_slave_0__s_axi_rdata ;

    assign w_net__axi4lite_slave_0__s_axi_rresp = w_port__axi4lite_slave_0__s_axi_rresp ;
    assign w_port__AXI_Lite_Matrix_0__ds0_rresp = w_net__axi4lite_slave_0__s_axi_rresp ;

    assign w_net__axi4lite_slave_0__s_axi_rvalid = w_port__axi4lite_slave_0__s_axi_rvalid ;
    assign w_port__AXI_Lite_Matrix_0__ds0_rvalid = w_net__axi4lite_slave_0__s_axi_rvalid ;

    assign w_net__axi4lite_slave_0__s_axi_wready = w_port__axi4lite_slave_0__s_axi_wready ;
    assign w_port__AXI_Lite_Matrix_0__ds0_wready = w_net__axi4lite_slave_0__s_axi_wready ;

    assign w_net__axi4lite_slave_0__vref_cmd_q16 = w_port__axi4lite_slave_0__vref_cmd_q16 ;
    assign vref_cmd_q16 = w_net__axi4lite_slave_0__vref_cmd_q16 ;

    assign w_net__axi_clk = axi_clk ;
    assign w_port__ARM_Processor_System_0__master_gp0_axi_aclk = w_net__axi_clk ;
    assign w_port__Processor_System_Reset_0__clk = w_net__axi_clk ;
    assign w_port__AXI_Protocol_Converter_0__aclk = w_net__axi_clk ;
    assign w_port__AXIS_Data_FIFO_0__us_aclk = w_net__axi_clk ;
    assign w_port__axi4lite_slave_0__clk = w_net__axi_clk ;
    assign w_port__adc_axis_source_0__clk = w_net__axi_clk ;
    assign w_port__AXI_Lite_Matrix_0__aclk = w_net__axi_clk ;
    assign w_port__ARM_Processor_System_0__slave_hp1_axi_aclk = w_net__axi_clk ;
    assign w_port__adc_fdma_writer_0__s_axi_lite_aclk = w_net__axi_clk ;
    assign w_port__HP1_AXI_Matrix_0__aclk = w_net__axi_clk ;
    assign w_port__HP1_Protocol_Converter_0__aclk = w_net__axi_clk ;
    assign w_port__VDMA_0__s_axi_lite_aclk = w_net__axi_clk ;
    assign w_port__VDMA_0__s_axis_s2mm_aclk = w_net__axi_clk ;
    assign w_port__VDMA_0__m_axi_s2mm_aclk = w_net__axi_clk ;
    assign w_port__HDMI_VTG_0__aclk = w_net__axi_clk ;
    assign w_port__HDMI_Reset_0__ctrl_clk = w_net__axi_clk ;
    assign w_port__ARM_Processor_System_0__master_gp1_axi_aclk = w_net__axi_clk ;
    assign w_port__Video_NPU_0__S_AXILite_ACLK = w_net__axi_clk ;
    assign w_port__Video_NPU_0__M_AXI_ACLK = w_net__axi_clk ;
    assign w_port__NPU_HP1_Adapter_0__aclk = w_net__axi_clk ;
    assign w_port__NPU_Control_Matrix_0__aclk = w_net__axi_clk ;
    assign w_port__NPU_Control_Converter_0__aclk = w_net__axi_clk ;

    assign w_net__control_status_in = control_status_in ;
    assign w_port__axi4lite_slave_0__control_status_in = w_net__control_status_in ;

    assign w_net__current_product_in = current_product_in ;
    assign w_port__adc_axis_source_0__current_product_in = w_net__current_product_in ;

    assign w_net__duty_q16_in = duty_q16_in ;
    assign w_port__adc_axis_source_0__duty_q16_in = w_net__duty_q16_in ;

    assign w_net__ext_reset_n = ext_reset_n ;
    assign w_port__Processor_System_Reset_0__aux_resetn = w_net__ext_reset_n ;

    assign w_net__pll_locked = pll_locked ;
    assign w_port__Processor_System_Reset_0__pll_locked = w_net__pll_locked ;

    assign w_net__protection_stop = protection_stop ;
    assign w_port__axi4lite_slave_0__protection_stop = w_net__protection_stop ;

    assign w_net__voltage_product_in = voltage_product_in ;
    assign w_port__adc_axis_source_0__voltage_product_in = w_net__voltage_product_in ;

    assign w_net__vref_active_q16_in = vref_active_q16_in ;
    assign w_port__axi4lite_slave_0__vref_active_q16_in = w_net__vref_active_q16_in ;

    axi_system_ARM_Processor_System_0 axi_system_ARM_Processor_System_0_Inst ( 
                                                                                .slave_hp0_axi_araddr(w_port__ARM_Processor_System_0__slave_hp0_axi_araddr)
                                                                              , .slave_hp0_axi_arburst(w_port__ARM_Processor_System_0__slave_hp0_axi_arburst)
                                                                              , .slave_hp0_axi_arcache(w_port__ARM_Processor_System_0__slave_hp0_axi_arcache)
                                                                              , .slave_hp0_axi_arid(w_port__ARM_Processor_System_0__slave_hp0_axi_arid)
                                                                              , .slave_hp0_axi_arlen(w_port__ARM_Processor_System_0__slave_hp0_axi_arlen)
                                                                              , .slave_hp0_axi_arlock(w_port__ARM_Processor_System_0__slave_hp0_axi_arlock)
                                                                              , .slave_hp0_axi_arprot(w_port__ARM_Processor_System_0__slave_hp0_axi_arprot)
                                                                              , .slave_hp0_axi_arqos(w_port__ARM_Processor_System_0__slave_hp0_axi_arqos)
                                                                              , .slave_hp0_axi_arready(w_port__ARM_Processor_System_0__slave_hp0_axi_arready)
                                                                              , .slave_hp0_axi_arsize(w_port__ARM_Processor_System_0__slave_hp0_axi_arsize)
                                                                              , .slave_hp0_axi_arvalid(w_port__ARM_Processor_System_0__slave_hp0_axi_arvalid)
                                                                              , .slave_hp0_axi_awaddr(w_port__ARM_Processor_System_0__slave_hp0_axi_awaddr)
                                                                              , .slave_hp0_axi_awburst(w_port__ARM_Processor_System_0__slave_hp0_axi_awburst)
                                                                              , .slave_hp0_axi_awcache(w_port__ARM_Processor_System_0__slave_hp0_axi_awcache)
                                                                              , .slave_hp0_axi_awid(w_port__ARM_Processor_System_0__slave_hp0_axi_awid)
                                                                              , .slave_hp0_axi_awlen(w_port__ARM_Processor_System_0__slave_hp0_axi_awlen)
                                                                              , .slave_hp0_axi_awlock(w_port__ARM_Processor_System_0__slave_hp0_axi_awlock)
                                                                              , .slave_hp0_axi_awprot(w_port__ARM_Processor_System_0__slave_hp0_axi_awprot)
                                                                              , .slave_hp0_axi_awqos(w_port__ARM_Processor_System_0__slave_hp0_axi_awqos)
                                                                              , .slave_hp0_axi_awready(w_port__ARM_Processor_System_0__slave_hp0_axi_awready)
                                                                              , .slave_hp0_axi_awsize(w_port__ARM_Processor_System_0__slave_hp0_axi_awsize)
                                                                              , .slave_hp0_axi_awvalid(w_port__ARM_Processor_System_0__slave_hp0_axi_awvalid)
                                                                              , .slave_hp0_axi_bid(w_port__ARM_Processor_System_0__slave_hp0_axi_bid)
                                                                              , .slave_hp0_axi_bready(w_port__ARM_Processor_System_0__slave_hp0_axi_bready)
                                                                              , .slave_hp0_axi_bresp(w_port__ARM_Processor_System_0__slave_hp0_axi_bresp)
                                                                              , .slave_hp0_axi_bvalid(w_port__ARM_Processor_System_0__slave_hp0_axi_bvalid)
                                                                              , .slave_hp0_axi_rdata(w_port__ARM_Processor_System_0__slave_hp0_axi_rdata)
                                                                              , .slave_hp0_axi_rid(w_port__ARM_Processor_System_0__slave_hp0_axi_rid)
                                                                              , .slave_hp0_axi_rlast(w_port__ARM_Processor_System_0__slave_hp0_axi_rlast)
                                                                              , .slave_hp0_axi_rready(w_port__ARM_Processor_System_0__slave_hp0_axi_rready)
                                                                              , .slave_hp0_axi_rresp(w_port__ARM_Processor_System_0__slave_hp0_axi_rresp)
                                                                              , .slave_hp0_axi_rvalid(w_port__ARM_Processor_System_0__slave_hp0_axi_rvalid)
                                                                              , .slave_hp0_axi_wdata(w_port__ARM_Processor_System_0__slave_hp0_axi_wdata)
                                                                              , .slave_hp0_axi_wlast(w_port__ARM_Processor_System_0__slave_hp0_axi_wlast)
                                                                              , .slave_hp0_axi_wready(w_port__ARM_Processor_System_0__slave_hp0_axi_wready)
                                                                              , .slave_hp0_axi_wstrb(w_port__ARM_Processor_System_0__slave_hp0_axi_wstrb)
                                                                              , .slave_hp0_axi_wvalid(w_port__ARM_Processor_System_0__slave_hp0_axi_wvalid)
                                                                              , .slave_hp1_axi_araddr(w_port__ARM_Processor_System_0__slave_hp1_axi_araddr)
                                                                              , .slave_hp1_axi_arburst(w_port__ARM_Processor_System_0__slave_hp1_axi_arburst)
                                                                              , .slave_hp1_axi_arcache(w_port__ARM_Processor_System_0__slave_hp1_axi_arcache)
                                                                              , .slave_hp1_axi_arid(w_port__ARM_Processor_System_0__slave_hp1_axi_arid)
                                                                              , .slave_hp1_axi_arlen(w_port__ARM_Processor_System_0__slave_hp1_axi_arlen)
                                                                              , .slave_hp1_axi_arlock(w_port__ARM_Processor_System_0__slave_hp1_axi_arlock)
                                                                              , .slave_hp1_axi_arprot(w_port__ARM_Processor_System_0__slave_hp1_axi_arprot)
                                                                              , .slave_hp1_axi_arqos(w_port__ARM_Processor_System_0__slave_hp1_axi_arqos)
                                                                              , .slave_hp1_axi_arready(w_port__ARM_Processor_System_0__slave_hp1_axi_arready)
                                                                              , .slave_hp1_axi_arsize(w_port__ARM_Processor_System_0__slave_hp1_axi_arsize)
                                                                              , .slave_hp1_axi_arvalid(w_port__ARM_Processor_System_0__slave_hp1_axi_arvalid)
                                                                              , .slave_hp1_axi_awaddr(w_port__ARM_Processor_System_0__slave_hp1_axi_awaddr)
                                                                              , .slave_hp1_axi_awburst(w_port__ARM_Processor_System_0__slave_hp1_axi_awburst)
                                                                              , .slave_hp1_axi_awcache(w_port__ARM_Processor_System_0__slave_hp1_axi_awcache)
                                                                              , .slave_hp1_axi_awid(w_port__ARM_Processor_System_0__slave_hp1_axi_awid)
                                                                              , .slave_hp1_axi_awlen(w_port__ARM_Processor_System_0__slave_hp1_axi_awlen)
                                                                              , .slave_hp1_axi_awlock(w_port__ARM_Processor_System_0__slave_hp1_axi_awlock)
                                                                              , .slave_hp1_axi_awprot(w_port__ARM_Processor_System_0__slave_hp1_axi_awprot)
                                                                              , .slave_hp1_axi_awqos(w_port__ARM_Processor_System_0__slave_hp1_axi_awqos)
                                                                              , .slave_hp1_axi_awready(w_port__ARM_Processor_System_0__slave_hp1_axi_awready)
                                                                              , .slave_hp1_axi_awsize(w_port__ARM_Processor_System_0__slave_hp1_axi_awsize)
                                                                              , .slave_hp1_axi_awvalid(w_port__ARM_Processor_System_0__slave_hp1_axi_awvalid)
                                                                              , .slave_hp1_axi_bid(w_port__ARM_Processor_System_0__slave_hp1_axi_bid)
                                                                              , .slave_hp1_axi_bready(w_port__ARM_Processor_System_0__slave_hp1_axi_bready)
                                                                              , .slave_hp1_axi_bresp(w_port__ARM_Processor_System_0__slave_hp1_axi_bresp)
                                                                              , .slave_hp1_axi_bvalid(w_port__ARM_Processor_System_0__slave_hp1_axi_bvalid)
                                                                              , .slave_hp1_axi_rdata(w_port__ARM_Processor_System_0__slave_hp1_axi_rdata)
                                                                              , .slave_hp1_axi_rid(w_port__ARM_Processor_System_0__slave_hp1_axi_rid)
                                                                              , .slave_hp1_axi_rlast(w_port__ARM_Processor_System_0__slave_hp1_axi_rlast)
                                                                              , .slave_hp1_axi_rready(w_port__ARM_Processor_System_0__slave_hp1_axi_rready)
                                                                              , .slave_hp1_axi_rresp(w_port__ARM_Processor_System_0__slave_hp1_axi_rresp)
                                                                              , .slave_hp1_axi_rvalid(w_port__ARM_Processor_System_0__slave_hp1_axi_rvalid)
                                                                              , .slave_hp1_axi_wdata(w_port__ARM_Processor_System_0__slave_hp1_axi_wdata)
                                                                              , .slave_hp1_axi_wlast(w_port__ARM_Processor_System_0__slave_hp1_axi_wlast)
                                                                              , .slave_hp1_axi_wready(w_port__ARM_Processor_System_0__slave_hp1_axi_wready)
                                                                              , .slave_hp1_axi_wstrb(w_port__ARM_Processor_System_0__slave_hp1_axi_wstrb)
                                                                              , .slave_hp1_axi_wvalid(w_port__ARM_Processor_System_0__slave_hp1_axi_wvalid)
                                                                              , .slave_hp0_axi_aclk(w_port__ARM_Processor_System_0__slave_hp0_axi_aclk)
                                                                              , .slave_hp1_axi_aclk(w_port__ARM_Processor_System_0__slave_hp1_axi_aclk)
                                                                              , .master_gp0_axi_aclk(w_port__ARM_Processor_System_0__master_gp0_axi_aclk)
                                                                              , .master_gp1_axi_aclk(w_port__ARM_Processor_System_0__master_gp1_axi_aclk)
                                                                              , .f2p_irq(w_port__ARM_Processor_System_0__f2p_irq)
                                                                              , .master_gp0_axi_araddr(w_port__ARM_Processor_System_0__master_gp0_axi_araddr)
                                                                              , .master_gp0_axi_arburst(w_port__ARM_Processor_System_0__master_gp0_axi_arburst)
                                                                              , .master_gp0_axi_arcache(w_port__ARM_Processor_System_0__master_gp0_axi_arcache)
                                                                              , .master_gp0_axi_arid(w_port__ARM_Processor_System_0__master_gp0_axi_arid)
                                                                              , .master_gp0_axi_arlen(w_port__ARM_Processor_System_0__master_gp0_axi_arlen)
                                                                              , .master_gp0_axi_arlock(w_port__ARM_Processor_System_0__master_gp0_axi_arlock)
                                                                              , .master_gp0_axi_arprot(w_port__ARM_Processor_System_0__master_gp0_axi_arprot)
                                                                              , .master_gp0_axi_arready(w_port__ARM_Processor_System_0__master_gp0_axi_arready)
                                                                              , .master_gp0_axi_arsize(w_port__ARM_Processor_System_0__master_gp0_axi_arsize)
                                                                              , .master_gp0_axi_arvalid(w_port__ARM_Processor_System_0__master_gp0_axi_arvalid)
                                                                              , .master_gp0_axi_awaddr(w_port__ARM_Processor_System_0__master_gp0_axi_awaddr)
                                                                              , .master_gp0_axi_awburst(w_port__ARM_Processor_System_0__master_gp0_axi_awburst)
                                                                              , .master_gp0_axi_awcache(w_port__ARM_Processor_System_0__master_gp0_axi_awcache)
                                                                              , .master_gp0_axi_awid(w_port__ARM_Processor_System_0__master_gp0_axi_awid)
                                                                              , .master_gp0_axi_awlen(w_port__ARM_Processor_System_0__master_gp0_axi_awlen)
                                                                              , .master_gp0_axi_awlock(w_port__ARM_Processor_System_0__master_gp0_axi_awlock)
                                                                              , .master_gp0_axi_awprot(w_port__ARM_Processor_System_0__master_gp0_axi_awprot)
                                                                              , .master_gp0_axi_awready(w_port__ARM_Processor_System_0__master_gp0_axi_awready)
                                                                              , .master_gp0_axi_awsize(w_port__ARM_Processor_System_0__master_gp0_axi_awsize)
                                                                              , .master_gp0_axi_awvalid(w_port__ARM_Processor_System_0__master_gp0_axi_awvalid)
                                                                              , .master_gp0_axi_bid(w_port__ARM_Processor_System_0__master_gp0_axi_bid)
                                                                              , .master_gp0_axi_bready(w_port__ARM_Processor_System_0__master_gp0_axi_bready)
                                                                              , .master_gp0_axi_bresp(w_port__ARM_Processor_System_0__master_gp0_axi_bresp)
                                                                              , .master_gp0_axi_bvalid(w_port__ARM_Processor_System_0__master_gp0_axi_bvalid)
                                                                              , .master_gp0_axi_rdata(w_port__ARM_Processor_System_0__master_gp0_axi_rdata)
                                                                              , .master_gp0_axi_rid(w_port__ARM_Processor_System_0__master_gp0_axi_rid)
                                                                              , .master_gp0_axi_rlast(w_port__ARM_Processor_System_0__master_gp0_axi_rlast)
                                                                              , .master_gp0_axi_rready(w_port__ARM_Processor_System_0__master_gp0_axi_rready)
                                                                              , .master_gp0_axi_rresp(w_port__ARM_Processor_System_0__master_gp0_axi_rresp)
                                                                              , .master_gp0_axi_rvalid(w_port__ARM_Processor_System_0__master_gp0_axi_rvalid)
                                                                              , .master_gp0_axi_wdata(w_port__ARM_Processor_System_0__master_gp0_axi_wdata)
                                                                              , .master_gp0_axi_wlast(w_port__ARM_Processor_System_0__master_gp0_axi_wlast)
                                                                              , .master_gp0_axi_wready(w_port__ARM_Processor_System_0__master_gp0_axi_wready)
                                                                              , .master_gp0_axi_wstrb(w_port__ARM_Processor_System_0__master_gp0_axi_wstrb)
                                                                              , .master_gp0_axi_wvalid(w_port__ARM_Processor_System_0__master_gp0_axi_wvalid)
                                                                              , .master_gp1_axi_araddr(w_port__ARM_Processor_System_0__master_gp1_axi_araddr)
                                                                              , .master_gp1_axi_arburst(w_port__ARM_Processor_System_0__master_gp1_axi_arburst)
                                                                              , .master_gp1_axi_arcache(w_port__ARM_Processor_System_0__master_gp1_axi_arcache)
                                                                              , .master_gp1_axi_arid(w_port__ARM_Processor_System_0__master_gp1_axi_arid)
                                                                              , .master_gp1_axi_arlen(w_port__ARM_Processor_System_0__master_gp1_axi_arlen)
                                                                              , .master_gp1_axi_arlock(w_port__ARM_Processor_System_0__master_gp1_axi_arlock)
                                                                              , .master_gp1_axi_arprot(w_port__ARM_Processor_System_0__master_gp1_axi_arprot)
                                                                              , .master_gp1_axi_arready(w_port__ARM_Processor_System_0__master_gp1_axi_arready)
                                                                              , .master_gp1_axi_arsize(w_port__ARM_Processor_System_0__master_gp1_axi_arsize)
                                                                              , .master_gp1_axi_arvalid(w_port__ARM_Processor_System_0__master_gp1_axi_arvalid)
                                                                              , .master_gp1_axi_awaddr(w_port__ARM_Processor_System_0__master_gp1_axi_awaddr)
                                                                              , .master_gp1_axi_awburst(w_port__ARM_Processor_System_0__master_gp1_axi_awburst)
                                                                              , .master_gp1_axi_awcache(w_port__ARM_Processor_System_0__master_gp1_axi_awcache)
                                                                              , .master_gp1_axi_awid(w_port__ARM_Processor_System_0__master_gp1_axi_awid)
                                                                              , .master_gp1_axi_awlen(w_port__ARM_Processor_System_0__master_gp1_axi_awlen)
                                                                              , .master_gp1_axi_awlock(w_port__ARM_Processor_System_0__master_gp1_axi_awlock)
                                                                              , .master_gp1_axi_awprot(w_port__ARM_Processor_System_0__master_gp1_axi_awprot)
                                                                              , .master_gp1_axi_awready(w_port__ARM_Processor_System_0__master_gp1_axi_awready)
                                                                              , .master_gp1_axi_awsize(w_port__ARM_Processor_System_0__master_gp1_axi_awsize)
                                                                              , .master_gp1_axi_awvalid(w_port__ARM_Processor_System_0__master_gp1_axi_awvalid)
                                                                              , .master_gp1_axi_bid(w_port__ARM_Processor_System_0__master_gp1_axi_bid)
                                                                              , .master_gp1_axi_bready(w_port__ARM_Processor_System_0__master_gp1_axi_bready)
                                                                              , .master_gp1_axi_bresp(w_port__ARM_Processor_System_0__master_gp1_axi_bresp)
                                                                              , .master_gp1_axi_bvalid(w_port__ARM_Processor_System_0__master_gp1_axi_bvalid)
                                                                              , .master_gp1_axi_rdata(w_port__ARM_Processor_System_0__master_gp1_axi_rdata)
                                                                              , .master_gp1_axi_rid(w_port__ARM_Processor_System_0__master_gp1_axi_rid)
                                                                              , .master_gp1_axi_rlast(w_port__ARM_Processor_System_0__master_gp1_axi_rlast)
                                                                              , .master_gp1_axi_rready(w_port__ARM_Processor_System_0__master_gp1_axi_rready)
                                                                              , .master_gp1_axi_rresp(w_port__ARM_Processor_System_0__master_gp1_axi_rresp)
                                                                              , .master_gp1_axi_rvalid(w_port__ARM_Processor_System_0__master_gp1_axi_rvalid)
                                                                              , .master_gp1_axi_wdata(w_port__ARM_Processor_System_0__master_gp1_axi_wdata)
                                                                              , .master_gp1_axi_wlast(w_port__ARM_Processor_System_0__master_gp1_axi_wlast)
                                                                              , .master_gp1_axi_wready(w_port__ARM_Processor_System_0__master_gp1_axi_wready)
                                                                              , .master_gp1_axi_wstrb(w_port__ARM_Processor_System_0__master_gp1_axi_wstrb)
                                                                              , .master_gp1_axi_wvalid(w_port__ARM_Processor_System_0__master_gp1_axi_wvalid)
                                                                              , .p2f_rst0_n(w_port__ARM_Processor_System_0__p2f_rst0_n)
                                                                              , .p2f_clk0(w_port__ARM_Processor_System_0__p2f_clk0) );

    axi_system_AXI_Protocol_Converter_0 axi_system_AXI_Protocol_Converter_0_Inst ( 
                                                                                    .us_axi_awid(w_port__AXI_Protocol_Converter_0__us_axi_awid)
                                                                                  , .us_axi_awaddr(w_port__AXI_Protocol_Converter_0__us_axi_awaddr)
                                                                                  , .us_axi_awlen(w_port__AXI_Protocol_Converter_0__us_axi_awlen)
                                                                                  , .us_axi_awsize(w_port__AXI_Protocol_Converter_0__us_axi_awsize)
                                                                                  , .us_axi_awburst(w_port__AXI_Protocol_Converter_0__us_axi_awburst)
                                                                                  , .us_axi_awlock(w_port__AXI_Protocol_Converter_0__us_axi_awlock)
                                                                                  , .us_axi_awcache(w_port__AXI_Protocol_Converter_0__us_axi_awcache)
                                                                                  , .us_axi_awprot(w_port__AXI_Protocol_Converter_0__us_axi_awprot)
                                                                                  , .us_axi_awqos(w_port__AXI_Protocol_Converter_0__us_axi_awqos)
                                                                                  , .us_axi_awvalid(w_port__AXI_Protocol_Converter_0__us_axi_awvalid)
                                                                                  , .us_axi_awready(w_port__AXI_Protocol_Converter_0__us_axi_awready)
                                                                                  , .us_axi_wdata(w_port__AXI_Protocol_Converter_0__us_axi_wdata)
                                                                                  , .us_axi_wstrb(w_port__AXI_Protocol_Converter_0__us_axi_wstrb)
                                                                                  , .us_axi_wlast(w_port__AXI_Protocol_Converter_0__us_axi_wlast)
                                                                                  , .us_axi_wvalid(w_port__AXI_Protocol_Converter_0__us_axi_wvalid)
                                                                                  , .us_axi_wready(w_port__AXI_Protocol_Converter_0__us_axi_wready)
                                                                                  , .us_axi_bid(w_port__AXI_Protocol_Converter_0__us_axi_bid)
                                                                                  , .us_axi_bresp(w_port__AXI_Protocol_Converter_0__us_axi_bresp)
                                                                                  , .us_axi_bvalid(w_port__AXI_Protocol_Converter_0__us_axi_bvalid)
                                                                                  , .us_axi_bready(w_port__AXI_Protocol_Converter_0__us_axi_bready)
                                                                                  , .us_axi_arid(w_port__AXI_Protocol_Converter_0__us_axi_arid)
                                                                                  , .us_axi_araddr(w_port__AXI_Protocol_Converter_0__us_axi_araddr)
                                                                                  , .us_axi_arlen(w_port__AXI_Protocol_Converter_0__us_axi_arlen)
                                                                                  , .us_axi_arsize(w_port__AXI_Protocol_Converter_0__us_axi_arsize)
                                                                                  , .us_axi_arburst(w_port__AXI_Protocol_Converter_0__us_axi_arburst)
                                                                                  , .us_axi_arlock(w_port__AXI_Protocol_Converter_0__us_axi_arlock)
                                                                                  , .us_axi_arcache(w_port__AXI_Protocol_Converter_0__us_axi_arcache)
                                                                                  , .us_axi_arprot(w_port__AXI_Protocol_Converter_0__us_axi_arprot)
                                                                                  , .us_axi_arqos(w_port__AXI_Protocol_Converter_0__us_axi_arqos)
                                                                                  , .us_axi_arvalid(w_port__AXI_Protocol_Converter_0__us_axi_arvalid)
                                                                                  , .us_axi_arready(w_port__AXI_Protocol_Converter_0__us_axi_arready)
                                                                                  , .us_axi_rid(w_port__AXI_Protocol_Converter_0__us_axi_rid)
                                                                                  , .us_axi_rdata(w_port__AXI_Protocol_Converter_0__us_axi_rdata)
                                                                                  , .us_axi_rresp(w_port__AXI_Protocol_Converter_0__us_axi_rresp)
                                                                                  , .us_axi_rlast(w_port__AXI_Protocol_Converter_0__us_axi_rlast)
                                                                                  , .us_axi_rvalid(w_port__AXI_Protocol_Converter_0__us_axi_rvalid)
                                                                                  , .us_axi_rready(w_port__AXI_Protocol_Converter_0__us_axi_rready)
                                                                                  , .aclk(w_port__AXI_Protocol_Converter_0__aclk)
                                                                                  , .aresetn(w_port__AXI_Protocol_Converter_0__aresetn)
                                                                                  , .ds_axi_awaddr(w_port__AXI_Protocol_Converter_0__ds_axi_awaddr)
                                                                                  , .ds_axi_awprot(w_port__AXI_Protocol_Converter_0__ds_axi_awprot)
                                                                                  , .ds_axi_awvalid(w_port__AXI_Protocol_Converter_0__ds_axi_awvalid)
                                                                                  , .ds_axi_awready(w_port__AXI_Protocol_Converter_0__ds_axi_awready)
                                                                                  , .ds_axi_wdata(w_port__AXI_Protocol_Converter_0__ds_axi_wdata)
                                                                                  , .ds_axi_wstrb(w_port__AXI_Protocol_Converter_0__ds_axi_wstrb)
                                                                                  , .ds_axi_wvalid(w_port__AXI_Protocol_Converter_0__ds_axi_wvalid)
                                                                                  , .ds_axi_wready(w_port__AXI_Protocol_Converter_0__ds_axi_wready)
                                                                                  , .ds_axi_bresp(w_port__AXI_Protocol_Converter_0__ds_axi_bresp)
                                                                                  , .ds_axi_bvalid(w_port__AXI_Protocol_Converter_0__ds_axi_bvalid)
                                                                                  , .ds_axi_bready(w_port__AXI_Protocol_Converter_0__ds_axi_bready)
                                                                                  , .ds_axi_araddr(w_port__AXI_Protocol_Converter_0__ds_axi_araddr)
                                                                                  , .ds_axi_arprot(w_port__AXI_Protocol_Converter_0__ds_axi_arprot)
                                                                                  , .ds_axi_arvalid(w_port__AXI_Protocol_Converter_0__ds_axi_arvalid)
                                                                                  , .ds_axi_arready(w_port__AXI_Protocol_Converter_0__ds_axi_arready)
                                                                                  , .ds_axi_rdata(w_port__AXI_Protocol_Converter_0__ds_axi_rdata)
                                                                                  , .ds_axi_rresp(w_port__AXI_Protocol_Converter_0__ds_axi_rresp)
                                                                                  , .ds_axi_rvalid(w_port__AXI_Protocol_Converter_0__ds_axi_rvalid)
                                                                                  , .ds_axi_rready(w_port__AXI_Protocol_Converter_0__ds_axi_rready) );

    axi_system_Processor_System_Reset_0 axi_system_Processor_System_Reset_0_Inst ( 
                                                                                    .clk(w_port__Processor_System_Reset_0__clk)
                                                                                  , .external_resetn(w_port__Processor_System_Reset_0__external_resetn)
                                                                                  , .aux_resetn(w_port__Processor_System_Reset_0__aux_resetn)
                                                                                  , .system_rst(w_port__Processor_System_Reset_0__system_rst)
                                                                                  , .pll_locked(w_port__Processor_System_Reset_0__pll_locked)
                                                                                  , .soc_reset()
                                                                                  , .bus_reset()
                                                                                  , .peripheral_reset()
                                                                                  , .interconnect_aresetn(w_port__Processor_System_Reset_0__interconnect_aresetn)
                                                                                  , .peripheral_aresetn(w_port__Processor_System_Reset_0__peripheral_aresetn) );

    axi_system_Constant_0 axi_system_Constant_0_Inst ( 
                                                        .dout(w_port__Constant_0__dout) );

    axi_system_Constant_0_0 axi_system_Constant_0_0_Inst ( 
                                                            .dout(w_port__Constant_0_0__dout) );

    axi_system_AXIS_Data_FIFO_0 axi_system_AXIS_Data_FIFO_0_Inst ( 
                                                                    .us_tvalid(w_port__AXIS_Data_FIFO_0__us_tvalid)
                                                                  , .us_tready(w_port__AXIS_Data_FIFO_0__us_tready)
                                                                  , .us_tdata(w_port__AXIS_Data_FIFO_0__us_tdata)
                                                                  , .us_tkeep(w_port__AXIS_Data_FIFO_0__us_tkeep)
                                                                  , .us_tlast(w_port__AXIS_Data_FIFO_0__us_tlast)
                                                                  , .us_aclk(w_port__AXIS_Data_FIFO_0__us_aclk)
                                                                  , .us_aresetn(w_port__AXIS_Data_FIFO_0__us_aresetn)
                                                                  , .ds_tvalid(w_port__AXIS_Data_FIFO_0__ds_tvalid)
                                                                  , .ds_tready(w_port__AXIS_Data_FIFO_0__ds_tready)
                                                                  , .ds_tdata(w_port__AXIS_Data_FIFO_0__ds_tdata)
                                                                  , .ds_tkeep(w_port__AXIS_Data_FIFO_0__ds_tkeep)
                                                                  , .ds_tlast(w_port__AXIS_Data_FIFO_0__ds_tlast)
                                                                  , .ds_tuser()
                                                                  , .almost_full()
                                                                  , .axis_wr_data_count()
                                                                  , .almost_empty()
                                                                  , .axis_rd_data_count() );

    axi_system_adc_axis_source_0 axi_system_adc_axis_source_0_Inst ( 
                                                                      .clk(w_port__adc_axis_source_0__clk)
                                                                    , .rst_n(w_port__adc_axis_source_0__rst_n)
                                                                    , .capture_enable(w_port__adc_axis_source_0__capture_enable)
                                                                    , .fifo_clear(w_port__adc_axis_source_0__fifo_clear)
                                                                    , .adc_sample_valid(w_port__adc_axis_source_0__adc_sample_valid)
                                                                    , .voltage_product_in(w_port__adc_axis_source_0__voltage_product_in)
                                                                    , .current_product_in(w_port__adc_axis_source_0__current_product_in)
                                                                    , .fifo_out_tvalid(w_port__adc_axis_source_0__fifo_out_tvalid)
                                                                    , .fifo_out_tready(w_port__adc_axis_source_0__fifo_out_tready)
                                                                    , .duty_q16_in(w_port__adc_axis_source_0__duty_q16_in)
                                                                    , .m_axis_tdata(w_port__adc_axis_source_0__m_axis_tdata)
                                                                    , .m_axis_tkeep(w_port__adc_axis_source_0__m_axis_tkeep)
                                                                    , .m_axis_tlast(w_port__adc_axis_source_0__m_axis_tlast)
                                                                    , .m_axis_tvalid(w_port__adc_axis_source_0__m_axis_tvalid)
                                                                    , .m_axis_tready(w_port__adc_axis_source_0__m_axis_tready)
                                                                    , .drop_count(w_port__adc_axis_source_0__drop_count)
                                                                    , .fifo_level(w_port__adc_axis_source_0__fifo_level)
                                                                    , .fifo_reset_n(w_port__adc_axis_source_0__fifo_reset_n) );

    axi_system_axi4lite_slave_0 axi_system_axi4lite_slave_0_Inst ( 
                                                                    .s_axis_tdata(w_port__axi4lite_slave_0__s_axis_tdata)
                                                                  , .s_axis_tkeep(w_port__axi4lite_slave_0__s_axis_tkeep)
                                                                  , .s_axis_tlast(w_port__axi4lite_slave_0__s_axis_tlast)
                                                                  , .s_axis_tvalid(w_port__axi4lite_slave_0__s_axis_tvalid)
                                                                  , .s_axis_tready()
                                                                  , .s_axi_awaddr(w_port__axi4lite_slave_0__s_axi_awaddr)
                                                                  , .s_axi_awvalid(w_port__axi4lite_slave_0__s_axi_awvalid)
                                                                  , .s_axi_awready(w_port__axi4lite_slave_0__s_axi_awready)
                                                                  , .s_axi_wdata(w_port__axi4lite_slave_0__s_axi_wdata)
                                                                  , .s_axi_wstrb(w_port__axi4lite_slave_0__s_axi_wstrb)
                                                                  , .s_axi_wvalid(w_port__axi4lite_slave_0__s_axi_wvalid)
                                                                  , .s_axi_wready(w_port__axi4lite_slave_0__s_axi_wready)
                                                                  , .s_axi_bresp(w_port__axi4lite_slave_0__s_axi_bresp)
                                                                  , .s_axi_bvalid(w_port__axi4lite_slave_0__s_axi_bvalid)
                                                                  , .s_axi_bready(w_port__axi4lite_slave_0__s_axi_bready)
                                                                  , .s_axi_araddr(w_port__axi4lite_slave_0__s_axi_araddr)
                                                                  , .s_axi_arvalid(w_port__axi4lite_slave_0__s_axi_arvalid)
                                                                  , .s_axi_arready(w_port__axi4lite_slave_0__s_axi_arready)
                                                                  , .s_axi_rdata(w_port__axi4lite_slave_0__s_axi_rdata)
                                                                  , .s_axi_rresp(w_port__axi4lite_slave_0__s_axi_rresp)
                                                                  , .s_axi_rvalid(w_port__axi4lite_slave_0__s_axi_rvalid)
                                                                  , .s_axi_rready(w_port__axi4lite_slave_0__s_axi_rready)
                                                                  , .adc_sample_valid(w_port__axi4lite_slave_0__adc_sample_valid)
                                                                  , .adc_status_in(w_port__axi4lite_slave_0__adc_status_in)
                                                                  , .fifo_level_in(w_port__axi4lite_slave_0__fifo_level_in)
                                                                  , .fifo_drop_count_in(w_port__axi4lite_slave_0__fifo_drop_count_in)
                                                                  , .fifo_ready_in(w_port__axi4lite_slave_0__fifo_ready_in)
                                                                  , .clk(w_port__axi4lite_slave_0__clk)
                                                                  , .rst_n(w_port__axi4lite_slave_0__rst_n)
                                                                  , .control_status_in(w_port__axi4lite_slave_0__control_status_in)
                                                                  , .vref_active_q16_in(w_port__axi4lite_slave_0__vref_active_q16_in)
                                                                  , .protection_stop(w_port__axi4lite_slave_0__protection_stop)
                                                                  , .capture_enable(w_port__axi4lite_slave_0__capture_enable)
                                                                  , .fifo_clear(w_port__axi4lite_slave_0__fifo_clear)
                                                                  , .output_enable_cmd(w_port__axi4lite_slave_0__output_enable_cmd)
                                                                  , .vref_cmd_q16(w_port__axi4lite_slave_0__vref_cmd_q16)
                                                                  , .fault_clear_cmd(w_port__axi4lite_slave_0__fault_clear_cmd) );

    axi_system_AXI_Lite_Matrix_0 axi_system_AXI_Lite_Matrix_0_Inst ( 
                                                                      .us0_araddr(w_port__AXI_Lite_Matrix_0__us0_araddr)
                                                                    , .us0_arprot(w_port__AXI_Lite_Matrix_0__us0_arprot)
                                                                    , .us0_arready(w_port__AXI_Lite_Matrix_0__us0_arready)
                                                                    , .us0_arvalid(w_port__AXI_Lite_Matrix_0__us0_arvalid)
                                                                    , .us0_awaddr(w_port__AXI_Lite_Matrix_0__us0_awaddr)
                                                                    , .us0_awprot(w_port__AXI_Lite_Matrix_0__us0_awprot)
                                                                    , .us0_awready(w_port__AXI_Lite_Matrix_0__us0_awready)
                                                                    , .us0_awvalid(w_port__AXI_Lite_Matrix_0__us0_awvalid)
                                                                    , .us0_bready(w_port__AXI_Lite_Matrix_0__us0_bready)
                                                                    , .us0_bresp(w_port__AXI_Lite_Matrix_0__us0_bresp)
                                                                    , .us0_bvalid(w_port__AXI_Lite_Matrix_0__us0_bvalid)
                                                                    , .us0_rdata(w_port__AXI_Lite_Matrix_0__us0_rdata)
                                                                    , .us0_rready(w_port__AXI_Lite_Matrix_0__us0_rready)
                                                                    , .us0_rresp(w_port__AXI_Lite_Matrix_0__us0_rresp)
                                                                    , .us0_rvalid(w_port__AXI_Lite_Matrix_0__us0_rvalid)
                                                                    , .us0_wdata(w_port__AXI_Lite_Matrix_0__us0_wdata)
                                                                    , .us0_wready(w_port__AXI_Lite_Matrix_0__us0_wready)
                                                                    , .us0_wstrb(w_port__AXI_Lite_Matrix_0__us0_wstrb)
                                                                    , .us0_wvalid(w_port__AXI_Lite_Matrix_0__us0_wvalid)
                                                                    , .aclk(w_port__AXI_Lite_Matrix_0__aclk)
                                                                    , .aresetn(w_port__AXI_Lite_Matrix_0__aresetn)
                                                                    , .ds0_araddr(w_port__AXI_Lite_Matrix_0__ds0_araddr)
                                                                    , .ds0_arprot()
                                                                    , .ds0_arready(w_port__AXI_Lite_Matrix_0__ds0_arready)
                                                                    , .ds0_arvalid(w_port__AXI_Lite_Matrix_0__ds0_arvalid)
                                                                    , .ds0_awaddr(w_port__AXI_Lite_Matrix_0__ds0_awaddr)
                                                                    , .ds0_awprot()
                                                                    , .ds0_awready(w_port__AXI_Lite_Matrix_0__ds0_awready)
                                                                    , .ds0_awvalid(w_port__AXI_Lite_Matrix_0__ds0_awvalid)
                                                                    , .ds0_bready(w_port__AXI_Lite_Matrix_0__ds0_bready)
                                                                    , .ds0_bresp(w_port__AXI_Lite_Matrix_0__ds0_bresp)
                                                                    , .ds0_bvalid(w_port__AXI_Lite_Matrix_0__ds0_bvalid)
                                                                    , .ds0_rdata(w_port__AXI_Lite_Matrix_0__ds0_rdata)
                                                                    , .ds0_rready(w_port__AXI_Lite_Matrix_0__ds0_rready)
                                                                    , .ds0_rresp(w_port__AXI_Lite_Matrix_0__ds0_rresp)
                                                                    , .ds0_rvalid(w_port__AXI_Lite_Matrix_0__ds0_rvalid)
                                                                    , .ds0_wdata(w_port__AXI_Lite_Matrix_0__ds0_wdata)
                                                                    , .ds0_wready(w_port__AXI_Lite_Matrix_0__ds0_wready)
                                                                    , .ds0_wstrb(w_port__AXI_Lite_Matrix_0__ds0_wstrb)
                                                                    , .ds0_wvalid(w_port__AXI_Lite_Matrix_0__ds0_wvalid)
                                                                    , .ds1_araddr(w_port__AXI_Lite_Matrix_0__ds1_araddr)
                                                                    , .ds1_arprot()
                                                                    , .ds1_arready(w_port__AXI_Lite_Matrix_0__ds1_arready)
                                                                    , .ds1_arvalid(w_port__AXI_Lite_Matrix_0__ds1_arvalid)
                                                                    , .ds1_awaddr(w_port__AXI_Lite_Matrix_0__ds1_awaddr)
                                                                    , .ds1_awprot()
                                                                    , .ds1_awready(w_port__AXI_Lite_Matrix_0__ds1_awready)
                                                                    , .ds1_awvalid(w_port__AXI_Lite_Matrix_0__ds1_awvalid)
                                                                    , .ds1_bready(w_port__AXI_Lite_Matrix_0__ds1_bready)
                                                                    , .ds1_bresp(w_port__AXI_Lite_Matrix_0__ds1_bresp)
                                                                    , .ds1_bvalid(w_port__AXI_Lite_Matrix_0__ds1_bvalid)
                                                                    , .ds1_rdata(w_port__AXI_Lite_Matrix_0__ds1_rdata)
                                                                    , .ds1_rready(w_port__AXI_Lite_Matrix_0__ds1_rready)
                                                                    , .ds1_rresp(w_port__AXI_Lite_Matrix_0__ds1_rresp)
                                                                    , .ds1_rvalid(w_port__AXI_Lite_Matrix_0__ds1_rvalid)
                                                                    , .ds1_wdata(w_port__AXI_Lite_Matrix_0__ds1_wdata)
                                                                    , .ds1_wready(w_port__AXI_Lite_Matrix_0__ds1_wready)
                                                                    , .ds1_wstrb(w_port__AXI_Lite_Matrix_0__ds1_wstrb)
                                                                    , .ds1_wvalid(w_port__AXI_Lite_Matrix_0__ds1_wvalid)
                                                                    , .ds2_araddr(w_port__AXI_Lite_Matrix_0__ds2_araddr)
                                                                    , .ds2_arprot()
                                                                    , .ds2_arready(w_port__AXI_Lite_Matrix_0__ds2_arready)
                                                                    , .ds2_arvalid(w_port__AXI_Lite_Matrix_0__ds2_arvalid)
                                                                    , .ds2_awaddr(w_port__AXI_Lite_Matrix_0__ds2_awaddr)
                                                                    , .ds2_awprot()
                                                                    , .ds2_awready(w_port__AXI_Lite_Matrix_0__ds2_awready)
                                                                    , .ds2_awvalid(w_port__AXI_Lite_Matrix_0__ds2_awvalid)
                                                                    , .ds2_bready(w_port__AXI_Lite_Matrix_0__ds2_bready)
                                                                    , .ds2_bresp(w_port__AXI_Lite_Matrix_0__ds2_bresp)
                                                                    , .ds2_bvalid(w_port__AXI_Lite_Matrix_0__ds2_bvalid)
                                                                    , .ds2_rdata(w_port__AXI_Lite_Matrix_0__ds2_rdata)
                                                                    , .ds2_rready(w_port__AXI_Lite_Matrix_0__ds2_rready)
                                                                    , .ds2_rresp(w_port__AXI_Lite_Matrix_0__ds2_rresp)
                                                                    , .ds2_rvalid(w_port__AXI_Lite_Matrix_0__ds2_rvalid)
                                                                    , .ds2_wdata(w_port__AXI_Lite_Matrix_0__ds2_wdata)
                                                                    , .ds2_wready(w_port__AXI_Lite_Matrix_0__ds2_wready)
                                                                    , .ds2_wstrb(w_port__AXI_Lite_Matrix_0__ds2_wstrb)
                                                                    , .ds2_wvalid(w_port__AXI_Lite_Matrix_0__ds2_wvalid)
                                                                    , .ds3_araddr(w_port__AXI_Lite_Matrix_0__ds3_araddr)
                                                                    , .ds3_arprot()
                                                                    , .ds3_arready(w_port__AXI_Lite_Matrix_0__ds3_arready)
                                                                    , .ds3_arvalid(w_port__AXI_Lite_Matrix_0__ds3_arvalid)
                                                                    , .ds3_awaddr(w_port__AXI_Lite_Matrix_0__ds3_awaddr)
                                                                    , .ds3_awprot()
                                                                    , .ds3_awready(w_port__AXI_Lite_Matrix_0__ds3_awready)
                                                                    , .ds3_awvalid(w_port__AXI_Lite_Matrix_0__ds3_awvalid)
                                                                    , .ds3_bready(w_port__AXI_Lite_Matrix_0__ds3_bready)
                                                                    , .ds3_bresp(w_port__AXI_Lite_Matrix_0__ds3_bresp)
                                                                    , .ds3_bvalid(w_port__AXI_Lite_Matrix_0__ds3_bvalid)
                                                                    , .ds3_rdata(w_port__AXI_Lite_Matrix_0__ds3_rdata)
                                                                    , .ds3_rready(w_port__AXI_Lite_Matrix_0__ds3_rready)
                                                                    , .ds3_rresp(w_port__AXI_Lite_Matrix_0__ds3_rresp)
                                                                    , .ds3_rvalid(w_port__AXI_Lite_Matrix_0__ds3_rvalid)
                                                                    , .ds3_wdata(w_port__AXI_Lite_Matrix_0__ds3_wdata)
                                                                    , .ds3_wready(w_port__AXI_Lite_Matrix_0__ds3_wready)
                                                                    , .ds3_wstrb()
                                                                    , .ds3_wvalid(w_port__AXI_Lite_Matrix_0__ds3_wvalid) );

    axi_system_adc_fdma_writer_0 axi_system_adc_fdma_writer_0_Inst ( 
                                                                      .s_axi_lite_awaddr(w_port__adc_fdma_writer_0__s_axi_lite_awaddr)
                                                                    , .s_axi_lite_awvalid(w_port__adc_fdma_writer_0__s_axi_lite_awvalid)
                                                                    , .s_axi_lite_awready(w_port__adc_fdma_writer_0__s_axi_lite_awready)
                                                                    , .s_axi_lite_wdata(w_port__adc_fdma_writer_0__s_axi_lite_wdata)
                                                                    , .s_axi_lite_wstrb(w_port__adc_fdma_writer_0__s_axi_lite_wstrb)
                                                                    , .s_axi_lite_wvalid(w_port__adc_fdma_writer_0__s_axi_lite_wvalid)
                                                                    , .s_axi_lite_wready(w_port__adc_fdma_writer_0__s_axi_lite_wready)
                                                                    , .s_axi_lite_bresp(w_port__adc_fdma_writer_0__s_axi_lite_bresp)
                                                                    , .s_axi_lite_bvalid(w_port__adc_fdma_writer_0__s_axi_lite_bvalid)
                                                                    , .s_axi_lite_bready(w_port__adc_fdma_writer_0__s_axi_lite_bready)
                                                                    , .s_axi_lite_araddr(w_port__adc_fdma_writer_0__s_axi_lite_araddr)
                                                                    , .s_axi_lite_arvalid(w_port__adc_fdma_writer_0__s_axi_lite_arvalid)
                                                                    , .s_axi_lite_arready(w_port__adc_fdma_writer_0__s_axi_lite_arready)
                                                                    , .s_axi_lite_rdata(w_port__adc_fdma_writer_0__s_axi_lite_rdata)
                                                                    , .s_axi_lite_rresp(w_port__adc_fdma_writer_0__s_axi_lite_rresp)
                                                                    , .s_axi_lite_rvalid(w_port__adc_fdma_writer_0__s_axi_lite_rvalid)
                                                                    , .s_axi_lite_rready(w_port__adc_fdma_writer_0__s_axi_lite_rready)
                                                                    , .s_axis_s2mm_tdata(w_port__adc_fdma_writer_0__s_axis_s2mm_tdata)
                                                                    , .s_axis_s2mm_tkeep(w_port__adc_fdma_writer_0__s_axis_s2mm_tkeep)
                                                                    , .s_axis_s2mm_tlast(w_port__adc_fdma_writer_0__s_axis_s2mm_tlast)
                                                                    , .s_axis_s2mm_tvalid(w_port__adc_fdma_writer_0__s_axis_s2mm_tvalid)
                                                                    , .s_axis_s2mm_tready(w_port__adc_fdma_writer_0__s_axis_s2mm_tready)
                                                                    , .s_axi_lite_aclk(w_port__adc_fdma_writer_0__s_axi_lite_aclk)
                                                                    , .axi_resetn(w_port__adc_fdma_writer_0__axi_resetn)
                                                                    , .m_axi_s2mm_awid(w_port__adc_fdma_writer_0__m_axi_s2mm_awid)
                                                                    , .m_axi_s2mm_awaddr(w_port__adc_fdma_writer_0__m_axi_s2mm_awaddr)
                                                                    , .m_axi_s2mm_awlen(w_port__adc_fdma_writer_0__m_axi_s2mm_awlen)
                                                                    , .m_axi_s2mm_awsize(w_port__adc_fdma_writer_0__m_axi_s2mm_awsize)
                                                                    , .m_axi_s2mm_awburst(w_port__adc_fdma_writer_0__m_axi_s2mm_awburst)
                                                                    , .m_axi_s2mm_awlock(w_port__adc_fdma_writer_0__m_axi_s2mm_awlock)
                                                                    , .m_axi_s2mm_awcache(w_port__adc_fdma_writer_0__m_axi_s2mm_awcache)
                                                                    , .m_axi_s2mm_awprot(w_port__adc_fdma_writer_0__m_axi_s2mm_awprot)
                                                                    , .m_axi_s2mm_awqos(w_port__adc_fdma_writer_0__m_axi_s2mm_awqos)
                                                                    , .m_axi_s2mm_awvalid(w_port__adc_fdma_writer_0__m_axi_s2mm_awvalid)
                                                                    , .m_axi_s2mm_awready(w_port__adc_fdma_writer_0__m_axi_s2mm_awready)
                                                                    , .m_axi_s2mm_wdata(w_port__adc_fdma_writer_0__m_axi_s2mm_wdata)
                                                                    , .m_axi_s2mm_wstrb(w_port__adc_fdma_writer_0__m_axi_s2mm_wstrb)
                                                                    , .m_axi_s2mm_wlast(w_port__adc_fdma_writer_0__m_axi_s2mm_wlast)
                                                                    , .m_axi_s2mm_wvalid(w_port__adc_fdma_writer_0__m_axi_s2mm_wvalid)
                                                                    , .m_axi_s2mm_wready(w_port__adc_fdma_writer_0__m_axi_s2mm_wready)
                                                                    , .m_axi_s2mm_bid(w_port__adc_fdma_writer_0__m_axi_s2mm_bid)
                                                                    , .m_axi_s2mm_bresp(w_port__adc_fdma_writer_0__m_axi_s2mm_bresp)
                                                                    , .m_axi_s2mm_bvalid(w_port__adc_fdma_writer_0__m_axi_s2mm_bvalid)
                                                                    , .m_axi_s2mm_bready(w_port__adc_fdma_writer_0__m_axi_s2mm_bready) );

    axi_system_HP1_AXI_Matrix_0 axi_system_HP1_AXI_Matrix_0_Inst ( 
                                                                    .us0_araddr(w_port__HP1_AXI_Matrix_0__us0_araddr)
                                                                  , .us0_arburst(w_port__HP1_AXI_Matrix_0__us0_arburst)
                                                                  , .us0_arcache(w_port__HP1_AXI_Matrix_0__us0_arcache)
                                                                  , .us0_arid(w_port__HP1_AXI_Matrix_0__us0_arid)
                                                                  , .us0_arlen(w_port__HP1_AXI_Matrix_0__us0_arlen)
                                                                  , .us0_arlock(w_port__HP1_AXI_Matrix_0__us0_arlock)
                                                                  , .us0_arprot(w_port__HP1_AXI_Matrix_0__us0_arprot)
                                                                  , .us0_arqos(w_port__HP1_AXI_Matrix_0__us0_arqos)
                                                                  , .us0_arready()
                                                                  , .us0_arsize(w_port__HP1_AXI_Matrix_0__us0_arsize)
                                                                  , .us0_arvalid(w_port__HP1_AXI_Matrix_0__us0_arvalid)
                                                                  , .us0_awaddr(w_port__HP1_AXI_Matrix_0__us0_awaddr)
                                                                  , .us0_awburst(w_port__HP1_AXI_Matrix_0__us0_awburst)
                                                                  , .us0_awcache(w_port__HP1_AXI_Matrix_0__us0_awcache)
                                                                  , .us0_awid(w_port__HP1_AXI_Matrix_0__us0_awid)
                                                                  , .us0_awlen(w_port__HP1_AXI_Matrix_0__us0_awlen)
                                                                  , .us0_awlock(w_port__HP1_AXI_Matrix_0__us0_awlock)
                                                                  , .us0_awprot(w_port__HP1_AXI_Matrix_0__us0_awprot)
                                                                  , .us0_awqos(w_port__HP1_AXI_Matrix_0__us0_awqos)
                                                                  , .us0_awready(w_port__HP1_AXI_Matrix_0__us0_awready)
                                                                  , .us0_awsize(w_port__HP1_AXI_Matrix_0__us0_awsize)
                                                                  , .us0_awvalid(w_port__HP1_AXI_Matrix_0__us0_awvalid)
                                                                  , .us0_bid(w_port__HP1_AXI_Matrix_0__us0_bid)
                                                                  , .us0_bready(w_port__HP1_AXI_Matrix_0__us0_bready)
                                                                  , .us0_bresp(w_port__HP1_AXI_Matrix_0__us0_bresp)
                                                                  , .us0_bvalid(w_port__HP1_AXI_Matrix_0__us0_bvalid)
                                                                  , .us0_rdata()
                                                                  , .us0_rid()
                                                                  , .us0_rlast()
                                                                  , .us0_rready(w_port__HP1_AXI_Matrix_0__us0_rready)
                                                                  , .us0_rresp()
                                                                  , .us0_rvalid()
                                                                  , .us0_wdata(w_port__HP1_AXI_Matrix_0__us0_wdata)
                                                                  , .us0_wlast(w_port__HP1_AXI_Matrix_0__us0_wlast)
                                                                  , .us0_wready(w_port__HP1_AXI_Matrix_0__us0_wready)
                                                                  , .us0_wstrb(w_port__HP1_AXI_Matrix_0__us0_wstrb)
                                                                  , .us0_wvalid(w_port__HP1_AXI_Matrix_0__us0_wvalid)
                                                                  , .us1_araddr(w_port__HP1_AXI_Matrix_0__us1_araddr)
                                                                  , .us1_arburst(w_port__HP1_AXI_Matrix_0__us1_arburst)
                                                                  , .us1_arcache(w_port__HP1_AXI_Matrix_0__us1_arcache)
                                                                  , .us1_arid(w_port__HP1_AXI_Matrix_0__us1_arid)
                                                                  , .us1_arlen(w_port__HP1_AXI_Matrix_0__us1_arlen)
                                                                  , .us1_arlock(w_port__HP1_AXI_Matrix_0__us1_arlock)
                                                                  , .us1_arprot(w_port__HP1_AXI_Matrix_0__us1_arprot)
                                                                  , .us1_arqos(w_port__HP1_AXI_Matrix_0__us1_arqos)
                                                                  , .us1_arready(w_port__HP1_AXI_Matrix_0__us1_arready)
                                                                  , .us1_arsize(w_port__HP1_AXI_Matrix_0__us1_arsize)
                                                                  , .us1_arvalid(w_port__HP1_AXI_Matrix_0__us1_arvalid)
                                                                  , .us1_awaddr(w_port__HP1_AXI_Matrix_0__us1_awaddr)
                                                                  , .us1_awburst(w_port__HP1_AXI_Matrix_0__us1_awburst)
                                                                  , .us1_awcache(w_port__HP1_AXI_Matrix_0__us1_awcache)
                                                                  , .us1_awid(w_port__HP1_AXI_Matrix_0__us1_awid)
                                                                  , .us1_awlen(w_port__HP1_AXI_Matrix_0__us1_awlen)
                                                                  , .us1_awlock(w_port__HP1_AXI_Matrix_0__us1_awlock)
                                                                  , .us1_awprot(w_port__HP1_AXI_Matrix_0__us1_awprot)
                                                                  , .us1_awqos(w_port__HP1_AXI_Matrix_0__us1_awqos)
                                                                  , .us1_awready(w_port__HP1_AXI_Matrix_0__us1_awready)
                                                                  , .us1_awsize(w_port__HP1_AXI_Matrix_0__us1_awsize)
                                                                  , .us1_awvalid(w_port__HP1_AXI_Matrix_0__us1_awvalid)
                                                                  , .us1_bid(w_port__HP1_AXI_Matrix_0__us1_bid)
                                                                  , .us1_bready(w_port__HP1_AXI_Matrix_0__us1_bready)
                                                                  , .us1_bresp(w_port__HP1_AXI_Matrix_0__us1_bresp)
                                                                  , .us1_bvalid(w_port__HP1_AXI_Matrix_0__us1_bvalid)
                                                                  , .us1_rdata(w_port__HP1_AXI_Matrix_0__us1_rdata)
                                                                  , .us1_rid(w_port__HP1_AXI_Matrix_0__us1_rid)
                                                                  , .us1_rlast(w_port__HP1_AXI_Matrix_0__us1_rlast)
                                                                  , .us1_rready(w_port__HP1_AXI_Matrix_0__us1_rready)
                                                                  , .us1_rresp(w_port__HP1_AXI_Matrix_0__us1_rresp)
                                                                  , .us1_rvalid(w_port__HP1_AXI_Matrix_0__us1_rvalid)
                                                                  , .us1_wdata(w_port__HP1_AXI_Matrix_0__us1_wdata)
                                                                  , .us1_wlast(w_port__HP1_AXI_Matrix_0__us1_wlast)
                                                                  , .us1_wready(w_port__HP1_AXI_Matrix_0__us1_wready)
                                                                  , .us1_wstrb(w_port__HP1_AXI_Matrix_0__us1_wstrb)
                                                                  , .us1_wvalid(w_port__HP1_AXI_Matrix_0__us1_wvalid)
                                                                  , .aclk(w_port__HP1_AXI_Matrix_0__aclk)
                                                                  , .aresetn(w_port__HP1_AXI_Matrix_0__aresetn)
                                                                  , .ds0_araddr(w_port__HP1_AXI_Matrix_0__ds0_araddr)
                                                                  , .ds0_arburst(w_port__HP1_AXI_Matrix_0__ds0_arburst)
                                                                  , .ds0_arcache(w_port__HP1_AXI_Matrix_0__ds0_arcache)
                                                                  , .ds0_arid(w_port__HP1_AXI_Matrix_0__ds0_arid)
                                                                  , .ds0_arlen(w_port__HP1_AXI_Matrix_0__ds0_arlen)
                                                                  , .ds0_arlock(w_port__HP1_AXI_Matrix_0__ds0_arlock)
                                                                  , .ds0_arprot(w_port__HP1_AXI_Matrix_0__ds0_arprot)
                                                                  , .ds0_arqos(w_port__HP1_AXI_Matrix_0__ds0_arqos)
                                                                  , .ds0_arregion()
                                                                  , .ds0_arready(w_port__HP1_AXI_Matrix_0__ds0_arready)
                                                                  , .ds0_arsize(w_port__HP1_AXI_Matrix_0__ds0_arsize)
                                                                  , .ds0_arvalid(w_port__HP1_AXI_Matrix_0__ds0_arvalid)
                                                                  , .ds0_awaddr(w_port__HP1_AXI_Matrix_0__ds0_awaddr)
                                                                  , .ds0_awburst(w_port__HP1_AXI_Matrix_0__ds0_awburst)
                                                                  , .ds0_awcache(w_port__HP1_AXI_Matrix_0__ds0_awcache)
                                                                  , .ds0_awid(w_port__HP1_AXI_Matrix_0__ds0_awid)
                                                                  , .ds0_awlen(w_port__HP1_AXI_Matrix_0__ds0_awlen)
                                                                  , .ds0_awlock(w_port__HP1_AXI_Matrix_0__ds0_awlock)
                                                                  , .ds0_awprot(w_port__HP1_AXI_Matrix_0__ds0_awprot)
                                                                  , .ds0_awqos(w_port__HP1_AXI_Matrix_0__ds0_awqos)
                                                                  , .ds0_awregion()
                                                                  , .ds0_awready(w_port__HP1_AXI_Matrix_0__ds0_awready)
                                                                  , .ds0_awsize(w_port__HP1_AXI_Matrix_0__ds0_awsize)
                                                                  , .ds0_awvalid(w_port__HP1_AXI_Matrix_0__ds0_awvalid)
                                                                  , .ds0_bid(w_port__HP1_AXI_Matrix_0__ds0_bid)
                                                                  , .ds0_bready(w_port__HP1_AXI_Matrix_0__ds0_bready)
                                                                  , .ds0_bresp(w_port__HP1_AXI_Matrix_0__ds0_bresp)
                                                                  , .ds0_bvalid(w_port__HP1_AXI_Matrix_0__ds0_bvalid)
                                                                  , .ds0_rdata(w_port__HP1_AXI_Matrix_0__ds0_rdata)
                                                                  , .ds0_rid(w_port__HP1_AXI_Matrix_0__ds0_rid)
                                                                  , .ds0_rlast(w_port__HP1_AXI_Matrix_0__ds0_rlast)
                                                                  , .ds0_rready(w_port__HP1_AXI_Matrix_0__ds0_rready)
                                                                  , .ds0_rresp(w_port__HP1_AXI_Matrix_0__ds0_rresp)
                                                                  , .ds0_rvalid(w_port__HP1_AXI_Matrix_0__ds0_rvalid)
                                                                  , .ds0_wdata(w_port__HP1_AXI_Matrix_0__ds0_wdata)
                                                                  , .ds0_wlast(w_port__HP1_AXI_Matrix_0__ds0_wlast)
                                                                  , .ds0_wready(w_port__HP1_AXI_Matrix_0__ds0_wready)
                                                                  , .ds0_wstrb(w_port__HP1_AXI_Matrix_0__ds0_wstrb)
                                                                  , .ds0_wvalid(w_port__HP1_AXI_Matrix_0__ds0_wvalid) );

    axi_system_HP1_Protocol_Converter_0 axi_system_HP1_Protocol_Converter_0_Inst ( 
                                                                                    .us_axi_awid(w_port__HP1_Protocol_Converter_0__us_axi_awid)
                                                                                  , .us_axi_awaddr(w_port__HP1_Protocol_Converter_0__us_axi_awaddr)
                                                                                  , .us_axi_awlen(w_port__HP1_Protocol_Converter_0__us_axi_awlen)
                                                                                  , .us_axi_awsize(w_port__HP1_Protocol_Converter_0__us_axi_awsize)
                                                                                  , .us_axi_awburst(w_port__HP1_Protocol_Converter_0__us_axi_awburst)
                                                                                  , .us_axi_awlock(w_port__HP1_Protocol_Converter_0__us_axi_awlock)
                                                                                  , .us_axi_awcache(w_port__HP1_Protocol_Converter_0__us_axi_awcache)
                                                                                  , .us_axi_awprot(w_port__HP1_Protocol_Converter_0__us_axi_awprot)
                                                                                  , .us_axi_awqos(w_port__HP1_Protocol_Converter_0__us_axi_awqos)
                                                                                  , .us_axi_awvalid(w_port__HP1_Protocol_Converter_0__us_axi_awvalid)
                                                                                  , .us_axi_awready(w_port__HP1_Protocol_Converter_0__us_axi_awready)
                                                                                  , .us_axi_wdata(w_port__HP1_Protocol_Converter_0__us_axi_wdata)
                                                                                  , .us_axi_wstrb(w_port__HP1_Protocol_Converter_0__us_axi_wstrb)
                                                                                  , .us_axi_wlast(w_port__HP1_Protocol_Converter_0__us_axi_wlast)
                                                                                  , .us_axi_wvalid(w_port__HP1_Protocol_Converter_0__us_axi_wvalid)
                                                                                  , .us_axi_wready(w_port__HP1_Protocol_Converter_0__us_axi_wready)
                                                                                  , .us_axi_bid(w_port__HP1_Protocol_Converter_0__us_axi_bid)
                                                                                  , .us_axi_bresp(w_port__HP1_Protocol_Converter_0__us_axi_bresp)
                                                                                  , .us_axi_bvalid(w_port__HP1_Protocol_Converter_0__us_axi_bvalid)
                                                                                  , .us_axi_bready(w_port__HP1_Protocol_Converter_0__us_axi_bready)
                                                                                  , .us_axi_arid(w_port__HP1_Protocol_Converter_0__us_axi_arid)
                                                                                  , .us_axi_araddr(w_port__HP1_Protocol_Converter_0__us_axi_araddr)
                                                                                  , .us_axi_arlen(w_port__HP1_Protocol_Converter_0__us_axi_arlen)
                                                                                  , .us_axi_arsize(w_port__HP1_Protocol_Converter_0__us_axi_arsize)
                                                                                  , .us_axi_arburst(w_port__HP1_Protocol_Converter_0__us_axi_arburst)
                                                                                  , .us_axi_arlock(w_port__HP1_Protocol_Converter_0__us_axi_arlock)
                                                                                  , .us_axi_arcache(w_port__HP1_Protocol_Converter_0__us_axi_arcache)
                                                                                  , .us_axi_arprot(w_port__HP1_Protocol_Converter_0__us_axi_arprot)
                                                                                  , .us_axi_arqos(w_port__HP1_Protocol_Converter_0__us_axi_arqos)
                                                                                  , .us_axi_arvalid(w_port__HP1_Protocol_Converter_0__us_axi_arvalid)
                                                                                  , .us_axi_arready(w_port__HP1_Protocol_Converter_0__us_axi_arready)
                                                                                  , .us_axi_rid(w_port__HP1_Protocol_Converter_0__us_axi_rid)
                                                                                  , .us_axi_rdata(w_port__HP1_Protocol_Converter_0__us_axi_rdata)
                                                                                  , .us_axi_rresp(w_port__HP1_Protocol_Converter_0__us_axi_rresp)
                                                                                  , .us_axi_rlast(w_port__HP1_Protocol_Converter_0__us_axi_rlast)
                                                                                  , .us_axi_rvalid(w_port__HP1_Protocol_Converter_0__us_axi_rvalid)
                                                                                  , .us_axi_rready(w_port__HP1_Protocol_Converter_0__us_axi_rready)
                                                                                  , .aclk(w_port__HP1_Protocol_Converter_0__aclk)
                                                                                  , .aresetn(w_port__HP1_Protocol_Converter_0__aresetn)
                                                                                  , .ds_axi_awid(w_port__HP1_Protocol_Converter_0__ds_axi_awid)
                                                                                  , .ds_axi_awaddr(w_port__HP1_Protocol_Converter_0__ds_axi_awaddr)
                                                                                  , .ds_axi_awlen(w_port__HP1_Protocol_Converter_0__ds_axi_awlen)
                                                                                  , .ds_axi_awsize(w_port__HP1_Protocol_Converter_0__ds_axi_awsize)
                                                                                  , .ds_axi_awburst(w_port__HP1_Protocol_Converter_0__ds_axi_awburst)
                                                                                  , .ds_axi_awlock(w_port__HP1_Protocol_Converter_0__ds_axi_awlock)
                                                                                  , .ds_axi_awcache(w_port__HP1_Protocol_Converter_0__ds_axi_awcache)
                                                                                  , .ds_axi_awprot(w_port__HP1_Protocol_Converter_0__ds_axi_awprot)
                                                                                  , .ds_axi_awregion()
                                                                                  , .ds_axi_awqos(w_port__HP1_Protocol_Converter_0__ds_axi_awqos)
                                                                                  , .ds_axi_awvalid(w_port__HP1_Protocol_Converter_0__ds_axi_awvalid)
                                                                                  , .ds_axi_awready(w_port__HP1_Protocol_Converter_0__ds_axi_awready)
                                                                                  , .ds_axi_wid()
                                                                                  , .ds_axi_wdata(w_port__HP1_Protocol_Converter_0__ds_axi_wdata)
                                                                                  , .ds_axi_wstrb(w_port__HP1_Protocol_Converter_0__ds_axi_wstrb)
                                                                                  , .ds_axi_wlast(w_port__HP1_Protocol_Converter_0__ds_axi_wlast)
                                                                                  , .ds_axi_wvalid(w_port__HP1_Protocol_Converter_0__ds_axi_wvalid)
                                                                                  , .ds_axi_wready(w_port__HP1_Protocol_Converter_0__ds_axi_wready)
                                                                                  , .ds_axi_bid(w_port__HP1_Protocol_Converter_0__ds_axi_bid)
                                                                                  , .ds_axi_bresp(w_port__HP1_Protocol_Converter_0__ds_axi_bresp)
                                                                                  , .ds_axi_bvalid(w_port__HP1_Protocol_Converter_0__ds_axi_bvalid)
                                                                                  , .ds_axi_bready(w_port__HP1_Protocol_Converter_0__ds_axi_bready)
                                                                                  , .ds_axi_arid(w_port__HP1_Protocol_Converter_0__ds_axi_arid)
                                                                                  , .ds_axi_araddr(w_port__HP1_Protocol_Converter_0__ds_axi_araddr)
                                                                                  , .ds_axi_arlen(w_port__HP1_Protocol_Converter_0__ds_axi_arlen)
                                                                                  , .ds_axi_arsize(w_port__HP1_Protocol_Converter_0__ds_axi_arsize)
                                                                                  , .ds_axi_arburst(w_port__HP1_Protocol_Converter_0__ds_axi_arburst)
                                                                                  , .ds_axi_arlock(w_port__HP1_Protocol_Converter_0__ds_axi_arlock)
                                                                                  , .ds_axi_arcache(w_port__HP1_Protocol_Converter_0__ds_axi_arcache)
                                                                                  , .ds_axi_arprot(w_port__HP1_Protocol_Converter_0__ds_axi_arprot)
                                                                                  , .ds_axi_arregion()
                                                                                  , .ds_axi_arqos(w_port__HP1_Protocol_Converter_0__ds_axi_arqos)
                                                                                  , .ds_axi_arvalid(w_port__HP1_Protocol_Converter_0__ds_axi_arvalid)
                                                                                  , .ds_axi_arready(w_port__HP1_Protocol_Converter_0__ds_axi_arready)
                                                                                  , .ds_axi_rid(w_port__HP1_Protocol_Converter_0__ds_axi_rid)
                                                                                  , .ds_axi_rdata(w_port__HP1_Protocol_Converter_0__ds_axi_rdata)
                                                                                  , .ds_axi_rresp(w_port__HP1_Protocol_Converter_0__ds_axi_rresp)
                                                                                  , .ds_axi_rlast(w_port__HP1_Protocol_Converter_0__ds_axi_rlast)
                                                                                  , .ds_axi_rvalid(w_port__HP1_Protocol_Converter_0__ds_axi_rvalid)
                                                                                  , .ds_axi_rready(w_port__HP1_Protocol_Converter_0__ds_axi_rready) );

    axi_system_HDMI_PLL_0 axi_system_HDMI_PLL_0_Inst ( 
                                                        .refclk(w_port__HDMI_PLL_0__refclk)
                                                      , .clk0_out()
                                                      , .clk1_out(w_port__HDMI_PLL_0__clk1_out)
                                                      , .clk2_out(w_port__HDMI_PLL_0__clk2_out)
                                                      , .lock(w_port__HDMI_PLL_0__lock) );

    axi_system_HDMI_PLL_1 axi_system_HDMI_PLL_1_Inst ( 
                                                        .refclk(w_port__HDMI_PLL_1__refclk)
                                                      , .reset(w_port__HDMI_PLL_1__reset)
                                                      , .clk0_out(w_port__HDMI_PLL_1__clk0_out)
                                                      , .lock(w_port__HDMI_PLL_1__lock) );

    axi_system_VDMA_0 axi_system_VDMA_0_Inst ( 
                                                .axi_lite_awvalid(w_port__VDMA_0__axi_lite_awvalid)
                                              , .axi_lite_awready(w_port__VDMA_0__axi_lite_awready)
                                              , .axi_lite_awaddr(w_port__VDMA_0__axi_lite_awaddr)
                                              , .axi_lite_wvalid(w_port__VDMA_0__axi_lite_wvalid)
                                              , .axi_lite_wready(w_port__VDMA_0__axi_lite_wready)
                                              , .axi_lite_wdata(w_port__VDMA_0__axi_lite_wdata)
                                              , .axi_lite_bresp(w_port__VDMA_0__axi_lite_bresp)
                                              , .axi_lite_bvalid(w_port__VDMA_0__axi_lite_bvalid)
                                              , .axi_lite_bready(w_port__VDMA_0__axi_lite_bready)
                                              , .axi_lite_arvalid(w_port__VDMA_0__axi_lite_arvalid)
                                              , .axi_lite_arready(w_port__VDMA_0__axi_lite_arready)
                                              , .axi_lite_araddr(w_port__VDMA_0__axi_lite_araddr)
                                              , .axi_lite_rvalid(w_port__VDMA_0__axi_lite_rvalid)
                                              , .axi_lite_rready(w_port__VDMA_0__axi_lite_rready)
                                              , .axi_lite_rdata(w_port__VDMA_0__axi_lite_rdata)
                                              , .axi_lite_rresp(w_port__VDMA_0__axi_lite_rresp)
                                              , .s_axis_s2mm_tdata(w_port__VDMA_0__s_axis_s2mm_tdata)
                                              , .s_axis_s2mm_tkeep(w_port__VDMA_0__s_axis_s2mm_tkeep)
                                              , .s_axis_s2mm_tuser(w_port__VDMA_0__s_axis_s2mm_tuser)
                                              , .s_axis_s2mm_tvalid(w_port__VDMA_0__s_axis_s2mm_tvalid)
                                              , .s_axis_s2mm_tready()
                                              , .s_axis_s2mm_tlast(w_port__VDMA_0__s_axis_s2mm_tlast)
                                              , .s_axi_lite_aclk(w_port__VDMA_0__s_axi_lite_aclk)
                                              , .m_axi_mm2s_aclk(w_port__VDMA_0__m_axi_mm2s_aclk)
                                              , .m_axis_mm2s_aclk(w_port__VDMA_0__m_axis_mm2s_aclk)
                                              , .m_axi_s2mm_aclk(w_port__VDMA_0__m_axi_s2mm_aclk)
                                              , .s_axis_s2mm_aclk(w_port__VDMA_0__s_axis_s2mm_aclk)
                                              , .resetn(w_port__VDMA_0__resetn)
                                              , .mm2s_fsync(w_port__VDMA_0__mm2s_fsync)
                                              , .s2mm_fsync(w_port__VDMA_0__s2mm_fsync)
                                              , .m_axi_mm2s_araddr(w_port__VDMA_0__m_axi_mm2s_araddr)
                                              , .m_axi_mm2s_arlen(w_port__VDMA_0__m_axi_mm2s_arlen)
                                              , .m_axi_mm2s_arsize(w_port__VDMA_0__m_axi_mm2s_arsize)
                                              , .m_axi_mm2s_arburst(w_port__VDMA_0__m_axi_mm2s_arburst)
                                              , .m_axi_mm2s_arprot(w_port__VDMA_0__m_axi_mm2s_arprot)
                                              , .m_axi_mm2s_arcache(w_port__VDMA_0__m_axi_mm2s_arcache)
                                              , .m_axi_mm2s_arvalid(w_port__VDMA_0__m_axi_mm2s_arvalid)
                                              , .m_axi_mm2s_arready(w_port__VDMA_0__m_axi_mm2s_arready)
                                              , .m_axi_mm2s_rdata(w_port__VDMA_0__m_axi_mm2s_rdata)
                                              , .m_axi_mm2s_rresp(w_port__VDMA_0__m_axi_mm2s_rresp)
                                              , .m_axi_mm2s_rlast(w_port__VDMA_0__m_axi_mm2s_rlast)
                                              , .m_axi_mm2s_rvalid(w_port__VDMA_0__m_axi_mm2s_rvalid)
                                              , .m_axi_mm2s_rready(w_port__VDMA_0__m_axi_mm2s_rready)
                                              , .m_axi_s2mm_awaddr()
                                              , .m_axi_s2mm_awlen()
                                              , .m_axi_s2mm_awsize()
                                              , .m_axi_s2mm_awburst()
                                              , .m_axi_s2mm_awprot()
                                              , .m_axi_s2mm_awcache()
                                              , .m_axi_s2mm_awvalid()
                                              , .m_axi_s2mm_awready(w_port__VDMA_0__m_axi_s2mm_awready)
                                              , .m_axi_s2mm_wdata()
                                              , .m_axi_s2mm_wstrb()
                                              , .m_axi_s2mm_wlast()
                                              , .m_axi_s2mm_wvalid()
                                              , .m_axi_s2mm_wready(w_port__VDMA_0__m_axi_s2mm_wready)
                                              , .m_axi_s2mm_bresp(w_port__VDMA_0__m_axi_s2mm_bresp)
                                              , .m_axi_s2mm_bvalid(w_port__VDMA_0__m_axi_s2mm_bvalid)
                                              , .m_axi_s2mm_bready()
                                              , .m_axis_mm2s_tdata(w_port__VDMA_0__m_axis_mm2s_tdata)
                                              , .m_axis_mm2s_tkeep()
                                              , .m_axis_mm2s_tuser(w_port__VDMA_0__m_axis_mm2s_tuser)
                                              , .m_axis_mm2s_tvalid(w_port__VDMA_0__m_axis_mm2s_tvalid)
                                              , .m_axis_mm2s_tready(w_port__VDMA_0__m_axis_mm2s_tready)
                                              , .m_axis_mm2s_tlast(w_port__VDMA_0__m_axis_mm2s_tlast)
                                              , .mm2s_frame_ptr_out()
                                              , .s2mm_frame_ptr_out()
                                              , .mm2s_introut(w_port__VDMA_0__mm2s_introut)
                                              , .s2mm_introut(w_port__VDMA_0__s2mm_introut) );

    axi_system_AXI4_Stream_to_Video_Out_0 axi_system_AXI4_Stream_to_Video_Out_0_Inst ( 
                                                                                        .s_axis_video_tdata(w_port__AXI4_Stream_to_Video_Out_0__s_axis_video_tdata)
                                                                                      , .s_axis_video_tvalid(w_port__AXI4_Stream_to_Video_Out_0__s_axis_video_tvalid)
                                                                                      , .s_axis_video_tready(w_port__AXI4_Stream_to_Video_Out_0__s_axis_video_tready)
                                                                                      , .s_axis_video_tuser(w_port__AXI4_Stream_to_Video_Out_0__s_axis_video_tuser)
                                                                                      , .s_axis_video_tlast(w_port__AXI4_Stream_to_Video_Out_0__s_axis_video_tlast)
                                                                                      , .aclk(w_port__AXI4_Stream_to_Video_Out_0__aclk)
                                                                                      , .aclken(w_port__AXI4_Stream_to_Video_Out_0__aclken)
                                                                                      , .aresetn(w_port__AXI4_Stream_to_Video_Out_0__aresetn)
                                                                                      , .fid(w_port__AXI4_Stream_to_Video_Out_0__fid)
                                                                                      , .vid_io_out_clk(w_port__AXI4_Stream_to_Video_Out_0__vid_io_out_clk)
                                                                                      , .vid_io_out_reset(w_port__AXI4_Stream_to_Video_Out_0__vid_io_out_reset)
                                                                                      , .vid_io_out_ce(w_port__AXI4_Stream_to_Video_Out_0__vid_io_out_ce)
                                                                                      , .vtg_vsync(w_port__AXI4_Stream_to_Video_Out_0__vtg_vsync)
                                                                                      , .vtg_hsync(w_port__AXI4_Stream_to_Video_Out_0__vtg_hsync)
                                                                                      , .vtg_vblank(w_port__AXI4_Stream_to_Video_Out_0__vtg_vblank)
                                                                                      , .vtg_hblank(w_port__AXI4_Stream_to_Video_Out_0__vtg_hblank)
                                                                                      , .vtg_active_video(w_port__AXI4_Stream_to_Video_Out_0__vtg_active_video)
                                                                                      , .vtg_field_id(w_port__AXI4_Stream_to_Video_Out_0__vtg_field_id)
                                                                                      , .vid_active_video(w_port__AXI4_Stream_to_Video_Out_0__vid_active_video)
                                                                                      , .vid_vsync(w_port__AXI4_Stream_to_Video_Out_0__vid_vsync)
                                                                                      , .vid_hsync(w_port__AXI4_Stream_to_Video_Out_0__vid_hsync)
                                                                                      , .vid_vblank()
                                                                                      , .vid_hblank()
                                                                                      , .vid_field_id()
                                                                                      , .vid_data(w_port__AXI4_Stream_to_Video_Out_0__vid_data)
                                                                                      , .vtg_ce(w_port__AXI4_Stream_to_Video_Out_0__vtg_ce)
                                                                                      , .locked(w_port__AXI4_Stream_to_Video_Out_0__locked)
                                                                                      , .overflow()
                                                                                      , .underflow()
                                                                                      , .fifo_read_level()
                                                                                      , .status()
                                                                                      , .sof_state_out() );

    axi_system_HDMI_VTG_0 axi_system_HDMI_VTG_0_Inst ( 
                                                        .s_axi_awaddr(w_port__HDMI_VTG_0__s_axi_awaddr)
                                                      , .s_axi_awvalid(w_port__HDMI_VTG_0__s_axi_awvalid)
                                                      , .s_axi_awready(w_port__HDMI_VTG_0__s_axi_awready)
                                                      , .s_axi_wdata(w_port__HDMI_VTG_0__s_axi_wdata)
                                                      , .s_axi_wstrb(w_port__HDMI_VTG_0__s_axi_wstrb)
                                                      , .s_axi_wvalid(w_port__HDMI_VTG_0__s_axi_wvalid)
                                                      , .s_axi_wready(w_port__HDMI_VTG_0__s_axi_wready)
                                                      , .s_axi_bresp(w_port__HDMI_VTG_0__s_axi_bresp)
                                                      , .s_axi_bvalid(w_port__HDMI_VTG_0__s_axi_bvalid)
                                                      , .s_axi_bready(w_port__HDMI_VTG_0__s_axi_bready)
                                                      , .s_axi_araddr(w_port__HDMI_VTG_0__s_axi_araddr)
                                                      , .s_axi_arvalid(w_port__HDMI_VTG_0__s_axi_arvalid)
                                                      , .s_axi_arready(w_port__HDMI_VTG_0__s_axi_arready)
                                                      , .s_axi_rdata(w_port__HDMI_VTG_0__s_axi_rdata)
                                                      , .s_axi_rresp(w_port__HDMI_VTG_0__s_axi_rresp)
                                                      , .s_axi_rvalid(w_port__HDMI_VTG_0__s_axi_rvalid)
                                                      , .s_axi_rready(w_port__HDMI_VTG_0__s_axi_rready)
                                                      , .aclk(w_port__HDMI_VTG_0__aclk)
                                                      , .arst_n(w_port__HDMI_VTG_0__arst_n)
                                                      , .ref_clk(w_port__HDMI_VTG_0__ref_clk)
                                                      , .vtg_ce(w_port__HDMI_VTG_0__vtg_ce)
                                                      , .vtg_pclk_locked(w_port__HDMI_VTG_0__vtg_pclk_locked)
                                                      , .vtg_pclk(w_port__HDMI_VTG_0__vtg_pclk)
                                                      , .vtg_hsync(w_port__HDMI_VTG_0__vtg_hsync)
                                                      , .vtg_vsync(w_port__HDMI_VTG_0__vtg_vsync)
                                                      , .vtg_hblank(w_port__HDMI_VTG_0__vtg_hblank)
                                                      , .vtg_vblank(w_port__HDMI_VTG_0__vtg_vblank)
                                                      , .vtg_active_video(w_port__HDMI_VTG_0__vtg_active_video) );

    axi_system_HDMI_TX_0 axi_system_HDMI_TX_0_Inst ( 
                                                      .I_pixel_clk(w_port__HDMI_TX_0__I_pixel_clk)
                                                    , .I_serial_clk(w_port__HDMI_TX_0__I_serial_clk)
                                                    , .I_rst(w_port__HDMI_TX_0__I_rst)
                                                    , .I_video_in_data(w_port__HDMI_TX_0__I_video_in_data)
                                                    , .I_video_in_de(w_port__HDMI_TX_0__I_video_in_de)
                                                    , .I_video_in_vs(w_port__HDMI_TX_0__I_video_in_vs)
                                                    , .I_video_in_hs(w_port__HDMI_TX_0__I_video_in_hs)
                                                    , .O_hdmi_clk_p(w_port__HDMI_TX_0__O_hdmi_clk_p)
                                                    , .O_hdmi_tx_p(w_port__HDMI_TX_0__O_hdmi_tx_p) );

    axi_system_HDMI_IRQ_Concat_0 axi_system_HDMI_IRQ_Concat_0_Inst ( 
                                                                      .In0(w_port__HDMI_IRQ_Concat_0__In0)
                                                                    , .In1(w_port__HDMI_IRQ_Concat_0__In1)
                                                                    , .In2(w_port__HDMI_IRQ_Concat_0__In2)
                                                                    , .In3(w_port__HDMI_IRQ_Concat_0__In3)
                                                                    , .In4(w_port__HDMI_IRQ_Concat_0__In4)
                                                                    , .In5(w_port__HDMI_IRQ_Concat_0__In5)
                                                                    , .In6(w_port__HDMI_IRQ_Concat_0__In6)
                                                                    , .In7(w_port__HDMI_IRQ_Concat_0__In7)
                                                                    , .In8(w_port__HDMI_IRQ_Concat_0__In8)
                                                                    , .In9(w_port__HDMI_IRQ_Concat_0__In9)
                                                                    , .In10(w_port__HDMI_IRQ_Concat_0__In10)
                                                                    , .In11(w_port__HDMI_IRQ_Concat_0__In11)
                                                                    , .In12(w_port__HDMI_IRQ_Concat_0__In12)
                                                                    , .In13(w_port__HDMI_IRQ_Concat_0__In13)
                                                                    , .In14(w_port__HDMI_IRQ_Concat_0__In14)
                                                                    , .In15(w_port__HDMI_IRQ_Concat_0__In15)
                                                                    , .Dout(w_port__HDMI_IRQ_Concat_0__Dout) );

    axi_system_HDMI_HP0_Protocol_Converter_0 axi_system_HDMI_HP0_Protocol_Converter_0_Inst ( 
                                                                                              .us_axi_awid(w_port__HDMI_HP0_Protocol_Converter_0__us_axi_awid)
                                                                                            , .us_axi_awaddr(w_port__HDMI_HP0_Protocol_Converter_0__us_axi_awaddr)
                                                                                            , .us_axi_awlen(w_port__HDMI_HP0_Protocol_Converter_0__us_axi_awlen)
                                                                                            , .us_axi_awsize(w_port__HDMI_HP0_Protocol_Converter_0__us_axi_awsize)
                                                                                            , .us_axi_awburst(w_port__HDMI_HP0_Protocol_Converter_0__us_axi_awburst)
                                                                                            , .us_axi_awlock(w_port__HDMI_HP0_Protocol_Converter_0__us_axi_awlock)
                                                                                            , .us_axi_awcache(w_port__HDMI_HP0_Protocol_Converter_0__us_axi_awcache)
                                                                                            , .us_axi_awprot(w_port__HDMI_HP0_Protocol_Converter_0__us_axi_awprot)
                                                                                            , .us_axi_awqos(w_port__HDMI_HP0_Protocol_Converter_0__us_axi_awqos)
                                                                                            , .us_axi_awvalid(w_port__HDMI_HP0_Protocol_Converter_0__us_axi_awvalid)
                                                                                            , .us_axi_awready()
                                                                                            , .us_axi_wdata(w_port__HDMI_HP0_Protocol_Converter_0__us_axi_wdata)
                                                                                            , .us_axi_wstrb(w_port__HDMI_HP0_Protocol_Converter_0__us_axi_wstrb)
                                                                                            , .us_axi_wlast(w_port__HDMI_HP0_Protocol_Converter_0__us_axi_wlast)
                                                                                            , .us_axi_wvalid(w_port__HDMI_HP0_Protocol_Converter_0__us_axi_wvalid)
                                                                                            , .us_axi_wready()
                                                                                            , .us_axi_bid()
                                                                                            , .us_axi_bresp()
                                                                                            , .us_axi_bvalid()
                                                                                            , .us_axi_bready(w_port__HDMI_HP0_Protocol_Converter_0__us_axi_bready)
                                                                                            , .us_axi_arid(w_port__HDMI_HP0_Protocol_Converter_0__us_axi_arid)
                                                                                            , .us_axi_araddr(w_port__HDMI_HP0_Protocol_Converter_0__us_axi_araddr)
                                                                                            , .us_axi_arlen(w_port__HDMI_HP0_Protocol_Converter_0__us_axi_arlen)
                                                                                            , .us_axi_arsize(w_port__HDMI_HP0_Protocol_Converter_0__us_axi_arsize)
                                                                                            , .us_axi_arburst(w_port__HDMI_HP0_Protocol_Converter_0__us_axi_arburst)
                                                                                            , .us_axi_arlock(w_port__HDMI_HP0_Protocol_Converter_0__us_axi_arlock)
                                                                                            , .us_axi_arcache(w_port__HDMI_HP0_Protocol_Converter_0__us_axi_arcache)
                                                                                            , .us_axi_arprot(w_port__HDMI_HP0_Protocol_Converter_0__us_axi_arprot)
                                                                                            , .us_axi_arqos(w_port__HDMI_HP0_Protocol_Converter_0__us_axi_arqos)
                                                                                            , .us_axi_arvalid(w_port__HDMI_HP0_Protocol_Converter_0__us_axi_arvalid)
                                                                                            , .us_axi_arready(w_port__HDMI_HP0_Protocol_Converter_0__us_axi_arready)
                                                                                            , .us_axi_rid()
                                                                                            , .us_axi_rdata(w_port__HDMI_HP0_Protocol_Converter_0__us_axi_rdata)
                                                                                            , .us_axi_rresp(w_port__HDMI_HP0_Protocol_Converter_0__us_axi_rresp)
                                                                                            , .us_axi_rlast(w_port__HDMI_HP0_Protocol_Converter_0__us_axi_rlast)
                                                                                            , .us_axi_rvalid(w_port__HDMI_HP0_Protocol_Converter_0__us_axi_rvalid)
                                                                                            , .us_axi_rready(w_port__HDMI_HP0_Protocol_Converter_0__us_axi_rready)
                                                                                            , .aclk(w_port__HDMI_HP0_Protocol_Converter_0__aclk)
                                                                                            , .aresetn(w_port__HDMI_HP0_Protocol_Converter_0__aresetn)
                                                                                            , .ds_axi_awid(w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_awid)
                                                                                            , .ds_axi_awaddr(w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_awaddr)
                                                                                            , .ds_axi_awlen(w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_awlen)
                                                                                            , .ds_axi_awsize(w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_awsize)
                                                                                            , .ds_axi_awburst(w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_awburst)
                                                                                            , .ds_axi_awlock(w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_awlock)
                                                                                            , .ds_axi_awcache(w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_awcache)
                                                                                            , .ds_axi_awprot(w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_awprot)
                                                                                            , .ds_axi_awregion()
                                                                                            , .ds_axi_awqos(w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_awqos)
                                                                                            , .ds_axi_awvalid(w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_awvalid)
                                                                                            , .ds_axi_awready(w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_awready)
                                                                                            , .ds_axi_wid()
                                                                                            , .ds_axi_wdata(w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_wdata)
                                                                                            , .ds_axi_wstrb(w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_wstrb)
                                                                                            , .ds_axi_wlast(w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_wlast)
                                                                                            , .ds_axi_wvalid(w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_wvalid)
                                                                                            , .ds_axi_wready(w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_wready)
                                                                                            , .ds_axi_bid(w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_bid)
                                                                                            , .ds_axi_bresp(w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_bresp)
                                                                                            , .ds_axi_bvalid(w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_bvalid)
                                                                                            , .ds_axi_bready(w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_bready)
                                                                                            , .ds_axi_arid(w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_arid)
                                                                                            , .ds_axi_araddr(w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_araddr)
                                                                                            , .ds_axi_arlen(w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_arlen)
                                                                                            , .ds_axi_arsize(w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_arsize)
                                                                                            , .ds_axi_arburst(w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_arburst)
                                                                                            , .ds_axi_arlock(w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_arlock)
                                                                                            , .ds_axi_arcache(w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_arcache)
                                                                                            , .ds_axi_arprot(w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_arprot)
                                                                                            , .ds_axi_arregion()
                                                                                            , .ds_axi_arqos(w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_arqos)
                                                                                            , .ds_axi_arvalid(w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_arvalid)
                                                                                            , .ds_axi_arready(w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_arready)
                                                                                            , .ds_axi_rid(w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_rid)
                                                                                            , .ds_axi_rdata(w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_rdata)
                                                                                            , .ds_axi_rresp(w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_rresp)
                                                                                            , .ds_axi_rlast(w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_rlast)
                                                                                            , .ds_axi_rvalid(w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_rvalid)
                                                                                            , .ds_axi_rready(w_port__HDMI_HP0_Protocol_Converter_0__ds_axi_rready) );

    axi_system_HDMI_Reset_0 axi_system_HDMI_Reset_0_Inst ( 
                                                            .ctrl_clk(w_port__HDMI_Reset_0__ctrl_clk)
                                                          , .mem_clk(w_port__HDMI_Reset_0__mem_clk)
                                                          , .axis_clk(w_port__HDMI_Reset_0__axis_clk)
                                                          , .pixel_clk(w_port__HDMI_Reset_0__pixel_clk)
                                                          , .axi_reset_n(w_port__HDMI_Reset_0__axi_reset_n)
                                                          , .display_pll_locked(w_port__HDMI_Reset_0__display_pll_locked)
                                                          , .pixel_pll_locked(w_port__HDMI_Reset_0__pixel_pll_locked)
                                                          , .serial_pll_locked(w_port__HDMI_Reset_0__serial_pll_locked)
                                                          , .video_locked(w_port__HDMI_Reset_0__video_locked)
                                                          , .serial_pll_reset(w_port__HDMI_Reset_0__serial_pll_reset)
                                                          , .ctrl_reset_n(w_port__HDMI_Reset_0__ctrl_reset_n)
                                                          , .mem_reset_n(w_port__HDMI_Reset_0__mem_reset_n)
                                                          , .axis_reset_n(w_port__HDMI_Reset_0__axis_reset_n)
                                                          , .pixel_reset(w_port__HDMI_Reset_0__pixel_reset)
                                                          , .tx_reset(w_port__HDMI_Reset_0__tx_reset) );

    axi_system_NPU_Control_Matrix_0 axi_system_NPU_Control_Matrix_0_Inst ( 
                                                                            .us0_araddr(w_port__NPU_Control_Matrix_0__us0_araddr)
                                                                          , .us0_arburst(w_port__NPU_Control_Matrix_0__us0_arburst)
                                                                          , .us0_arcache(w_port__NPU_Control_Matrix_0__us0_arcache)
                                                                          , .us0_arid(w_port__NPU_Control_Matrix_0__us0_arid)
                                                                          , .us0_arlen(w_port__NPU_Control_Matrix_0__us0_arlen)
                                                                          , .us0_arlock(w_port__NPU_Control_Matrix_0__us0_arlock)
                                                                          , .us0_arprot(w_port__NPU_Control_Matrix_0__us0_arprot)
                                                                          , .us0_arqos(w_port__NPU_Control_Matrix_0__us0_arqos)
                                                                          , .us0_arready(w_port__NPU_Control_Matrix_0__us0_arready)
                                                                          , .us0_arsize(w_port__NPU_Control_Matrix_0__us0_arsize)
                                                                          , .us0_arvalid(w_port__NPU_Control_Matrix_0__us0_arvalid)
                                                                          , .us0_awaddr(w_port__NPU_Control_Matrix_0__us0_awaddr)
                                                                          , .us0_awburst(w_port__NPU_Control_Matrix_0__us0_awburst)
                                                                          , .us0_awcache(w_port__NPU_Control_Matrix_0__us0_awcache)
                                                                          , .us0_awid(w_port__NPU_Control_Matrix_0__us0_awid)
                                                                          , .us0_awlen(w_port__NPU_Control_Matrix_0__us0_awlen)
                                                                          , .us0_awlock(w_port__NPU_Control_Matrix_0__us0_awlock)
                                                                          , .us0_awprot(w_port__NPU_Control_Matrix_0__us0_awprot)
                                                                          , .us0_awqos(w_port__NPU_Control_Matrix_0__us0_awqos)
                                                                          , .us0_awready(w_port__NPU_Control_Matrix_0__us0_awready)
                                                                          , .us0_awsize(w_port__NPU_Control_Matrix_0__us0_awsize)
                                                                          , .us0_awvalid(w_port__NPU_Control_Matrix_0__us0_awvalid)
                                                                          , .us0_bid(w_port__NPU_Control_Matrix_0__us0_bid)
                                                                          , .us0_bready(w_port__NPU_Control_Matrix_0__us0_bready)
                                                                          , .us0_bresp(w_port__NPU_Control_Matrix_0__us0_bresp)
                                                                          , .us0_bvalid(w_port__NPU_Control_Matrix_0__us0_bvalid)
                                                                          , .us0_rdata(w_port__NPU_Control_Matrix_0__us0_rdata)
                                                                          , .us0_rid(w_port__NPU_Control_Matrix_0__us0_rid)
                                                                          , .us0_rlast(w_port__NPU_Control_Matrix_0__us0_rlast)
                                                                          , .us0_rready(w_port__NPU_Control_Matrix_0__us0_rready)
                                                                          , .us0_rresp(w_port__NPU_Control_Matrix_0__us0_rresp)
                                                                          , .us0_rvalid(w_port__NPU_Control_Matrix_0__us0_rvalid)
                                                                          , .us0_wdata(w_port__NPU_Control_Matrix_0__us0_wdata)
                                                                          , .us0_wlast(w_port__NPU_Control_Matrix_0__us0_wlast)
                                                                          , .us0_wready(w_port__NPU_Control_Matrix_0__us0_wready)
                                                                          , .us0_wstrb(w_port__NPU_Control_Matrix_0__us0_wstrb)
                                                                          , .us0_wvalid(w_port__NPU_Control_Matrix_0__us0_wvalid)
                                                                          , .aclk(w_port__NPU_Control_Matrix_0__aclk)
                                                                          , .aresetn(w_port__NPU_Control_Matrix_0__aresetn)
                                                                          , .ds0_araddr(w_port__NPU_Control_Matrix_0__ds0_araddr)
                                                                          , .ds0_arburst(w_port__NPU_Control_Matrix_0__ds0_arburst)
                                                                          , .ds0_arcache(w_port__NPU_Control_Matrix_0__ds0_arcache)
                                                                          , .ds0_arid(w_port__NPU_Control_Matrix_0__ds0_arid)
                                                                          , .ds0_arlen(w_port__NPU_Control_Matrix_0__ds0_arlen)
                                                                          , .ds0_arlock(w_port__NPU_Control_Matrix_0__ds0_arlock)
                                                                          , .ds0_arprot(w_port__NPU_Control_Matrix_0__ds0_arprot)
                                                                          , .ds0_arqos(w_port__NPU_Control_Matrix_0__ds0_arqos)
                                                                          , .ds0_arregion()
                                                                          , .ds0_arready(w_port__NPU_Control_Matrix_0__ds0_arready)
                                                                          , .ds0_arsize(w_port__NPU_Control_Matrix_0__ds0_arsize)
                                                                          , .ds0_arvalid(w_port__NPU_Control_Matrix_0__ds0_arvalid)
                                                                          , .ds0_awaddr(w_port__NPU_Control_Matrix_0__ds0_awaddr)
                                                                          , .ds0_awburst(w_port__NPU_Control_Matrix_0__ds0_awburst)
                                                                          , .ds0_awcache(w_port__NPU_Control_Matrix_0__ds0_awcache)
                                                                          , .ds0_awid(w_port__NPU_Control_Matrix_0__ds0_awid)
                                                                          , .ds0_awlen(w_port__NPU_Control_Matrix_0__ds0_awlen)
                                                                          , .ds0_awlock(w_port__NPU_Control_Matrix_0__ds0_awlock)
                                                                          , .ds0_awprot(w_port__NPU_Control_Matrix_0__ds0_awprot)
                                                                          , .ds0_awqos(w_port__NPU_Control_Matrix_0__ds0_awqos)
                                                                          , .ds0_awregion()
                                                                          , .ds0_awready(w_port__NPU_Control_Matrix_0__ds0_awready)
                                                                          , .ds0_awsize(w_port__NPU_Control_Matrix_0__ds0_awsize)
                                                                          , .ds0_awvalid(w_port__NPU_Control_Matrix_0__ds0_awvalid)
                                                                          , .ds0_bid(w_port__NPU_Control_Matrix_0__ds0_bid)
                                                                          , .ds0_bready(w_port__NPU_Control_Matrix_0__ds0_bready)
                                                                          , .ds0_bresp(w_port__NPU_Control_Matrix_0__ds0_bresp)
                                                                          , .ds0_bvalid(w_port__NPU_Control_Matrix_0__ds0_bvalid)
                                                                          , .ds0_rdata(w_port__NPU_Control_Matrix_0__ds0_rdata)
                                                                          , .ds0_rid(w_port__NPU_Control_Matrix_0__ds0_rid)
                                                                          , .ds0_rlast(w_port__NPU_Control_Matrix_0__ds0_rlast)
                                                                          , .ds0_rready(w_port__NPU_Control_Matrix_0__ds0_rready)
                                                                          , .ds0_rresp(w_port__NPU_Control_Matrix_0__ds0_rresp)
                                                                          , .ds0_rvalid(w_port__NPU_Control_Matrix_0__ds0_rvalid)
                                                                          , .ds0_wdata(w_port__NPU_Control_Matrix_0__ds0_wdata)
                                                                          , .ds0_wlast(w_port__NPU_Control_Matrix_0__ds0_wlast)
                                                                          , .ds0_wready(w_port__NPU_Control_Matrix_0__ds0_wready)
                                                                          , .ds0_wstrb(w_port__NPU_Control_Matrix_0__ds0_wstrb)
                                                                          , .ds0_wvalid(w_port__NPU_Control_Matrix_0__ds0_wvalid) );

    axi_system_NPU_Control_Converter_0 axi_system_NPU_Control_Converter_0_Inst ( 
                                                                                  .us_axi_awid(w_port__NPU_Control_Converter_0__us_axi_awid)
                                                                                , .us_axi_awaddr(w_port__NPU_Control_Converter_0__us_axi_awaddr)
                                                                                , .us_axi_awlen(w_port__NPU_Control_Converter_0__us_axi_awlen)
                                                                                , .us_axi_awsize(w_port__NPU_Control_Converter_0__us_axi_awsize)
                                                                                , .us_axi_awburst(w_port__NPU_Control_Converter_0__us_axi_awburst)
                                                                                , .us_axi_awlock(w_port__NPU_Control_Converter_0__us_axi_awlock)
                                                                                , .us_axi_awcache(w_port__NPU_Control_Converter_0__us_axi_awcache)
                                                                                , .us_axi_awprot(w_port__NPU_Control_Converter_0__us_axi_awprot)
                                                                                , .us_axi_awqos(w_port__NPU_Control_Converter_0__us_axi_awqos)
                                                                                , .us_axi_awvalid(w_port__NPU_Control_Converter_0__us_axi_awvalid)
                                                                                , .us_axi_awready(w_port__NPU_Control_Converter_0__us_axi_awready)
                                                                                , .us_axi_wdata(w_port__NPU_Control_Converter_0__us_axi_wdata)
                                                                                , .us_axi_wstrb(w_port__NPU_Control_Converter_0__us_axi_wstrb)
                                                                                , .us_axi_wlast(w_port__NPU_Control_Converter_0__us_axi_wlast)
                                                                                , .us_axi_wvalid(w_port__NPU_Control_Converter_0__us_axi_wvalid)
                                                                                , .us_axi_wready(w_port__NPU_Control_Converter_0__us_axi_wready)
                                                                                , .us_axi_bid(w_port__NPU_Control_Converter_0__us_axi_bid)
                                                                                , .us_axi_bresp(w_port__NPU_Control_Converter_0__us_axi_bresp)
                                                                                , .us_axi_bvalid(w_port__NPU_Control_Converter_0__us_axi_bvalid)
                                                                                , .us_axi_bready(w_port__NPU_Control_Converter_0__us_axi_bready)
                                                                                , .us_axi_arid(w_port__NPU_Control_Converter_0__us_axi_arid)
                                                                                , .us_axi_araddr(w_port__NPU_Control_Converter_0__us_axi_araddr)
                                                                                , .us_axi_arlen(w_port__NPU_Control_Converter_0__us_axi_arlen)
                                                                                , .us_axi_arsize(w_port__NPU_Control_Converter_0__us_axi_arsize)
                                                                                , .us_axi_arburst(w_port__NPU_Control_Converter_0__us_axi_arburst)
                                                                                , .us_axi_arlock(w_port__NPU_Control_Converter_0__us_axi_arlock)
                                                                                , .us_axi_arcache(w_port__NPU_Control_Converter_0__us_axi_arcache)
                                                                                , .us_axi_arprot(w_port__NPU_Control_Converter_0__us_axi_arprot)
                                                                                , .us_axi_arqos(w_port__NPU_Control_Converter_0__us_axi_arqos)
                                                                                , .us_axi_arvalid(w_port__NPU_Control_Converter_0__us_axi_arvalid)
                                                                                , .us_axi_arready(w_port__NPU_Control_Converter_0__us_axi_arready)
                                                                                , .us_axi_rid(w_port__NPU_Control_Converter_0__us_axi_rid)
                                                                                , .us_axi_rdata(w_port__NPU_Control_Converter_0__us_axi_rdata)
                                                                                , .us_axi_rresp(w_port__NPU_Control_Converter_0__us_axi_rresp)
                                                                                , .us_axi_rlast(w_port__NPU_Control_Converter_0__us_axi_rlast)
                                                                                , .us_axi_rvalid(w_port__NPU_Control_Converter_0__us_axi_rvalid)
                                                                                , .us_axi_rready(w_port__NPU_Control_Converter_0__us_axi_rready)
                                                                                , .aclk(w_port__NPU_Control_Converter_0__aclk)
                                                                                , .aresetn(w_port__NPU_Control_Converter_0__aresetn)
                                                                                , .ds_axi_awaddr(w_port__NPU_Control_Converter_0__ds_axi_awaddr)
                                                                                , .ds_axi_awprot(w_port__NPU_Control_Converter_0__ds_axi_awprot)
                                                                                , .ds_axi_awvalid(w_port__NPU_Control_Converter_0__ds_axi_awvalid)
                                                                                , .ds_axi_awready(w_port__NPU_Control_Converter_0__ds_axi_awready)
                                                                                , .ds_axi_wdata(w_port__NPU_Control_Converter_0__ds_axi_wdata)
                                                                                , .ds_axi_wstrb(w_port__NPU_Control_Converter_0__ds_axi_wstrb)
                                                                                , .ds_axi_wvalid(w_port__NPU_Control_Converter_0__ds_axi_wvalid)
                                                                                , .ds_axi_wready(w_port__NPU_Control_Converter_0__ds_axi_wready)
                                                                                , .ds_axi_bresp(w_port__NPU_Control_Converter_0__ds_axi_bresp)
                                                                                , .ds_axi_bvalid(w_port__NPU_Control_Converter_0__ds_axi_bvalid)
                                                                                , .ds_axi_bready(w_port__NPU_Control_Converter_0__ds_axi_bready)
                                                                                , .ds_axi_araddr(w_port__NPU_Control_Converter_0__ds_axi_araddr)
                                                                                , .ds_axi_arprot(w_port__NPU_Control_Converter_0__ds_axi_arprot)
                                                                                , .ds_axi_arvalid(w_port__NPU_Control_Converter_0__ds_axi_arvalid)
                                                                                , .ds_axi_arready(w_port__NPU_Control_Converter_0__ds_axi_arready)
                                                                                , .ds_axi_rdata(w_port__NPU_Control_Converter_0__ds_axi_rdata)
                                                                                , .ds_axi_rresp(w_port__NPU_Control_Converter_0__ds_axi_rresp)
                                                                                , .ds_axi_rvalid(w_port__NPU_Control_Converter_0__ds_axi_rvalid)
                                                                                , .ds_axi_rready(w_port__NPU_Control_Converter_0__ds_axi_rready) );

    axi_system_Video_NPU_0 axi_system_Video_NPU_0_Inst ( 
                                                          .s_axilite_awaddr_i(w_port__Video_NPU_0__s_axilite_awaddr_i)
                                                        , .s_axilite_awprot_i(w_port__Video_NPU_0__s_axilite_awprot_i)
                                                        , .s_axilite_awvalid_i(w_port__Video_NPU_0__s_axilite_awvalid_i)
                                                        , .s_axilite_awready_o(w_port__Video_NPU_0__s_axilite_awready_o)
                                                        , .s_axilite_wdata_i(w_port__Video_NPU_0__s_axilite_wdata_i)
                                                        , .s_axilite_wstrb_i(w_port__Video_NPU_0__s_axilite_wstrb_i)
                                                        , .s_axilite_wvalid_i(w_port__Video_NPU_0__s_axilite_wvalid_i)
                                                        , .s_axilite_wready_o(w_port__Video_NPU_0__s_axilite_wready_o)
                                                        , .s_axilite_bvalid_o(w_port__Video_NPU_0__s_axilite_bvalid_o)
                                                        , .s_axilite_bresp_o(w_port__Video_NPU_0__s_axilite_bresp_o)
                                                        , .s_axilite_bready_i(w_port__Video_NPU_0__s_axilite_bready_i)
                                                        , .s_axilite_araddr_i(w_port__Video_NPU_0__s_axilite_araddr_i)
                                                        , .s_axilite_arprot_i(w_port__Video_NPU_0__s_axilite_arprot_i)
                                                        , .s_axilite_arvalid_i(w_port__Video_NPU_0__s_axilite_arvalid_i)
                                                        , .s_axilite_arready_o(w_port__Video_NPU_0__s_axilite_arready_o)
                                                        , .s_axilite_rdata_o(w_port__Video_NPU_0__s_axilite_rdata_o)
                                                        , .s_axilite_rresp_o(w_port__Video_NPU_0__s_axilite_rresp_o)
                                                        , .s_axilite_rvalid_o(w_port__Video_NPU_0__s_axilite_rvalid_o)
                                                        , .s_axilite_rready_i(w_port__Video_NPU_0__s_axilite_rready_i)
                                                        , .M_AXI_ACLK(w_port__Video_NPU_0__M_AXI_ACLK)
                                                        , .M_AXI_AResetn(w_port__Video_NPU_0__M_AXI_AResetn)
                                                        , .S_AXILite_ACLK(w_port__Video_NPU_0__S_AXILite_ACLK)
                                                        , .S_AXILite_AResetn(w_port__Video_NPU_0__S_AXILite_AResetn)
                                                        , .m_axi_awready_soft_i(w_port__Video_NPU_0__m_axi_awready_soft_i)
                                                        , .m_axi_awid_soft_o(w_port__Video_NPU_0__m_axi_awid_soft_o)
                                                        , .m_axi_awaddr_soft_o(w_port__Video_NPU_0__m_axi_awaddr_soft_o)
                                                        , .m_axi_awlen_soft_o(w_port__Video_NPU_0__m_axi_awlen_soft_o)
                                                        , .m_axi_awsize_soft_o(w_port__Video_NPU_0__m_axi_awsize_soft_o)
                                                        , .m_axi_awburst_soft_o(w_port__Video_NPU_0__m_axi_awburst_soft_o)
                                                        , .m_axi_awprot_soft_o(w_port__Video_NPU_0__m_axi_awprot_soft_o)
                                                        , .m_axi_awvalid_soft_o(w_port__Video_NPU_0__m_axi_awvalid_soft_o)
                                                        , .m_axi_awlock_soft_o(w_port__Video_NPU_0__m_axi_awlock_soft_o)
                                                        , .m_axi_awcache_soft_o(w_port__Video_NPU_0__m_axi_awcache_soft_o)
                                                        , .m_axi_wdata_soft_o(w_port__Video_NPU_0__m_axi_wdata_soft_o)
                                                        , .m_axi_wstrb_soft_o(w_port__Video_NPU_0__m_axi_wstrb_soft_o)
                                                        , .m_axi_wready_soft_i(w_port__Video_NPU_0__m_axi_wready_soft_i)
                                                        , .m_axi_wlast_soft_o(w_port__Video_NPU_0__m_axi_wlast_soft_o)
                                                        , .m_axi_wvalid_soft_o(w_port__Video_NPU_0__m_axi_wvalid_soft_o)
                                                        , .m_axi_bid_soft_i(w_port__Video_NPU_0__m_axi_bid_soft_i)
                                                        , .m_axi_bresp_soft_i(w_port__Video_NPU_0__m_axi_bresp_soft_i)
                                                        , .m_axi_bvalid_soft_i(w_port__Video_NPU_0__m_axi_bvalid_soft_i)
                                                        , .m_axi_bready_soft_o(w_port__Video_NPU_0__m_axi_bready_soft_o)
                                                        , .m_axi_arready_soft_i(w_port__Video_NPU_0__m_axi_arready_soft_i)
                                                        , .m_axi_arid_soft_o(w_port__Video_NPU_0__m_axi_arid_soft_o)
                                                        , .m_axi_araddr_soft_o(w_port__Video_NPU_0__m_axi_araddr_soft_o)
                                                        , .m_axi_arlen_soft_o(w_port__Video_NPU_0__m_axi_arlen_soft_o)
                                                        , .m_axi_arsize_soft_o(w_port__Video_NPU_0__m_axi_arsize_soft_o)
                                                        , .m_axi_arburst_soft_o(w_port__Video_NPU_0__m_axi_arburst_soft_o)
                                                        , .m_axi_arprot_soft_o(w_port__Video_NPU_0__m_axi_arprot_soft_o)
                                                        , .m_axi_arvalid_soft_o(w_port__Video_NPU_0__m_axi_arvalid_soft_o)
                                                        , .m_axi_arlock_soft_o(w_port__Video_NPU_0__m_axi_arlock_soft_o)
                                                        , .m_axi_arcache_soft_o(w_port__Video_NPU_0__m_axi_arcache_soft_o)
                                                        , .m_axi_rid_soft_i(w_port__Video_NPU_0__m_axi_rid_soft_i)
                                                        , .m_axi_rdata_soft_i(w_port__Video_NPU_0__m_axi_rdata_soft_i)
                                                        , .m_axi_rresp_soft_i(w_port__Video_NPU_0__m_axi_rresp_soft_i)
                                                        , .m_axi_rlast_soft_i(w_port__Video_NPU_0__m_axi_rlast_soft_i)
                                                        , .m_axi_rvalid_soft_i(w_port__Video_NPU_0__m_axi_rvalid_soft_i)
                                                        , .m_axi_rready_soft_o(w_port__Video_NPU_0__m_axi_rready_soft_o)
                                                        , .npu_soft_intr(w_port__Video_NPU_0__npu_soft_intr) );

    axi_system_NPU_HP1_Adapter_0 axi_system_NPU_HP1_Adapter_0_Inst ( 
                                                                      .s_axi_awid(w_port__NPU_HP1_Adapter_0__s_axi_awid)
                                                                    , .s_axi_awaddr(w_port__NPU_HP1_Adapter_0__s_axi_awaddr)
                                                                    , .s_axi_awlen(w_port__NPU_HP1_Adapter_0__s_axi_awlen)
                                                                    , .s_axi_awsize(w_port__NPU_HP1_Adapter_0__s_axi_awsize)
                                                                    , .s_axi_awburst(w_port__NPU_HP1_Adapter_0__s_axi_awburst)
                                                                    , .s_axi_awlock(w_port__NPU_HP1_Adapter_0__s_axi_awlock)
                                                                    , .s_axi_awcache(w_port__NPU_HP1_Adapter_0__s_axi_awcache)
                                                                    , .s_axi_awprot(w_port__NPU_HP1_Adapter_0__s_axi_awprot)
                                                                    , .s_axi_awvalid(w_port__NPU_HP1_Adapter_0__s_axi_awvalid)
                                                                    , .s_axi_awready(w_port__NPU_HP1_Adapter_0__s_axi_awready)
                                                                    , .s_axi_wdata(w_port__NPU_HP1_Adapter_0__s_axi_wdata)
                                                                    , .s_axi_wstrb(w_port__NPU_HP1_Adapter_0__s_axi_wstrb)
                                                                    , .s_axi_wlast(w_port__NPU_HP1_Adapter_0__s_axi_wlast)
                                                                    , .s_axi_wvalid(w_port__NPU_HP1_Adapter_0__s_axi_wvalid)
                                                                    , .s_axi_wready(w_port__NPU_HP1_Adapter_0__s_axi_wready)
                                                                    , .s_axi_bid(w_port__NPU_HP1_Adapter_0__s_axi_bid)
                                                                    , .s_axi_bresp(w_port__NPU_HP1_Adapter_0__s_axi_bresp)
                                                                    , .s_axi_bvalid(w_port__NPU_HP1_Adapter_0__s_axi_bvalid)
                                                                    , .s_axi_bready(w_port__NPU_HP1_Adapter_0__s_axi_bready)
                                                                    , .s_axi_arid(w_port__NPU_HP1_Adapter_0__s_axi_arid)
                                                                    , .s_axi_araddr(w_port__NPU_HP1_Adapter_0__s_axi_araddr)
                                                                    , .s_axi_arlen(w_port__NPU_HP1_Adapter_0__s_axi_arlen)
                                                                    , .s_axi_arsize(w_port__NPU_HP1_Adapter_0__s_axi_arsize)
                                                                    , .s_axi_arburst(w_port__NPU_HP1_Adapter_0__s_axi_arburst)
                                                                    , .s_axi_arlock(w_port__NPU_HP1_Adapter_0__s_axi_arlock)
                                                                    , .s_axi_arcache(w_port__NPU_HP1_Adapter_0__s_axi_arcache)
                                                                    , .s_axi_arprot(w_port__NPU_HP1_Adapter_0__s_axi_arprot)
                                                                    , .s_axi_arvalid(w_port__NPU_HP1_Adapter_0__s_axi_arvalid)
                                                                    , .s_axi_arready(w_port__NPU_HP1_Adapter_0__s_axi_arready)
                                                                    , .s_axi_rid(w_port__NPU_HP1_Adapter_0__s_axi_rid)
                                                                    , .s_axi_rdata(w_port__NPU_HP1_Adapter_0__s_axi_rdata)
                                                                    , .s_axi_rresp(w_port__NPU_HP1_Adapter_0__s_axi_rresp)
                                                                    , .s_axi_rlast(w_port__NPU_HP1_Adapter_0__s_axi_rlast)
                                                                    , .s_axi_rvalid(w_port__NPU_HP1_Adapter_0__s_axi_rvalid)
                                                                    , .s_axi_rready(w_port__NPU_HP1_Adapter_0__s_axi_rready)
                                                                    , .aclk(w_port__NPU_HP1_Adapter_0__aclk)
                                                                    , .aresetn(w_port__NPU_HP1_Adapter_0__aresetn)
                                                                    , .m_axi_awid(w_port__NPU_HP1_Adapter_0__m_axi_awid)
                                                                    , .m_axi_awaddr(w_port__NPU_HP1_Adapter_0__m_axi_awaddr)
                                                                    , .m_axi_awlen(w_port__NPU_HP1_Adapter_0__m_axi_awlen)
                                                                    , .m_axi_awsize(w_port__NPU_HP1_Adapter_0__m_axi_awsize)
                                                                    , .m_axi_awburst(w_port__NPU_HP1_Adapter_0__m_axi_awburst)
                                                                    , .m_axi_awlock(w_port__NPU_HP1_Adapter_0__m_axi_awlock)
                                                                    , .m_axi_awcache(w_port__NPU_HP1_Adapter_0__m_axi_awcache)
                                                                    , .m_axi_awprot(w_port__NPU_HP1_Adapter_0__m_axi_awprot)
                                                                    , .m_axi_awqos(w_port__NPU_HP1_Adapter_0__m_axi_awqos)
                                                                    , .m_axi_awvalid(w_port__NPU_HP1_Adapter_0__m_axi_awvalid)
                                                                    , .m_axi_awready(w_port__NPU_HP1_Adapter_0__m_axi_awready)
                                                                    , .m_axi_wdata(w_port__NPU_HP1_Adapter_0__m_axi_wdata)
                                                                    , .m_axi_wstrb(w_port__NPU_HP1_Adapter_0__m_axi_wstrb)
                                                                    , .m_axi_wlast(w_port__NPU_HP1_Adapter_0__m_axi_wlast)
                                                                    , .m_axi_wvalid(w_port__NPU_HP1_Adapter_0__m_axi_wvalid)
                                                                    , .m_axi_wready(w_port__NPU_HP1_Adapter_0__m_axi_wready)
                                                                    , .m_axi_bid(w_port__NPU_HP1_Adapter_0__m_axi_bid)
                                                                    , .m_axi_bresp(w_port__NPU_HP1_Adapter_0__m_axi_bresp)
                                                                    , .m_axi_bvalid(w_port__NPU_HP1_Adapter_0__m_axi_bvalid)
                                                                    , .m_axi_bready(w_port__NPU_HP1_Adapter_0__m_axi_bready)
                                                                    , .m_axi_arid(w_port__NPU_HP1_Adapter_0__m_axi_arid)
                                                                    , .m_axi_araddr(w_port__NPU_HP1_Adapter_0__m_axi_araddr)
                                                                    , .m_axi_arlen(w_port__NPU_HP1_Adapter_0__m_axi_arlen)
                                                                    , .m_axi_arsize(w_port__NPU_HP1_Adapter_0__m_axi_arsize)
                                                                    , .m_axi_arburst(w_port__NPU_HP1_Adapter_0__m_axi_arburst)
                                                                    , .m_axi_arlock(w_port__NPU_HP1_Adapter_0__m_axi_arlock)
                                                                    , .m_axi_arcache(w_port__NPU_HP1_Adapter_0__m_axi_arcache)
                                                                    , .m_axi_arprot(w_port__NPU_HP1_Adapter_0__m_axi_arprot)
                                                                    , .m_axi_arqos(w_port__NPU_HP1_Adapter_0__m_axi_arqos)
                                                                    , .m_axi_arvalid(w_port__NPU_HP1_Adapter_0__m_axi_arvalid)
                                                                    , .m_axi_arready(w_port__NPU_HP1_Adapter_0__m_axi_arready)
                                                                    , .m_axi_rid(w_port__NPU_HP1_Adapter_0__m_axi_rid)
                                                                    , .m_axi_rdata(w_port__NPU_HP1_Adapter_0__m_axi_rdata)
                                                                    , .m_axi_rresp(w_port__NPU_HP1_Adapter_0__m_axi_rresp)
                                                                    , .m_axi_rlast(w_port__NPU_HP1_Adapter_0__m_axi_rlast)
                                                                    , .m_axi_rvalid(w_port__NPU_HP1_Adapter_0__m_axi_rvalid)
                                                                    , .m_axi_rready(w_port__NPU_HP1_Adapter_0__m_axi_rready) );

endmodule
