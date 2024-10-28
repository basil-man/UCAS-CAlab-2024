`include "width.h"


module AXI_bridge(
    input  wire        aclk,
    input  wire        aresetn,

    // inst sram 
    input  wire         inst_sram_req,      //请求信号，为 1 时有读写请求，为 0 时无读写请求。
    input  wire [ 3:0]  inst_sram_wstrb,    //该次写请求的字节写使能。
    input  wire [31:0]  inst_sram_addr,     //该次请求的地址
    input  wire [31:0]  inst_sram_wdata,    //该次写请求的写数据
    input  wire         inst_sram_wr,       //为 1 表示该次是写请求，为 0 表示该次是读请求。
    input  wire [ 1:0]  inst_sram_size,     //该次请求传输的字节数，0: 1 byte；1: 2 bytes；2: 4 bytes。
    output wire [31:0]  inst_sram_rdata,    //该次请求返回的读数据。
    output wire         inst_sram_addr_ok,  //该次请求的地址传输 OK，读：地址被接收；写：地址和数据被接收
    output wire         inst_sram_data_ok,  //该次请求的数据传输 OK，读：数据返回；写：数据写入完成。
    // data sram 
    input  wire        data_sram_req,
    input  wire [ 3:0] data_sram_wstrb,
    input  wire [31:0] data_sram_addr,
    input  wire [31:0] data_sram_wdata,
    input  wire        data_sram_wr,
    input  wire [ 1:0] data_sram_size,
    output wire        data_sram_addr_ok,
    output wire [31:0] data_sram_rdata,
    output wire        data_sram_data_ok,

    //AXI
    //读请求通道,（以 ar 开头）
    output reg  [`A_ID_WID]     arid,   //读请求的 ID 号,取指置为 0；取数置为 1
    output reg  [`DATA_WID]     araddr, //读请求的地址
    output wire  [`A_LEN_WID]   arlen,  //读请求控制信号,请求传输的长度 (数据传输拍数),固定为 0
    output reg   [`A_SIZE_WID]  arsize, //读请求控制信号,请求传输的大小 (数据传输每拍的字节数)
    output wire  [`A_BURST_WID] arburst,//读请求控制信号,传输类型，固定为 0b01
    output wire  [`A_LOCK_WID]  arlock, //读请求控制信号,原子锁,固定为 0
    output wire  [`A_CACHE_WID] arcache,//读请求控制信号,CATHE属性,固定为 0
    output wire  [`A_PROT_WID]  arprot, //读请求控制信号,保护属性,固定为 0
    output wire                 arvalid,//读请求地址握手信号，读请求地址有效
    input  wire                 arready,//读请求地址握手信号，slave 端准备好接收地址传输
    //读响应通道,（以 r 开头）
    input  wire [`A_ID_WID]     rid,    //读请求的 ID 号，同一请求的 rid 应和 arid 一致,0 对应取指；1 对应数据。
    input  wire [`DATA_WID]     rdata,  //读请求的读回数据
    input  wire [`A_RESP_WID]   rresp,  //读请求控制信号，本次读请求是否成功完成(可忽略)
    input  wire                 rlast,  //读请求控制信号，本次读请求的最后一拍数据的指示信号(可忽略)
    input  wire                 rvalid, //读请求数据握手信号，读请求数据有效
    output wire                 rready, //读请求数据握手信号，master 端准备好接收数据传输
    //写请求通道,（以 aw 开头）
    output wire [`A_ID_WID]     awid,   //写请求的 ID 号,固定为 1
    output reg  [`DATA_WID]     awaddr, //写请求的地址
    output wire [`A_LEN_WID]    awlen,  //写请求控制信号,请求传输的长度 (数据传输拍数),固定为 0
    output reg  [`A_SIZE_WID]   awsize, //写请求控制信号,请求传输的大小 (数据传输每拍的字节数)
    output wire [`A_BURST_WID]  awburst,//写请求控制信号,传输类型，固定为 0b01
    output wire [`A_LOCK_WID]   awlock, //写请求控制信号,原子锁,固定为 0
    output wire [`A_CACHE_WID]  awcache,//写请求控制信号,CATHE属性,固定为 0
    output wire [`A_PROT_WID]   awprot, //写请求控制信号,保护属性,固定为 0
    output wire                 awvalid,//写请求地址握手信号，写请求地址有效
    input  wire                 awready,//写请求地址握手信号，slave 端准备好接收地址传输
    //写数据通道,（以 w 开头）
    output wire [`A_ID_WID]     wid,    //写请求的 ID 号，固定为 1 
    output reg  [`DATA_WID]     wdata,  //写请求的写数据
    output reg  [`A_STRB_WID]   wstrb,  //写请求控制信号，字节选通位
    output wire                 wlast,  //写请求控制信号，本次写请求的最后一拍数据的指示信号,固定为 1
    output wire                 wvalid, //写请求数据握手信号，写请求数据有效
    input  wire                 wready, //写请求数据握手信号，slave 端准备好接收数据传输
    //写响应通道,（以 b 开头）
    input  wire [`A_ID_WID]     bid,    //写请求的 ID 号，同一请求的 bid 应和 awid 一致(可忽略)
    input  wire [`A_RESP_WID]   bresp,  //写请求控制信号，本次写请求是否成功完成(可忽略)
    input  wire                 bvalid, //写请求响应握手信号，写请求响应有效
    output wire                 bready  //写请求响应握手信号，master 端准备好接收写响应
);
    `define IDLE        3'b001 //空闲状态
    `define START       3'b010
    `define FINISH      3'b100

    `define W_IDLE      5'b00001 //空闲状态(写请求&写数据通道)
    `define W_START     5'b00010 //开始状态(写请求&写数据通道)
    `define W_ADDR      5'b00100 //地址传输状态(写请求&写数据通道)
    `define W_DATA      5'b01000 //数据传输状态(写请求&写数据通道)
    `define W_FINISH    5'b10000 //结束状态(写请求&写数据通道)

    //读请求通道
    reg [2:0] ar_state;
    reg [2:0] ar_next_state;

    wire ar_state_idle   = (ar_state == `IDLE);
    wire ar_state_start  = (ar_state == `START);
    wire ar_state_finish = (ar_state == `FINISH);

    wire ar_block;

    //读响应通道
    reg [2:0] r_state;
    reg [2:0] r_next_state;
    reg [1:0] r_cnt;

    wire r_state_idle   = (r_state == `IDLE);
    wire r_state_start  = (r_state == `START);
    wire r_state_finish = (r_state == `FINISH);


    //写请求&写数据通道
    reg [4:0] w_state;
    reg [4:0] w_next_state;

    wire w_state_idle   = (w_state == `W_IDLE);
    wire w_state_start  = (w_state == `W_START);
    wire w_state_addr   = (w_state == `W_ADDR);
    wire w_state_data   = (w_state == `W_DATA);
    wire w_state_finish = (w_state == `W_FINISH);

    //写响应通道
    reg  [2:0] b_state;
    reg  [2:0] b_next_state;
    reg  [1:0] aw_cnt,w_cnt;

    wire b_state_idle   = (b_state == `IDLE);
    wire b_state_start  = (b_state == `START);
    wire b_state_finish = (b_state == `FINISH);
    
    //rdata buffer
    reg [31:0] rdata_buffer [1:0];    
    reg [`A_ID_WID] rid_buffer;
    wire is_data_r,is_data_w,is_data_r_buffer,is_data_w_buffer;

    reg debug_catch_defualt;

    //////////////////////////////////////////////////////////////////////////
    //读请求通道状态机
    //////////////////////////////////////////////////////////////////////////

    //读请求通道状态机时序逻辑
    always @(posedge aclk) begin
        if (!aresetn) begin
            ar_state <= `IDLE;
        end else begin
            ar_state <= ar_next_state;
        end
    end

    //读请求通道状态机next_state逻辑
    always @(*)begin
        case(ar_state)
            `IDLE:begin
                if(~aresetn | ar_block)
                    ar_next_state = `IDLE;
                else if(inst_sram_req & ~ inst_sram_wr | data_sram_req & ~data_sram_wr) 
                    ar_next_state = `START;
                else 
                    ar_next_state = `IDLE;
            end
            `START:begin
                if(arready & arvalid)
                    ar_next_state = `FINISH;
                else 
                    ar_next_state = `START;
            end
            `FINISH:begin
                ar_next_state = `IDLE;
            end
            default:begin
                debug_catch_defualt = 1;
                ar_next_state = `IDLE;
            end
        endcase
    end

    assign ar_block = (araddr == awaddr) & ~w_state_idle & ~b_state_finish;

    //////////////////////////////////////////////////////////////////////////
    //读响应通道状态机
    //////////////////////////////////////////////////////////////////////////

    //读响应通道状态机时序逻辑
    always @(posedge aclk) begin
        if (!aresetn) begin
            r_state <= `IDLE;
        end else begin
            r_state <= r_next_state;
        end
    end

    //读相应通道状态机next_state逻辑
    always @(*)begin
        case(r_state)
            `IDLE:begin
                debug_catch_defualt = 0;
                if(~aresetn)
                    r_next_state = `IDLE;
                else if(arvalid & arready | (|r_cnt))
                    r_next_state = `START;
                else 
                    r_next_state = `IDLE;
            end
            `START:begin
                if(rready & rvalid)
                    r_next_state = `FINISH;
                else 
                    r_next_state = `START;
            end
            `FINISH:begin
                r_next_state = `IDLE;
            end
            default:begin
                debug_catch_defualt = 1;
                r_next_state = `IDLE;
            end
        endcase
    end


    //////////////////////////////////////////////////////////////////////////
    //写请求&写数据通道状态机
    //////////////////////////////////////////////////////////////////////////

    //写请求&写数据通道状态机时序逻辑
    always @(posedge aclk) begin
        if (!aresetn) begin
            w_state <= `W_IDLE;
        end else begin
            w_state <= w_next_state;
        end
    end

    //写请求&写数据通道状态机next_state逻辑
    always @(*) begin
        case(w_state)
            `W_IDLE:begin
                if(~aresetn)
                    w_next_state = `W_IDLE;
                else if(data_sram_req & data_sram_wr)
                    w_next_state = `W_START;
                else 
                    w_next_state = `W_IDLE;
            end
            `W_START:begin
                if(awready & awvalid & wready & wvalid | (|aw_cnt) & (|w_cnt))
                    w_next_state = `W_FINISH;
                else if(awready & awvalid | (|aw_cnt))
                    w_next_state = `W_ADDR;
                else if(wready & wvalid  | (|w_cnt))
                    w_next_state = `W_DATA;
                else 
                    w_next_state = `W_START;
            end
            `W_ADDR:begin
                if(wready & wvalid)
                    w_next_state = `W_DATA;
                else 
                    w_next_state = `W_ADDR;
            end
            `W_DATA:begin
                if(awready & awvalid)
                    w_next_state = `W_FINISH;
                else 
                    w_next_state = `W_DATA;
            end
            `W_FINISH:begin
                if(bready & bvalid)
                    w_next_state = `W_IDLE;
                else
                    w_next_state = `W_FINISH;
            end
            default:begin
                debug_catch_defualt = 1;
                w_next_state = `W_IDLE;
            end
        endcase
    end
    

    //////////////////////////////////////////////////////////////////////////
    //写响应通道状态机
    //////////////////////////////////////////////////////////////////////////

    //写响应通道状态机时序逻辑
    always @(posedge aclk) begin
        if (!aresetn) begin
            b_state <= `IDLE;
        end else begin
            b_state <= b_next_state;
        end
    end

    //写相应通道状态机next_state逻辑
    always @(*)begin
        case(b_state)
            `IDLE:begin
                if(~aresetn)
                    b_next_state = `IDLE;
                else if(bready)
                    b_next_state = `START;
                else 
                    b_next_state = `IDLE;
            end
            `START:begin
                if(bready & bvalid)
                    b_next_state = `FINISH;
                else 
                    b_next_state = `START;
            end
            `FINISH:begin
                b_next_state = `IDLE;
            end
            default:begin
                debug_catch_defualt = 1;
                b_next_state = `IDLE;
            end
        endcase
    end

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////读请求通道////////////////////////////
    
    //为固定值的信号赋值
    assign arlen    = 'b0;
    assign arburst  = 2'b01;
    assign arlock   = 'b0;
    assign arcache  = 'b0;
    assign arprot   = 'b0;

    //读请求通道信号逻辑
    assign arvalid  = ar_state_start;

    always @(posedge aclk)begin
        if(~aresetn)begin
            {arid,araddr,arsize} <= 'b0;
        end else if(ar_state_idle)begin
            if(inst_sram_req & ~inst_sram_wr)begin
                arid   <= 4'b0;
                araddr <= inst_sram_addr;
                arsize <={inst_sram_size,1'b0};
            end else if(data_sram_req & ~data_sram_wr)begin
                arid   <= 4'b1;
                araddr <= data_sram_addr;
                arsize <=(|data_sram_size) ? {data_sram_size,1'b0} : 3'b1;
            end
        end
    end

    ////////////////////////////读响应通道////////////////////////////

    //读响应通道信号逻辑
    assign rready = r_state_start;

    //读响应通道计数器
    always @(posedge aclk) begin
        if(~aresetn)
            r_cnt <= 2'b0;
        else if(arvalid & arready & rvalid & rready)
            r_cnt <= r_cnt;
        else if(arvalid & arready)
            r_cnt <= r_cnt + 2'b1;
        else if(rvalid & rready)
            r_cnt <= r_cnt - 2'b1;
    end

    ////////////////////////////写请求&写数据通道////////////////////////////

    //为固定值的信号赋值
    assign awid    = 'b1;
    assign awlen   = 'b0;
    assign awburst = 2'b01;
    assign awlock  = 'b0;
    assign awcache = 'b0;
    assign awprot  = 'b0;
    assign wid     = 'b1;
    assign wlast   = 'b1;

    //写请求&写数据通道信号逻辑
    assign awvalid = w_state_start | w_state_data;
    assign wvalid  = w_state_start | w_state_addr;

    always @(posedge aclk)begin
        if(~aresetn)begin
            {awaddr,awsize} <= 'b0;
        end else if(w_state_idle)begin
            if(data_sram_wr)begin
                awaddr <= data_sram_addr;
                awsize <= (|data_sram_size) ? {data_sram_size,1'b0} : 3'b1;
            end else begin
                awaddr <= inst_sram_addr;
                awsize <= {inst_sram_size,1'b0};
            end
        end
    end

    always @(posedge aclk) begin
        if(~aresetn)begin
            {wdata,wstrb}   <= 'b0;
        end else if (w_state_idle)begin
            wstrb <= data_sram_wstrb;
            wdata <= data_sram_wdata;
        end
    end

    ////////////////////////////写响应通道////////////////////////////

    assign bid = 1'b1;

    //写响应通道信号逻辑
    assign bready = w_state_finish;

    //写响应通道计数器
    always @(posedge aclk) begin
        if(~aresetn)
            aw_cnt <= 2'b0;
        else if(awvalid & awready & bvalid & bready)
            aw_cnt <= aw_cnt;
        else if(awvalid & awready)
            aw_cnt <= aw_cnt + 2'b1;
        else if(bvalid & bready)
            aw_cnt <= aw_cnt - 2'b1;
    end

    always @(posedge aclk) begin
        if(~aresetn)
            w_cnt <= 2'b0;
        else if(wvalid & wready & bvalid & bready)
            w_cnt <= w_cnt;
        else if(wvalid & wready)
            w_cnt <= w_cnt + 2'b1;
        else if(bvalid & bready)
            w_cnt <= w_cnt - 2'b1;
    end

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //rdata buffer

    always @(posedge aclk) begin
        if(~aresetn)
            {rdata_buffer[0],rdata_buffer[1]} <= 64'b0;
        else if(rvalid & rready)
            rdata_buffer[rid] <= rdata;
    end

    always @(posedge aclk) begin
        if(~aresetn)
            rid_buffer <= 'b0;
        else if(rvalid & rready)
            rid_buffer <= rid;
    end

    //interface with sram
    assign is_data_r = arid[0];
    assign is_data_w = awid[0];
    assign is_data_r_buffer = rid_buffer[0];
    assign is_data_w_buffer = bid[0];

    assign inst_sram_rdata = rdata_buffer[0];
    assign inst_sram_addr_ok = ~is_data_r & arvalid & arready | ~is_data_w & awvalid & awready;
    assign inst_sram_data_ok = ~is_data_r_buffer & r_state_finish | ~is_data_w_buffer & bvalid & bready;

    assign data_sram_rdata = rdata_buffer[1];
    assign data_sram_addr_ok = is_data_r & arvalid & arready | is_data_w & awvalid & awready; 
    assign data_sram_data_ok = is_data_r_buffer & r_state_finish | is_data_w_buffer & bvalid & bready;

endmodule