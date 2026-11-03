`timescale 1ns/1ps
module tb_hdmi_reset;
    reg ctrl=0,mem=0,axis_clk=0,pixel=0,serial=0;
    always #5 ctrl=~ctrl;
    always #4.166 mem=~mem;
    always #3.333 axis_clk=~axis_clk;
    always #10.204081633 pixel=~pixel;
    always #2.040816327 serial=~serial;
    reg axi_reset_n=0,display_lock=0,pixel_lock=0,serial_lock=0,video_lock=0;
    wire cr,mr,ar,pr,tr,spr;
    reg test_passed=0;
    hdmi_clock_reset dut(.ctrl_clk(ctrl),.mem_clk(mem),.axis_clk(axis_clk),.pixel_clk(pixel),
        .axi_reset_n(axi_reset_n),.display_pll_locked(display_lock),.pixel_pll_locked(pixel_lock),
        .serial_pll_locked(serial_lock),.video_locked(video_lock),.serial_pll_reset(spr),
        .ctrl_reset_n(cr),.mem_reset_n(mr),.axis_reset_n(ar),.pixel_reset(pr),.tx_reset(tr));
    hdmi_tx_phy_wrapper_c33abe7c933e #(.DEVICE("DR1")) phy(
        .I_pixel_clk(pixel),.I_serial_clk(serial),.I_rst(tr),
        .I_tmds_channel_0(10'h155),.I_tmds_channel_1(10'h2aa),.I_tmds_channel_2(10'h055),.I_tmds_channel_clk(10'h01f),
        .O_tmds_ch0_p(),.O_tmds_ch1_p(),.O_tmds_ch2_p(),.O_tmds_clk_p());
    initial begin
        #20;
        if({cr,mr,ar,pr,tr,spr} !== 6'b000111) $fatal(1,"startup reset state");
        axi_reset_n=1;display_lock=1;
        @(posedge ctrl);#0.01;if(cr) $fatal(1,"control reset released early");
        repeat(2) @(posedge ctrl);
        #0.01;if(!cr || !mr || !ar || !pr || !tr) $fatal(1,"clock-domain release state");
        pixel_lock=1;serial_lock=1;
        repeat(4) @(posedge pixel);
        #0.01;if(pr || !tr || spr) $fatal(1,"TX must wait for video lock");
        video_lock=1;
        @(negedge tr);
        #0.01;if(!phy.serial_reset) $fatal(1,"serial reset released without synchronization");
        repeat(2) @(posedge serial);
        #0.01;if(!phy.serial_reset) $fatal(1,"serial reset released before third cycle");
        @(posedge serial);#0.01;
        if(phy.serial_reset) $fatal(1,"serial reset did not release");
        #0.123;video_lock=0;#0.01;
        if(!tr || !phy.serial_reset || !cr || !mr || !ar) $fatal(1,"video lock loss reset isolation");
        video_lock=1;
        repeat(5) @(posedge pixel);
        #0.123;display_lock=0;#0.01;
        if({cr,mr,ar,pr,tr} !== 5'b00011) $fatal(1,"display PLL loss asynchronous assertion");
        if(!axi_reset_n) $fatal(1,"display reset affected acquisition reset input");
        $display("HDMI_RESET_DOMAINS_AND_SERIAL_RECOVERY_PASS");
        test_passed=1;$finish;
    end
endmodule

// Simulation-only ODDR primitive, sufficient to exercise the actual PHY reset
// tree and serializer registers; it does not model IO electrical behavior.
module DR1_LOGIC_ODDR(input clk,rst,d0,d1,output reg q);
    always @(posedge clk or negedge clk or posedge rst)
        if(rst) q<=0; else if(clk) q<=d1; else q<=d0;
endmodule
