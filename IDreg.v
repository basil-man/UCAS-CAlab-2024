`include "width.h"
`define CSR_TID    14'h40
module IDreg(
    input wire clk,
    input wire resetn,
    input wire fs_to_ds_valid,
    output wire ds_allowin,
    output wire [`D2F_BRC_WID] br_collect,
    input wire [`F2D_WID] fs_to_ds_bus,
    input wire es_allowin,
    output wire ds_to_es_valid,
    output wire [`D2E_WID] ds_to_es_bus, // from 155bit -> 196bit (add from_ds_except, inst_rdcnt**, csr_rvalue, csr_re)
    output wire [`D2E_MINST_WID] mem_inst_bus,
    input wire [`W_RFC_WID] ws_rf_collect,  // {ws_rf_we, ws_rf_waddr, ws_rf_wdata}
    input wire [`M_RFC_WID] ms_rf_collect,  // {ms_res_from_mem, ms_rf_we, ms_rf_waddr, ms_rf_wdata} 1+1+5+32=39
    input wire [`E_RFC_WID] es_rf_collect, // {es_res_from_mem, es_rf_we, es_rf_waddr, es_alu_result}
    input wire [`E_EXCEPT_WID] es_except_collect,
    input wire [`M_EXCEPT_WID] ms_except_collect,
    // csr interface
    output wire [`D2C_CSRC_WID] csr_collect,
    input wire [31:0] csr_rvalue,
    input wire ds_int_except,

    input wire except_flush,
    output wire [`D2E_RDCNT_WID] collect_inst_rd_cnt,
    input wb_ex
);
    
    wire        ds_ready_go;
    reg         ds_valid;
    reg  [31:0] ds_inst;
    wire        ds_stall;
    
    wire [11:0] ds_alu_op;
    wire [18:0] new_alu_op; // add new_alu_op
    wire [31:0] ds_alu_src1;
    wire [31:0] ds_alu_src2;
    wire        ds_src1_is_pc;
    wire        ds_src2_is_imm;
    wire        ds_res_from_mem;
    reg  [31:0] ds_pc;
    wire [31:0] ds_rkd_value;
    wire        ds_mem_en;
    
    wire        dst_is_r1;
    wire        dst_is_rj;
    wire        gr_we;
    wire        src_reg_is_rd;
    wire        rj_eq_rd;
    wire        rj_ge_rd;
    wire        unsigned_rj_ge_rd;
    wire [4: 0] dest;
    wire [31:0] rj_value;
    wire [31:0] rkd_value;
    wire [31:0] imm;
    wire [31:0] br_offs;
    wire [31:0] jirl_offs;
    
    wire [5:0] op_31_26;
    wire [3:0] op_25_22;
    wire [1:0] op_21_20;
    wire [4:0] op_19_15;
    wire [4:0] rd;
    wire [4:0] rj;
    wire [4:0] rk;
    wire [13:0] csr;
    wire [11:0] i12;
    wire [19:0] i20;
    wire [15:0] i16;
    wire [25:0] i26;
    
    wire [63:0] op_31_26_d;
    wire [15:0] op_25_22_d;
    wire [3:0] op_21_20_d;
    wire [31:0] op_19_15_d;
    
    //alu
    wire [11:0] ds_branch_alu_op     ;
    wire [31:0] ds_branch_alu_src1   ;
    wire [31:0] ds_branch_alu_src2   ;
    wire [31:0] ds_branch_alu_result ;
    
    wire is_branch_unsigned,is_branch;
    
    //slti、sltui、andi、ori、xori、sll、srl、sra、pcaddu12i
    wire        inst_slti;
    wire        inst_sltui;
    wire        inst_andi;
    wire        inst_ori;
    wire        inst_xori;
    
    wire        inst_sll_w;
    wire        inst_srl_w;
    wire        inst_sra_w;
    wire        inst_pcaddu12i;
    
    //mul.w、mulh.w、mulh.wu、div.w、mod.w、div.wu、mod.wu
    wire        inst_mul_w;
    wire        inst_mulh_w;
    wire        inst_mulh_wu;
    wire        inst_div_w;
    wire        inst_mod_w;
    wire        inst_div_wu;
    wire        inst_mod_wu;
    
    // blt, bge, bltu, bgeu
    wire inst_blt;
    wire inst_bge;
    wire inst_bltu;
    wire inst_bgeu;
    
    // ld.b, ld.h, ld.bu, st.b, st.h
    wire inst_ld_b;
    wire inst_ld_h;
    wire inst_ld_bu;
    wire inst_ld_hu;
    wire inst_st_b;
    wire inst_st_h;
    
    // csrrd, csrwr, csrxchg, ertn, syscall
    wire inst_csrrd;
    wire inst_csrwr;
    wire inst_csrxchg;
    wire inst_ertn;
    wire inst_syscall;
    wire inst_break;

    // rdcntvl.w, rdcntvh.w, rdcntid
    wire inst_rdcntvl_w;
    wire inst_rdcntvh_w;
    wire inst_rdcntid;

    //oral wires
    wire        inst_add_w;
    wire        inst_sub_w;
    wire        inst_slt;
    wire        inst_sltu;
    wire        inst_nor;
    wire        inst_and;
    wire        inst_or;
    wire        inst_xor;
    wire        inst_slli_w;
    wire        inst_srli_w;
    wire        inst_srai_w;
    wire        inst_addi_w;
    wire        inst_ld_w;
    wire        inst_st_w;
    wire        inst_jirl;
    wire        inst_b;
    wire        inst_bl;
    wire        inst_beq;
    wire        inst_bne;

    //tlb inst
    wire        inst_lu12i_w;
    wire        inst_tlbsrch;
    wire        inst_tlbrd  ;
    wire        inst_tlbwr  ;
    wire        inst_tlbfill;
    wire        inst_invtlb ;
    wire        inst_type_tlb;
    wire        inst_invtlb_valid;

    //cacop inst
    wire        inst_cacop;
    
    wire        need_ui5;
    wire        need_si12;
    wire        need_ui12;
    wire        need_si16;
    wire        need_si20;
    wire        need_si26;
    wire        src2_is_4;
    
    wire        br_taken;
    wire [31:0] br_target;
    
    wire [4:0] rf_raddr1;
    wire [31:0] rf_rdata1;
    wire [4:0] rf_raddr2;
    wire [31:0] rf_rdata2;
    
    wire        hazard_r1_wb;
    wire        hazard_r2_wb;
    wire        hazard_r1_mem;
    wire        hazard_r2_mem;
    wire        hazard_r1_exe;
    wire        hazard_r2_exe;
    wire        need_r1;
    wire        need_r2;
    
    wire        ws_rf_we   ;
    wire [4:0] ws_rf_waddr;
    wire [31:0] ws_rf_wdata;
    wire        ms_res_from_mem;
    wire        ms_rf_we   ;
    wire [4:0]  ms_rf_waddr;
    wire [31:0] ms_rf_wdata;
    wire        es_rf_we   ;
    wire [4:0] es_rf_waddr;
    wire [31:0] es_rf_wdata;
    wire        es_res_from_mem;
    
    wire        ds_rf_we   ;
    wire [4:0] ds_rf_waddr;

    wire inst_ld, inst_st;
    
    wire [9:0] ds_except_collect;
    wire ds_ine_except;
    wire ds_syscall_except;
    wire ds_break_except;
    reg ds_adef_except, ds_tlbr_except, ds_pif_except, ds_ppi_except, ds_pme_except;

    wire br_stall;
    wire branch_type;
    wire es_csr_re,ms_csr_re;
    

    wire flush_by_former_except = (|ds_except_collect) | (|es_except_collect) | (|ms_except_collect) | except_flush;

    assign ds_ine_except =  ~(
                            inst_add_w | inst_addi_w | inst_and | inst_andi | inst_b | inst_beq | inst_bge | inst_bgeu | inst_bl |
                            inst_blt | inst_bltu | inst_bne | inst_break | inst_csrrd | inst_csrwr | inst_csrxchg | inst_div_w |
                            inst_div_wu | inst_ertn | inst_jirl | inst_ld | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu |
                            inst_ld_w | inst_lu12i_w | inst_mod_w | inst_mod_wu | inst_mul_w | inst_mulh_w | inst_mulh_wu |
                            inst_nor | inst_or | inst_ori | inst_pcaddu12i | inst_rdcntid | inst_rdcntvh_w |
                            inst_rdcntvl_w | inst_sll_w | inst_slli_w | inst_slt | inst_slti | inst_sltu | inst_sltui |
                            inst_sra_w | inst_srai_w | inst_srl_w | inst_srli_w | inst_st | inst_st_b | inst_st_h | inst_st_w |
                            inst_sub_w | inst_syscall | inst_xor | inst_xori |
                            inst_type_tlb
                            ); 

    assign branch_type = inst_b | inst_bl | inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu | inst_jirl;

    assign ds_syscall_except = inst_syscall;
    assign ds_break_except   = inst_break;

    assign ds_ready_go    = ~ds_stall;
    assign ds_allowin     = ~ds_valid | ds_ready_go & es_allowin;
    assign ds_stall       = (es_res_from_mem | es_csr_re) & (hazard_r1_exe & need_r1 | hazard_r2_exe & need_r2) |
                            (ms_res_from_mem | ms_csr_re) & (hazard_r1_mem & need_r1 | hazard_r2_mem & need_r2) |
                            inst_tlbsrch & (es_csr_re|ms_csr_re);
    assign ds_to_es_valid = ds_valid & ds_ready_go;
    assign br_stall       = ds_stall & branch_type;

    always @(posedge clk) begin
        if (~resetn||except_flush) begin
            ds_valid <= 1'b0;
        end else if (ds_allowin) begin
            if(br_taken) 
                ds_valid <= 1'b0;
            else
                ds_valid <= fs_to_ds_valid;
        end
    end
    
    always @(posedge clk) begin
        if (~resetn) begin
            {ds_adef_except, ds_tlbr_except, ds_pif_except, ds_ppi_except, ds_pme_except, ds_inst, ds_pc} <= 'b0;
        end
        if (fs_to_ds_valid & ds_allowin) begin
            {ds_adef_except, ds_tlbr_except, ds_pif_except, ds_ppi_except, ds_pme_except, ds_inst, ds_pc} <= fs_to_ds_bus;
        end
    end
    
    assign rj_ge_rd          = $signed(rj_value) >= $signed(rkd_value);
    assign unsigned_rj_ge_rd = $unsigned(rj_value) >= $unsigned(rkd_value);
    
    assign rj_eq_rd = (rj_value == rkd_value);
    assign br_taken =   (inst_beq   &  rj_eq_rd
                        | inst_bne  & !rj_eq_rd
                        | inst_jirl
                        | inst_bl
                        | inst_b
                        | inst_blt  & ~rj_ge_rd
                        | inst_bge  & rj_ge_rd
                        | inst_bltu & ~unsigned_rj_ge_rd
                        | inst_bgeu & unsigned_rj_ge_rd
                        ) & ds_valid & ~br_stall;
    
    assign is_branch = inst_beq | inst_bne | inst_bl | inst_b | inst_blt | inst_bge | inst_bltu | inst_bgeu;
    assign br_target = is_branch ? (ds_pc + br_offs) :
    /*inst_jirl*/ (rj_value + jirl_offs);
    assign br_collect = {br_stall, br_taken, br_target};
    
    assign op_31_26 = ds_inst[31:26];
    assign op_25_22 = ds_inst[25:22];
    assign op_21_20 = ds_inst[21:20];
    assign op_19_15 = ds_inst[19:15];
    
    assign rd = ds_inst[4: 0];
    assign rj = ds_inst[9: 5];
    assign rk = ds_inst[14:10];
    assign csr = ds_inst[23:10];
    assign i12 = ds_inst[21:10];
    assign i20 = ds_inst[24: 5];
    assign i16 = ds_inst[25:10];
    assign i26 = {ds_inst[9: 0], ds_inst[25:10]};
    
    decoder_6_64 u_dec0(.in(op_31_26), .out(op_31_26_d));
    decoder_4_16 u_dec1(.in(op_25_22), .out(op_25_22_d));
    decoder_2_4  u_dec2(.in(op_21_20), .out(op_21_20_d));
    decoder_5_32 u_dec3(.in(op_19_15), .out(op_19_15_d));
    
    // slti, sltui, andi, ori, xori, sll, srl, sra, pcaddu12i
    assign inst_slti  = op_31_26_d[6'h00] & op_25_22_d[4'h8];
    assign inst_sltui = op_31_26_d[6'h00] & op_25_22_d[4'h9];
    assign inst_andi  = op_31_26_d[6'h00] & op_25_22_d[4'hd];
    assign inst_ori   = op_31_26_d[6'h00] & op_25_22_d[4'he];
    assign inst_xori  = op_31_26_d[6'h00] & op_25_22_d[4'hf];
    
    assign inst_sll_w     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
    assign inst_srl_w     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
    assign inst_sra_w     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];
    assign inst_pcaddu12i = op_31_26_d[6'h07] & ~ds_inst[25];
    
    // mul.w, mulh.w, mulh.wu, div.w, mod.w, div.wu, mod.wu
    assign inst_mul_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
    assign inst_mulh_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
    assign inst_mulh_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
    assign inst_div_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
    assign inst_div_wu  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
    assign inst_mod_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
    assign inst_mod_wu  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];
    
    // blt, bge, bltu, bgeu
    assign inst_blt  = op_31_26_d[6'h18];
    assign inst_bge  = op_31_26_d[6'h19];
    assign inst_bltu = op_31_26_d[6'h1a];
    assign inst_bgeu = op_31_26_d[6'h1b];
    
    // ld.b, ld.h, ld.bu, st.b, st.h
    assign inst_ld_b  = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
    assign inst_ld_h  = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
    assign inst_ld_bu = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
    assign inst_ld_hu = op_31_26_d[6'h0a] & op_25_22_d[4'h9];
    assign inst_st_b  = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
    assign inst_st_h  = op_31_26_d[6'h0a] & op_25_22_d[4'h5];
    
    assign inst_ld = inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_ld_w;
    assign inst_st = inst_st_b | inst_st_h | inst_st_w;
    // csrrd, csrwr, csrxchg, ertn
    assign inst_csrrd      = op_31_26_d[6'h01] & (op_25_22[3:2] == 2'h0) & (rj == 5'h00);
    assign inst_csrwr      = op_31_26_d[6'h01] & (op_25_22[3:2] == 2'h0) & (rj == 5'h01);
    assign inst_csrxchg    = op_31_26_d[6'h01] & (op_25_22[3:2] == 2'b0) & (|rj[4:1]);
    assign inst_ertn       = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h00] & op_19_15_d[5'h10] 
                             & (rk == 5'h0e) & (rj == 5'h00) & (rd == 5'h00);
    
    assign inst_syscall    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h16];
    assign inst_break      = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h14];
    // rdcntvl.w, rdcntvh.w, rdcntid
    assign inst_rdcntvl_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (rk == 5'h18) & (rj == 5'h00);
    assign inst_rdcntvh_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (rk == 5'h19) & (rj == 5'h00);
    assign inst_rdcntid    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (rk == 5'h18) & (rd == 5'h00);

    //tlb inst
    assign inst_tlbsrch = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & rk == 5'h0a;
    assign inst_tlbrd   = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & rk == 5'h0b;
    assign inst_tlbwr   = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & rk == 5'h0c;
    assign inst_tlbfill = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & rk == 5'h0d;
    assign inst_invtlb  = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h13];

    assign inst_invtlb_valid = ~((|rd[4:3]) | (&rd[2:0]));//rd <= 0x7  

    assign inst_type_tlb = inst_tlbsrch | inst_tlbrd | inst_tlbwr | inst_tlbfill | (inst_invtlb & inst_invtlb_valid);

    //cacop inst
    assign inst_cacop = op_31_26_d[6'h01] & op_25_22_d[4'h8];
    wire cacop_code = ds_inst[4: 0];

    //oral code
    assign inst_add_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
    assign inst_sub_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
    assign inst_slt     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
    assign inst_sltu    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
    assign inst_nor     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
    assign inst_and     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
    assign inst_or      = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
    assign inst_xor     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
    assign inst_slli_w  = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
    assign inst_srli_w  = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
    assign inst_srai_w  = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
    assign inst_addi_w  = op_31_26_d[6'h00] & op_25_22_d[4'ha];
    assign inst_ld_w    = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
    assign inst_st_w    = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
    assign inst_jirl    = op_31_26_d[6'h13];
    assign inst_b       = op_31_26_d[6'h14];
    assign inst_bl      = op_31_26_d[6'h15];
    assign inst_beq     = op_31_26_d[6'h16];
    assign inst_bne     = op_31_26_d[6'h17];
    assign inst_lu12i_w = op_31_26_d[6'h05] & ~ds_inst[25];
    
    assign ds_alu_op[0] =  inst_add_w | inst_addi_w | inst_ld | inst_st
                           | inst_jirl | inst_bl | inst_pcaddu12i;
    assign ds_alu_op[1]  = inst_sub_w;
    assign ds_alu_op[2]  = inst_slt | inst_slti;
    assign ds_alu_op[3]  = inst_sltu | inst_sltui;
    assign ds_alu_op[4]  = inst_and | inst_andi;
    assign ds_alu_op[5]  = inst_nor;
    assign ds_alu_op[6]  = inst_or | inst_ori;
    assign ds_alu_op[7]  = inst_xor | inst_xori;
    assign ds_alu_op[8]  = inst_slli_w | inst_sll_w;
    assign ds_alu_op[9]  = inst_srli_w | inst_srl_w;
    assign ds_alu_op[10] = inst_srai_w | inst_sra_w;
    assign ds_alu_op[11] = inst_lu12i_w;
    
    assign new_alu_op = {inst_mul_w, inst_mulh_w, inst_mulh_wu, inst_div_w, inst_mod_w, inst_div_wu, inst_mod_wu, ds_alu_op};
    
    assign need_ui5  = inst_slli_w | inst_srli_w | inst_srai_w;
    assign need_si12 = inst_addi_w | inst_ld | inst_st | inst_slti | inst_sltui;
    assign need_ui12 = inst_andi | inst_ori | inst_xori;
    assign need_si16 = inst_jirl | inst_beq | inst_bne;
    assign need_si20 = inst_lu12i_w | inst_pcaddu12i ;
    assign need_si26 = inst_b | inst_bl;
    assign src2_is_4 = inst_jirl | inst_bl;
    
    // assign imm = src2_is_4 ? 32'h4                      :
    //             need_si20 ? {i20[19:0], 12'b0}         :
    // /*need_ui5 | need_si12*/{{20{i12[11]}}, i12[11:0]} ;
     
    assign imm =    {32{src2_is_4}} & 32'h4                     |
                    {32{need_si20}} & {i20[19:0], 12'b0}        |
                    {32{need_si12}} & {{20{i12[11]}}, i12[11:0]}|
                    {32{need_ui5}}  & {27'b0, rk[4:0]}          |
                    {32{need_ui12}} & {20'b0, i12[11:0]}        ;
     
    assign br_offs =    need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                        {{14{i16[15]}}, i16[15:0], 2'b0} ;
     
    assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};
    
    assign src_reg_is_rd = inst_beq | inst_bne | inst_st | inst_blt | inst_bge | inst_bltu | inst_bgeu | inst_csrwr | inst_csrxchg;
    
    assign ds_src1_is_pc = inst_jirl | inst_bl | inst_pcaddu12i;
     
    assign ds_src2_is_imm =     inst_slli_w |
                                inst_srli_w |
                                inst_srai_w |
                                inst_addi_w |
                                inst_ld     |
                                inst_st     |
                                inst_lu12i_w|
                                inst_jirl   |
                                inst_bl     |
                                inst_slti   |
                                inst_sltui  |
                                inst_andi   |
                                inst_ori    |
                                inst_xori   |
                                inst_pcaddu12i;
     
    assign ds_alu_src1 = ds_src1_is_pc  ? ds_pc[31:0] : rj_value;
    assign ds_alu_src2 = ds_src2_is_imm ? imm : rkd_value;
     
    assign ds_rkd_value    = rkd_value;
    assign ds_res_from_mem = inst_ld;
    assign dst_is_r1       = inst_bl;
    assign dst_is_rj       = inst_rdcntid;
    assign gr_we =  ~inst_st    & ~inst_beq &
                    ~inst_bne   & ~inst_b   &
                    ~inst_bge   & ~inst_bgeu&
                    ~inst_blt   & ~inst_bltu& ~inst_syscall & ~inst_type_tlb;
    assign ds_mem_en = inst_st & ds_valid;
    assign dest      = dst_is_r1 ? 5'd1 : dst_is_rj ? rj : rd;
     
    assign rf_raddr1   = rj;
    assign rf_raddr2   = src_reg_is_rd ? rd :rk;
    assign ds_rf_we    = gr_we & ~flush_by_former_except;
    assign ds_rf_waddr = dest;
    wire space;
    assign {ws_rf_we, ws_rf_waddr, ws_rf_wdata}                  = ws_rf_collect;
    assign {ms_res_from_mem,ms_csr_re, ms_rf_we, ms_rf_waddr, ms_rf_wdata} = ms_rf_collect;//1+1+1+1+5+32 = 41 ????
    assign {es_csr_re,es_res_from_mem, es_rf_we, es_rf_waddr, es_rf_wdata} = es_rf_collect;
    // assign ms_res_from_mem = ms_rf_collect[37];
    regfile u_regfile(
        .clk    (clk),
        .raddr1 (rf_raddr1),
        .rdata1 (rf_rdata1),
        .raddr2 (rf_raddr2),
        .rdata2 (rf_rdata2),
        .we     (ws_rf_we),
        .waddr  (ws_rf_waddr),
        .wdata  (ws_rf_wdata)
    );
     
    assign hazard_r1_wb  = (|rf_raddr1) & (rf_raddr1 == ws_rf_waddr) & ws_rf_we;
    assign hazard_r2_wb  = (|rf_raddr2) & (rf_raddr2 == ws_rf_waddr) & ws_rf_we;
    assign hazard_r1_mem = (|rf_raddr1) & (rf_raddr1 == ms_rf_waddr) & ms_rf_we;
    assign hazard_r2_mem = (|rf_raddr2) & (rf_raddr2 == ms_rf_waddr) & ms_rf_we;
    assign hazard_r1_exe = (|rf_raddr1) & (rf_raddr1 == es_rf_waddr) & es_rf_we;
    assign hazard_r2_exe = (|rf_raddr2) & (rf_raddr2 == es_rf_waddr) & es_rf_we;
    assign need_r1       = ~ds_src1_is_pc & (|ds_alu_op | inst_bne | inst_beq | inst_blt | inst_bge | inst_bltu | inst_bgeu | inst_csrxchg);
    assign need_r2       = ~ds_src2_is_imm & (|ds_alu_op | inst_bne | inst_beq | inst_blt | inst_bge | inst_bltu | inst_bgeu | inst_csrwr | inst_csrxchg);
     
    assign rj_value =   hazard_r1_exe ? es_rf_wdata :
                        hazard_r1_mem ? ms_rf_wdata :
                        hazard_r1_wb  ? ws_rf_wdata :
                        rf_rdata1;
     
    assign rkd_value =  hazard_r2_exe ? es_rf_wdata :
                        hazard_r2_mem ? ms_rf_wdata :
                        hazard_r2_wb  ? ws_rf_wdata :
                        rf_rdata2;

    // to csr
    wire csr_re, csr_we;
    wire [13:0] csr_num;
    wire [31:0] csr_wmask;
    wire [31:0] csr_wvalue;
    assign csr_re    = inst_csrrd | inst_csrxchg | inst_csrwr | inst_rdcntid;
    assign csr_num   = inst_rdcntid ? `CSR_TID : csr;
    assign csr_we    = (inst_csrwr | inst_csrxchg) & ds_valid & ~flush_by_former_except;
    assign csr_wmask = ({32{inst_csrxchg}} & rj_value) | {32{inst_csrwr}};
    assign csr_wvalue= rkd_value;
    assign csr_collect = {csr_re, csr_num, csr_we, csr_wmask, csr_wvalue};
    assign ds_except_collect =  {
                                ds_adef_except,
                                ds_tlbr_except, 
                                ds_pif_except, 
                                ds_ppi_except, 
                                ds_pme_except,
                                ds_ine_except,
                                ds_syscall_except,
                                ds_break_except,
                                ds_int_except,
                                inst_ertn
                                } & {10{ds_valid}};

    assign ds_to_es_bus =   {
                            inst_rdcntvl_w, // 1 bit
                            inst_rdcntvh_w, // 1 bit
                            ds_except_collect, // 10 bit
                            new_alu_op,
                            ds_res_from_mem,
                            ds_alu_src1,
                            ds_alu_src2,
                            ds_mem_en,
                            ds_rf_we,
                            ds_rf_waddr,
                            ds_rkd_value,
                            ds_pc,
                            csr_rvalue,// 32 bit
                            csr_re,
                            rd,//5 bit
                            inst_tlbsrch,
                            inst_tlbrd,
                            inst_tlbwr,
                            inst_tlbfill,
                            inst_invtlb, //5 bit total
                            rj
                            };

    assign mem_inst_bus =   {
                            inst_ld_w,
                            inst_ld_h,
                            inst_ld_hu,
                            inst_ld_b,
                            inst_ld_bu,
                            inst_st_w,
                            inst_st_h,
                            inst_st_b
                            };

    assign collect_inst_rd_cnt =   {
                                    inst_rdcntvl_w,
                                    inst_rdcntvh_w
    };
    
    endmodule
