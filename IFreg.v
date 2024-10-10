module IFreg(
    input  wire   clk,
    input  wire   resetn,
    // inst sram interface
    output wire         inst_sram_en,
    output wire [ 3:0]  inst_sram_we,
    output wire [31:0]  inst_sram_addr,
    output wire [31:0]  inst_sram_wdata,
    input  wire [31:0]  inst_sram_rdata,
    // ds to fs interface
    input  wire         ds_allowin,
    input  wire [32:0]  br_collect,
    // fs to ds interface
    output wire         fs_to_ds_valid,
    output wire [64:0]  fs_to_ds_bus
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

    // add in exp12
    wire fetch_inst_error;

    assign fetch_inst_error = (|fs_pc[1:0]) & fs_valid;

    assign {br_taken, br_target} = br_collect;

    assign fs_to_ds_bus = {fs_inst, fs_pc};

    assign seq_pc   = fs_pc + 3'h4;
    assign nextpc   = br_taken ? br_target : seq_pc;

    assign to_fs_valid      = resetn;
    assign fs_ready_go      = 1'b1;
    assign fs_allowin       = ~fs_valid | fs_ready_go & ds_allowin;     
    assign fs_to_ds_valid   = fs_valid & fs_ready_go;
    
    always @(posedge clk) begin
        if (~resetn) begin
            fs_valid <= 1'b0;
        end else if (fs_allowin) begin
            fs_valid <= to_fs_valid;
        end
    end
    
    assign inst_sram_en     = fs_allowin & resetn;
    assign inst_sram_we     = 4'b0;
    assign inst_sram_addr   = nextpc;
    assign inst_sram_wdata  = 32'b0;

    
    assign seq_pc   = fs_pc + 3'h4;  
    assign nextpc   = br_taken ? br_target : seq_pc;

    always @(posedge clk) begin
        if (~resetn) begin
            fs_pc <= 32'h1bfffffc;
        end else if (fs_allowin) begin
            fs_pc <= nextpc;
        end
    end

    assign fs_inst      = inst_sram_rdata;
    assign fs_to_ds_bus =   {
                            fetch_inst_error,
                            fs_inst,
                            fs_pc
                            };
endmodule