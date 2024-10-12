module MEMreg(
    input  wire        clk,
    input  wire        resetn,
    // ex and mem state interface
    output wire        ms_allowin,
    input  wire [38:0] es_rf_collect, // es_to_ms_bus  {es_res_from_mem, es_rf_we, es_rf_waddr, es_rf_wdata}
    input  wire        es_to_ms_valid,
    input  wire [31:0] es_pc,    
    // mem and wb state interface
    input  wire        ws_allowin,
    output wire [37:0] ms_rf_collect, // {ms_rf_we, ms_rf_waddr, ms_rf_wdata}
    output wire        ms_to_ws_valid,
    output reg  [31:0] ms_pc,
    // data sram interface
    input  wire [31:0] data_sram_rdata,
    input  wire [4:0]  mem_inst_bus,
    input  wire [6:0]  es_to_ms_bus,
    output wire [6:0]  ms_to_ws_bus,

    input wire except_flush,
    output reg [6:0] ms_except
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

    // add in exp12

    assign ms_ready_go  = 1'b1;
    assign ms_allowin   = ~ms_valid | ms_ready_go & ws_allowin;     
    assign ms_to_ws_valid  = ms_valid & ms_ready_go;
    
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
            {ms_res_from_mem, ms_rf_we, ms_rf_waddr, ms_alu_result} <= 38'b0;
            {inst_ld_w,inst_ld_h,inst_ld_hu,inst_ld_b,inst_ld_bu} <= 5'd0;
            {ms_except} <= 7'b0;
        end
        if (es_to_ms_valid & ms_allowin) begin
            ms_pc <= es_pc;
            {ms_res_from_mem, ms_rf_we, ms_rf_waddr, ms_alu_result} <= es_rf_collect;
            {inst_ld_w,inst_ld_h,inst_ld_hu,inst_ld_b,inst_ld_bu} <= mem_inst_bus;
            {ms_except} <= es_to_ms_bus;
        end
    end

    //assign {inst_ld_w,inst_ld_h,inst_ld_hu,inst_ld_b,inst_ld_bu} = mem_inst_bus;
    assign inst_ld = inst_ld_w | inst_ld_h | inst_ld_hu | inst_ld_b | inst_ld_bu;
    assign is_sign_extend = inst_ld_h | inst_ld_b;
    assign word_rdata = data_sram_rdata;
    assign half_rdata = {32{!ms_alu_result[1]}} & {{16{data_sram_rdata[15] & is_sign_extend}}, data_sram_rdata[15:0]} |
                        {32{ ms_alu_result[1]}} & {{16{data_sram_rdata[31] & is_sign_extend}}, data_sram_rdata[31:16]};
    assign byte_rdata = {32{ ms_alu_result[1:0] == 2'b00}} & {{24{data_sram_rdata[7] & is_sign_extend}}, data_sram_rdata[7:0]} |
                        {32{ ms_alu_result[1:0] == 2'b01}} & {{24{data_sram_rdata[15] & is_sign_extend}}, data_sram_rdata[15:8]} |
                        {32{ ms_alu_result[1:0] == 2'b10}} & {{24{data_sram_rdata[23] & is_sign_extend}}, data_sram_rdata[23:16]} |
                        {32{ ms_alu_result[1:0] == 2'b11}} & {{24{data_sram_rdata[31] & is_sign_extend}}, data_sram_rdata[31:24]};
    assign ms_mem_result = inst_ld_w ? word_rdata : ((inst_ld_h | inst_ld_hu) ? half_rdata : (inst_ld_b|inst_ld_bu) ? byte_rdata : 32'b0);
    assign ms_rf_wdata      = ms_res_from_mem ? ms_mem_result : ms_alu_result;
    assign ms_rf_collect    = {ms_rf_we & ms_valid, ms_rf_waddr, ms_rf_wdata};

    // add in exp12:
    assign ms_to_ws_bus =   {
                            ms_except
                            };

endmodule