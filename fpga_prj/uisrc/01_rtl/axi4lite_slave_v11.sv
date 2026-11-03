// AXI Lite Slave 寄存器读写模块
// 寄存器数量：默认根据地址位宽进行计算
// 数据位宽：32
// 支持 AXI Lite 协议的读写操作，支持地址、数据乱序到达
// 仅支持TD6.2.1 以及以后的版本，其他版本请联系客户支持
// 20250810 初始版本
// 20250811 优化读写逻辑，提高效率
// 20251124 Optimize resource utilization
//          Replace the IP packaging method with the import of RTL module approach, making it easier for users to add logic


module axi4lite_slave_v11 #(
    parameter ADDR_WIDTH  = 8,                   // 地址宽度
    parameter DATA_WIDTH  = 32                   // 数据位宽，不要修改
)(
    
    // GP0 control/status only. No raw or converted V/I/duty readback.
    input  wire                  adc_sample_valid,
    input  wire [31:0]           adc_status_in,
    input  wire [31:0]           control_status_in,
    input  wire [31:0]           vref_active_q16_in,
    input  wire                  protection_stop,
    output reg                   fault_clear_cmd,
    output reg                   output_enable_cmd,
    output reg  [31:0]           vref_cmd_q16,

    input  wire [31:0]           s_axis_tdata,
    input  wire [3:0]            s_axis_tkeep,
    input  wire                  s_axis_tlast,
    input  wire                  s_axis_tvalid,
    output wire                  s_axis_tready,
    input  wire [31:0]           fifo_level_in,
    input  wire [31:0]           fifo_drop_count_in,
    input  wire                  fifo_ready_in,
    output reg                   capture_enable,
    output reg                   fifo_clear,
    
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
    // 数据宽度,只支持32位
    localparam REG_NUM    = (1 << (ADDR_WIDTH-2));  // 寄存器数量，可配置
    // 参数化的寄存器数组，不连续的地址，建议使用多个寄存器组以节约资源使用
    reg [DATA_WIDTH-1:0] reg_array [0:REG_NUM-1];

    // ADC1 diagnostic/status and sample count remain. CTR1 is retained by
    // agreement with PS; retired measurement registers return SLVERR.
    reg [31:0] sample_count;
    reg sample_seen;
    localparam [31:0] VREF_MAX_Q16 = 32'd4194304; // 64 V command limit
    reg command_error;
    reg [31:0] merged_vref;
    reg [1:0] bresp;
    wire [31:0] adc_status = (adc_status_in & 32'hffffffbf)
                           | (sample_seen ? 32'h00000040 : 32'h00000000);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sample_count <= 32'd0;
            sample_seen <= 1'b0;
        end else if (adc_sample_valid) begin
            sample_count <= sample_count + 32'd1;
            sample_seen <= 1'b1;
        end
    end

    // 写通道状态机
    localparam [1:0] WRITE_IDLE = 2'b00,
                     WRITE_ADDR = 2'b01,
                     WRITE_DATA = 2'b10,
                     WRITE_RESP = 2'b11;
    
    reg [1:0] write_state;
    
    // 写通道寄存器 , 确保数据缓存
    reg [ADDR_WIDTH-1:0] write_addr;
    reg [DATA_WIDTH-1:0] write_data;     // 缓存写数据
    reg [3:0]            write_strb;     // 缓存写字节使能
    reg                  bvalid;
    
    // 读通道状态寄存器
    reg [DATA_WIDTH-1:0] rdata;
    reg rvalid;
    reg [1:0] rresp;
    wire fifo_available = fifo_ready_in && !fifo_clear && s_axis_tvalid;
    // DATA is a destructive read. Pop at AR acceptance, then hold the copied
    // value and response until RREADY. R-channel stalls cannot pop twice.
    assign s_axis_tready = rst_n && fifo_ready_in && !fifo_clear
                        && s_axi_arvalid && s_axi_arready
                        && (s_axi_araddr == 'h28);
    wire [31:0] fifo_status = {27'd0,
        (fifo_available && s_axis_tlast),
        (fifo_drop_count_in != 0),
        (!fifo_ready_in || fifo_clear), capture_enable, !fifo_available};

    // 声明变量
    integer j;
    reg [ADDR_WIDTH-3:0] reg_index;
    reg addr_in_range;
    
    // 输出信号连接
    assign s_axi_awready = (write_state == WRITE_IDLE) || (write_state == WRITE_ADDR);
    assign s_axi_wready  = (write_state == WRITE_IDLE) || (write_state == WRITE_DATA);

    assign s_axi_bvalid  = bvalid;
    assign s_axi_bresp   = bresp;

    // 优化的读通道信号连接 
    assign s_axi_arready = (!rvalid || s_axi_rready);
    assign s_axi_rdata   = rdata;
    assign s_axi_rvalid  = rvalid;
    assign s_axi_rresp   = rresp;

    `pragma protect begin
    task execute_write_operation;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] data;
        input [3:0] strb;
        begin
           write_data_to_reg(addr,data,strb); 
        end
    endtask

    task w_fsm;
       case (write_state)
                WRITE_IDLE: begin
                    if (s_axi_awvalid && s_axi_wvalid) begin
                        // 地址和数据同时到达，直接执行写操作
                        execute_write_operation(s_axi_awaddr, s_axi_wdata, s_axi_wstrb);
                        write_state <= WRITE_RESP;
                        bvalid <= 1'b1;
                    end else if (s_axi_awvalid) begin
                        // 只有地址到达，缓存地址
                        write_addr <= s_axi_awaddr;
                        write_state <= WRITE_DATA;
                    end else if (s_axi_wvalid) begin
                        // 只有数据到达，缓存数据
                        write_data <= s_axi_wdata;
                        write_strb <= s_axi_wstrb;
                        write_state <= WRITE_ADDR;
                    end
                end
                
                WRITE_ADDR: begin
                    // 等待地址，数据已缓存
                    if (s_axi_awvalid) begin
                        // 使用缓存的数据和当前地址执行写操作
                        execute_write_operation(s_axi_awaddr, write_data, write_strb);
                        write_state <= WRITE_RESP;
                        bvalid <= 1'b1;
                    end
                end
                
                WRITE_DATA: begin
                    // 等待数据，地址已缓存
                    if (s_axi_wvalid) begin
                        // 使用缓存的地址和当前数据执行写操作
                        execute_write_operation(write_addr, s_axi_wdata, s_axi_wstrb);
                        write_state <= WRITE_RESP;
                        bvalid <= 1'b1;
                    end
                end
                
                WRITE_RESP: begin
                    // 等待响应被接收
                    if (s_axi_bready) begin
                        bvalid <= 1'b0;
                        write_state <= WRITE_IDLE;
                    end
                    // 关键：在RESP状态下，bvalid必须保持为1直到被接收
                end
                
                default: begin
                    write_state <= WRITE_IDLE;
                    bvalid <= 1'b0;
                end
            endcase
    endtask
`pragma protect end

    // 写通道状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_state <= WRITE_IDLE;
            write_addr  <= {ADDR_WIDTH{1'b0}};
            write_data  <= {DATA_WIDTH{1'b0}};
            write_strb  <= 4'b0000;
            bvalid      <= 1'b0;
            bresp <= 2'b00;
            output_enable_cmd <= 1'b0;
            vref_cmd_q16 <= 32'd0;
            command_error <= 1'b0;
            capture_enable <= 1'b0;
            fifo_clear <= 1'b0;
            fault_clear_cmd <= 1'b0;
            // 初始化寄存器数组, 可以根据实际情况进行修改
            for (j = 0; j < REG_NUM; j = j + 1) begin
                reg_array[j] <= {DATA_WIDTH{1'b0}};
            end
        end else begin
            fifo_clear <= 1'b0;
            fault_clear_cmd <= 1'b0;
            w_fsm;
            // Protection wins over concurrent writes. Clear both old commands so
            // recovery requires a fresh nonzero VREF write followed by OUTPUT_ON.
            if (protection_stop) begin
                output_enable_cmd <= 1'b0;
                vref_cmd_q16 <= 32'd0;
            end
        end
    end


integer i;

task write_data_to_reg;
    input [ADDR_WIDTH-1:0] addr;
    input [DATA_WIDTH-1:0] data;
    input [3:0] strb;
    begin
        bresp <= 2'b00;
        // 写地址以及地址判断，可以根据实际情况进行修改
        reg_index = addr[ADDR_WIDTH-1:2];
        addr_in_range = (reg_index < REG_NUM);
        // 字节写入操作
        // Only 0x80..0xfc is writable scratch space. Telemetry and reserved
        // addresses acknowledge writes without changing measurement state.
        // Live control-status bit9 is the PL RS485 ownership interlock.
        // Reject control writes while remote owns the power stage; diagnostics,
        // capture control and all other GP0 peripherals remain accessible.
        if (control_status_in[9] &&
            ((addr[ADDR_WIDTH-1:2] == 'h10) ||
             (addr[ADDR_WIDTH-1:2] == 'h11) ||
             (addr[ADDR_WIDTH-1:2] == 'h18))) begin
            bresp <= 2'b10;
            command_error <= 1'b1;
        end else if ((addr[ADDR_WIDTH-1:2] == 'h10) && (addr[1:0] != 0)) begin
            bresp <= 2'b10;
            command_error <= 1'b1;
        end else if ((addr[ADDR_WIDTH-1:2] == 'h11) && (addr[1:0] != 0)) begin
            bresp <= 2'b10;
            command_error <= 1'b1;
        end else if ((addr[ADDR_WIDTH-1:2] == 'h18) && (addr[1:0] != 0)) begin
            bresp <= 2'b10;
            command_error <= 1'b1;
        end else if ((addr == 'h40) && strb[0]) begin
            // Fault-interlocked ON; OFF remains writable during any fault.
            if (data[0] && ((vref_cmd_q16 == 0) ||
                           ((control_status_in & 32'h00000188) != 0))) begin
                bresp <= 2'b10;
                command_error <= 1'b1;
            end else begin
                output_enable_cmd <= data[0];
            end
        end else if (addr == 'h44) begin
            merged_vref = vref_cmd_q16;
            for (i = 0; i < 4; i = i + 1)
                if (strb[i]) merged_vref[i*8 +: 8] = data[i*8 +: 8];
            if (!merged_vref[31] && (merged_vref <= VREF_MAX_Q16)) begin
                vref_cmd_q16 <= merged_vref;
                if (merged_vref == 0) output_enable_cmd <= 1'b0;
            end else begin
                bresp <= 2'b10;
                command_error <= 1'b1;
            end
        end else if ((addr == 'h60) && strb[0] && data[0]) begin
            // W1 pulse. Always remove both commands before the PL clears faults.
            output_enable_cmd <= 1'b0;
            vref_cmd_q16 <= 32'd0;
            fault_clear_cmd <= 1'b1;
        end else if ((addr == 'h5c) && strb[0] && data[0]) begin
            command_error <= 1'b0;
        end else if ((addr == 'h2c) && strb[0]) begin
            capture_enable <= data[0];
            fifo_clear <= data[1];
        end else if (addr_in_range && (addr >= 8'h80)) begin
            for (i = 0; i < 4; i = i + 1) begin : byte_write
                 if (strb[i])
                      reg_array[reg_index][i*8 +: 8] <= data[i*8 +: 8];
            end
        end
    end
endtask


    // 优化的读操作处理
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rvalid <= 1'b0;
            rdata  <= {DATA_WIDTH{1'b0}};
            rresp <= 2'b00;
        end else begin
            if (s_axi_arvalid && (!rvalid || s_axi_rready)) begin
                rresp <= 2'b00;
                // 可以在以下情况接收新的读地址：
                // 1. rvalid为0（没有待处理的读数据）
                // 2. rvalid为1但master准备好接收数据
                
                // 检查地址是否在有效范围内并读取数据，可以根据实际情况进行修改
                case (s_axi_araddr[ADDR_WIDTH-1:2])
                    0: rdata <= 32'h41444331; // "ADC1": telemetry interface ID
                    1: rdata <= adc_status;
                    2: rdata <= sample_count;
                    3,4,5,6,18: begin                 // retired raw/V/I/duty
                        rdata <= 32'd0;
                        rresp <= 2'b10;
                    end
                    8: rdata <= fifo_status;           // 0x20
                    9: rdata <= fifo_ready_in ? fifo_level_in : 32'd0;
                    10: begin                         // 0x28: pop one beat
                        if ((s_axi_araddr[1:0] == 2'b00) && fifo_available) begin
                            rdata <= s_axis_tdata;
                            rresp <= (s_axis_tkeep == 4'hf) ? 2'b00 : 2'b10;
                        end else begin
                            rdata <= 32'd0;
                            rresp <= 2'b10;            // SLVERR, no pop
                        end
                    end
                    11: rdata <= {31'd0, capture_enable};
                    12: rdata <= fifo_drop_count_in;
                    13: rdata <= 32'h50343831;         // 0x34: P481: 48/48/32, no status
                    16: rdata <= {31'd0, output_enable_cmd}; // 0x40
                    17: rdata <= vref_cmd_q16;          // 0x44: requested V
                    19: rdata <= control_status_in;     // 0x4c: live output state
                    20: rdata <= vref_active_q16_in;    // 0x50: ramped V
                    21: rdata <= 32'h43545231;          // 0x54: "CTR1", retained control ID
                    22: rdata <= VREF_MAX_Q16;          // 0x58
                    23: rdata <= {31'd0, command_error}; // 0x5c: sticky write error
                    24: rdata <= 32'd0;                 // 0x60: clear pulse, reads zero
                    25: rdata <= 32'h464c5431;          // 0x64: FLT1 clear capability
                    default: begin
                        if ((s_axi_araddr >= 8'h80) &&
                            (s_axi_araddr[ADDR_WIDTH-1:2] < REG_NUM))
                            rdata <= reg_array[s_axi_araddr[ADDR_WIDTH-1:2]];
                        else
                            rdata <= 32'd0;
                    end
                endcase
                
                rvalid <= 1'b1;                   // 标记读数据有效
            end else if (rvalid && s_axi_rready) begin
                // 当前读数据被接收，但没有新的读请求
                rvalid <= 1'b0;
            end
        end
    end

// 添加用户逻辑
// ...

// 用户逻辑添加结束

endmodule
