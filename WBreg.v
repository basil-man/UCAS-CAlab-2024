`include "width.h"
`include "csr.vh"

module WBreg(
    input  wire        clk,
    input  wire        resetn,
    // mem and ws state interface
    output wire        ws_allowin,
    input  wire [`M_RFC_WID] ms_rf_collect, // {ms_rf_we, ms_rf_waddr, ms_rf_wdata}
    input  wire        ms_to_ws_valid,
    input  wire [31:0] ms_pc,    
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,
    // id and ws state interface
    output wire [`W_RFC_WID] ws_rf_collect,  // {ws_rf_we, ws_rf_waddr, ws_rf_wdata}
    input  wire [`M2W_WID] ms_to_ws_bus, // new
    // wb-csr interface
    output wire ertn_flush, //来自WB阶段的ertn指令执行有效信号
    output wire wb_ex     , //来自WB阶段的异常处理触发信号
    output wire wb_flush , //来自WB阶段的flush信号
    output wire [`W2C_ECODE_WID] wb_ecode  , //来自WB阶段的异常类型
    output wire [`W2C_ESUBCODE_WID] wb_esubcode,//来自WB阶段的异常类型辅助码
    output wire [31:0] wb_pc,       //写回的返回地址
    input wire [31:0] vaddr,
    output reg [31:0] wb_vaddr,
    //tlb related in exp 18
    input  wire  [ 3:0] csr_tlbidx_index, // from csr
    // tlbrd
    output wire         tlbrd_we, // to csr
    output wire  [ 3:0] r_index,  // to tlb
    // tlbwr and tlbfill, to tlb
    output wire  [ 3:0] w_index,
    output wire         tlb_we,
    // tlbsrch, to csr
    output wire         tlbsrch_we,
    output wire         tlbsrch_hit,
    output wire  [ 3:0] tlbsrch_hit_index,   
    output wire ws_csr_tlbrd,
    input  wire [`D2C_CSRC_WID] ms_to_ws_csr_collect,
    output reg [`D2C_CSRC_WID] ws_csr_collect,
    input wire [31:0] csr_rvalue,

    output reg [31:0] cacop_addr,
    output wire cacop_req,
    output reg [4:0] cacop_code,
    input wire cacop_data_ok,
    output reg br_taken
);

    wire        ws_ready_go;
    reg         ws_valid;
    reg  [31:0] ws_pc;
    reg  [31:0] ws_rf_wdata;
    reg  [4 :0] ws_rf_waddr;
    reg         ws_rf_we;

    reg  [15:0]  ws_except;
    wire        ws_ertn_except;
    wire        ws_adef_except;
    wire        ws_ale_except;
    wire        ws_tlbr_except, ws_pif_except, ws_ppi_except, ws_pme_except, ws_data_tlbr, ws_data_pil, ws_data_pis, ws_data_ppi, ws_data_pme;
    wire        ws_syscall_except;
    wire        ws_break_except;
    wire        ws_ine_except;
    wire        ws_int_except;

    reg [13:0] ws_csr_num;
    reg ws_csr_we;
    reg               s1_found;
    reg [`T_IDX_WID]  s1_index;
    reg inst_tlbsrch,inst_tlbrd,inst_tlbwr,inst_tlbfill,inst_invtlb;
    wire [`T_IDX_WID]  random_idx;
    wire tlb_refetch;
    reg cacop_icache;
    reg cacop_data_ok_r;
    assign cacop_req=cacop_icache&&~cacop_data_ok_r;
    always @(posedge clk) begin
        if (~resetn) begin
            cacop_data_ok_r <= 1'b0;
        end else if (ms_to_ws_valid & ws_allowin) begin
            cacop_data_ok_r <= 1'b0;
        end else if(cacop_data_ok&&cacop_icache) begin
            cacop_data_ok_r <= 1'b1;
        end
    end

    assign ws_ready_go      = cacop_icache ? cacop_data_ok_r : 1'b1;
    assign ws_allowin       = ~ws_valid | ws_ready_go ;     
    always @(posedge clk) begin
        if (~resetn||ertn_flush||wb_ex) begin
            ws_valid <= 1'b0;
        end else if (ws_allowin) begin
            ws_valid <= ms_to_ws_valid;
        end
    end

    always @(posedge clk) begin
        if (~resetn) begin
            ws_pc <= 32'b0;
            {ws_rf_we, ws_rf_waddr, ws_rf_wdata} <= 38'b0;
            {ws_except,s1_found,s1_index,inst_tlbsrch,inst_tlbrd,inst_tlbwr,inst_tlbfill,inst_invtlb,cacop_icache,cacop_addr,cacop_code,br_taken} <= 'b0;
            wb_vaddr <= 32'b0;
            ws_csr_collect <= 'b0;
            ws_csr_we <= 1'b0;
            ws_csr_num <= 14'b0;
        end
        if (ms_to_ws_valid & ws_allowin) begin
            ws_pc <= ms_pc;
            {ws_rf_we, ws_rf_waddr, ws_rf_wdata} <= ms_rf_collect;
            {ws_except,s1_found,s1_index,inst_tlbsrch,inst_tlbrd,inst_tlbwr,inst_tlbfill,inst_invtlb,cacop_icache,cacop_addr,cacop_code,br_taken} <= ms_to_ws_bus;
            wb_vaddr <= vaddr;
            ws_csr_collect <= ms_to_ws_csr_collect;
            ws_csr_we <=  ms_to_ws_csr_collect[`CSR_WE];
            ws_csr_num <= ms_to_ws_csr_collect[`CSR_NUM];
        end
    end
    assign {ws_ale_except, ws_adef_except, ws_tlbr_except, ws_pif_except, ws_ppi_except, ws_pme_except, ws_ine_except, ws_syscall_except,
            ws_break_except, ws_int_except, ws_ertn_except, ws_data_tlbr, ws_data_pil, ws_data_pis, ws_data_ppi, ws_data_pme} = ws_except;

    wire      csr_re, csr_we;
    wire [13:0] csr_num;
    wire [31:0] csr_wmask;
    wire [31:0] csr_wvalue;
    assign {csr_re, csr_num, csr_we, csr_wmask, csr_wvalue} = ws_csr_collect;
    assign ertn_flush = ws_ertn_except & ws_valid;
    assign wb_ex = (ws_ale_except | ws_adef_except | ws_tlbr_except | ws_pif_except | ws_ppi_except | ws_pme_except | ws_ine_except |
         ws_syscall_except | ws_break_except | ws_int_except | ws_data_tlbr | ws_data_pil | ws_data_pis | ws_data_ppi | ws_data_pme) & ws_valid;
    //assign wb_ex = ws_syscall_except & ws_valid;
    assign wb_ecode =   ws_int_except ? `ECODE_INT:
                        ws_adef_except? `ECODE_ADE:
                        ws_ale_except? `ECODE_ALE: 
                        ws_tlbr_except? `ECODE_TLBR:
                        ws_pif_except? `ECODE_PIF:
                        ws_ppi_except? `ECODE_PPI:
                        ws_pme_except? `ECODE_PME:
                        ws_syscall_except? `ECODE_SYS:
                        ws_break_except? `ECODE_BRK:
                        ws_ine_except? `ECODE_INE:
                        ws_data_tlbr? `ECODE_TLBR:
                        ws_data_pil? `ECODE_PIL:
                        ws_data_pis? `ECODE_PIS:
                        ws_data_ppi? `ECODE_PPI:
                        ws_data_pme? `ECODE_PME:
                        6'b0;
    //assign wb_ecode = ws_syscall_except ? `ECODE_SYS : 6'b0;
    assign wb_esubcode = 9'b0;
    assign wb_pc = ws_pc;
    assign ws_rf_collect = {ws_rf_we & ws_valid & ~wb_ex, ws_rf_waddr, debug_wb_rf_wdata};
    
    //tlb related in exp 18
    assign ws_csr_tlbrd = ((ws_csr_num == `CSR_ASID | ws_csr_num == `CSR_TLBEHI) & ws_csr_we | inst_tlbrd) && ws_valid;
    random_gen random_gen_inst(
        .clk(clk),
        .resetn(resetn),
        .random_num(random_idx)
    ); 

    //tlbrd
    assign tlbrd_we = inst_tlbrd;
    assign r_index = csr_tlbidx_index;

    // tlbwr & tlbfill
    assign w_index = inst_tlbwr ? csr_tlbidx_index : random_idx;
    assign tlb_we = inst_tlbwr | inst_tlbfill;

    // tlbsrch
    assign tlbsrch_we = inst_tlbsrch;
    assign tlbsrch_hit = s1_found;
    assign tlbsrch_hit_index = s1_index;

    //refetch
    assign tlb_refetch = (inst_tlbsrch | inst_tlbrd | inst_tlbwr | inst_tlbfill | inst_invtlb |
                        (ws_csr_num == `CSR_ASID | ws_csr_num == `CSR_TLBEHI) & ws_csr_we
                        ) && ws_valid ||(cacop_icache && ~cacop_data_ok_r);



    assign wb_flush = tlb_refetch | wb_ex | ertn_flush;
    
    assign debug_wb_pc          = ws_pc;
    assign debug_wb_rf_wdata    = csr_re ? csr_rvalue : ws_rf_wdata;
    assign debug_wb_rf_we       = {4{ws_rf_we & ws_valid & ~wb_ex }};
    assign debug_wb_rf_wnum     = ws_rf_waddr;
endmodule

`define RANDOM_SEED 4'b0000
module random_gen(
    input wire clk,
    input wire resetn,
    output wire [3:0] random_num
);
    reg [3:0] num;
    assign random_num = num;
    always @(posedge clk) begin
        if (~resetn) begin
            num <= `RANDOM_SEED;
        end else begin
            num <= num + 1;// a LFSR may be better
        end
    end 

endmodule