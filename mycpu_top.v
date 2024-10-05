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
    wire [63:0] fs_to_ds_bus;
    wire [154:0] ds_to_es_bus;

    wire [7:0] ds_mem_inst_bus;
    wire [4:0] es_mem_inst_bus;


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
        .fs_to_ds_bus(fs_to_ds_bus)
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
        .es_rf_collect(es_rf_collect)
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
        
        .data_sram_en(data_sram_en),
        .data_sram_we(data_sram_we),
        .data_sram_addr(data_sram_addr),
        .data_sram_wdata(data_sram_wdata),
        
        .es_mem_inst_bus(es_mem_inst_bus)
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

        .mem_inst_bus(es_mem_inst_bus)
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

        .ws_rf_collect(ws_rf_collect)
    );
endmodule