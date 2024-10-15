`include "width.h"

`define ECODE_INT       6'h00
`define ECODE_ADE       6'h08
`define ECODE_ALE       6'h09   
`define ECODE_SYS       6'h0B
`define ECODE_BRK       6'h0C   
`define ECODE_INE       6'h0D
`define ECODE_TLBR      6'h3F
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
    output wire [`W2C_ECODE_WID] wb_ecode  , //来自WB阶段的异常类型
    output wire [`W2C_ESUBCODE_WID] wb_esubcode,//来自WB阶段的异常类型辅助码
    output wire [31:0] wb_pc,       //写回的返回地址
    input wire [31:0] vaddr,
    output reg [31:0] wb_vaddr
);
    
    wire        ws_ready_go;
    reg         ws_valid;
    reg  [31:0] ws_pc;
    reg  [31:0] ws_rf_wdata;
    reg  [4 :0] ws_rf_waddr;
    reg         ws_rf_we;

    // add in exp12
    reg [6:0] ws_except;
    wire       ws_adef_except;
    wire       ws_ale_except;
    wire       ws_syscall_except;
    wire       ws_break_except;
    wire       ws_ine_except;
    wire       ws_int_except;

    assign ws_ready_go      = 1'b1;
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
            {ws_except} <= 7'b0;
            wb_vaddr <= 32'b0;
        end
        if (ms_to_ws_valid & ws_allowin) begin
            ws_pc <= ms_pc;
            {ws_rf_we, ws_rf_waddr, ws_rf_wdata} <= ms_rf_collect;
            {ws_except} <= ms_to_ws_bus;
            wb_vaddr <= vaddr;
        end
    end
    assign {ws_ale_except, ws_adef_except, ws_ine_except, ws_syscall_except,
            ws_break_except, ws_int_except, ertn_flush} = ws_except;

    assign wb_ex = (ws_ale_except | ws_adef_except | ws_ine_except | ws_syscall_except | ws_break_except | ws_int_except) & ws_valid;
    //assign wb_ex = ws_syscall_except & ws_valid;
    assign wb_ecode =   ws_int_except ? `ECODE_INT:
                        ws_adef_except? `ECODE_ADE:
                        ws_ale_except? `ECODE_ALE: 
                        ws_syscall_except? `ECODE_SYS:
                        ws_break_except? `ECODE_BRK:
                        ws_ine_except? `ECODE_INE:
                        6'b0;
    //assign wb_ecode = ws_syscall_except ? `ECODE_SYS : 6'b0;
    assign wb_esubcode = 9'b0;
    assign wb_pc = ws_pc;
    assign ws_rf_collect = {ws_rf_we & ws_valid & ~wb_ex, ws_rf_waddr, ws_rf_wdata};
    
    assign debug_wb_pc          = ws_pc;
    assign debug_wb_rf_wdata    = ws_rf_wdata;
    assign debug_wb_rf_we       = {4{ws_rf_we & ws_valid & ~wb_ex}};
    assign debug_wb_rf_wnum     = ws_rf_waddr;
endmodule