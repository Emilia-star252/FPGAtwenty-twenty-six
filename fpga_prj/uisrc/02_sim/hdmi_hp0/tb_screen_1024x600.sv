`timescale 1ns/1ps
// Vendor VTG counter test. PLL divider tuples are TD-verified simulation substitutions.
module tb_screen_1024x600;
    reg ctrl=0,refclk=0,axis_clk=0,rst_n=0;
    always #5 ctrl=~ctrl;
    always #10 refclk=~refclk;
    always #3.333333 axis_clk=~axis_clk;
    wire pixel,pll_lock,hs,vs,hb,vb,active;
    reg test_passed=0;
    axi_system_HDMI_VTG_0 vtg(
        .aclk(ctrl),.arst_n(rst_n),.s_axi_awaddr(13'd0),.s_axi_awvalid(1'b0),
        .s_axi_wdata(32'd0),.s_axi_wstrb(4'd0),.s_axi_wvalid(1'b0),.s_axi_bready(1'b1),
        .s_axi_araddr(13'd0),.s_axi_arvalid(1'b0),.s_axi_rready(1'b1),
        .ref_clk(refclk),.vtg_ce(1'b1),.vtg_pclk_locked(pll_lock),.vtg_pclk(pixel),
        .vtg_hsync(hs),.vtg_vsync(vs),.vtg_hblank(hb),.vtg_vblank(vb),.vtg_active_video(active));
    integer hs_pixels,vs_pixels,de_pixels;
    realtime edge1,edge2;
    initial begin
        #200;rst_n=1;
        repeat(10) @(posedge pixel);
        edge1=$realtime;@(posedge pixel);edge2=$realtime;
        if(edge2-edge1<20.407 || edge2-edge1>20.410)
            $fatal(1,"wrong pixel period %f",edge2-edge1);
        if(vtg.video_timing_generator_v01_dd045705834d_Inst.reg0!=48 ||
           vtg.video_timing_generator_v01_dd045705834d_Inst.reg1!=1024 ||
           vtg.video_timing_generator_v01_dd045705834d_Inst.reg2!=96 ||
           vtg.video_timing_generator_v01_dd045705834d_Inst.reg3!=144 ||
           vtg.video_timing_generator_v01_dd045705834d_Inst.reg4!=3 ||
           vtg.video_timing_generator_v01_dd045705834d_Inst.reg5!=600 ||
           vtg.video_timing_generator_v01_dd045705834d_Inst.reg6!=7 ||
           vtg.video_timing_generator_v01_dd045705834d_Inst.reg7!=14)
            $fatal(1,"screen default timing registers mismatch");
        @(posedge vs);
        hs_pixels=0;vs_pixels=0;de_pixels=0;
        repeat(1312*624) begin
            @(posedge pixel);#0.001;
            if(!hs)hs_pixels++;
            if(!vs)vs_pixels++;
            if(active)de_pixels++;
        end
        if(hs_pixels!=96*624 || vs_pixels!=7*1312 || de_pixels!=1024*600)
            $fatal(1,"frame counts H=%0d V=%0d DE=%0d",hs_pixels,vs_pixels,de_pixels);
        $display("SCREEN_VTG_TIMING_PASS totals=1312x624 active=%0d hsync_low=%0d vsync_low=%0d period_ns=%f",de_pixels,hs_pixels,vs_pixels,edge2-edge1);
        test_passed=1;$finish;
    end
    initial begin #40000000;$fatal(1,"screen timing simulation timeout");end
endmodule
