`include "width.h"
module mycpu_top(
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
        .collect_inst_rd_cnt(collect_inst_rd_cnt)
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
        .collect_inst_rd_cnt(collect_inst_rd_cnt)
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

        .data_sram_rdata(data_sram_rdata),

        .mem_inst_bus(es_mem_inst_bus),
        .es_to_ms_bus(es_to_ms_bus),
        .ms_to_ws_bus(ms_to_ws_bus),

        .ms_except_collect(ms_except_collect), //Forward signal
        .except_flush(wb_ex|ertn_flush),
        .ms_except(ms_except),
        .vaddr(vaddr)
    ) ;

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