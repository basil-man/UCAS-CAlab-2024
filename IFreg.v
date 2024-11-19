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
    input  wire         ertn_flush,//ugly trick:ertn includes tlb refetch
    input  wire         wb_flush,
    input  wire [31:0]  ex_entry,
    input  wire [31:0]  ertn_entry,

    input  wire [`A_ID_WID] axi_arid,

    //MMU
    output wire [31:0]  inst_va,
    input  wire [31:0]  inst_pa,
    input  wire         ex_TLBR,//ex is exception rather than execute
    input  wire         ex_PIx,
    input  wire         ex_PPI,
    input  wire         ex_PME,

    input  wire         inst_tlb_map,
    input  wire [31:0]  csr_crmd_data,
    input  wire [ 1:0]  s0_plv,
    input  wire         s0_v
);

    reg         fs_valid;
    wire        fs_ready_go;
    wire        fs_allowin;
    wire        to_fs_valid;

    wire [31:0] seq_pc;
    wire [31:0] nextpc;

    wire         br_stall;
    wire         br_taken;
    wire [31:0]  br_target;
    reg          br_taken_r;
    reg          wb_ex_r;
    reg          ertn_flush_r;
    reg  [31:0]  br_target_r;
    reg  [31:0]  ex_entry_r;
    reg  [31:0]  ertn_entry_r;

    wire [31:0] fs_inst;
    reg  [31:0] fs_pc;

    wire adef_except;

    // add in exp14
    wire pf_ready_go;
    wire fs_cancel;
    reg  pf_cancel;

    reg [31:0] fs_inst_buf;
    reg fs_inst_buf_valid;
    wire inst_cancel;
    reg br_stall_r;
    reg [2:0] inst_cancel_num;
    wire inst_sram_req_send;
    // reg inst_sram_addr_ok_r;

    // MMU execptions
    wire tlbr_except=ex_TLBR;
    wire pif_except=inst_tlb_map & ~s0_v;
    wire ppi_except=inst_tlb_map & (csr_crmd_data[1:0] > s0_plv);
    wire pme_except=ex_PME;

    assign inst_sram_size = 2'b10;

    assign adef_except = (|fs_pc[1:0]) & fs_valid;

    assign {br_stall, br_taken, br_target} = br_collect;

    assign pf_ready_go      = inst_sram_req & inst_sram_addr_ok; 
    assign to_fs_valid      = pf_ready_go & fs_allowin & ~pf_cancel & ~wb_flush;

    always @(posedge clk) begin
        if(~resetn)
            br_stall_r <= 1'b0;
        else if(br_stall)
            br_stall_r <= 1'b1;
        else if(to_fs_valid & fs_allowin)
            br_stall_r <= 1'b0;
    end
    
    always @(posedge clk) begin
        if(~resetn) begin
            {wb_ex_r, ertn_flush_r, br_taken_r} <= 3'b0;
            {ex_entry_r, ertn_entry_r, br_target_r} <= {3{32'b0}};
        end
        else if(wb_ex) begin
            ex_entry_r <= ex_entry;
            wb_ex_r <= 1'b1;
        end
        else if(ertn_flush ) begin
            ertn_entry_r <= ertn_entry;
            ertn_flush_r <= 1'b1;
        end    
        else if(br_taken ) begin
            br_target_r <= br_target;
            br_taken_r <= 1'b1;
        end
        // 若对应地址已经获得了来自指令SRAM的ok，后续nextpc不再从寄存器中取
        else if(pf_ready_go) begin
            {wb_ex_r, ertn_flush_r, br_taken_r} <= 3'b0;
        end
    end
    
    
    assign fs_ready_go      = (inst_sram_data_ok | fs_inst_buf_valid) & ~inst_cancel;
    assign fs_allowin       = ~fs_valid | fs_ready_go & ds_allowin /*| ertn_flush | wb_ex*/;
    assign fs_to_ds_valid   = fs_valid & fs_ready_go & ~wb_flush;
    
    always @(posedge clk) begin
        if (~resetn) begin
            fs_valid <= 1'b0;
        end else if (fs_allowin) begin
            fs_valid <= to_fs_valid;
        end else if (fs_cancel | br_taken_r) begin
            fs_valid <= 1'b0;
        end
    end
    
    assign inst_sram_req     = fs_allowin & resetn & ~pf_cancel & ~br_stall;
    assign inst_sram_wr     = |inst_sram_wstrb;
    assign inst_sram_wstrb   = 4'b0;
    assign inst_sram_addr   = inst_pa;
    assign inst_sram_wdata  = 32'b0;

    assign fs_cancel = wb_flush | br_taken ;

    always @(posedge clk)begin
        if(~resetn)
            inst_cancel_num <= 'b0;
        else if((fs_cancel) & (fs_valid & ~fs_ready_go))
            inst_cancel_num <= inst_cancel_num + 'b1;
        else if(inst_cancel & inst_sram_data_ok)
            inst_cancel_num <= inst_cancel_num - 'b1;
    end

    assign inst_cancel = | inst_cancel_num;

    assign inst_sram_req_send = inst_sram_req | br_stall;

    always @(posedge clk) begin
        if(~resetn)
            pf_cancel <= 1'b0;
        else if(inst_sram_req_send & (fs_cancel | (br_stall | br_stall_r) & inst_sram_addr_ok) & ~axi_arid[0])
            pf_cancel <= 1'b1;
        else if(inst_sram_data_ok & ~inst_cancel)
            pf_cancel <= 1'b0;
    end

    always @(posedge clk) begin
        if(~resetn)begin
            fs_inst_buf <= 32'b0;
            fs_inst_buf_valid <= 1'b0;
        end else if(fs_to_ds_valid & fs_allowin)begin
            fs_inst_buf_valid <= 1'b0;
        end else if(fs_cancel)begin
            fs_inst_buf_valid <= 1'b0;
        end else if(~fs_inst_buf_valid & inst_sram_data_ok & ~inst_cancel & ~pf_cancel)begin
            fs_inst_buf <= fs_inst;
            fs_inst_buf_valid <= 1'b1;
        end
    end

    wire [31:0] ex_pc=ex_entry;
    assign seq_pc   =   fs_pc + 3'h4;
//  assign nextpc   =   wb_ex ? ex_entry : ertn_flush ? ertn_entry : br_taken ? br_target : seq_pc;
    assign nextpc   =   wb_ex_r ? ex_entry_r: wb_ex ? ex_entry:
                        ertn_flush_r ? ertn_entry_r : ertn_flush ? ertn_entry:
                        br_taken_r ? br_target_r : br_taken ? br_target : seq_pc;
    assign inst_va = nextpc;
    always @(posedge clk) begin
        if (~resetn) begin
            fs_pc <= 32'h1bfffffc;
        end else if (to_fs_valid & fs_allowin) begin
            fs_pc <= nextpc;
        end
    end

    assign fs_inst      = (fs_inst_buf_valid | inst_cancel | ~inst_sram_data_ok) ? fs_inst_buf : inst_sram_rdata;
    assign fs_to_ds_bus =   {
                            adef_except,
                            tlbr_except,
                            pif_except,
                            ppi_except,
                            pme_except,
                            fs_inst,
                            fs_pc
                            };
endmodule