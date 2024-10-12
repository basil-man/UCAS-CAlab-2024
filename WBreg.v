module WBreg(
    input  wire        clk,
    input  wire        resetn,
    // mem and ws state interface
    output wire        ws_allowin,
    input  wire [37:0] ms_rf_collect, // {ms_rf_we, ms_rf_waddr, ms_rf_wdata}
    input  wire        ms_to_ws_valid,
    input  wire [31:0] ms_pc,    
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,
    // id and ws state interface
    output wire [37:0] ws_rf_collect,  // {ws_rf_we, ws_rf_waddr, ws_rf_wdata}
    input wire [6:0] ms_to_ws_bus, // new
    output ertn_flush,
    output ws_exc
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
        if (~resetn) begin
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
        end
        if (ms_to_ws_valid & ws_allowin) begin
            ws_pc <= ms_pc;
            {ws_rf_we, ws_rf_waddr, ws_rf_wdata} <= ms_rf_collect;
            {ws_except} <= ms_to_ws_bus;
        end
    end
    assign {ws_ale_except, ws_adef_except, ws_ine_except, ws_syscall_except,
            ws_break_except, ws_int_except, ertn_flush} = ws_except;

    assign ws_exc = (ws_ale_except | ws_adef_except | ws_ine_except | ws_syscall_except | ws_break_except | ws_int_except) & ws_valid;

    assign ws_rf_collect = {ws_rf_we & ws_valid, ws_rf_waddr, ws_rf_wdata};
    
    assign debug_wb_pc          = ws_pc;
    assign debug_wb_rf_wdata    = ws_rf_wdata;
    assign debug_wb_rf_we       = {4{ws_rf_we & ws_valid}};
    assign debug_wb_rf_wnum     = ws_rf_waddr;
endmodule