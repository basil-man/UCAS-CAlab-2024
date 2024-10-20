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
    output wire [`A_ID_WID]     arid,   //读请求的 ID 号,取指置为 0；取数置为 1
    output wire [`DATA_WID]     araddr, //读请求的地址
    output wire [`A_LEN_WID]    arlen,  //读请求控制信号,请求传输的长度 (数据传输拍数),固定为 0
    output wire [`A_SIZE_WID]   arsize, //读请求控制信号,请求传输的大小 (数据传输每拍的字节数)
    output wire [`A_BURST_WID]  arburst,//读请求控制信号,传输类型，固定为 0b01
    output wire [`A_LOCK_WID]   arlock, //读请求控制信号,原子锁,固定为 0
    output wire [`A_CACHE_WID]  arcache,//读请求控制信号,CATHE属性,固定为 0
    output wire [`A_PROT_WID]   arprot, //读请求控制信号,保护属性,固定为 0
    output wire                 arvalid,//读请求地址握手信号，读请求地址有效
    input  wire                 arready,//读请求地址握手信号，slave 端准备好接收地址传输
    //读响应通道,（以 r 开头）
    input  wire [`A_ID_WID]     rid,    //读请求的 ID 号，同一请求的 rid 应和 arid 一致,0 对应取指；1 对应数据。
    input  wire [`DATA_WID]     rdata,  //读请求的读回数据
    input  wire                 rvalid, //读请求数据握手信号，读请求数据有效
    output wire                 rready, //读请求数据握手信号，master 端准备好接收数据传输
    //写请求通道,（以 aw 开头）
    output wire [`A_ID_WID]     awid,   //写请求的 ID 号,固定为 1
    output wire [`DATA_WID]     awaddr, //写请求的地址
    output wire [`A_LEN_WID]    awlen,  //写请求控制信号,请求传输的长度 (数据传输拍数),固定为 0
    output wire [`A_SIZE_WID]   awsize, //写请求控制信号,请求传输的大小 (数据传输每拍的字节数)
    output wire [`A_BURST_WID]  awburst,//写请求控制信号,传输类型，固定为 0b01
    output wire [`A_LOCK_WID]   awlock, //写请求控制信号,原子锁,固定为 0
    output wire [`A_CACHE_WID]  awcache,//写请求控制信号,CATHE属性,固定为 0
    output wire [`A_PROT_WID]   awprot, //写请求控制信号,保护属性,固定为 0
    output wire                 awvalid,//写请求地址握手信号，写请求地址有效
    input  wire                 awready,//写请求地址握手信号，slave 端准备好接收地址传输
    //写数据通道,（以 w 开头）
    output wire [`A_ID_WID]     wid,    //写请求的 ID 号，固定为 1 
    output wire [`DATA_WID]     wdata,  //写请求的写数据
    output wire [`A_STRB_WID]   wstrb,  //写请求控制信号，字节选通位
    output wire                 wlast,  //写请求控制信号，本次写请求的最后一拍数据的指示信号,固定为 1
    output wire                 wvalid, //写请求数据握手信号，写请求数据有效
    input  wire                 wready, //写请求数据握手信号，slave 端准备好接收数据传输
    //写响应通道,（以 b 开头）
    input  wire                 bvaild, //写请求响应握手信号，写请求响应有效
    output wire                 bready  //写请求响应握手信号，master 端准备好接收写响应
);

endmodule