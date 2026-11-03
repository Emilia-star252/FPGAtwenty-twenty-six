`timescale 1ns/1ps
// Simulation-only GP0 initiator and HP0 DDR responder; not a PS/DDR hardware model.
module axi_system_ARM_Processor_System_0
(
  input                         slave_hp0_axi_aclk,
  input   [32:0]                slave_hp0_axi_araddr,
  input   [1:0]                 slave_hp0_axi_arburst,
  input   [3:0]                 slave_hp0_axi_arcache,
  input   [5:0]                 slave_hp0_axi_arid,
  input   [3:0]                 slave_hp0_axi_arlen,
  input                         slave_hp0_axi_arlock,
  input   [2:0]                 slave_hp0_axi_arprot,
  input   [3:0]                 slave_hp0_axi_arqos,
  output reg slave_hp0_axi_arready,
  input   [1:0]                 slave_hp0_axi_arsize,
  input                         slave_hp0_axi_arvalid,
  input   [32:0]                slave_hp0_axi_awaddr,
  input   [1:0]                 slave_hp0_axi_awburst,
  input   [3:0]                 slave_hp0_axi_awcache,
  input   [5:0]                 slave_hp0_axi_awid,
  input   [3:0]                 slave_hp0_axi_awlen,
  input                         slave_hp0_axi_awlock,
  input   [2:0]                 slave_hp0_axi_awprot,
  input   [3:0]                 slave_hp0_axi_awqos,
  output reg slave_hp0_axi_awready,
  input   [1:0]                 slave_hp0_axi_awsize,
  input                         slave_hp0_axi_awvalid,
  output reg [5:0]                 slave_hp0_axi_bid,
  input                         slave_hp0_axi_bready,
  output reg [1:0]                 slave_hp0_axi_bresp,
  output reg slave_hp0_axi_bvalid,
  output reg [63:0]                slave_hp0_axi_rdata,
  output reg [5:0]                 slave_hp0_axi_rid,
  output reg slave_hp0_axi_rlast,
  input                         slave_hp0_axi_rready,
  output reg [1:0]                 slave_hp0_axi_rresp,
  output reg slave_hp0_axi_rvalid,
  input   [63:0]                slave_hp0_axi_wdata,
  input                         slave_hp0_axi_wlast,
  output reg slave_hp0_axi_wready,
  input   [7:0]                 slave_hp0_axi_wstrb,
  input                         slave_hp0_axi_wvalid,
  input                         slave_hp1_axi_aclk,
  input   [32:0]                slave_hp1_axi_araddr,
  input   [1:0]                 slave_hp1_axi_arburst,
  input   [3:0]                 slave_hp1_axi_arcache,
  input   [5:0]                 slave_hp1_axi_arid,
  input   [3:0]                 slave_hp1_axi_arlen,
  input                         slave_hp1_axi_arlock,
  input   [2:0]                 slave_hp1_axi_arprot,
  input   [3:0]                 slave_hp1_axi_arqos,
  output reg slave_hp1_axi_arready,
  input   [1:0]                 slave_hp1_axi_arsize,
  input                         slave_hp1_axi_arvalid,
  input   [32:0]                slave_hp1_axi_awaddr,
  input   [1:0]                 slave_hp1_axi_awburst,
  input   [3:0]                 slave_hp1_axi_awcache,
  input   [5:0]                 slave_hp1_axi_awid,
  input   [3:0]                 slave_hp1_axi_awlen,
  input                         slave_hp1_axi_awlock,
  input   [2:0]                 slave_hp1_axi_awprot,
  input   [3:0]                 slave_hp1_axi_awqos,
  output reg slave_hp1_axi_awready,
  input   [1:0]                 slave_hp1_axi_awsize,
  input                         slave_hp1_axi_awvalid,
  output reg [5:0]                 slave_hp1_axi_bid,
  input                         slave_hp1_axi_bready,
  output reg [1:0]                 slave_hp1_axi_bresp,
  output reg slave_hp1_axi_bvalid,
  output reg [63:0]                slave_hp1_axi_rdata,
  output reg [5:0]                 slave_hp1_axi_rid,
  output reg slave_hp1_axi_rlast,
  input                         slave_hp1_axi_rready,
  output reg [1:0]                 slave_hp1_axi_rresp,
  output reg slave_hp1_axi_rvalid,
  input   [63:0]                slave_hp1_axi_wdata,
  input                         slave_hp1_axi_wlast,
  output reg slave_hp1_axi_wready,
  input   [7:0]                 slave_hp1_axi_wstrb,
  input                         slave_hp1_axi_wvalid,
  input                         master_gp0_axi_aclk,
  output reg [32:0]                master_gp0_axi_araddr,
  output reg [1:0]                 master_gp0_axi_arburst,
  output reg [3:0]                 master_gp0_axi_arcache,
  output reg [11:0]                master_gp0_axi_arid,
  output reg [3:0]                 master_gp0_axi_arlen,
  output reg master_gp0_axi_arlock,
  output reg [2:0]                 master_gp0_axi_arprot,
  input                         master_gp0_axi_arready,
  output reg [1:0]                 master_gp0_axi_arsize,
  output reg master_gp0_axi_arvalid,
  output reg [32:0]                master_gp0_axi_awaddr,
  output reg [1:0]                 master_gp0_axi_awburst,
  output reg [3:0]                 master_gp0_axi_awcache,
  output reg [11:0]                master_gp0_axi_awid,
  output reg [3:0]                 master_gp0_axi_awlen,
  output reg master_gp0_axi_awlock,
  output reg [2:0]                 master_gp0_axi_awprot,
  input                         master_gp0_axi_awready,
  output reg [1:0]                 master_gp0_axi_awsize,
  output reg master_gp0_axi_awvalid,
  input   [11:0]                master_gp0_axi_bid,
  output reg master_gp0_axi_bready,
  input   [1:0]                 master_gp0_axi_bresp,
  input                         master_gp0_axi_bvalid,
  input   [31:0]                master_gp0_axi_rdata,
  input   [11:0]                master_gp0_axi_rid,
  input                         master_gp0_axi_rlast,
  output reg master_gp0_axi_rready,
  input   [1:0]                 master_gp0_axi_rresp,
  input                         master_gp0_axi_rvalid,
  output reg [31:0]                master_gp0_axi_wdata,
  output reg master_gp0_axi_wlast,
  input                         master_gp0_axi_wready,
  output reg [3:0]                 master_gp0_axi_wstrb,
  output reg master_gp0_axi_wvalid,
  output reg p2f_rst0_n,
  output reg p2f_clk0
);
initial begin
    slave_hp0_axi_arready = '0;
    slave_hp0_axi_awready = '0;
    slave_hp0_axi_bid = '0;
    slave_hp0_axi_bresp = '0;
    slave_hp0_axi_bvalid = '0;
    slave_hp0_axi_rdata = '0;
    slave_hp0_axi_rid = '0;
    slave_hp0_axi_rlast = '0;
    slave_hp0_axi_rresp = '0;
    slave_hp0_axi_rvalid = '0;
    slave_hp0_axi_wready = '0;
    slave_hp1_axi_arready = '0;
    slave_hp1_axi_awready = '0;
    slave_hp1_axi_bid = '0;
    slave_hp1_axi_bresp = '0;
    slave_hp1_axi_bvalid = '0;
    slave_hp1_axi_rdata = '0;
    slave_hp1_axi_rid = '0;
    slave_hp1_axi_rlast = '0;
    slave_hp1_axi_rresp = '0;
    slave_hp1_axi_rvalid = '0;
    slave_hp1_axi_wready = '0;
    master_gp0_axi_araddr = '0;
    master_gp0_axi_arburst = '0;
    master_gp0_axi_arcache = '0;
    master_gp0_axi_arid = '0;
    master_gp0_axi_arlen = '0;
    master_gp0_axi_arlock = '0;
    master_gp0_axi_arprot = '0;
    master_gp0_axi_arsize = '0;
    master_gp0_axi_arvalid = '0;
    master_gp0_axi_awaddr = '0;
    master_gp0_axi_awburst = '0;
    master_gp0_axi_awcache = '0;
    master_gp0_axi_awid = '0;
    master_gp0_axi_awlen = '0;
    master_gp0_axi_awlock = '0;
    master_gp0_axi_awprot = '0;
    master_gp0_axi_awsize = '0;
    master_gp0_axi_awvalid = '0;
    master_gp0_axi_bready = '0;
    master_gp0_axi_rready = '0;
    master_gp0_axi_wdata = '0;
    master_gp0_axi_wlast = '0;
    master_gp0_axi_wstrb = '0;
    master_gp0_axi_wvalid = '0;
    p2f_rst0_n = '0;
    p2f_clk0 = '0;
end

reg reset_release = 0;
initial begin
    repeat (20) @(posedge master_gp0_axi_aclk);
    @(negedge master_gp0_axi_aclk); reset_release = 1;
end
always @* p2f_rst0_n = reset_release;
always @* p2f_clk0 = master_gp0_axi_aclk;

task automatic write32(input [32:0] addr, input [31:0] data);
    bit awdone, wdone;
    integer ticks;
    begin
        @(negedge master_gp0_axi_aclk);
        master_gp0_axi_awaddr=addr; master_gp0_axi_awlen=0;
        master_gp0_axi_awsize=2; master_gp0_axi_awburst=1;
        master_gp0_axi_awvalid=1; master_gp0_axi_wdata=data;
        master_gp0_axi_wstrb=15; master_gp0_axi_wlast=1;
        master_gp0_axi_wvalid=1; master_gp0_axi_bready=1;
        awdone=0; wdone=0; ticks=0;
        while (!awdone || !wdone) begin
            @(posedge master_gp0_axi_aclk);
            if (master_gp0_axi_awready && master_gp0_axi_awvalid) awdone=1;
            if (master_gp0_axi_wready && master_gp0_axi_wvalid) wdone=1;
            @(negedge master_gp0_axi_aclk);
            if (awdone) master_gp0_axi_awvalid=0;
            if (wdone) master_gp0_axi_wvalid=0;
            ticks++;
            if (ticks>2000) $fatal(1,"GP0 write handshake timeout addr=%h",addr);
        end
        while (!master_gp0_axi_bvalid) begin
            @(negedge master_gp0_axi_aclk); ticks++;
            if (ticks>4000) $fatal(1,"GP0 B timeout");
        end
        if(master_gp0_axi_bresp!=0) $fatal(1,"GP0 write error addr=%h resp=%b",addr,master_gp0_axi_bresp);
        @(posedge master_gp0_axi_aclk);
        @(negedge master_gp0_axi_aclk); master_gp0_axi_bready=0;
    end
endtask
task automatic read32(input [32:0] addr, output [31:0] data, output [1:0] resp);
    integer ticks;
    begin
        @(negedge master_gp0_axi_aclk);
        master_gp0_axi_araddr=addr; master_gp0_axi_arlen=0;
        master_gp0_axi_arsize=2; master_gp0_axi_arburst=1;
        master_gp0_axi_arvalid=1; master_gp0_axi_rready=0; ticks=0;
        do begin
            @(posedge master_gp0_axi_aclk); ticks++;
            if (ticks>2000) $fatal(1,"GP0 AR timeout addr=%h",addr);
        end while (!master_gp0_axi_arready);
        @(negedge master_gp0_axi_aclk); master_gp0_axi_arvalid=0;
        while (!master_gp0_axi_rvalid) begin
            @(negedge master_gp0_axi_aclk); ticks++;
            if (ticks>4000) $fatal(1,"GP0 R timeout addr=%h",addr);
        end
        data=master_gp0_axi_rdata; resp=master_gp0_axi_rresp;
        // Exercise GP0 read-response backpressure.
        repeat (3) begin
            @(negedge master_gp0_axi_aclk);
            if (!master_gp0_axi_rvalid || master_gp0_axi_rdata!==data || master_gp0_axi_rresp!==resp)
                $fatal(1,"GP0 unstable read response");
        end
        master_gp0_axi_rready=1;
        @(posedge master_gp0_axi_aclk);
        @(negedge master_gp0_axi_aclk); master_gp0_axi_rready=0;
    end
endtask

byte unsigned memory [0:32767];
integer cycle=0, remain=0, write_bytes=0, burst_count=0, response_delay=0;
reg active=0;
reg [32:0] pointer;
reg [5:0] write_id;
reg inject_error=0;
always @(negedge slave_hp0_axi_aclk) begin
    cycle=cycle+1;
    slave_hp0_axi_awready=reset_release && !active && !slave_hp0_axi_bvalid && response_delay==0 && (cycle%3!=0);
    slave_hp0_axi_wready=reset_release && active && (cycle%5!=0);
end
always @(posedge slave_hp0_axi_aclk) begin
    if(slave_hp0_axi_awvalid && slave_hp0_axi_awready) begin
        if(active) $fatal(1,"HP0 overlapping address");
        if(slave_hp0_axi_awsize!=3 || slave_hp0_axi_awburst!=1 || slave_hp0_axi_awlock!=0)
            $fatal(1,"HP0 burst attributes size=%d burst=%d",slave_hp0_axi_awsize,slave_hp0_axi_awburst);
        if(({1'b0,slave_hp0_axi_awaddr[11:0]}+((slave_hp0_axi_awlen+1)*8))>4096)
            $fatal(1,"HP0 4K boundary crossing");
        pointer=slave_hp0_axi_awaddr; remain=slave_hp0_axi_awlen+1;
        write_id=slave_hp0_axi_awid; active=1; burst_count++;
    end
    if(slave_hp0_axi_wvalid && slave_hp0_axi_wready) begin
        if(!active || slave_hp0_axi_wlast!=(remain==1)) $fatal(1,"HP0 WLAST mismatch");
        for(integer j=0;j<8;j++) if(slave_hp0_axi_wstrb[j]) begin
            if(pointer+j<33'h10000000 || pointer+j>=33'h10008000) $fatal(1,"DDR address out of model range");
            memory[pointer+j-33'h10000000]=slave_hp0_axi_wdata[j*8+:8];
            write_bytes++;
        end
        pointer=pointer+8; remain--;
        if(remain==0) begin active=0; response_delay=4; end
    end
    if(slave_hp0_axi_bvalid && slave_hp0_axi_bready) slave_hp0_axi_bvalid<=0;
    if(response_delay>0) begin
        response_delay--;
        if(response_delay==0) begin
            slave_hp0_axi_bvalid<=1;
            slave_hp0_axi_bid<=write_id;
            slave_hp0_axi_bresp<=inject_error?2'b10:2'b00;
        end
    end
    if(slave_hp0_axi_arvalid || slave_hp1_axi_arvalid || slave_hp1_axi_awvalid || slave_hp1_axi_wvalid)
        $fatal(1,"Unexpected read or HP1 transaction");
end
endmodule
