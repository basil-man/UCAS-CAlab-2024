module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire        inst_sram_en,
    output wire [ 3:0] inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire        data_sram_en,
    output wire [ 3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
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

    wire [38:0] es_rf_collect;
    wire [37:0] ms_rf_collect;
    wire [37:0] ws_rf_collect;

    wire [32:0] br_collect;
    wire [64:0] fs_to_ds_bus;
    wire [195:0] ds_to_es_bus; // from 155bit -> 196bit (add from_ds_except, inst_rdcnt**, csr_rvalue, csr_re)
    wire [6:0] es_to_ms_bus; // new
    wire [6:0] ms_to_ws_bus; // new

    wire [7:0] ds_mem_inst_bus;
    wire [4:0] es_mem_inst_bus;
    wire       ertn_flush;
    wire       wb_ex;

    //csr interface
    wire csr_re, csr_we;
    wire [13:0] csr_num;
    wire [31:0] csr_wmask;
    wire [31:0] csr_wvalue;
    wire [79:0] csr_collect;
    wire [31:0] csr_rvalue;
    wire [31:0] ex_entry;
    wire [31:0] ertn_entry;
    wire [31:0] wb_pc;
    wire [ 5:0] wb_ecode;
    wire [ 8:0] wb_esubcode;
    wire has_int;
    wire [6:0] ms_except;


    IFreg my_ifReg(
        .clk(clk),
        .resetn(resetn),

        .inst_sram_en(inst_sram_en),
        .inst_sram_we(inst_sram_we),
        .inst_sram_addr(inst_sram_addr),
        .inst_sram_wdata(inst_sram_wdata),
        .inst_sram_rdata(inst_sram_rdata),
        
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

        .except_flush(wb_ex|ertn_flush)
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
        
        .data_sram_en(data_sram_en),
        .data_sram_we(data_sram_we),
        .data_sram_addr(data_sram_addr),
        .data_sram_wdata(data_sram_wdata),
        
        .es_mem_inst_bus(es_mem_inst_bus),
        .es_to_ms_bus(es_to_ms_bus),

        .except_flush(wb_ex|ertn_flush),
        .ms_except(ms_except)
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

        .except_flush(wb_ex|ertn_flush),
        .ms_except(ms_except)
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
        .wb_pc(wb_pc)
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
        .wb_vaddr  (0) ,//来自WB阶段的访存地址
        .wb_pc     (wb_pc) //写回的返回地址
    );
endmodule