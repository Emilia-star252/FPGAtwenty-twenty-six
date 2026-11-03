`timescale 1ns/1ps
// Isolate the vendor Stream-to-Video core from DDR, VDMA and register startup.
module tb_video_out_unit;
    reg axis_clk=0,pixel_clk=0;
    always #3.333 axis_clk=~axis_clk;
    always #3.367 pixel_clk=~pixel_clk;
    reg axis_reset_n=0,pixel_reset=1,send=0;
    integer index=0,h=0,v=0,native_count=0;
    wire ready,locked,ce,de,uf,of;
    wire [31:0] status;
    reg test_passed=0;
    wire hs=h<44,vs=v<5,hb=h<192||h>=2112,vb=v<41||v>=1121;
    axi_system_AXI4_Stream_to_Video_Out_0 dut(
        .aclk(axis_clk),.aclken(1'b1),.aresetn(axis_reset_n),
        .s_axis_video_tdata(24'h123456),.s_axis_video_tvalid(send),
        .s_axis_video_tready(ready),.s_axis_video_tuser(index==0),
        .s_axis_video_tlast(index%1920==1919),.fid(1'b0),
        .vid_io_out_clk(pixel_clk),.vid_io_out_reset(pixel_reset),.vid_io_out_ce(1'b1),
        .vid_active_video(de),.vid_vsync(),.vid_hsync(),.vid_vblank(),.vid_hblank(),.vid_field_id(),.vid_data(),
        .vtg_vsync(vs),.vtg_hsync(hs),.vtg_vblank(vb),.vtg_hblank(hb),.vtg_active_video(!(hb||vb)),.vtg_field_id(1'b0),
        .vtg_ce(ce),.locked(locked),.overflow(of),.underflow(uf),.fifo_read_level(),.status(status),.sof_state_out());
    defparam dut.alc_axi4s_vid_out_Inst.AXIS2Vid_VTG_MASTER_SLAVE=0;
    always @(posedge axis_clk)
        if(send && ready) begin if(index==2073599) index<=0; else index<=index+1; end
    always @(posedge pixel_clk) begin
        if(pixel_reset) begin h<=0;v<=0;end
        else if(h==2199) begin h<=0;if(v==1124)v<=0;else v<=v+1;end
        else h<=h+1;
        if(de) native_count++;
    end
    initial begin
        #200;axis_reset_n=1;
        #100;pixel_reset=0;
        #200;send=1;
        #100000000;
        if(!locked || native_count<4096)
            $fatal(1,"VIDEO_OUT_UNIT_NOT_LOCKED status=%h native=%0d input_index=%0d",status,native_count,index);
        $display("VIDEO_OUT_UNIT_PASS pixels=%0d",native_count);
        test_passed=1;$finish;
    end
endmodule



