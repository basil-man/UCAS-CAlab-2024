`include "width.h"
module mycpu_top(
    /*
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire         inst_sram_req,
    output wire [ 3:0]  inst_sram_wstrb,
    output wire [31:0]  inst_sram_addr,
    output wire [31:0]  inst_sram_wdata,
    output wire         inst_sram_wr,
    output wire [ 1:0]  inst_sram_size,
    input  wire [31:0]  inst_sram_rdata,
    input  wire         inst_sram_addr_ok,
    input  wire         inst_sram_data_ok,
    // data sram interface
    output wire        data_sram_req,
    output wire [ 3:0] data_sram_wstrb,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    output wire        data_sram_wr,
    output wire [ 1:0] data_sram_size,
    input  wire        data_sram_addr_ok,
    input  wire [31:0] data_sram_rdata,
    input  wire        data_sram_data_ok,
    */
    //注释掉以上代码，将下面的代码取消注释，即可转换为AXI接口
    
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
    input  wire [`A_RESP_WID]   rresp,  //读请求控制信号，本次读请求是否成功完成(可忽略)
    input  wire                 rlast,  //读请求控制信号，本次读请求的最后一拍数据的指示信号
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
    input  wire [`A_ID_WID]     bid,    //写请求的 ID 号，同一请求的 bid 应和 awid 一致(可忽略)
    input  wire [`A_RESP_WID]   bresp,  //写请求控制信号，本次写请求是否成功完成(可忽略)
    input  wire                 bvalid, //写请求响应握手信号，写请求响应有效
    output wire                 bready,  //写请求响应握手信号，master 端准备好接收写响应
    
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
    wire        ds_allowin;
    wire        es_allowin;
    wire        ms_allowin;
    wire        ws_allowin;

    wire        fs_to_ds_valid;
    wire        ds_to_es_valid;
    wire        es_to_ms_valid;
    wire        ms_to_ws_valid;

    wire [31:0] es_pc;
    wire [31:0] ms_pc;

    wire [`E_RFC_WID] es_rf_collect;
    wire [`M_RFC_WID] ms_rf_collect;
    wire [`W_RFC_WID] ws_rf_collect;

    wire [`D2F_BRC_WID] br_collect;
    wire [`F2D_WID] fs_to_ds_bus;
    wire [`D2E_WID] ds_to_es_bus; // from 155bit -> 196bit (add from_ds_except, inst_rdcnt**, csr_rvalue, csr_re)
    wire [`E2M_WID] es_to_ms_bus; // new
    wire [`M2W_WID] ms_to_ws_bus; // new

    wire [`D2E_MINST_WID] ds_mem_inst_bus;
    wire [`E2M_MINST_WID] es_mem_inst_bus;
    wire       ertn_flush;
    wire       wb_ex;

    //csr interface
    wire csr_re, csr_we;
    wire [`D2C_CSRNUM_WID] csr_num;
    wire [`D2C_CSRWMASK_WID] csr_wmask;
    wire [`D2C_CSRWVAL_WID] csr_wvalue;
    wire [`D2C_CSRC_WID] csr_collect;
    wire [31:0] csr_rvalue;
    wire [31:0] ex_entry;
    wire [31:0] ertn_entry;
    wire [31:0] wb_pc;
    wire [`W2C_ECODE_WID] wb_ecode;
    wire [`W2C_ESUBCODE_WID] wb_esubcode;
    wire has_int;
    wire [`E2M_EXCEPT_WID] ms_except;
    wire [31:0] vaddr;
    wire [31:0] wb_vaddr;
    wire [`D2E_RDCNT_WID] collect_inst_rd_cnt;
    wire [`E_EXCEPT_WID] es_except_collect;
    wire [`M_EXCEPT_WID] ms_except_collect;

    AXI_bridge my_AXIbridge(
        .aclk(clk),
        .aresetn(resetn),

        .inst_sram_req(inst_sram_req),
        .inst_sram_wstrb(inst_sram_wstrb),
        .inst_sram_addr(inst_sram_addr),
        .inst_sram_wdata(inst_sram_wdata),
        .inst_sram_wr(inst_sram_wr),
        .inst_sram_size(inst_sram_size),
        .inst_sram_rdata(inst_sram_rdata),
        .inst_sram_addr_ok(inst_sram_addr_ok),
        .inst_sram_data_ok(inst_sram_data_ok),

        .data_sram_req(data_sram_req),
        .data_sram_wstrb(data_sram_wstrb),
        .data_sram_addr(data_sram_addr),
        .data_sram_wdata(data_sram_wdata),
        .data_sram_wr(data_sram_wr),
        .data_sram_size(data_sram_size),
        .data_sram_addr_ok(data_sram_addr_ok),
        .data_sram_rdata(data_sram_rdata),
        .data_sram_data_ok(data_sram_data_ok),

        .arid(arid),
        .araddr(araddr),
        .arlen(arlen),
        .arsize(arsize),
        .arburst(arburst),
        .arlock(arlock),
        .arcache(arcache),
        .arprot(arprot),
        .arvalid(arvalid),
        .arready(arready),

        .rid(rid),
        .rdata(rdata),
        .rresp(rresp),
        .rlast(rlast),
        .rvalid(rvalid),
        .rready(rready),

        .awid(awid),
        .awaddr(awaddr),
        .awlen(awlen),
        .awsize(awsize),
        .awburst(awburst),
        .awlock(awlock),
        .awcache(awcache),
        .awprot(awprot),
        .awvalid(awvalid),
        .awready(awready),

        .wid(wid),
        .wdata(wdata),
        .wstrb(wstrb),
        .wlast(wlast),
        .wvalid(wvalid),
        .wready(wready),

        .bid(bid),
        .bresp(bresp),
        .bvalid(bvalid),
        .bready(bready)
    );

    IFreg my_ifReg(
        .clk(clk),
        .resetn(resetn),

        .inst_sram_req(inst_sram_req),
        .inst_sram_wstrb(inst_sram_wstrb),
        .inst_sram_addr(inst_sram_addr),
        .inst_sram_wdata(inst_sram_wdata),
        .inst_sram_wr(inst_sram_wr),
        .inst_sram_size(inst_sram_size),
        .inst_sram_rdata(inst_sram_rdata),
        .inst_sram_addr_ok(inst_sram_addr_ok),
        .inst_sram_data_ok(inst_sram_data_ok),
        
        .ds_allowin(ds_allowin),
        .br_collect(br_collect),
        .fs_to_ds_valid(fs_to_ds_valid),
        .fs_to_ds_bus(fs_to_ds_bus),

        .wb_ex(wb_ex),
        .ertn_flush(ertn_flush),
        .ex_entry(ex_entry),
        .ertn_entry(ertn_entry)
    );

    IDreg my_idReg(
        .clk(clk),
        .resetn(resetn),

        .ds_allowin(ds_allowin),
        .br_collect(br_collect),
        .fs_to_ds_valid(fs_to_ds_valid),
        .fs_to_ds_bus(fs_to_ds_bus),

        .es_allowin(es_allowin),
        .ds_to_es_valid(ds_to_es_valid),
        .ds_to_es_bus(ds_to_es_bus),
        .mem_inst_bus(ds_mem_inst_bus),

        .ws_rf_collect(ws_rf_collect),
        .ms_rf_collect(ms_rf_collect),
        .es_rf_collect(es_rf_collect),

        .csr_collect(csr_collect),
        .csr_rvalue(csr_rvalue),
        .ds_int_except(has_int),

        .es_except_collect(es_except_collect), //Forward signal
        .ms_except_collect(ms_except_collect), //Forward signal

        .except_flush(wb_ex|ertn_flush),
        .collect_inst_rd_cnt(collect_inst_rd_cnt),
        .wb_ex(wb_ex)
    );
    assign {csr_re, csr_num, csr_we, csr_wmask, csr_wvalue} = csr_collect;

    EXreg my_exReg(
        .clk(clk),
        .resetn(resetn),
        
        .es_allowin(es_allowin),
        .ds_to_es_valid(ds_to_es_valid),
        .ds_to_es_bus(ds_to_es_bus),
        .ds_mem_inst_bus(ds_mem_inst_bus),

        .ms_allowin(ms_allowin),
        .es_rf_collect(es_rf_collect),
        .es_to_ms_valid(es_to_ms_valid),
        .es_pc(es_pc),
        
        .data_sram_req(data_sram_req),
        .data_sram_wstrb(data_sram_wstrb),
        .data_sram_addr(data_sram_addr),
        .data_sram_wdata(data_sram_wdata),
        .data_sram_wr(data_sram_wr),
        .data_sram_size(data_sram_size),
        .data_sram_addr_ok(data_sram_addr_ok),
        
        .es_mem_inst_bus(es_mem_inst_bus),
        .es_to_ms_bus(es_to_ms_bus), //Forward signal

        .es_except_collect(es_except_collect),
        .except_flush(wb_ex|ertn_flush),
        .ms_except(ms_except),
        .collect_inst_rd_cnt(collect_inst_rd_cnt),
        .wb_ex(wb_ex)
    );

    MEMreg my_memReg(
        .clk(clk),
        .resetn(resetn),

        .ms_allowin(ms_allowin),
        .es_rf_collect(es_rf_collect),
        .es_to_ms_valid(es_to_ms_valid),
        .es_pc(es_pc),

        .ws_allowin(ws_allowin),
        .ms_rf_collect(ms_rf_collect),
        .ms_to_ws_valid(ms_to_ws_valid),
        .ms_pc(ms_pc),

        .data_sram_data_ok(data_sram_data_ok),
        .data_sram_rdata(data_sram_rdata),

        .mem_inst_bus(es_mem_inst_bus),
        .es_to_ms_bus(es_to_ms_bus),
        .ms_to_ws_bus(ms_to_ws_bus),

        .ms_except_collect(ms_except_collect), //Forward signal
        .except_flush(wb_ex|ertn_flush),
        .ms_except(ms_except),
        .vaddr(vaddr),
        .wb_ex(wb_ex)
    );

    WBreg my_wbReg(
        .clk(clk),
        .resetn(resetn),

        .ws_allowin(ws_allowin),
        .ms_rf_collect(ms_rf_collect),
        .ms_to_ws_valid(ms_to_ws_valid),
        .ms_pc(ms_pc),

        .debug_wb_pc(debug_wb_pc),
        .debug_wb_rf_we(debug_wb_rf_we),
        .debug_wb_rf_wnum(debug_wb_rf_wnum),
        .debug_wb_rf_wdata(debug_wb_rf_wdata),

        .ws_rf_collect(ws_rf_collect),
        .ms_to_ws_bus(ms_to_ws_bus),

        .ertn_flush(ertn_flush),
        .wb_ex(wb_ex),
        .wb_ecode(wb_ecode),
        .wb_esubcode(wb_esubcode),
        .wb_pc(wb_pc),
        .vaddr(vaddr),
        .wb_vaddr(wb_vaddr)
    );

    csr my_csr(
        .clk       (clk),
        .reset     (~resetn),

        .csr_re    (csr_re),
        .csr_num   (csr_num),
        .csr_rvalue(csr_rvalue),
        .csr_we    (csr_we),
        .csr_wmask (csr_wmask),
        .csr_wvalue(csr_wvalue),

        .ex_entry  (ex_entry), //送往pre-IF的异常入口地址
        .ertn_entry(ertn_entry), //送往pre-IF的返回入口地址
        .has_int   (has_int), //送往ID阶段的中断有效信号
        .ertn_flush(ertn_flush), //来自WB阶段的ertn指令执行有效信号
        .wb_ex     (wb_ex), //来自WB阶段的异常处理触发信号
        .wb_ecode  (wb_ecode), //来自WB阶段的异常类型
        .wb_esubcode(wb_esubcode),//来自WB阶段的异常类型辅助码
        .wb_vaddr  (wb_vaddr) ,//来自WB阶段的访存地址
        .wb_pc     (wb_pc) //写回的返回地址
    );
endmodule