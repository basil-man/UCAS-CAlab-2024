`include "width.h"
module IFreg(
    input  wire   clk,
    input  wire   resetn,
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

    // ds to fs interface
    input  wire         ds_allowin,
    input  wire [`D2F_BRC_WID]  br_collect,
    // fs to ds interface
    output wire         fs_to_ds_valid,
    output wire [`F2D_WID]  fs_to_ds_bus,

    input  wire         wb_ex,
    input  wire         ertn_flush,
    input  wire [31:0]  ex_entry,
    input  wire [31:0]  ertn_entry
);

    reg         fs_valid;
    wire        fs_ready_go;
    wire        fs_allowin;
    wire        to_fs_valid;

    wire [31:0] seq_pc;
    wire [31:0] nextpc;

    wire         br_taken;
    wire [ 31:0] br_target;

    wire [31:0] fs_inst;
    reg  [31:0] fs_pc;

    wire adef_except;

    // add in exp14
    wire pf_ready_go;
    wire fs_cancel;
    wire pf_cancel;

    reg [31:0] fs_inst_buf;
    reg inst_buf_valid;
    reg inst_cancel;

    assign adef_except = (|fs_pc[1:0]) & fs_valid;

    assign {br_taken, br_target} = br_collect;


    assign seq_pc   = fs_pc + 3'h4;

    assign pf_ready_go      = inst_sram_addr_ok & fs_valid;
    assign to_fs_valid      = pf_ready_go;
    assign fs_ready_go      = inst_sram_data_ok;
    assign fs_allowin       = ~fs_valid | fs_ready_go & ds_allowin | ertn_flush | wb_ex;     
    assign fs_to_ds_valid   = fs_valid & fs_ready_go;
    
    always @(posedge clk) begin
        if (~resetn) begin
            fs_valid <= 1'b0;
        end else if (fs_allowin) begin
            fs_valid <= to_fs_valid;
        end else if (fs_cancel) begin
            fs_valid <= 1'b0;
        end
    end

    always @(posedge clk) begin
        if (~resetn) begin
            fs_pc <= 32'h1bfffffc;
        end else if (fs_allowin) begin
            fs_pc <= nextpc;
        end
    end
    
    assign inst_sram_req     = fs_allowin & resetn & ~pf_cancel;
    assign inst_sram_wr     = |inst_sram_wstrb;
    assign inst_sram_wstrb   = 4'b0;
    assign inst_sram_addr   = nextpc;
    assign inst_sram_wdata  = 32'b0;

    assign fs_cancel = wb_ex | ertn_flush | br_taken;
    assign pf_cancel = 1'b0;

    wire [31:0] ex_pc=ex_entry;
    assign seq_pc   = fs_pc + 3'h4;
    assign nextpc   = wb_ex ? ex_entry : ertn_flush ? ertn_entry : br_taken ? br_target : seq_pc;
    
    always @(posedge clk) begin
        if (~resetn) begin
            fs_pc <= 32'h1bfffffc;
        end else if (fs_allowin) begin
            fs_pc <= nextpc;
        end
    end
    
    always @(posedge clk) begin
        if (~resetn) begin
            fs_inst_buf <= 32'b0;
            inst_buf_valid <= 1'b0;
        end else if (fs_to_ds_valid & ds_allowin) begin
            inst_buf_valid <= 1'b0;
        end else if (inst_cancel) begin
            inst_buf_valid <= 1'b0;
        end else if (~inst_buf_valid & inst_sram_data_ok & ~inst_cancel) begin
            fs_inst_buf <= fs_inst;
            inst_buf_valid <= 1'b1;
        end
    end

    assign fs_inst      = inst_buf_valid ? fs_inst_buf : inst_sram_rdata;
    assign fs_to_ds_bus =   {
                            adef_except,
                            fs_inst,
                            fs_pc
                            };
endmodule