`include "width.h"
`include "csr.vh"

module csr(
    input  wire          clk       ,
    input  wire          reset     ,
    // command access interface(指令访问接口)
    input  wire          csr_re    ,
    input  wire [`D2C_CSRNUM_WID]   csr_num   ,
    output wire [31:0]   csr_rvalue,
    input  wire          csr_we    ,
    input  wire [`D2C_CSRWMASK_WID]   csr_wmask ,
    input  wire [`D2C_CSRWVAL_WID]   csr_wvalue,

    /* interface signals for direct interaction with hardware circuits
    (与硬件电路交互的接口信号) */
    output wire [31:0]   ex_entry  , //送往pre-IF的异常入口地址
    output wire [31:0]   ertn_entry, //送往pre-IF的返回入口地址
    output wire          has_int   , //送往ID阶段的中断有效信号
    input  wire          ertn_flush, //来自WB阶段的ertn指令执行有效信号
    input  wire          wb_ex     , //来自WB阶段的异常处理触发信号
    input  wire [`W2C_ECODE_WID]   wb_ecode  , //来自WB阶段的异常类型
    input  wire [`W2C_ESUBCODE_WID]   wb_esubcode,//来自WB阶段的异常类型辅助码
    input  wire [31:0]   wb_vaddr   ,//来自WB阶段的访存地址
    input  wire [31:0]   wb_pc,      //写回的返回地址

    // tlb related wires in exp 18
    output reg  [`T_ASID_WID]       csr_asid,
    output reg  [`T_VPPN_WID]       csr_tlbehi_vppn,
    output reg  [`T_IDX_WID]        csr_tlbidx_index,

    input  wire                     tlbsrch_we,
    input  wire                     tlbsrch_hit,
    input  wire                     tlbrd_we,
    input  wire [`T_IDX_WID]        tlbsrch_hit_index,
    
    input  wire                     r_e,
    input  wire [`T_PS_WID]         r_ps,
    input  wire [`T_VPPN_WID]       r_vppn,
    input  wire [`T_ASID_WID]       r_asid,
    input  wire                     r_g,

    input  wire [`T_PPN_WID]        r_ppn0,
    input  wire [`T_plv_WID]        r_plv0,
    input  wire [`T_MAT_WID]        r_mat0,
    input  wire                     r_d0,
    input  wire                     r_v0,
    input  wire [`T_PPN_WID]        r_ppn1,
    input  wire [`T_plv_WID]        r_plv1,
    input  wire [`T_MAT_WID]        r_mat1,
    input  wire                     r_d1,
    input  wire                     r_v1,

    output wire                     w_e,
    output wire [`T_PS_WID]         w_ps,
    output wire [`T_VPPN_WID]       w_vppn,
    output wire [`T_ASID_WID]       w_asid,
    output wire                     w_g,

    output wire [`T_PPN_WID]        w_ppn0,
    output wire [`T_plv_WID]        w_plv0,
    output wire [`T_MAT_WID]        w_mat0,
    output wire                     w_d0,
    output wire                     w_v0,
    output wire [`T_PPN_WID]        w_ppn1,
    output wire [`T_plv_WID]        w_plv1,
    output wire [`T_MAT_WID]        w_mat1,
    output wire                     w_d1,
    output wire                     w_v1,

    // to MMU
    output wire [31:0]              csr_crmd_data,
    output wire [31:0]              csr_dmw0_data,
    output wire [31:0]              csr_dmw1_data,
    output wire [31:0]              csr_asid_data
);
    wire [ 7: 0] hw_int_in;
    wire         ipi_int_in;
    // 当前模式信息
    //wire [31: 0] csr_crmd_data;
    reg  [ 1: 0] csr_crmd_plv;      //CRMD的PLV域，当前特权等级
    reg          csr_crmd_ie;       //CRMD的全局中断使能信号
    reg          csr_crmd_da;       //CRMD的直接地址翻译使能
    reg          csr_crmd_pg;
    reg  [ 6: 5] csr_crmd_datf;
    reg  [ 8: 7] csr_crmd_datm;
    // reg  [31: 9] csr_crmd_r0;

    // 例外前模式信息
    wire [31: 0] csr_prmd_data;
    reg  [ 1: 0] csr_prmd_pplv;     //CRMD的PLV域旧值
    reg          csr_prmd_pie;      //CRMD的IE域旧值

    // 例外控制
    wire [31: 0] csr_ecfg_data;     // 保留位31:13
    reg  [12: 0] csr_ecfg_lie;      //局部中断使能位

    // 例外状态
    wire [31: 0] csr_estat_data;    // 保留位15:13, 31
    reg  [12: 0] csr_estat_is;      // 例外中断的状态位（8个硬件中断+1个定时器中断+1个核间中断+2个软件中断）
    reg  [ 5: 0] csr_estat_ecode;   // 例外类型一级编码
    reg  [ 8: 0] csr_estat_esubcode;// 例外类型二级编码

    // 例外返回地址ERA
    reg  [31: 0] csr_era_data;  // data

    // 例外入口地址eentry
    wire [31: 0] csr_eentry_data;   // 保留位5:0
    reg  [25: 0] csr_eentry_va;     // 例外中断入口高位地址
    // 数据保存
    reg  [31: 0] csr_save0_data;
    reg  [31: 0] csr_save1_data;
    reg  [31: 0] csr_save2_data;
    reg  [31: 0] csr_save3_data;
    // 出错虚地址
    wire         wb_ex_addr_err;
    reg  [31: 0] csr_badv_vaddr;
    wire [31: 0] csr_badv_data;
    // 定时器编号 
    wire [31: 0] csr_tid_data;
    reg  [31: 0] csr_tid_tid;

    // 定时器配置
    wire [31: 0] csr_tcfg_data;
    reg          csr_tcfg_en;
    reg          csr_tcfg_periodic;
    reg  [29: 0] csr_tcfg_initval;
    wire [31: 0] tcfg_next_value;

    // 定时器数值
    wire [31: 0] csr_tval_data;
    reg  [31: 0] timer_cnt;
    // 定时中断清除
    wire [31: 0] csr_ticlr_data;

    //TLB相关
    // TLBIDX
    reg  [ 5:0] csr_tlbidx_ps;
    reg         csr_tlbidx_ne;
    wire [31:0] csr_tlbidx_rvalue;

    // TLBEHI
    wire [31:0] csr_tlbehi_rvalue;

    // TLELO0
    reg         csr_tlbelo0_v;
    reg         csr_tlbelo0_d;
    reg  [ 1:0] csr_tlbelo0_plv;
    reg  [ 1:0] csr_tlbelo0_mat;
    reg         csr_tlbelo0_g;
    reg  [23:0] csr_tlbelo0_ppn;
    wire [31:0] csr_tlbelo0_rvalue;

    // TLELO1
    reg         csr_tlbelo1_v;
    reg         csr_tlbelo1_d;
    reg  [ 1:0] csr_tlbelo1_plv;
    reg  [ 1:0] csr_tlbelo1_mat;
    reg         csr_tlbelo1_g;
    reg  [23:0] csr_tlbelo1_ppn;
    wire [31:0] csr_tlbelo1_rvalue;

    // ASID
    wire [ 7:0] csr_asid_asidbits;
    wire [31:0] csr_asid_rvalue;

    // TLBRENTRY
    reg  [25:0] csr_tlbrentry_pa;
    wire [31:0] csr_tlbrentry_rvalue;

    //DMW0
    reg         csr_dmw0_plv0;
    reg         csr_dmw0_plv3;
    reg  [ 1:0] csr_dmw0_mat ;
    reg  [ 2:0] csr_dmw0_pseg;
    reg  [ 2:0] csr_dmw0_vseg;

    reg         csr_dmw1_plv0;
    reg         csr_dmw1_plv3;
    reg  [ 1:0] csr_dmw1_mat ;
    reg  [ 2:0] csr_dmw1_pseg;
    reg  [ 2:0] csr_dmw1_vseg;

    assign has_int = (|(csr_estat_is[11:0] & csr_ecfg_lie[11:0])) & csr_crmd_ie;
    assign ex_entry = csr_eentry_data;
    assign ertn_entry = csr_era_data;

    // CRMD的PLV、IE域
    always @(posedge clk) begin
        if (reset) begin
            csr_crmd_plv <= 2'b0;//最高优先级
            csr_crmd_ie  <= 1'b0;
        end
        else if (wb_ex) begin
            csr_crmd_plv <= 2'b0;
            csr_crmd_ie  <= 1'b0;
        end
        else if (ertn_flush) begin
            csr_crmd_plv <= csr_prmd_pplv;
            csr_crmd_ie  <= csr_prmd_pie;
        end
        else if (csr_we && csr_num == `CSR_CRMD) begin
            csr_crmd_plv <= csr_wmask[`CSR_CRMD_PLV] & csr_wvalue[`CSR_CRMD_PLV]
                          | ~csr_wmask[`CSR_CRMD_PLV] & csr_crmd_plv;
            csr_crmd_ie  <= csr_wmask[`CSR_CRMD_IE ] & csr_wvalue[`CSR_CRMD_IE ]
                          | ~csr_wmask[`CSR_CRMD_IE ] & csr_crmd_ie;
        end
    end

    // CRMD的DA、PG、DATF、DATM域
    /*等到第九章的实践任务中可完善DA和PG域的功能，
    等到第十章的实践任务中可进一步完善DATF和DATM域的功能。*/
    always @(posedge clk) begin
        if(reset) begin
            csr_crmd_da   <= 1'b1;
            csr_crmd_pg   <= 1'b0;
            csr_crmd_datf <= 2'b00;
            csr_crmd_datm <= 2'b00;
        end
        else if (wb_ex && wb_ecode == `ECODE_TLBR) begin
            csr_crmd_da <= 1'b1;
            csr_crmd_pg <= 1'b0;
            csr_crmd_datf <= 2'b00;
            csr_crmd_datm <= 2'b00;
        end 
        else if (ertn_flush && csr_estat_ecode == `ECODE_TLBR) begin
            csr_crmd_da <= 1'b0;
            csr_crmd_pg <= 1'b1;
            csr_crmd_datf <= 2'b01;
            csr_crmd_datm <= 2'b01;
        end
        else if (csr_we && csr_num == `CSR_CRMD) begin
            csr_crmd_da <= csr_wmask[`CSR_CRMD_DA] & csr_wvalue[`CSR_CRMD_DA] |
                          ~csr_wmask[`CSR_CRMD_DA] & csr_crmd_da;
            csr_crmd_pg <= csr_wmask[`CSR_CRMD_PG] & csr_wvalue[`CSR_CRMD_PG] |
                          ~csr_wmask[`CSR_CRMD_PG] & csr_crmd_pg;
            csr_crmd_datf <= csr_wmask[`CSR_CRMD_DATF] & csr_wvalue[`CSR_CRMD_DATF] |
                            ~csr_wmask[`CSR_CRMD_DATF] & csr_crmd_datf;
            csr_crmd_datm <= csr_wmask[`CSR_CRMD_DATM] & csr_wvalue[`CSR_CRMD_DATM] |
                            ~csr_wmask[`CSR_CRMD_DATM] & csr_crmd_datm;
        end

    end

    // PRMD的PPLV、PIE域
    always @(posedge clk) begin
        if (wb_ex) begin
            csr_prmd_pplv <= csr_crmd_plv;
            csr_prmd_pie  <= csr_crmd_ie;
        end
        else if (csr_we && csr_num==`CSR_PRMD) begin
            csr_prmd_pplv <=  csr_wmask[`CSR_PRMD_PPLV] & csr_wvalue[`CSR_PRMD_PPLV]
                           | ~csr_wmask[`CSR_PRMD_PPLV] & csr_prmd_pplv;
            csr_prmd_pie  <=  csr_wmask[`CSR_PRMD_PIE ] & csr_wvalue[`CSR_PRMD_PIE ]
                           | ~csr_wmask[`CSR_PRMD_PIE ] & csr_prmd_pie;
        end
    end

    // ECFG的LIE域
    always @(posedge clk) begin
        if(reset)
            csr_ecfg_lie <= 13'b0;
        else if(csr_we && csr_num == `CSR_ECFG)
            csr_ecfg_lie <= csr_wmask[`CSR_ECFG_LIE] & 13'h1bff & csr_wvalue[`CSR_ECFG_LIE]
                        |  ~csr_wmask[`CSR_ECFG_LIE] & 13'h1bff & csr_ecfg_lie;
    end

    // ESTAT的IS域
    assign hw_int_in = 8'b0;
    assign ipi_int_in= 1'b0;
    always @(posedge clk) begin
        if (reset) begin
            csr_estat_is[1:0] <= 2'b0;
        end
        else if (csr_we && (csr_num == `CSR_ESTAT)) begin
            csr_estat_is[1:0] <= ( csr_wmask[`CSR_ESTAT_IS10] & csr_wvalue[`CSR_ESTAT_IS10])
                               | (~csr_wmask[`CSR_ESTAT_IS10] & csr_estat_is[1:0]          );
        end

        csr_estat_is[9:2] <= hw_int_in[7:0];
        csr_estat_is[10] <= 1'b0;

        if (timer_cnt[31:0] == 32'b0) begin
            csr_estat_is[11] <= 1'b1;
        end
        else if (csr_we && csr_num == `CSR_TICLR && csr_wmask[`CSR_TICLR_CLR] 
                && csr_wvalue[`CSR_TICLR_CLR]) 
            csr_estat_is[11] <= 1'b0;
        csr_estat_is[12] <= ipi_int_in;
    end    
    // ESTAT的Ecode和EsubCode域
    // 触发异常时填写异常的类型代号，精确异常是在写回级进行触发
    always @(posedge clk) begin
        if (wb_ex) begin
            csr_estat_ecode    <= wb_ecode;
            csr_estat_esubcode <= wb_esubcode;
        end
    end
    // ERA的PC域
    //当位于写回级指令触发异常时，需要记录到 ERA 寄存器的 PC 就是当前写回级的 PC
    always @(posedge clk) begin
        if(wb_ex)
            csr_era_data <= wb_pc;
        else if (csr_we && csr_num == `CSR_ERA) 
            csr_era_data <= csr_wmask[`CSR_ERA_PC] & csr_wvalue[`CSR_ERA_PC]
                        | ~csr_wmask[`CSR_ERA_PC] & csr_era_data;
    end
    // BADV的VAddr域
    //load store在执行级、访存级和写回级增加虚地址通路，采用增加一个vaddr域
    assign wb_ex_addr_err = wb_ecode==`ECODE_ALE || wb_ecode==`ECODE_ADE; 
    always @(posedge clk) begin
        if (wb_ex && wb_ex_addr_err) begin
            csr_badv_vaddr <= (wb_ecode==`ECODE_ADE && wb_esubcode==`ESUBCODE_ADEF) ? wb_pc:wb_vaddr;
        end
    end
    // EENTRY
    always @(posedge clk) begin
        if (csr_we && (csr_num == `CSR_EENTRY))
            csr_eentry_va <=   csr_wmask[`CSR_EENTRY_VA] & csr_wvalue[`CSR_EENTRY_VA]
                            | ~csr_wmask[`CSR_EENTRY_VA] & csr_eentry_va ;
    end

    // SAVE0~3
    always @(posedge clk) begin
        if (csr_we && csr_num == `CSR_SAVE0) 
            csr_save0_data <=  csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                            | ~csr_wmask[`CSR_SAVE_DATA] & csr_save0_data;
        if (csr_we && (csr_num == `CSR_SAVE1)) 
            csr_save1_data <=  csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                            | ~csr_wmask[`CSR_SAVE_DATA] & csr_save1_data;
        if (csr_we && (csr_num == `CSR_SAVE2)) 
            csr_save2_data <=  csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                            | ~csr_wmask[`CSR_SAVE_DATA] & csr_save2_data;
        if (csr_we && (csr_num == `CSR_SAVE3)) 
            csr_save3_data <=  csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                            | ~csr_wmask[`CSR_SAVE_DATA] & csr_save3_data;
    end

    // TID
    always @(posedge clk) begin
        if (reset) begin
            csr_tid_tid <= 32'b0;
        end
        else if (csr_we && csr_num == `CSR_TID) begin
            csr_tid_tid <= csr_wmask[`CSR_TID_TID] & csr_wvalue[`CSR_TID_TID]
                        | ~csr_wmask[`CSR_TID_TID] & csr_tid_tid;
        end
    end

    // TCFG的EN、Periodic、InitVal域
    always @(posedge clk) begin
        if (reset) 
            csr_tcfg_en <= 1'b0;
        else if (csr_we && csr_num == `CSR_TCFG) begin
            csr_tcfg_en <= csr_wmask[`CSR_TCFG_EN] & csr_wvalue[`CSR_TCFG_EN]
                        | ~csr_wmask[`CSR_TCFG_EN] & csr_tcfg_en;
        end
        if (csr_we && csr_num == `CSR_TCFG) begin
            csr_tcfg_periodic <= csr_wmask[`CSR_TCFG_PERIOD] & csr_wvalue[`CSR_TCFG_PERIOD]
                              | ~csr_wmask[`CSR_TCFG_PERIOD] & csr_tcfg_periodic;
            csr_tcfg_initval  <= csr_wmask[`CSR_TCFG_INITV] & csr_wvalue[`CSR_TCFG_INITV]
                              | ~csr_wmask[`CSR_TCFG_INITV] & csr_tcfg_initval;
        end
    end

    // TVAL的TimeVal域 返回定时器计数器的值
    assign tcfg_next_value = csr_wmask[31:0] & csr_wvalue[31:0]
                           |~csr_wmask[31:0] & {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};
    always @(posedge clk) begin
        if (reset) begin
            timer_cnt <= 32'hffffffff;
        end
        else if (csr_we && csr_num == `CSR_TCFG && tcfg_next_value[`CSR_TCFG_EN]) begin
            timer_cnt <= {tcfg_next_value[`CSR_TCFG_INITV], 2'b0};
        end
        else if (csr_tcfg_en && timer_cnt != 32'hffffffff) begin
            if (timer_cnt[31:0] == 32'b0 && csr_tcfg_periodic) begin
                timer_cnt <= {csr_tcfg_initval, 2'b0};
            end
            else begin
                timer_cnt <= timer_cnt - 1'b1;
            end
        end
    end

    assign csr_tval_data  = timer_cnt[31:0];

    // TICLR的CLR域
    assign csr_ticlr_clr = 1'b0;

    //TLBIDX
    always @ (posedge clk) begin
        if (reset) begin
            csr_tlbidx_index <= 4'b0;
            csr_tlbidx_ps    <= 6'b0;
            csr_tlbidx_ne    <= 1'b1;
        end 
        else if (tlbrd_we) begin
            if (r_e)
                csr_tlbidx_ps <= r_ps;
            else
                csr_tlbidx_ps <= 6'b0;

            csr_tlbidx_ne <= ~r_e;
        end 
        else if (tlbsrch_we) begin
            if(tlbsrch_hit) begin
                csr_tlbidx_index <= tlbsrch_hit_index;
                csr_tlbidx_ne <= 1'b0;
            end
            else
                csr_tlbidx_ne <= 1'b1;
        end 
        else if (csr_we && csr_num == `CSR_TLBIDX) begin
            csr_tlbidx_index <= csr_wmask[`CSR_TLBIDX_INDEX] & csr_wvalue[`CSR_TLBIDX_INDEX] |
                               ~csr_wmask[`CSR_TLBIDX_INDEX] & csr_tlbidx_index;
            csr_tlbidx_ps <= csr_wmask[`CSR_TLBIDX_PS] & csr_wvalue[`CSR_TLBIDX_PS] |
                            ~csr_wmask[`CSR_TLBIDX_PS] & csr_tlbidx_ps;
            csr_tlbidx_ne <= csr_wmask[`CSR_TLBIDX_NE] & csr_wvalue[`CSR_TLBIDX_NE] |
                            ~csr_wmask[`CSR_TLBIDX_NE] & csr_tlbidx_ne;
        end
    end

    // TLBEHI
    always @ (posedge clk) begin
        if (reset) begin
            csr_tlbehi_vppn <= 19'b0;
        end 
        else if (tlbrd_we) begin
            if(r_e)
                csr_tlbehi_vppn <= r_vppn;
            else    
                csr_tlbehi_vppn <= 19'b0;
        end 
        else if (csr_we && csr_num == `CSR_TLBEHI) begin
            csr_tlbehi_vppn <= csr_wmask[`CSR_TLBEHI_VPPN] & csr_wvalue[`CSR_TLBEHI_VPPN] |
                              ~csr_wmask[`CSR_TLBEHI_VPPN] & csr_tlbehi_vppn;
        end
    end

    // TLBELO0 and TLBELO1
    always @ (posedge clk) begin
        if (reset) begin
            csr_tlbelo0_v   <= 1'b0;
            csr_tlbelo0_d   <= 1'b0;
            csr_tlbelo0_plv <= 2'b0;
            csr_tlbelo0_mat <= 2'b0;
            csr_tlbelo0_g   <= 1'b0;
            csr_tlbelo0_ppn <= 24'b0;

            csr_tlbelo1_v   <= 1'b0;
            csr_tlbelo1_d   <= 1'b0;
            csr_tlbelo1_plv <= 2'b0;
            csr_tlbelo1_mat <= 2'b0;
            csr_tlbelo1_g   <= 1'b0;
            csr_tlbelo1_ppn <= 24'b0;
        end 
        else if (tlbrd_we) begin
            if(r_e) begin
                csr_tlbelo0_v   <= r_v0;
                csr_tlbelo0_d   <= r_d0;
                csr_tlbelo0_plv <= r_plv0;
                csr_tlbelo0_mat <= r_mat0;
                csr_tlbelo0_g   <= r_g;
                csr_tlbelo0_ppn <= {4'b0, r_ppn0};

                csr_tlbelo1_v   <= r_v1;
                csr_tlbelo1_d   <= r_d1;
                csr_tlbelo1_plv <= r_plv1;
                csr_tlbelo1_mat <= r_mat1;
                csr_tlbelo1_g   <= r_g;
                csr_tlbelo1_ppn <= {4'b0, r_ppn1};
            end
            else begin
                csr_tlbelo0_v   <= 1'b0;
                csr_tlbelo0_d   <= 1'b0;
                csr_tlbelo0_plv <= 2'b0;
                csr_tlbelo0_mat <= 2'b0;
                csr_tlbelo0_g   <= 1'b0;
                csr_tlbelo0_ppn <= 24'b0;

                csr_tlbelo1_v   <= 1'b0;
                csr_tlbelo1_d   <= 1'b0;
                csr_tlbelo1_plv <= 2'b0;
                csr_tlbelo1_mat <= 2'b0;
                csr_tlbelo1_g   <= 1'b0;
                csr_tlbelo1_ppn <= 24'b0;
            end
        end 
        else if (csr_we) begin
            if (csr_num == `CSR_TLBELO0) begin
                csr_tlbelo0_v   <= csr_wmask[`CSR_TLBELO_V]   & csr_wvalue[`CSR_TLBELO_V]   |
                                  ~csr_wmask[`CSR_TLBELO_V]   & csr_tlbelo0_v;
                csr_tlbelo0_d   <= csr_wmask[`CSR_TLBELO_D]   & csr_wvalue[`CSR_TLBELO_D]   |
                                  ~csr_wmask[`CSR_TLBELO_D]   & csr_tlbelo0_d;
                csr_tlbelo0_plv <= csr_wmask[`CSR_TLBELO_PLV] & csr_wvalue[`CSR_TLBELO_PLV] |
                                  ~csr_wmask[`CSR_TLBELO_PLV] & csr_tlbelo0_plv;
                csr_tlbelo0_mat <= csr_wmask[`CSR_TLBELO_MAT] & csr_wvalue[`CSR_TLBELO_MAT] |
                                  ~csr_wmask[`CSR_TLBELO_MAT] & csr_tlbelo0_mat;
                csr_tlbelo0_g   <= csr_wmask[`CSR_TLBELO_G]   & csr_wvalue[`CSR_TLBELO_G]   |
                                  ~csr_wmask[`CSR_TLBELO_G]   & csr_tlbelo0_g;
                csr_tlbelo0_ppn <= csr_wmask[`CSR_TLBELO_PPN] & csr_wvalue[`CSR_TLBELO_PPN] |
                                  ~csr_wmask[`CSR_TLBELO_PPN] & csr_tlbelo0_ppn;
            end 
            else if (csr_num == `CSR_TLBELO1) begin
                csr_tlbelo1_v   <= csr_wmask[`CSR_TLBELO_V]   & csr_wvalue[`CSR_TLBELO_V]   |
                                  ~csr_wmask[`CSR_TLBELO_V]   & csr_tlbelo1_v;
                csr_tlbelo1_d   <= csr_wmask[`CSR_TLBELO_D]   & csr_wvalue[`CSR_TLBELO_D]   |
                                  ~csr_wmask[`CSR_TLBELO_D]   & csr_tlbelo1_d;
                csr_tlbelo1_plv <= csr_wmask[`CSR_TLBELO_PLV] & csr_wvalue[`CSR_TLBELO_PLV] |
                                  ~csr_wmask[`CSR_TLBELO_PLV] & csr_tlbelo1_plv;
                csr_tlbelo1_mat <= csr_wmask[`CSR_TLBELO_MAT] & csr_wvalue[`CSR_TLBELO_MAT] |
                                  ~csr_wmask[`CSR_TLBELO_MAT] & csr_tlbelo1_mat;
                csr_tlbelo1_g   <= csr_wmask[`CSR_TLBELO_G]   & csr_wvalue[`CSR_TLBELO_G]   |
                                  ~csr_wmask[`CSR_TLBELO_G]   & csr_tlbelo1_g;
                csr_tlbelo1_ppn <= csr_wmask[`CSR_TLBELO_PPN] & csr_wvalue[`CSR_TLBELO_PPN] |
                                  ~csr_wmask[`CSR_TLBELO_PPN] & csr_tlbelo1_ppn;
            end
        end
    end

    // ASID
    always @ (posedge clk) begin
        if (reset) begin
            csr_asid <= 10'b0;
        end 
        else if (tlbrd_we) begin
            if(r_e)
                csr_asid <= r_asid;
            else
                csr_asid <= 10'b0;
        end 
        else if (csr_we && csr_num == `CSR_ASID) begin
            csr_asid <= csr_wmask[`CSR_ASID_ASID] & csr_wvalue[`CSR_ASID_ASID] |
                        ~csr_wmask[`CSR_ASID_ASID] & csr_asid;
        end
    end

    assign csr_asid_asidbits = 8'd10;

    // TLBRENTRY
    always @ (posedge clk) begin
        if (reset) begin
            csr_tlbrentry_pa <= 26'b0;
        end 
        else if (csr_we && csr_num == `CSR_TLBRENTRY) begin
            csr_tlbrentry_pa <= csr_wmask[`CSR_TLBRENTRY_PA] & csr_wvalue[`CSR_TLBRENTRY_PA] |
                               ~csr_wmask[`CSR_TLBRENTRY_PA] & csr_tlbrentry_pa;
        end
    end

    assign csr_tlbidx_rvalue = {csr_tlbidx_ne, 1'b0, csr_tlbidx_ps, 20'b0, csr_tlbidx_index};
    assign csr_tlbehi_rvalue = {csr_tlbehi_vppn, 13'b0};
    assign csr_tlbelo0_rvalue = {csr_tlbelo0_ppn, 1'b0, csr_tlbelo0_g, csr_tlbelo0_mat, csr_tlbelo0_plv, csr_tlbelo0_d, csr_tlbelo0_v};
    assign csr_tlbelo1_rvalue = {csr_tlbelo1_ppn, 1'b0, csr_tlbelo1_g, csr_tlbelo1_mat, csr_tlbelo1_plv, csr_tlbelo1_d, csr_tlbelo1_v};
    assign csr_asid_rvalue = {8'b0, csr_asid_asidbits, 6'b0, csr_asid};
    assign csr_tlbrentry_rvalue = {csr_tlbrentry_pa, 6'b0};

    // DMW0-1
    always @(posedge clk ) begin
        if(reset) begin
            csr_dmw0_plv0 <= 1'b0;
            csr_dmw0_plv3 <= 1'b0;
            csr_dmw0_mat  <= 2'b0;
            csr_dmw0_pseg <= 3'b0;
            csr_dmw0_vseg <= 3'b0;
        end
        else if(csr_we && csr_num == `CSR_DMW0)begin
            csr_dmw0_plv0  <= csr_wmask[`CSR_DMW_PLV0] & csr_wvalue[`CSR_DMW_PLV0]
                        | ~csr_wmask[`CSR_DMW_PLV0] & csr_dmw0_plv0; 
            csr_dmw0_plv3  <= csr_wmask[`CSR_DMW_PLV3] & csr_wvalue[`CSR_DMW_PLV3]
                        | ~csr_wmask[`CSR_DMW_PLV3] & csr_dmw0_plv3; 
            csr_dmw0_mat   <= csr_wmask[`CSR_DMW_MAT] & csr_wvalue[`CSR_DMW_MAT]
                        | ~csr_wmask[`CSR_DMW_MAT] & csr_dmw0_mat; 
            csr_dmw0_pseg  <= csr_wmask[`CSR_DMW_PSEG] & csr_wvalue[`CSR_DMW_PSEG]
                        | ~csr_wmask[`CSR_DMW_PSEG] & csr_dmw0_pseg;
            csr_dmw0_vseg  <= csr_wmask[`CSR_DMW_VSEG] & csr_wvalue[`CSR_DMW_VSEG]
                        | ~csr_wmask[`CSR_DMW_VSEG] & csr_dmw0_vseg;   
        end
    end

    always @(posedge clk ) begin
        if(reset) begin
            csr_dmw1_plv0 <= 1'b0;
            csr_dmw1_plv3 <= 1'b0;
            csr_dmw1_mat  <= 2'b0;
            csr_dmw1_pseg <= 3'b0;
            csr_dmw1_vseg <= 3'b0;
        end
        else if(csr_we && csr_num == `CSR_DMW1)begin
            csr_dmw1_plv0  <= csr_wmask[`CSR_DMW_PLV0] & csr_wvalue[`CSR_DMW_PLV0]
                        | ~csr_wmask[`CSR_DMW_PLV0] & csr_dmw1_plv0; 
            csr_dmw1_plv3  <= csr_wmask[`CSR_DMW_PLV3] & csr_wvalue[`CSR_DMW_PLV3]
                        | ~csr_wmask[`CSR_DMW_PLV3] & csr_dmw1_plv3; 
            csr_dmw1_mat   <= csr_wmask[`CSR_DMW_MAT] & csr_wvalue[`CSR_DMW_MAT]
                        | ~csr_wmask[`CSR_DMW_MAT] & csr_dmw1_mat; 
            csr_dmw1_pseg  <= csr_wmask[`CSR_DMW_PSEG] & csr_wvalue[`CSR_DMW_PSEG]
                        | ~csr_wmask[`CSR_DMW_PSEG] & csr_dmw1_pseg;
            csr_dmw1_vseg  <= csr_wmask[`CSR_DMW_VSEG] & csr_wvalue[`CSR_DMW_VSEG]
                        | ~csr_wmask[`CSR_DMW_VSEG] & csr_dmw1_vseg;   
        end
    end


    // CSR 的读出逻辑
    assign csr_dmw0_data = {csr_dmw0_vseg, 1'b0, csr_dmw0_pseg, 19'b0, csr_dmw0_mat, csr_dmw0_plv3, 2'b0, csr_dmw0_plv0};
    assign csr_dmw1_data = {csr_dmw1_vseg, 1'b0, csr_dmw1_pseg, 19'b0, csr_dmw1_mat, csr_dmw1_plv3, 2'b0, csr_dmw1_plv0};
    assign csr_crmd_data  = {23'b0, csr_crmd_datm, csr_crmd_datf, csr_crmd_pg, 
                            csr_crmd_da, csr_crmd_ie, csr_crmd_plv};
    assign csr_prmd_data  = {29'b0, csr_prmd_pie, csr_prmd_pplv};
    assign csr_ecfg_data  = {19'b0, csr_ecfg_lie};
    assign csr_estat_data = { 1'b0, csr_estat_esubcode, csr_estat_ecode, 3'b0, csr_estat_is};
    assign csr_eentry_data= {csr_eentry_va, 6'b0};
    assign csr_badv_data  = csr_badv_vaddr;
    assign csr_tid_data   = csr_tid_tid;
    assign csr_tcfg_data  = {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};
    assign csr_ticlr_data = {31'b0, csr_ticlr_clr};
    assign csr_asid_data  = csr_asid_rvalue;
    assign csr_rvalue = {32{csr_num == `CSR_CRMD  }} & csr_crmd_data
                      | {32{csr_num == `CSR_PRMD  }} & csr_prmd_data
                      | {32{csr_num == `CSR_ECFG  }} & csr_ecfg_data
                      | {32{csr_num == `CSR_ESTAT }} & csr_estat_data
                      | {32{csr_num == `CSR_ERA   }} & csr_era_data
                      | {32{csr_num == `CSR_EENTRY}} & csr_eentry_data
                      | {32{csr_num == `CSR_SAVE0 }} & csr_save0_data
                      | {32{csr_num == `CSR_SAVE1 }} & csr_save1_data
                      | {32{csr_num == `CSR_SAVE2 }} & csr_save2_data
                      | {32{csr_num == `CSR_SAVE3 }} & csr_save3_data
                      | {32{csr_num == `CSR_BADV  }} & csr_badv_data
                      | {32{csr_num == `CSR_TID   }} & csr_tid_data
                      | {32{csr_num == `CSR_TCFG  }} & csr_tcfg_data
                      | {32{csr_num == `CSR_TVAL  }} & csr_tval_data
                      | {32{csr_num == `CSR_TICLR }} & csr_ticlr_data 
                      | {32{csr_num == `CSR_TLBIDX}} & csr_tlbidx_rvalue
                      | {32{csr_num == `CSR_TLBEHI}} & csr_tlbehi_rvalue
                      | {32{csr_num == `CSR_TLBELO0}} & csr_tlbelo0_rvalue
                      | {32{csr_num == `CSR_TLBELO1}} & csr_tlbelo1_rvalue
                      | {32{csr_num == `CSR_ASID  }} & csr_asid_rvalue
                      | {32{csr_num == `CSR_TLBRENTRY}} & csr_tlbrentry_rvalue;

    assign w_e    = ~csr_tlbidx_ne;
    assign w_ps   =  csr_tlbidx_ps;
    assign w_vppn =  csr_tlbehi_vppn;
    assign w_asid =  csr_asid;
    assign w_g    =  csr_tlbelo0_g & csr_tlbelo1_g;

    assign w_ppn0 = csr_tlbelo0_ppn[19:0];
    assign w_plv0 = csr_tlbelo0_plv;
    assign w_mat0 = csr_tlbelo0_mat;
    assign w_d0   = csr_tlbelo0_d;
    assign w_v0   = csr_tlbelo0_v;

    assign w_ppn1 = csr_tlbelo1_ppn[19:0];
    assign w_plv1 = csr_tlbelo1_plv;
    assign w_mat1 = csr_tlbelo1_mat;
    assign w_d1   = csr_tlbelo1_d;
    assign w_v1   = csr_tlbelo1_v;

endmodule