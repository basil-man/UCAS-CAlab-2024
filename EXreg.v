`include "width.h"
module EXreg(
    input wire clk,
    input wire resetn,
    output wire es_allowin,
    input wire ds_to_es_valid,
    input wire [`D2E_WID] ds_to_es_bus,     // from 155bit -> 196bit (add from_ds_except, inst_rdcnt**, csr_rvalue, csr_re)
    input wire [`D2E_MINST_WID] ds_mem_inst_bus,
    input wire ms_allowin,
    output wire [`E_RFC_WID] es_rf_collect,    // {es_res_from_mem, es_rf_we, es_rf_waddr, es_alu_result}
    output wire es_to_ms_valid,
    output reg [31:0] es_pc,
    output wire         data_sram_req,
    output wire [ 3:0]  data_sram_wstrb,
    output wire [31:0]  data_sram_addr,
    output wire [31:0]  data_sram_wdata,
    output wire         data_sram_wr,
    output wire [ 1:0]  data_sram_size,
    input  wire         data_sram_addr_ok,
    output reg  [4:0]   es_mem_inst_bus,
    output wire [31:0] es_result,
    output wire [`E2M_WID] es_to_ms_bus,

    input wire except_flush,
    input wire [`E2M_EXCEPT_WID] ms_except,
    input wire [`D2E_RDCNT_WID] collect_inst_rd_cnt,
    output wire [`E_EXCEPT_WID] es_except_collect,
    input  wire wb_ex
);
    //debug signalse
    wire bus_we;
    wire bus_es_res_from_mem;
    wire inst_ld_w, inst_ld_h, inst_ld_hu, inst_ld_b, inst_ld_bu;
    wire inst_mul_w, inst_mulh_w, inst_mulh_wu, inst_div_w, inst_mod_w, inst_div_wu, inst_mod_wu; //mul & div insts
    wire long_insts    = inst_div_w | inst_mod_w | inst_div_wu | inst_mod_wu; //insts that need multi cycles, reserved for future extension
    wire div_mod_insts = inst_div_w | inst_mod_w | inst_div_wu | inst_mod_wu; //div insts
    wire mul_insts     = inst_mul_w | inst_mulh_w | inst_mulh_wu; //mul insts
    
    //mul & div results
    wire [31:0]mul_result;
    wire [31:0] div_result;
    wire [31:0] mod_result;
    wire [63:0] unsigned_prod, signed_prod;
    wire div_mod_done;
    wire [31:0] signed_quot;
    wire [63:0] signed_divider_res;
    wire [63:0] unsigned_divider_res;
    wire [31:0] div_mod_result;
    wire [31:0] EX_result;
    
    wire         es_ready_go;
    reg          es_valid;
    
    reg  [18:0] extend_es_alu_op;
    wire [11:0] es_alu_op;
    reg  [31:0] es_alu_src1;
    reg  [31:0] es_alu_src2;
    wire [31:0] es_alu_result;
    reg  [31:0] es_rkd_value;
    reg          es_res_from_mem;
    reg          es_mem_en;
    reg          es_rf_we;
    reg  [4 : 0] es_rf_waddr;
    wire [31:0] es_mem_result;
    
    wire handshake_done;

    reg inst_st_w,inst_st_h,inst_st_b;
    wire inst_st;
    wire [3:0] mem_we;
    reg reg_div_mod_done;
    wire [31:0] st_wdata;
    
    reg csr_re;
    reg [5:0] from_ds_except;
    
    wire es_ale_except;
    reg [31:0] csr_rvalue;
    reg inst_rdcntvl;
    reg inst_rdcntvh;
    reg [1:0] tmp;
    wire ms_adef_except, ms_ine_except, ms_syscall_except, ms_break_except, ms_int_except, inst_ertn;

    wire flush_by_former_except =(|es_except_collect) | (|es_except_collect) | except_flush;

    wire es_ex;
    wire es_mem_req;

    assign es_ex          = (|es_except_collect) & es_valid;
    assign es_ready_go    = (long_insts ? reg_div_mod_done : 1'b1) & (~data_sram_req | data_sram_req & data_sram_addr_ok); //for further extension
    assign es_allowin     = ~es_valid | es_ready_go & ms_allowin;
    assign es_to_ms_valid = es_valid & es_ready_go;
    
    always @(posedge clk) begin
        if (~resetn||except_flush) begin
            es_valid <= 1'b0;
            end else if (es_allowin) begin
            es_valid <= ds_to_es_valid;
        end
    end
    always @(posedge clk) begin
        if (~resetn) begin
            {tmp, from_ds_except, extend_es_alu_op, es_res_from_mem, es_alu_src1, es_alu_src2,
            es_mem_en, es_rf_we, es_rf_waddr, es_rkd_value, es_pc, csr_rvalue, csr_re} <= 196'b0;
            {inst_st_w,inst_st_h,inst_st_b} <= 3'b000;
            es_mem_inst_bus <= 5'd0;
            {inst_rdcntvl,inst_rdcntvh} <= 2'b00;
        end else if (ds_to_es_valid & es_allowin) begin
            {tmp, from_ds_except, extend_es_alu_op, es_res_from_mem, es_alu_src1, es_alu_src2,
            es_mem_en, es_rf_we, es_rf_waddr, es_rkd_value, es_pc, csr_rvalue, csr_re} <= ds_to_es_bus;
            {inst_st_w,inst_st_h,inst_st_b} <= ds_mem_inst_bus[2:0];
            es_mem_inst_bus <= ds_mem_inst_bus[7:3];
            {inst_rdcntvl,inst_rdcntvh} <= collect_inst_rd_cnt;
        end
    end
    assign {inst_mul_w, inst_mulh_w, inst_mulh_wu, inst_div_w, inst_mod_w, inst_div_wu, inst_mod_wu, es_alu_op} = extend_es_alu_op;

    assign {inst_ld_w, inst_ld_h, inst_ld_hu, inst_ld_b, inst_ld_bu}=es_mem_inst_bus;
    // mul
    assign unsigned_prod = es_alu_src1 * es_alu_src2;
    assign signed_prod   = $signed(es_alu_src1) * $signed(es_alu_src2);
    assign mul_result = ({32{inst_mul_w}} & signed_prod[31:0])
                        | ({32{inst_mulh_w}} & signed_prod[63:32])
                        | ({32{inst_mulh_wu}} & unsigned_prod[63:32]);
    // div
    reg handshake_flag;
    assign div_mod_done = handshake_flag & (((inst_div_w || inst_mod_w) && signed_dout_tvalid)||((inst_div_wu || inst_mod_wu) && unsigned_dout_tvalid));
    
    always @(posedge clk) begin
        if (~resetn) begin
            reg_div_mod_done <= 1'b0;
            end else if (es_valid & es_allowin) begin
            reg_div_mod_done <= 1'b0;
            end else if (div_mod_done) begin
            reg_div_mod_done <= 1'b1;
        end
    end
    reg
    signed_dividend_tvalid,
    signed_divisor_tvalid,
    unsigned_dividend_tvalid,
    unsigned_divisor_tvalid;
    reg valid_cnt;
    always @(posedge clk) begin
        if (~resetn) begin
            valid_cnt <= 0;
        end else if (es_valid & es_allowin) begin
            valid_cnt <= 0;
        end else if (div_mod_insts) begin
            valid_cnt <= 1;
        end
    end
    
    always @(posedge clk) begin
        if (~resetn) begin
            handshake_flag <= 1'b0;
        end else if (es_valid & es_allowin) begin
            handshake_flag <= 1'b0;
        end else if ((signed_dividend_tvalid&&signed_dividend_tready)||(unsigned_dividend_tvalid&&unsigned_dividend_tready)) begin
            handshake_flag <= 1'b1;
        end
    end
    
    assign handshake_done = (signed_dividend_tvalid&&signed_dividend_tready&&signed_divisor_tready)||(unsigned_dividend_tvalid&&unsigned_dividend_tready&&unsigned_divisor_tready);
    //this always block can be separated for multi driven problem
    always @(posedge clk) begin //valid signal for divider, only valid when both src1 and src2 are ready
        if (~resetn||handshake_done) begin
            //reset to zero when divider is ready or reset
            signed_dividend_tvalid   <= 1'b0;
            signed_divisor_tvalid    <= 1'b0;
            unsigned_dividend_tvalid <= 1'b0;
            unsigned_divisor_tvalid  <= 1'b0;
            end else if (div_mod_insts&&~valid_cnt) begin
            signed_dividend_tvalid   <= inst_div_w || inst_mod_w;
            signed_divisor_tvalid    <= inst_div_w || inst_mod_w;
            unsigned_dividend_tvalid <= inst_div_wu || inst_mod_wu;
            unsigned_divisor_tvalid  <= inst_div_wu || inst_mod_wu;
        end
    end
    
    mydiv mydiv_signed (
        .aclk(clk),
        
        .s_axis_dividend_tdata (es_alu_src1),
        .s_axis_dividend_tready(signed_dividend_tready),
        .s_axis_dividend_tvalid(signed_dividend_tvalid),
        
        .s_axis_divisor_tdata (es_alu_src2),
        .s_axis_divisor_tready(signed_divisor_tready),
        .s_axis_divisor_tvalid(signed_divisor_tvalid),
        
        .m_axis_dout_tdata (signed_divider_res),
        .m_axis_dout_tvalid(signed_dout_tvalid)
    );
    
    
    mydiv_unsigned mydiv_unsigned (
        .aclk(clk),
        
        .s_axis_dividend_tdata (es_alu_src1),
        .s_axis_dividend_tready(unsigned_dividend_tready),
        .s_axis_dividend_tvalid(unsigned_dividend_tvalid),
        
        .s_axis_divisor_tdata (es_alu_src2),
        .s_axis_divisor_tready(unsigned_divisor_tready),
        .s_axis_divisor_tvalid(unsigned_divisor_tvalid),
        
        .m_axis_dout_tdata (unsigned_divider_res),
        .m_axis_dout_tvalid(unsigned_dout_tvalid)
    );
    
    
    //inst_div_w | inst_mod_w | inst_div_wu | inst_mod_wu
    assign div_mod_result = ({32{inst_div_w}} & signed_divider_res[63:32])
                            | ({32{inst_mod_w}} & signed_divider_res[31:0])
                            | ({32{inst_div_wu}} & unsigned_divider_res[63:32])
                            | ({32{inst_mod_wu}} & unsigned_divider_res[31:0]);

    // add in exp12: exception part
    
     assign es_ale_except = ((|es_alu_result[1:0]) & (inst_st_w | inst_ld_w)|
                         es_alu_result[0] & (inst_st_h | inst_ld_hu | inst_ld_h)) & es_valid;

    assign es_except_collect = {es_ale_except, from_ds_except} & {7{es_valid}};

    alu u_alu (
        .alu_op    (es_alu_op),
        .alu_src1  (es_alu_src1),
        .alu_src2  (es_alu_src2),
        .alu_result(es_alu_result)
    );


    //assign {inst_st_w,inst_st_h,inst_st_b}= ds_mem_inst_bus[2:0];
    assign inst_st = inst_st_w | inst_st_h | inst_st_b;
    assign mem_we = {4{inst_st_b}} & {4'b0001 << (es_alu_result[1:0] )} |
                    {4{inst_st_h}} & {4'b0011 << {es_alu_result[1],1'b0}} |
                    {4{inst_st_w}} & 4'b1111;
    assign st_wdata = {32{inst_st_b}} & {4{es_rkd_value[7:0]}}
                    | {32{inst_st_h}} & {2{es_rkd_value[15:0]}}
                    | {32{inst_st_w}} & {es_rkd_value[31:0]};

    //cnt
    reg [63:0] cnt;
    always @(posedge clk) begin
        if (~resetn) begin
            cnt <= 64'b0;
        end else begin
            cnt <= cnt + 1'b1;
        end
        
    end

    //assign es_mem_inst_bus = ds_mem_inst_bus[7:3];
    // pass ld inst mem_inst_bus 
    
    assign EX_result = mul_insts ? mul_result : div_mod_insts ? div_mod_result : es_alu_result;
    wire [31:0] ex_to_ms_result =inst_rdcntvl ? cnt[31:0] : inst_rdcntvh ? cnt[63:32] : (csr_re ? csr_rvalue : EX_result);

    assign data_sram_req    = (es_res_from_mem || es_mem_en) & es_valid & ~flush_by_former_except & es_mem_req;
    assign data_sram_wstrb  = mem_we & {4{es_valid & ~|ms_except & ~|es_except_collect & ~except_flush & ~flush_by_former_except}};
    assign data_sram_wr     = (|data_sram_wstrb) & es_valid & ~es_ex;
    assign data_sram_addr   = {es_alu_result[31:2],2'b00};
    assign data_sram_wdata  = st_wdata;
    assign data_sram_size   = ({2{inst_st_w}} & 2'b10) | ({2{inst_st_h}} & 2'b01) | ({2{inst_st_b}} & 2'b00);
    assign bus_we           = es_rf_we & es_valid;
    assign bus_es_res_from_mem = es_res_from_mem & es_valid;
    assign es_mem_req       = (es_res_from_mem | (|data_sram_wstrb));


    assign es_to_ms_bus =   {
                            es_mem_req,
                            es_except_collect
                            };

    assign es_rf_collect =  {
                            bus_es_res_from_mem,
                            bus_we,
                            es_rf_waddr,
                            ex_to_ms_result
                            };
    assign {ms_adef_except, ms_ine_except, ms_syscall_except, ms_break_except, ms_int_except, inst_ertn} = ms_except;
    
endmodule
