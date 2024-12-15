`include "width.h"
module mycpu_top(
    
    input  wire        aclk,
    input  wire        aresetn,
    /*// inst sram interface
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
    wire clk = aclk;
    wire resetn = aresetn;

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
    wire       wb_flush;

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

    wire         inst_sram_req;
    wire [ 3:0]  inst_sram_wstrb;
    wire [31:0]  inst_sram_addr;
    wire [31:0]  inst_sram_wdata;
    wire         inst_sram_wr;
    wire [ 1:0]  inst_sram_size;
    wire [31:0]  inst_sram_rdata;
    wire         inst_sram_addr_ok;
    wire         inst_sram_data_ok;
    wire         data_sram_req;
    wire [ 3:0]  data_sram_wstrb;
    wire [31:0]  data_sram_addr;
    wire [31:0]  data_sram_wdata;
    wire         data_sram_wr;
    wire [ 1:0]  data_sram_size;
    wire         data_sram_addr_ok;
    wire [31:0]  data_sram_rdata;
    wire         data_sram_data_ok;

    wire [`T_VPPN_WID]  s0_vppn;
    wire                s0_va_bit12;
    wire [`T_ASID_WID]  s0_asid;
    wire                s0_found;
    wire [`T_IDX_WID]   s0_index;
    wire [`T_PPN_WID]   s0_ppn;
    wire [`T_PS_WID]    s0_ps;
    wire [`T_plv_WID]   s0_plv;
    wire [`T_MAT_WID]   s0_mat;
    wire                s0_d;
    wire                s0_v;

    wire [`T_VPPN_WID]  s1_vppn;
    wire                s1_va_bit12;
    wire [`T_ASID_WID]  s1_asid;
    wire                s1_found;
    wire [`T_IDX_WID]   s1_index;
    wire [`T_PPN_WID]   s1_ppn;
    wire [`T_PS_WID]    s1_ps;
    wire [`T_plv_WID]   s1_plv;
    wire [`T_MAT_WID]   s1_mat;
    wire                s1_d;
    wire                s1_v;


    wire [ 4:0] invtlb_op;
    wire        invtlb_valid;

    wire [`T_ASID_WID]       csr_asid;
    wire [`T_VPPN_WID]       csr_tlbehi_vppn;
    wire [`T_IDX_WID]        csr_tlbidx_index;

    wire                     tlbsrch_we;
    wire                     tlbsrch_hit;
    wire                     tlbrd_we;
    wire [`T_IDX_WID]        tlbsrch_hit_index;

    wire [`T_IDX_WID]        r_index;
    wire                     r_e;
    wire [`T_PS_WID]         r_ps;
    wire [`T_VPPN_WID]       r_vppn;
    wire [`T_ASID_WID]       r_asid;
    wire                     r_g;

    wire [`T_PPN_WID]        r_ppn0;
    wire [`T_plv_WID]        r_plv0;
    wire [`T_MAT_WID]        r_mat0;
    wire                     r_d0;
    wire                     r_v0;
    wire [`T_PPN_WID]        r_ppn1;
    wire [`T_plv_WID]        r_plv1;
    wire [`T_MAT_WID]        r_mat1;
    wire                     r_d1;
    wire                     r_v1;

    wire [`T_IDX_WID]        w_index;
    wire                     w_e;
    wire [`T_PS_WID]         w_ps;
    wire [`T_VPPN_WID]       w_vppn;
    wire [`T_ASID_WID]       w_asid;
    wire                     w_g;

    wire [`T_PPN_WID]        w_ppn0;
    wire [`T_plv_WID]        w_plv0;
    wire [`T_MAT_WID]        w_mat0;
    wire                     w_d0;
    wire                     w_v0; 
    wire [`T_PPN_WID]        w_ppn1;
    wire [`T_plv_WID]        w_plv1;
    wire [`T_MAT_WID]        w_mat1;
    wire                     w_d1;
    wire                     w_v1;

    wire [31:0]              inst_va;
    wire [31:0]              inst_pa;
    wire [31:0]              data_va;
    wire [31:0]              data_pa;
    wire                     data_cacheable;   

    wire [9:0]               es_asid;

    wire [31:0] csr_crmd_data;
    wire [31:0] csr_dmw0_data;
    wire [31:0] csr_dmw1_data;
    wire [31:0] csr_asid_data;

    wire inst_ex_TLBR,inst_ex_PIx,inst_ex_PPI,inst_ex_PME;
    wire data_ex_TLBR,data_ex_PIx,data_ex_PPI,data_ex_PME;

    wire ms_csr_tlbrd,ws_csr_tlbrd;
    wire [`D2C_CSRC_WID] es_to_ms_csr_collect,ms_to_ws_csr_collect;
    wire [`D2C_CSRC_WID] ws_csr_collect;

    //exp21 ichache

    wire        icache_rd_req;
    wire [ 2:0] icache_rd_type;
    wire [31:0] icache_rd_addr;
    wire        icache_rd_rdy;
    wire        icache_ret_valid;
    wire        icache_ret_last;
    wire [31:0] icache_ret_data;

    //exp22 dcache

    wire        dcache_rd_req;
    wire [ 2:0] dcache_rd_type;
    wire [31:0] dcache_rd_addr;
    wire        dcache_rd_cacheable;
    wire        dcache_rd_rdy;
    wire        dcache_ret_valid;
    wire        dcache_ret_last;
    wire [31:0] dcache_ret_data;

    wire        dcache_wr_req;
    wire [ 2:0] dcache_wr_type;
    wire [31:0] dcache_wr_addr;
    wire        dcache_wr_cacheable;
    wire [ 3:0] dcache_wr_strb;
    wire[127:0] dcache_wr_data;
    wire        dcache_wr_rdy;

    AXI_bridge my_AXIbridge(
        .aclk(clk),
        .aresetn(resetn),

        .icache_rd_req(icache_rd_req),
        .icache_rd_type(icache_rd_type),
        .icache_rd_addr(icache_rd_addr),
        .icache_rd_rdy(icache_rd_rdy),
        .icache_ret_valid(icache_ret_valid),
        .icache_ret_last(icache_ret_last),
        .icache_ret_data(icache_ret_data),

        .dcache_rd_req      (dcache_rd_req      ),
        .dcache_rd_type     (dcache_rd_type     ),
        .dcache_rd_addr     (dcache_rd_addr     ),
        .dcache_rd_rdy      (dcache_rd_rdy      ),
        .dcache_ret_valid   (dcache_ret_valid   ),
        .dcache_ret_last    (dcache_ret_last    ),
        .dcache_ret_data    (dcache_ret_data    ),

        .dcache_wr_req      (dcache_wr_req      ),
        .dcache_wr_type     (dcache_wr_type     ),
        .dcache_wr_addr     (dcache_wr_addr     ),
        .dcache_wr_wstrb    (dcache_wr_wstrb    ),
        .dcache_wr_data     (dcache_wr_data     ),
        .dcache_wr_rdy      (dcache_wr_rdy      ),

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
    wire inst_tlb_map;
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
        .ertn_flush(wb_flush & ~ wb_ex),//ugly trick
        .wb_flush(wb_flush),
        .ex_entry(ex_entry),
        .ertn_entry(ertn_flush ? ertn_entry : (debug_wb_pc + 4'h4)),//ugly trick to reuse ertn 

        .axi_arid(arid),

        .inst_va(inst_va),
        .inst_pa(inst_pa),

        .ex_TLBR(inst_ex_TLBR),
        .ex_PIx(inst_ex_PIx),
        .ex_PPI(inst_ex_PIx),
        .ex_PME(inst_ex_PME),

        .inst_tlb_map(inst_tlb_map),
        .csr_crmd_data(csr_crmd_data),
        .s0_plv(s0_plv),
        .s0_v(s0_v)
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

        .except_flush(wb_flush),
        .collect_inst_rd_cnt(collect_inst_rd_cnt),
        .wb_ex(wb_ex)

    );


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
        .except_flush(wb_flush),
        .ms_except(ms_except),
        .collect_inst_rd_cnt(collect_inst_rd_cnt),
        .wb_ex(wb_ex),

        .s1_va_highbits({s1_vppn,s1_va_bit12}),
        .s1_asid(s1_asid),
        .invtlb_valid(invtlb_valid),
        .invtlb_op(invtlb_op),

        .csr_asid_asid(csr_asid),
        .csr_tlbehi_vppn(csr_tlbehi_vppn),

        .s1_found(s1_found),
        .s1_index(s1_index),

        .ms_csr_tlbrd(ms_csr_tlbrd),
        .ws_csr_tlbrd(ws_csr_tlbrd),

        .ds_to_es_csr_collect(csr_collect),
        .es_to_ms_csr_collect(es_to_ms_csr_collect),

        .es_asid(es_asid),
        .data_va(data_va),
        .data_pa(data_pa),

        .ex_TLBR(data_ex_TLBR),
        .ex_PIx(data_ex_PIx),
        .ex_PPI(data_ex_PPI),
        .ex_PME(data_ex_PME),
        .s1_vppn(s1_vppn),
        .s1_va_bit12(s1_va_bit12),
        .cacheable(data_cacheable)
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
        .except_flush(wb_flush),
        .ms_except(ms_except),
        .vaddr(vaddr),
        .wb_ex(wb_ex),

        .ms_csr_tlbrd(ms_csr_tlbrd),

        .es_to_ms_csr_collect(es_to_ms_csr_collect),
        .ms_to_ws_csr_collect(ms_to_ws_csr_collect)
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
        .wb_flush(wb_flush),
        .wb_ecode(wb_ecode),
        .wb_esubcode(wb_esubcode),
        .wb_pc(wb_pc),
        .vaddr(vaddr),
        .wb_vaddr(wb_vaddr),
        //exp18
        .csr_tlbidx_index(csr_tlbidx_index),
        .tlbrd_we(tlbrd_we),
        .r_index(r_index),
        .w_index(w_index),
        .tlb_we(tlb_we),
        .tlbsrch_we(tlbsrch_we),
        .tlbsrch_hit(tlbsrch_hit),
        .tlbsrch_hit_index(tlbsrch_hit_index),
        .ws_csr_tlbrd(ws_csr_tlbrd),
        .ms_to_ws_csr_collect(ms_to_ws_csr_collect),
        
        .ws_csr_collect(ws_csr_collect),
        .csr_rvalue(csr_rvalue)
    );

    assign {csr_re, csr_num, csr_we, csr_wmask, csr_wvalue} = ws_csr_collect;

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
        .wb_pc     (wb_pc), //写回的返回地址

        .csr_asid        (csr_asid),
        .csr_tlbehi_vppn (csr_tlbehi_vppn),
        .csr_tlbidx_index(csr_tlbidx_index),

        .tlbsrch_we        (tlbsrch_we),
        .tlbsrch_hit       (tlbsrch_hit),
        .tlbsrch_hit_index (tlbsrch_hit_index),
        .tlbrd_we          (tlbrd_we),

        .r_e         (r_e),
        .r_ps        (r_ps),
        .r_vppn      (r_vppn),
        .r_asid      (r_asid),
        .r_g         (r_g),
        .r_ppn0      (r_ppn0),
        .r_plv0      (r_plv0),
        .r_mat0      (r_mat0),
        .r_d0        (r_d0),
        .r_v0        (r_v0),
        .r_ppn1      (r_ppn1),
        .r_plv1      (r_plv1),
        .r_mat1      (r_mat1),
        .r_d1        (r_d1),
        .r_v1        (r_v1),


        .w_e         (w_e),
        .w_ps        (w_ps),
        .w_vppn      (w_vppn),
        .w_asid      (w_asid),
        .w_g         (w_g),
        .w_ppn0      (w_ppn0),
        .w_plv0      (w_plv0),
        .w_mat0      (w_mat0),
        .w_d0        (w_d0),
        .w_v0        (w_v0),
        .w_ppn1      (w_ppn1),
        .w_plv1      (w_plv1),
        .w_mat1      (w_mat1),
        .w_d1        (w_d1),
        .w_v1        (w_v1),

        .csr_crmd_data(csr_crmd_data),
        .csr_dmw0_data(csr_dmw0_data),
        .csr_dmw1_data(csr_dmw1_data),
        .csr_asid_data(csr_asid_data)
    );

    tlb my_tlb(
        .clk        (aclk),
        
        .s0_vppn    (s0_vppn),
        .s0_va_bit12(s0_va_bit12),
        .s0_asid    (s0_asid),
        .s0_found   (s0_found),
        .s0_index   (s0_index),
        .s0_ppn     (s0_ppn),
        .s0_ps      (s0_ps),
        .s0_plv     (s0_plv),
        .s0_mat     (s0_mat),
        .s0_d       (s0_d),
        .s0_v       (s0_v),

        .s1_vppn    (data_va[31:13]),
        .s1_va_bit12(data_va[12]),
        .s1_asid    (s1_asid),
        .s1_found   (s1_found),
        .s1_index   (s1_index),
        .s1_ppn     (s1_ppn),
        .s1_ps      (s1_ps),
        .s1_plv     (s1_plv),
        .s1_mat     (s1_mat),
        .s1_d       (s1_d),
        .s1_v       (s1_v),

        .invtlb_op  (invtlb_op),
        .invtlb_valid(invtlb_valid),
        
        .we         (tlb_we),
        .w_index    (w_index),
        .w_e        (w_e),
        .w_vppn     (w_vppn),
        .w_ps       (w_ps),
        .w_asid     (w_asid),
        .w_g        (w_g),
        .w_ppn0     (w_ppn0),
        .w_plv0     (w_plv0),
        .w_mat0     (w_mat0),
        .w_d0       (w_d0),
        .w_v0       (w_v0),
        .w_ppn1     (w_ppn1),
        .w_plv1     (w_plv1),
        .w_mat1     (w_mat1),
        .w_d1       (w_d1),
        .w_v1       (w_v1),

        .r_index    (r_index),
        .r_e        (r_e),
        .r_vppn     (r_vppn),
        .r_ps       (r_ps),
        .r_asid     (r_asid),
        .r_g        (r_g),

        .r_ppn0     (r_ppn0),
        .r_plv0     (r_plv0),
        .r_mat0     (r_mat0),
        .r_d0       (r_d0),
        .r_v0       (r_v0),

        .r_ppn1     (r_ppn1),
        .r_plv1     (r_plv1),
        .r_mat1     (r_mat1),
        .r_d1       (r_d1),
        .r_v1       (r_v1)
    );

    MMU inst_MMU(
        .MMU_mode(0),
        .input_asid(),
        //va & pa
        .va(inst_va),
        .pa(inst_pa),

        //tlb interface
        .s_vppn(s0_vppn),
        .s_va_bit12(s0_va_bit12),
        .s_asid(s0_asid),
        .s_found(s0_found),
        .s_ppn(s0_ppn),
        .s_ps(s0_ps),
        .s_plv(s0_plv),
        .s_mat(s0_mat),
        .s_d(s0_d),
        .s_v(s0_v),

        //from csr
        .csr_crmd_data(csr_crmd_data),
        .csr_dmw0_data(csr_dmw0_data),
        .csr_dmw1_data(csr_dmw1_data),
        .csr_asid_data(csr_asid_data),

        //exception  
        .ex_TLBR(inst_ex_TLBR),
        .ex_PIx(inst_ex_PIx),
        .ex_PPI(inst_ex_PIx),
        .ex_PME(inst_ex_PME),
        .tlb_map(inst_tlb_map)
    );

    MMU data_MMU(
        .MMU_mode(1),
        .input_asid(es_asid),
        //va & pa
        .va(data_va),
        .pa(data_pa),
        .cacheable(data_cacheable),

        //tlb interface
        .s_vppn(),
        .s_va_bit12(),
        .s_asid(s1_asid),
        .s_found(s1_found),
        .s_ppn(s1_ppn),
        .s_ps(s1_ps),
        .s_plv(s1_plv),
        .s_mat(s1_mat),
        .s_d(s1_d),
        .s_v(s1_v),

        //from csr
        .csr_crmd_data(csr_crmd_data),
        .csr_dmw0_data(csr_dmw0_data),
        .csr_dmw1_data(csr_dmw1_data),
        .csr_asid_data(csr_asid_data),

        //exception  
        .ex_TLBR(data_ex_TLBR),
        .ex_PIx(data_ex_PIx),
        .ex_PPI(data_ex_PPI),
        .ex_PME(data_ex_PME),
        .tlb_map()
    );

    cache icache(
        .clk(aclk),
        .resetn(aresetn),

        .valid      (inst_sram_req),
        .op         (1'b0),

        .index      (inst_sram_addr[11:4]),
        .tag        (inst_sram_addr[31:12]),
        .offset     (inst_sram_addr[3:0]),
        .wstrb      (inst_sram_wstrb),
        .wdata      (inst_sram_wdata),
        .addr_ok    (inst_sram_addr_ok),
        .data_ok    (inst_sram_data_ok),
        .rdata      (inst_sram_rdata),

        .rd_req     (icache_rd_req),
        .rd_type    (icache_rd_type),
        .rd_addr    (icache_rd_addr),
        .rd_rdy     (icache_rd_rdy),
        .ret_valid  (icache_ret_valid),
        .ret_last   ({1'b0,icache_ret_last}),
        .ret_data   (icache_ret_data),

        .cacheable  (1'b0) //temporary set to 0 to test uncacheable situation
    );


    cache dcache(
        .clk(aclk),
        .resetn(aresetn),

        .valid      (data_sram_req),
        .op         (data_sram_wr),

        .index      (data_sram_addr[11:4]),
        .tag        (data_sram_addr[31:12]),
        .offset     (data_sram_addr[3:0]),
        .wstrb      (data_sram_wstrb),
        .wdata      (data_sram_wdata),
        .addr_ok    (data_sram_addr_ok),
        .data_ok    (data_sram_data_ok),
        .rdata      (data_sram_rdata),

        .rd_req     (dcache_rd_req),
        .rd_type    (dcache_rd_type),
        .rd_addr    (dcache_rd_addr),
        // .rd_cacheable(dcache_rd_cacheable),
        .rd_rdy     (dcache_rd_rdy),
        .ret_valid  (dcache_ret_valid),
        .ret_last   ({1'b0,dcache_ret_last}),
        .ret_data   (dcache_ret_data),

        .wr_req     (dcache_wr_req),
        .wr_type    (dcache_wr_type),
        .wr_addr    (dcache_wr_addr),
        .wr_data    (dcache_wr_data),
        .wr_wstrb   (dcache_wr_strb),
        .wr_cacheable(dcache_wr_cacheable),
        .wr_rdy     (dcache_wr_rdy),

        .cacheable  (data_cacheable)

    );
endmodule