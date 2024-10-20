`include "width.h"
module MEMreg(
    input  wire        clk,
    input  wire        resetn,
    // ex and mem state interface
    output wire        ms_allowin,
    input  wire [`E_RFC_WID] es_rf_collect, // es_to_ms_bus  {es_res_from_mem, es_rf_we, es_rf_waddr, es_rf_wdata}
    input  wire        es_to_ms_valid,
    input  wire [31:0] es_pc,    
    // mem and wb state interface
    input  wire        ws_allowin,
    output wire [`M_RFC_WID] ms_rf_collect, // {ms_rf_we, ms_rf_waddr, ms_rf_wdata}
    output wire        ms_to_ws_valid,
    output reg  [31:0] ms_pc,
    // data sram interface
    input  wire        data_sram_data_ok,
    input  wire [31:0] data_sram_rdata,
    input  wire [4:0]  mem_inst_bus,
    input  wire [7:0]  es_to_ms_bus,
    output wire [6:0]  ms_to_ws_bus,

    input wire except_flush,
    output reg [`E2M_EXCEPT_WID] ms_except,
    output wire [31:0] vaddr,
    output wire [`M_EXCEPT_WID] ms_except_collect,
    input  wire wb_ex
);
    wire        ms_ready_go;
    reg         ms_valid;
    reg  [31:0] ms_alu_result ; 
    reg         ms_res_from_mem;
    reg         ms_rf_we      ;
    reg  [4 :0] ms_rf_waddr   ;
    wire [31:0] ms_rf_wdata   ;
    wire [31:0] ms_mem_result ;

    reg inst_ld_w,inst_ld_h,inst_ld_hu,inst_ld_b,inst_ld_bu;
    wire inst_ld;
    wire is_sign_extend;
    wire [31:0] word_rdata, half_rdata, byte_rdata;

    reg  [31:0] ms_data_buf;
    reg         data_buf_valid;
    wire        ms_wait_data_ok;
    reg         ms_wait_data_ok_r;
    wire [31:0] shift_rdata;

    assign ms_wait_data_ok  = ms_wait_data_ok_r & ms_valid & ~wb_ex;
    assign ms_ready_go      = ~ms_wait_data_ok | ms_wait_data_ok & data_sram_data_ok;
    assign ms_allowin       = ~ms_valid | ms_ready_go & ws_allowin;     
    assign ms_to_ws_valid   = ms_valid & ms_ready_go;

    always @(posedge clk) begin
        if (~resetn||except_flush) begin
            ms_valid <= 1'b0;
        end else begin
            ms_valid <= es_to_ms_valid & ms_allowin;
        end 
    end

    always @(posedge clk) begin
        if (~resetn) begin
            ms_pc <= 32'b0;
            {ms_res_from_mem, ms_rf_we, ms_rf_waddr, ms_alu_result} <= 39'b0;
            {inst_ld_w,inst_ld_h,inst_ld_hu,inst_ld_b,inst_ld_bu} <= 5'd0;
            {ms_wait_data_ok_r, ms_except} <= 8'b0;
        end
        if (es_to_ms_valid & ms_allowin) begin
            ms_pc <= es_pc;
            {ms_res_from_mem, ms_rf_we, ms_rf_waddr, ms_alu_result} <= es_rf_collect;
            {inst_ld_w,inst_ld_h,inst_ld_hu,inst_ld_b,inst_ld_bu} <= mem_inst_bus;
            {ms_wait_data_ok_r, ms_except} <= es_to_ms_bus;
        end
    end

    // add in exp14
    always @(posedge clk) begin
        if (~resetn) begin
            data_buf_valid <= 1'b0;
            ms_data_buf <= 32'b0;
        end else if (ms_to_ws_valid & ms_allowin) begin
            data_buf_valid <= 1'b0;
        end else if (~data_buf_valid & data_sram_data_ok & ms_valid) begin
            data_buf_valid <= 1'b1;
            ms_data_buf <= data_sram_rdata;
        end
    end

    assign ms_wait_data_ok = data_buf_valid & ms_wait_data_ok_r;
    always @(posedge clk) begin
        if (~resetn) begin
            ms_wait_data_ok_r <= 1'b0;
        end else begin
            ms_wait_data_ok_r <= ms_wait_data_ok;
        end
    end

    //assign {inst_ld_w,inst_ld_h,inst_ld_hu,inst_ld_b,inst_ld_bu} = mem_inst_bus;
    assign inst_ld = inst_ld_w | inst_ld_h | inst_ld_hu | inst_ld_b | inst_ld_bu;
    assign is_sign_extend = inst_ld_h | inst_ld_b;
    assign shift_rdata = data_buf_valid ? ms_data_buf : data_sram_rdata;
    assign word_rdata = shift_rdata;
    assign half_rdata = {32{!ms_alu_result[1]}} & {{16{shift_rdata[15] & is_sign_extend}}, shift_rdata[15:0]} |
                        {32{ ms_alu_result[1]}} & {{16{shift_rdata[31] & is_sign_extend}}, shift_rdata[31:16]};
    assign byte_rdata = {32{ ms_alu_result[1:0] == 2'b00}} & {{24{shift_rdata[7] & is_sign_extend}}, shift_rdata[7:0]} |
                        {32{ ms_alu_result[1:0] == 2'b01}} & {{24{shift_rdata[15] & is_sign_extend}}, shift_rdata[15:8]} |
                        {32{ ms_alu_result[1:0] == 2'b10}} & {{24{shift_rdata[23] & is_sign_extend}}, shift_rdata[23:16]} |
                        {32{ ms_alu_result[1:0] == 2'b11}} & {{24{shift_rdata[31] & is_sign_extend}}, shift_rdata[31:24]};
    assign ms_mem_result = inst_ld_w ? word_rdata : ((inst_ld_h | inst_ld_hu) ? half_rdata : (inst_ld_b|inst_ld_bu) ? byte_rdata : 32'b0);
    assign ms_rf_wdata      = ms_res_from_mem ? ms_mem_result : ms_alu_result;
    assign ms_rf_collect    = {ms_rf_we & ms_valid, ms_rf_waddr, ms_rf_wdata}; // 1+5+32=38
    assign vaddr=ms_alu_result;

    assign ms_to_ws_bus =   {
                            ms_except
                            };
    assign ms_except_collect = ms_except & {7{ms_valid}};

endmodule