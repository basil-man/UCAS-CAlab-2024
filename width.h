`define DATA_WIDTH 31:0
`define DATA_WID 31:0 //vvvvvvvvvvvvvvv

//总线长度命名规范
//type1:用于一对一连接的总线
//X2Y_ZZ(C)_WIDTH
//X:发送流水级
//Y:接收流水级
//ZZ(C):内容(除了最初的bus之外，其他的bus)
//type2:用于一对多连接的总线
//X_ZZ(C)_WIDTH
//X:发送流水级
//csr.v简称为C
//AXI简称为A
//TLB简称为T

//bus width between stages
`define F2D_WID 68:0
`define D2E_WID 221:0
`define E2M_WID 67:0
`define M2W_WID 64:0

//mem inst (ld/st) bus width
`define D2E_MINST_WID 7:0
`define E2M_MINST_WID 4:0

//regfile related (we,waddr,result..)bus width 
`define E_RFC_WID 39:0
`define M_RFC_WID 39:0
`define W_RFC_WID 37:0

//br_collect(br_taken,br_target) ID->IF bus width
`define D2F_BRC_WID 33:0

//csr.v related bus width
`define D2C_CSRNUM_WID 13:0
`define D2C_CSRWMASK_WID 31:0
`define D2C_CSRWVAL_WID 31:0
`define D2C_CSRC_WID 79:0
`define W2C_ECODE_WID 5:0
`define W2C_ESUBCODE_WID 8:0

//except related bus width
`define E2M_EXCEPT_WID 15:0

//rdcnt related bus width
`define D2E_RDCNT_WID 1:0

//forward exception bus width
`define E_EXCEPT_WID 15:0
`define M_EXCEPT_WID 15:0

//AXI related bus width
`define A_ID_WID 3:0
`define A_LEN_WID 7:0
`define A_SIZE_WID 2:0
`define A_BURST_WID 1:0
`define A_LOCK_WID 1:0
`define A_CACHE_WID 3:0
`define A_PROT_WID 2:0
`define A_STRB_WID 3:0
`define A_RESP_WID 1:0

//TLB related bus width in exp 18
`define T_ASID_WID 9:0
`define T_VPPN_WID 18:0
`define T_PPN_WID  19:0
`define T_IDX_WID  3:0
`define T_PS_WID   5:0
`define T_plv_WID  1:0
`define T_MAT_WID  1:0

`define CSR_WE 64
`define CSR_NUM 78:55