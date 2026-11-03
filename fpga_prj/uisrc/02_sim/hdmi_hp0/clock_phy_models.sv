`timescale 1ns/1ps
module axi_system_HDMI_PLL_0(input refclk, output reg clk0_out=0,
    output reg clk1_out=0, output reg clk2_out=0, output reg lock=0);
always #5 clk0_out=~clk0_out;
always #4.166667 clk1_out=~clk1_out;
always #3.333333 clk2_out=~clk2_out;
initial #100 lock=1;
endmodule
module axi_system_HDMI_PLL_1(input refclk, input reset, output reg clk0_out=0, output lock);
// Selected screen profile: 49 MHz pixel, 245 MHz serial.
always #2.040816327 clk0_out=~clk0_out;
assign lock=~reset;
endmodule
module hdmi_tx_phy_wrapper_c33abe7c933e #(parameter DEVICE="DR1")(
    input I_pixel_clk,I_serial_clk,I_rst,
    input [9:0] I_tmds_channel_0,I_tmds_channel_1,I_tmds_channel_2,I_tmds_channel_clk,
    output O_tmds_ch0_p,O_tmds_ch1_p,O_tmds_ch2_p,O_tmds_clk_p);
assign {O_tmds_clk_p,O_tmds_ch2_p,O_tmds_ch1_p,O_tmds_ch0_p} =
       {I_tmds_channel_clk[0],I_tmds_channel_2[0],I_tmds_channel_1[0],I_tmds_channel_0[0]};
endmodule


module dr1_phy_pll_vtc_dd045705834d #(
  parameter FBKCLK            = "CLKC0_EXT",     

  parameter FBKCLK_INT        = "VCO_PHASE0",    

  parameter REFCLK_DIV        = 1,               
  parameter FBCLK_DIV         = 1,               

  parameter CLKC0_FPHASE      = 0,               
  parameter CLKC1_FPHASE      = 0,               
  parameter CLKC2_FPHASE      = 0,               
  parameter CLKC3_FPHASE      = 0,               
  parameter CLKC4_FPHASE      = 0,               
  parameter CLKC5_FPHASE      = 0,               
  parameter CLKC6_FPHASE      = 0,               

  parameter CLKC0_DIV2_ENABLE = "DISABLE",       
  parameter CLKC1_DIV2_ENABLE = "DISABLE",       
  parameter CLKC2_DIV2_ENABLE = "DISABLE",       
  parameter CLKC3_DIV2_ENABLE = "DISABLE",       
  parameter CLKC4_DIV2_ENABLE = "DISABLE",       
  parameter CLKC5_DIV2_ENABLE = "DISABLE",       
  parameter CLKC6_DIV2_ENABLE = "DISABLE",       

  parameter PREDIV_MUXC0      = "VCO",           
  parameter PREDIV_MUXC1      = "VCO",           
  parameter PREDIV_MUXC2      = "VCO",           
  parameter PREDIV_MUXC3      = "VCO",           
  parameter PREDIV_MUXC4      = "VCO",           
  parameter PREDIV_MUXC5      = "VCO",           
  parameter PREDIV_MUXC6      = "VCO",           

  parameter CLKC0_CPHASE      = 0,               
  parameter CLKC1_CPHASE      = 0,               
  parameter CLKC2_CPHASE      = 0,               
  parameter CLKC3_CPHASE      = 0,               
  parameter CLKC4_CPHASE      = 0,               
  parameter CLKC5_CPHASE      = 0,               
  parameter CLKC6_CPHASE      = 0,               

// output divider
  parameter CLKC0_DIV         = 1,               
  parameter CLKC1_DIV         = 1,               
  parameter CLKC2_DIV         = 1,               
  parameter CLKC3_DIV         = 1,               
  parameter CLKC4_DIV         = 1,               
  parameter CLKC5_DIV         = 1,               
  parameter CLKC6_DIV         = 1,               

// duty
  parameter CLKC0_DUTY_INT    = 1,               
  parameter CLKC1_DUTY_INT    = 1,               
  parameter CLKC2_DUTY_INT    = 1,               
  parameter CLKC3_DUTY_INT    = 1,               
  parameter CLKC4_DUTY_INT    = 1,               
  parameter CLKC5_DUTY_INT    = 1,               
  parameter CLKC6_DUTY_INT    = 1,               

//ssc
  parameter FREQ_OFFSET       = 0,               

// clk output
  parameter DIVOUT_MUXC0      = "DIV",           
  parameter DIVOUT_MUXC1      = "DIV",           
  parameter DIVOUT_MUXC2      = "DIV",           
  parameter DIVOUT_MUXC3      = "DIV",           
  parameter DIVOUT_MUXC4      = "DIV",           
  parameter DIVOUT_MUXC5      = "DIV",           
  parameter DIVOUT_MUXC6      = "DIV",           
  parameter MAIN_MUXC         = "MAIN",          

  parameter CLKC0_ENABLE      = "DISABLE",       
  parameter CLKC1_ENABLE      = "DISABLE",       
  parameter CLKC2_ENABLE      = "DISABLE",       
  parameter CLKC3_ENABLE      = "DISABLE",       
  parameter CLKC4_ENABLE      = "DISABLE",       
  parameter CLKC5_ENABLE      = "DISABLE",       
  parameter CLKC6_ENABLE      = "DISABLE",       
  parameter CLK_MAIN_ENABLE   = "DISABLE",       

  parameter WORK_MODE         = "USER",          

  parameter FIN               = "100.0000",      

  parameter FEEDBK_MODE       = "NORMAL",        

  parameter PD_DIG            = "DISABLE",       
  parameter REFCLK_USR_RST    = "DISABLE",       
  parameter PLL_USR_RST       = "DISABLE",       
  parameter PLL_FEED_TYPE     = "INTERNAL",      

// loop   parameter
  parameter LPF_RES           = 2,               
  parameter LPF_CAP           = 2,               
  parameter ICP_CUR           = 12,              
  parameter GMC_GAIN          = 2,               

//frac-N
  parameter FRAC_ENABLE       = "DISABLE",       
  parameter DITHER_ENABLE     = "DISABLE",       
  parameter SDM_FRAC          = 0,               

  parameter SSC_AMP           = 0.0,             
                                               
//fine phase shift
  parameter MPHASE_ENABLE     = "DISABLE",       
  parameter PHASE_PATH_SEL    = 0,               
  parameter DYN_PHASE_PATH_SEL= "DISABLE",       
  parameter DYN_FPHASE_EN     = "DISABLE",       

  parameter CLKC0_FPHASE_RSTSEL        = 0,               
  parameter CLKC1_FPHASE_RSTSEL        = 0,               
  parameter CLKC2_FPHASE_RSTSEL        = 0,               
  parameter CLKC3_FPHASE_RSTSEL        = 0,               
  parameter CLKC4_FPHASE_RSTSEL        = 0,               
  parameter CLKC5_FPHASE_RSTSEL        = 0,               
  parameter CLKC6_FPHASE_RSTSEL        = 0,               

//coarse phase shift
  parameter DYN_CPHASE_CLKC0_DIV2_EN   = "DISABLE",       
  parameter DYN_CPHASE_CLKC1_DIV2_EN   = "DISABLE",       
  parameter DYN_CPHASE_CLKC2_DIV2_EN   = "DISABLE",       
  parameter DYN_CPHASE_CLKC3_DIV2_EN   = "DISABLE",       
  parameter DYN_CPHASE_CLKC4_DIV2_EN   = "DISABLE",       
  parameter DYN_CPHASE_CLKC5_DIV2_EN   = "DISABLE",       
  parameter DYN_CPHASE_CLKC6_DIV2_EN   = "DISABLE",       
  parameter DYN_CPHASE_CLKC0_DIV_EN    = "DISABLE",       
  parameter DYN_CPHASE_CLKC1_DIV_EN    = "DISABLE",       
  parameter DYN_CPHASE_CLKC2_DIV_EN    = "DISABLE",       
  parameter DYN_CPHASE_CLKC3_DIV_EN    = "DISABLE",       
  parameter DYN_CPHASE_CLKC4_DIV_EN    = "DISABLE",       
  parameter DYN_CPHASE_CLKC5_DIV_EN    = "DISABLE",       
  parameter DYN_CPHASE_CLKC6_DIV_EN    = "DISABLE",       

  parameter CLKC0_CPHASE_DIV2 = 0,               
  parameter CLKC1_CPHASE_DIV2 = 0,               
  parameter CLKC2_CPHASE_DIV2 = 0,               
  parameter CLKC3_CPHASE_DIV2 = 0,               
  parameter CLKC4_CPHASE_DIV2 = 0,               
  parameter CLKC5_CPHASE_DIV2 = 0,               
  parameter CLKC6_CPHASE_DIV2 = 0,               

  parameter CLKC0_DUTY50      = "ENABLE",        
  parameter CLKC1_DUTY50      = "ENABLE",        
  parameter CLKC2_DUTY50      = "ENABLE",        
  parameter CLKC3_DUTY50      = "ENABLE",        
  parameter CLKC4_DUTY50      = "ENABLE",        
  parameter CLKC5_DUTY50      = "ENABLE",        
  parameter CLKC6_DUTY50      = "ENABLE",        

  parameter CLKC0_USR_RST     = "ENABLE",        
  parameter CLKC1_USR_RST     = "ENABLE",        

//ssc
  parameter INTPI             = 0,               
  parameter SSC_ENABLE        = "DISABLE",       
  parameter SSC_MODE          = "CENTER",        
  parameter EXT_USR_FREQ_EN   = "DISABLE",       
  parameter SSC_FREQ_DIV      = 0,               
  parameter SSC_RNGE          = 242,             
  parameter HIGH_SPEED_EN     = "DISABLE",       

  parameter REFCLK_OUT_ENABLE = "DISABLE",       

  parameter REFCLK_DET_BYP    = "DISABLE",       

  parameter DERIVE_PLL_CLOCKS = "DISABLE",       
  parameter GEN_BASIC_CLOCK   = "DISABLE"  
) (
  input            refclk,           
  input            fbclk,            
  output		   clk0_out,
  output		   clk1_out,
  output		   clk2_out,
  output		   clk3_out,
  output		   clk4_out,
  output		   clk5_out,
  output		   clk6_out,
  output	       clkb0_out,
  output	       clkb1_out,
  output	       clkb2_out,
  output	       clkb3_out,
  output	       clkb4_out,
  output	       clkb5_out,
  output	       clkb6_out,
  input            clk0_en,
  input            clk1_en,
  input            clk2_en,
  input            clk3_en,
  input            clk4_en,
  input            clk5_en,
  input            clk6_en,  
  input			   wakeup,           
  output           lock,             
  input            reset,         
  input  [1:0]     clkc_rst,         
  input            refclk_rst,       
  input  [1:0]     cps_step,         
  input            pllpd,            
  input            drp_clk,          
  input            drp_rstn,         
  input            drp_sel,          
  input            drp_rd,           
  input            drp_wr,           
  input  [7:0]     drp_addr,         
  input  [7:0]     drp_wdata,        
  output           drp_err,          
  output           drp_rdy,          
  output [7:0]     drp_rdata,        
  input            psclk,            
  input  [2:0]     psclksel,         
  input            psstep,           
  input            psdown,           
  output           psdone,           
  input            ssc_en,           
  input            ext_freq_mod_clk, 
  input            ext_freq_mod_en,  
  input  [16:0]    ext_freq_mod_val 	
);
reg sim_clk=0;
// This model is for the VTG's internal-feedback PLL, with a 50 MHz refclk.
// Derive the period from the actual elaborated PLL divider parameters.
localparam real HALF_PERIOD_NS = 10.0 * REFCLK_DIV * CLKC0_DIV / FBCLK_DIV;
always #(HALF_PERIOD_NS) sim_clk=~sim_clk;
assign clk0_out=sim_clk;
assign lock=~reset;
assign drp_rdy=drp_rd|drp_wr;
assign drp_rdata=0;
assign drp_err=0;
endmodule
