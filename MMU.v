`include "width.h"

module MMU(
    input wire         MMU_mode,//0 for inst, 1 for data
    input wire [9:0]   input_asid,
    //va & pa
    input  wire [31:0] va,
    output wire [31:0] pa,

    //tlb interface
    output wire [18:0] s_vppn,
    output wire        s_va_bit12,
    output wire [ 9:0] s_asid,
    input  wire        s_found,
    input  wire [19:0] s_ppn,
    input  wire [ 5:0] s_ps,
    input  wire [ 1:0] s_plv,
    input  wire [ 1:0] s_mat,
    input  wire        s_d,
    input  wire        s_v,

    //from csr
    input  wire [31:0] csr_crmd_data,
    input  wire [31:0] csr_dmw0_data,
    input  wire [31:0] csr_dmw1_data,
    input  wire [31:0] csr_asid_data,
    //exception  
    output wire        ex_TLBR,
    output wire        ex_PIx,
    output wire        ex_PPI,
    output wire        ex_PME,
    output wire        tlb_map
);
    wire        csr_crmd_da;
    wire        csr_crmd_pg;
    wire [1:0]  csr_crmd_plv;

    wire        dmw0_hit;
    wire        dmw1_hit;
    wire [31:0] dmw_pa0;
    wire [31:0] dmw_pa1;
    wire [31:0] tlb_pa;

    wire        direct_mode;
    wire        map_mode;

//vitual addr to physical addr

    //crmd signals
    assign csr_crmd_da   = csr_crmd_data[3];
    assign csr_crmd_pg   = csr_crmd_data[4];
    assign csr_crmd_plv  = csr_crmd_data[1:0];

    //translate mode
    assign direct_mode   = csr_crmd_da & ~csr_crmd_pg;
    assign map_mode      = ~csr_crmd_da & csr_crmd_pg;

    //direct mapping hit
    assign dmw0_hit =   map_mode & csr_dmw0_data[csr_crmd_plv] & 
                        (csr_dmw0_data[31:29] == va[31:29]);
    assign dmw1_hit =   map_mode & csr_dmw1_data[csr_crmd_plv] & 
                        (csr_dmw1_data[31:29] == va[31:29]);
    //direct mapping physical addr
    assign dmw_pa0  =   {csr_dmw0_data[27:25], va[28:0]}; //csr_dmw_rvalue[27:25] = csr_dmw_pseg
    assign dmw_pa1  =   {csr_dmw1_data[27:25], va[28:0]}; 

    //tlb mapping
    assign tlb_map  =   ~dmw0_hit & ~dmw1_hit & map_mode;
    assign {s_vppn, s_va_bit12} = va[31:12];
    assign s_asid  =   MMU_mode ? input_asid : csr_asid_data[9:0];

    assign tlb_pa   =  {32{s_ps == 6'd12}} & {s_ppn[19:0], va[11:0]} |
                       {32{s_ps == 6'd21}} & {s_ppn[19:9], va[20:0]};

    //physical addr
    assign pa    =  direct_mode ? va
                  : dmw0_hit    ? dmw_pa0
                  : dmw1_hit    ? dmw_pa1
                  : tlb_pa; 
    
    //exception
    assign ex_TLBR = tlb_map & (~s_found);
    assign ex_PIx = tlb_map & (~s_v); // PIF | PIL | PIS according to mem_type
    assign ex_PPI = tlb_map & (csr_crmd_plv > s_plv);
    assign ex_PME = tlb_map & (~s_d) & MMU_mode;

endmodule