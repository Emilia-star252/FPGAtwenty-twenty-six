// AXI4 Slave RTL Wrapper
// 自动生成的Wrapper文件，用于封装axilite_slave_v11模块
// AXI Lite Slave 寄存器读写模块
// 寄存器数量：默认根据地址位宽进行计算
// 数据位宽：32
// 支持 AXI Lite 协议的读写操作，支持地址、数据乱序到达
// 仅支持TD6.2.1 以及以后的版本，其他版本请联系客户支持
// 20250810 初始版本
// 20250811 优化读写逻辑，提高效率
// 20251124 Optimize resource utilization
//          Replace the IP packaging method with the import of RTL module approach, making it easier for users to add logic

module axi4lite_slave #(
    parameter ADDR_WIDTH  = 8,                   // 地址宽度
    parameter DATA_WIDTH  = 32                   // 数据位宽，不要修改

)(
    
    // GP0 control/status only. Sample values are delivered exclusively via DDR.
    input  wire                  adc_sample_valid,
    input  wire [31:0]           adc_status_in,
    input  wire [31:0]           control_status_in,
    input  wire [31:0]           vref_active_q16_in,
    input  wire                  protection_stop,
    output wire                  fault_clear_cmd,
    output wire                  output_enable_cmd,
    output wire [31:0]           vref_cmd_q16,

    // FIFO read side, synchronous to clk. Replaced by DMA in a later design.
    input  wire [31:0]           s_axis_tdata,
    input  wire [3:0]            s_axis_tkeep,
    input  wire                  s_axis_tlast,
    input  wire                  s_axis_tvalid,
    output wire                  s_axis_tready,
    input  wire [31:0]           fifo_level_in,
    input  wire [31:0]           fifo_drop_count_in,
    input  wire                  fifo_ready_in,
    output wire                  capture_enable,
    output wire                  fifo_clear,
    
    input  wire                  clk,          // 时钟信号
    input  wire                  rst_n,        // 异步复位，低有效

    // AXI Lite 接口信号
    input  wire [ADDR_WIDTH-1:0] s_axi_awaddr  ,  // 写地址
    input  wire                  s_axi_awvalid ,  // 写地址有效
    output wire                  s_axi_awready ,  // 写地址准备好  
    input  wire [DATA_WIDTH-1:0] s_axi_wdata   ,  // 写数据

    input  wire [3:0]            s_axi_wstrb   ,  // 写字节使能
    input  wire                  s_axi_wvalid  ,  // 写数据有效
    output wire                  s_axi_wready  ,  // 写数据准备好 
    output wire [1:0]            s_axi_bresp   ,  // 写响应
    output wire                  s_axi_bvalid  ,  // 写响应有效
    input  wire                  s_axi_bready  ,  // 写响应准备好 
    input  wire [ADDR_WIDTH-1:0] s_axi_araddr  ,  // 读地址
    input  wire                  s_axi_arvalid ,  // 读地址有效
    output wire                  s_axi_arready ,  // 读地址准备好 
    output wire [DATA_WIDTH-1:0] s_axi_rdata   ,  // 读数据
    output wire [1:0]            s_axi_rresp   ,  // 读响应
    output wire                  s_axi_rvalid  ,  // 读数据有效
    input  wire                  s_axi_rready     // 读数据准备好 
);

    // 实例化原始AXI Lite Slave模块
    axi4lite_slave_v11 #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_axi4lite_slave_v11 (
        
        .adc_sample_valid(adc_sample_valid),
        .adc_status_in(adc_status_in),
        .control_status_in(control_status_in),
        .vref_active_q16_in(vref_active_q16_in),
        .protection_stop(protection_stop),
        .fault_clear_cmd(fault_clear_cmd),
        .output_enable_cmd(output_enable_cmd),
        .vref_cmd_q16(vref_cmd_q16),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tkeep(s_axis_tkeep),
        .s_axis_tlast(s_axis_tlast),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .fifo_level_in(fifo_level_in),
        .fifo_drop_count_in(fifo_drop_count_in),
        .fifo_ready_in(fifo_ready_in),
        .capture_enable(capture_enable),
        .fifo_clear(fifo_clear),
    
        .clk(clk),
        .rst_n(rst_n),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready)
    );

endmodule
