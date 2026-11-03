`timescale 1ns/1ps
// Interface-only BFM; does not implement neural-network arithmetic.
module axi_system_Video_NPU_0
(
  input                         M_AXI_ACLK,
  input                         M_AXI_AResetn,
  input                         S_AXILite_ACLK,
  input                         S_AXILite_AResetn,
  input   [32:0]                s_axilite_awaddr_i,
  input   [2:0]                 s_axilite_awprot_i,
  input                         s_axilite_awvalid_i,
  output reg s_axilite_awready_o,
  input   [31:0]                s_axilite_wdata_i,
  input   [3:0]                 s_axilite_wstrb_i,
  input                         s_axilite_wvalid_i,
  output reg s_axilite_wready_o,
  output reg s_axilite_bvalid_o,
  output reg [1:0]                 s_axilite_bresp_o,
  input                         s_axilite_bready_i,
  input   [32:0]                s_axilite_araddr_i,
  input   [2:0]                 s_axilite_arprot_i,
  input                         s_axilite_arvalid_i,
  output reg s_axilite_arready_o,
  output reg [31:0]                s_axilite_rdata_o,
  output reg [1:0]                 s_axilite_rresp_o,
  output reg s_axilite_rvalid_o,
  input                         s_axilite_rready_i,
  input                         m_axi_awready_soft_i,
  output reg [5:0]                 m_axi_awid_soft_o,
  output reg [32:0]                m_axi_awaddr_soft_o,
  output reg [3:0]                 m_axi_awlen_soft_o,
  output reg [1:0]                 m_axi_awsize_soft_o,
  output reg [1:0]                 m_axi_awburst_soft_o,
  output reg [2:0]                 m_axi_awprot_soft_o,
  output reg m_axi_awvalid_soft_o,
  output reg m_axi_awlock_soft_o,
  output reg [3:0]                 m_axi_awcache_soft_o,
  output reg [63:0]                m_axi_wdata_soft_o,
  output reg [7:0]                 m_axi_wstrb_soft_o,
  input                         m_axi_wready_soft_i,
  output reg m_axi_wlast_soft_o,
  output reg m_axi_wvalid_soft_o,
  input   [5:0]                 m_axi_bid_soft_i,
  input   [1:0]                 m_axi_bresp_soft_i,
  input                         m_axi_bvalid_soft_i,
  output reg m_axi_bready_soft_o,
  input                         m_axi_arready_soft_i,
  output reg [5:0]                 m_axi_arid_soft_o,
  output reg [32:0]                m_axi_araddr_soft_o,
  output reg [3:0]                 m_axi_arlen_soft_o,
  output reg [1:0]                 m_axi_arsize_soft_o,
  output reg [1:0]                 m_axi_arburst_soft_o,
  output reg [2:0]                 m_axi_arprot_soft_o,
  output reg m_axi_arvalid_soft_o,
  output reg m_axi_arlock_soft_o,
  output reg [3:0]                 m_axi_arcache_soft_o,
  input   [5:0]                 m_axi_rid_soft_i,
  input   [63:0]                m_axi_rdata_soft_i,
  input   [1:0]                 m_axi_rresp_soft_i,
  input                         m_axi_rlast_soft_i,
  input                         m_axi_rvalid_soft_i,
  output reg m_axi_rready_soft_o,
  output reg npu_soft_intr
);
initial begin
    s_axilite_awready_o='0;
    s_axilite_wready_o='0;
    s_axilite_bvalid_o='0;
    s_axilite_bresp_o='0;
    s_axilite_arready_o='0;
    s_axilite_rdata_o='0;
    s_axilite_rresp_o='0;
    s_axilite_rvalid_o='0;
    m_axi_awid_soft_o='0;
    m_axi_awaddr_soft_o='0;
    m_axi_awlen_soft_o='0;
    m_axi_awsize_soft_o='0;
    m_axi_awburst_soft_o='0;
    m_axi_awprot_soft_o='0;
    m_axi_awvalid_soft_o='0;
    m_axi_awlock_soft_o='0;
    m_axi_awcache_soft_o='0;
    m_axi_wdata_soft_o='0;
    m_axi_wstrb_soft_o='0;
    m_axi_wlast_soft_o='0;
    m_axi_wvalid_soft_o='0;
    m_axi_bready_soft_o='0;
    m_axi_arid_soft_o='0;
    m_axi_araddr_soft_o='0;
    m_axi_arlen_soft_o='0;
    m_axi_arsize_soft_o='0;
    m_axi_arburst_soft_o='0;
    m_axi_arprot_soft_o='0;
    m_axi_arvalid_soft_o='0;
    m_axi_arlock_soft_o='0;
    m_axi_arcache_soft_o='0;
    m_axi_rready_soft_o='0;
    npu_soft_intr='0;
end

reg have_aw=0,have_w=0;
reg [32:0] aw_saved;
reg [31:0] w_saved;
reg [3:0] strb_saved;
reg [31:0] registers[0:63];
always @* begin
    s_axilite_awready_o=!have_aw && !s_axilite_bvalid_o;
    s_axilite_wready_o=!have_w && !s_axilite_bvalid_o;
    s_axilite_arready_o=!s_axilite_rvalid_o;
end
always @(posedge S_AXILite_ACLK) begin
    if(!S_AXILite_AResetn)begin
        have_aw<=0;have_w<=0;s_axilite_bvalid_o<=0;s_axilite_rvalid_o<=0;npu_soft_intr<=0;
        for(integer i=0;i<64;i++)registers[i]<=0;
    end else begin
        if(s_axilite_awvalid_i && s_axilite_awready_o)begin have_aw<=1;aw_saved<=s_axilite_awaddr_i;end
        if(s_axilite_wvalid_i && s_axilite_wready_o)begin have_w<=1;w_saved<=s_axilite_wdata_i;strb_saved<=s_axilite_wstrb_i;end
        if(have_aw && have_w && !s_axilite_bvalid_o)begin
            if(aw_saved[32:16]!==17'h1f000)$fatal(1,"GP1 33-bit address lost: %h",aw_saved);
            for(integer i=0;i<4;i++)if(strb_saved[i])registers[aw_saved[7:2]][i*8+:8]<=w_saved[i*8+:8];
            if(aw_saved[15:0]==0 && strb_saved[0])npu_soft_intr<=w_saved[0];
            have_aw<=0;have_w<=0;s_axilite_bvalid_o<=1;s_axilite_bresp_o<=0;
        end
        if(s_axilite_bvalid_o && s_axilite_bready_i)s_axilite_bvalid_o<=0;
        if(s_axilite_arvalid_i && s_axilite_arready_o)begin
            if(s_axilite_araddr_i[32:16]!==17'h1f000)$fatal(1,"GP1 read address lost");
            s_axilite_rdata_o<=registers[s_axilite_araddr_i[7:2]];s_axilite_rresp_o<=0;s_axilite_rvalid_o<=1;
        end
        if(s_axilite_rvalid_o && s_axilite_rready_i)s_axilite_rvalid_o<=0;
    end
end
function automatic [63:0] pattern(input integer id,input integer beat);
    pattern=64'h81fedcba76543210 ^ (id*16+beat);
endfunction
task automatic test_write(input [32:0] addr,input [5:0] id,input integer beats,input [1:0] expected_resp=0);
    integer ticks;
    begin
        @(negedge M_AXI_ACLK);
        m_axi_awaddr_soft_o=addr;m_axi_awid_soft_o=id;m_axi_awlen_soft_o=beats-1;
        m_axi_awsize_soft_o=3;m_axi_awburst_soft_o=1;m_axi_awvalid_soft_o=1;
        ticks=0;
        do begin @(posedge M_AXI_ACLK);if(ticks++>10000)$fatal(1,"NPU AW timeout");end while(!m_axi_awready_soft_i);
        @(negedge M_AXI_ACLK);m_axi_awvalid_soft_o=0;
        for(integer b=0;b<beats;b++)begin
            m_axi_wdata_soft_o=pattern(id,b);m_axi_wstrb_soft_o=8'hff;
            m_axi_wlast_soft_o=(b==beats-1);m_axi_wvalid_soft_o=1;
            do begin @(posedge M_AXI_ACLK);if(ticks++>20000)$fatal(1,"NPU W timeout");end while(!m_axi_wready_soft_i);
            @(negedge M_AXI_ACLK);m_axi_wvalid_soft_o=0;
        end
        while(!m_axi_bvalid_soft_i)begin @(negedge M_AXI_ACLK);if(ticks++>30000)$fatal(1,"NPU B timeout");end
        repeat(5)begin
            @(negedge M_AXI_ACLK);
            if(!m_axi_bvalid_soft_i || m_axi_bid_soft_i!==id || m_axi_bresp_soft_i!==expected_resp)
                $fatal(1,"NPU B ID/response/backpressure mismatch id=%h got=%h resp=%h",id,m_axi_bid_soft_i,m_axi_bresp_soft_i);
        end
        m_axi_bready_soft_o=1;@(posedge M_AXI_ACLK);@(negedge M_AXI_ACLK);m_axi_bready_soft_o=0;
    end
endtask
task automatic test_read(input [32:0] addr,input [5:0] id,input integer beats,input [1:0] expected_resp=0);
    integer ticks;
    reg [63:0] held;
    begin
        @(negedge M_AXI_ACLK);
        m_axi_araddr_soft_o=addr;m_axi_arid_soft_o=id;m_axi_arlen_soft_o=beats-1;
        m_axi_arsize_soft_o=3;m_axi_arburst_soft_o=1;m_axi_arvalid_soft_o=1;
        ticks=0;
        do begin @(posedge M_AXI_ACLK);if(ticks++>10000)$fatal(1,"NPU AR timeout");end while(!m_axi_arready_soft_i);
        @(negedge M_AXI_ACLK);m_axi_arvalid_soft_o=0;
        for(integer b=0;b<beats;b++)begin
            while(!m_axi_rvalid_soft_i)begin @(negedge M_AXI_ACLK);if(ticks++>30000)$fatal(1,"NPU R timeout");end
            held=m_axi_rdata_soft_i;
            repeat(2)begin
                @(negedge M_AXI_ACLK);
                if(!m_axi_rvalid_soft_i || m_axi_rdata_soft_i!==held || m_axi_rid_soft_i!==id || m_axi_rresp_soft_i!==expected_resp || m_axi_rlast_soft_i!==(b==beats-1))
                    $fatal(1,"NPU R stability/ID/response mismatch id=%h got=%h beat=%0d",id,m_axi_rid_soft_i,b);
            end
            if(held!==pattern(id,b))$fatal(1,"NPU DDR data mismatch id=%h beat=%0d got=%h",id,b,held);
            m_axi_rready_soft_o=1;@(posedge M_AXI_ACLK);@(negedge M_AXI_ACLK);m_axi_rready_soft_o=0;
        end
    end
endtask
endmodule
