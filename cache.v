module cache(
    input  wire         clk,
    input  wire         resetn,
    // cpu interface
    input  wire         valid,      // 表明请求有效
    input  wire         op,         // 1:write, 0:read
    input  wire [  7:0] index,      // 地址的index域(addr[11:4])
    input  wire [ 19:0] tag,        // 经虚实地址转换后的paddr形成的tag，由于来自组合逻辑运算，故与index是同拍信号
    input  wire [  3:0] offset,     // 地址的offset域(addr[3:0])
    input  wire [  3:0] wstrb,      // 写字节使能信号
    input  wire [ 31:0] wdata,      // 写数据
    output wire         addr_ok,    // 该次请求的地址传输OK，读：地址被接收；写：地址和数据被接收
    output wire         data_ok,    // 该次请求的数据传输OK，读：数据返回；写：数据写入完成
    output wire [ 31:0] rdata,      // 读Cache的结果
    // AXI interface
    output wire         rd_req,     // 读请求有效信号。高电平有效。
    output wire [  2:0] rd_type,    // 读请求类型。3’b000——字节，3’b001——半字，3’b010——字，3’b100——Cache行
    output wire [ 31:0] rd_addr,    // 读请求起始地址
    input  wire         rd_rdy,     // 读请求能否被接收的握手信号。高电平有效
    input  wire         ret_valid,  // 返回数据有效信号后。高电平有效
    input  wire [  1:0] ret_last,   // 返回数据是一次读请求对应的最后一个返回数据
    input  wire [ 31:0] ret_data,   // 读返回数据

    output wire         wr_req,     // 写请求有效信号。高电平有效
    output wire [  2:0] wr_type,    // 写请求类型。3’b000——字节，3’b001——半字，3’b010——字，3’b100——Cache行
    output wire [ 31:0] wr_addr,    // 写请求起始地址
    output wire [  3:0] wr_wstrb,   // 写操作的字节掩码。仅在写请求类型为3’b000、3’b001、3’b010情况下才有意义
    output wire [127:0] wr_data,    // 写数据
    input  wire         wr_rdy,     // 写请求能否被接收的握手信号。高电平有效。此处要求wr_rdy要先于wr_req置起，wr_req看到wr_rdy后才可能置上1

    //exp22
    input  wire         cacheable   //是否可缓存,0——强序非缓存，1——一致可缓存
);

    wire        hit_write_conflict;
    wire        cache_hit;
    wire        hit_write;
    wire [31:0] hit_result;
    wire [1:0]  hit_way;
    // for request buffer
    reg         op_reg;
    reg  [ 7:0] index_reg;
    reg  [19:0] tag_reg;
    reg  [ 3:0] offset_reg;
    reg  [ 3:0] wstrb_reg;
    reg  [31:0] wdata_reg;

    // for write buffer
    reg         wrbuf_way;
    reg  [ 7:0] wrbuf_index;
    reg  [ 3:0] wrbuf_offset;
    reg  [ 3:0] wrbuf_wstrb;
    reg  [31:0] wrbuf_wdata;

    wire        tagv_we [1:0];
    wire [ 7:0] tagv_addr;
    wire [20:0] tagv_wdata;
    wire [20:0] tagv_rdata [1:0];

    wire [ 3:0]  data_bank_we    [1:0][3:0];
    wire [ 7:0]  data_bank_addr  [3:0];
    wire [31:0]  data_bank_wdata [3:0];
    wire [31:0]  data_bank_rdata [1:0][3:0];

    reg [255:0] dirty_array [1:0];
    reg [255:0] replace_way;

    reg [1:0] ret_cnt;

    parameter IDLE    = 5'b00001;
    parameter LOOKUP  = 5'b00010;
    parameter MISS    = 5'b00100;
    parameter REPLACE = 5'b01000;
    parameter REFILL  = 5'b10000;
    reg [4:0] current_state;
    reg [4:0] next_state;

    parameter WR_IDLE  = 2'b01;
    parameter WR_WRITE = 2'b10;
    reg [1:0] wr_current_state;
    reg [1:0] wr_next_state;

    genvar i, way;

    // main state machine
    always @(posedge clk) begin
        if (~resetn) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    always @(*) begin
        case (current_state)
            IDLE:
                if (valid & ~hit_write_conflict) begin
                    next_state <= LOOKUP;
                end else begin
                    next_state <= IDLE;
                end
            LOOKUP:
                if (cache_hit & (~valid | hit_write_conflict)) begin
                    next_state <= IDLE;
                end else if (cache_hit & valid & (~hit_write_conflict)) begin
                    next_state <= LOOKUP;
                end else if (~dirty_array[replace_way[index_reg]][index_reg] | ~tagv_rdata[replace_way[index_reg]][0]) begin 
                    next_state <= REPLACE;
                end else if (~cache_hit) begin
                    next_state <= MISS;
                end
            MISS:
                if (~wr_rdy) begin
                    next_state <= MISS;
                end else begin
                    next_state <= REPLACE;
                end
                
            REPLACE:
                if (~rd_rdy) begin
                    next_state <= REPLACE;
                end else begin
                    next_state <= REFILL;
                end
            REFILL:
                if (ret_valid & (ret_last == 'd1)) begin
                    next_state <= IDLE;
                end else begin
                    next_state <= REFILL;
                end
            default:
                next_state <= IDLE;
        endcase
    end

    // write state machine
    always @(posedge clk) begin
        if (~resetn) begin
            wr_current_state <= WR_IDLE;
        end else begin
            wr_current_state <= wr_next_state;
        end
    end

    always @(*) begin
        case (wr_current_state)
            WR_IDLE:
                if (hit_write) begin
                    wr_next_state <= WR_WRITE;
                end else begin
                    wr_next_state <= WR_IDLE;
                end
            WR_WRITE:
                if (hit_write) begin
                    wr_next_state <= WR_WRITE;
                end else begin
                    wr_next_state <= WR_IDLE;
                end
            default:
                wr_next_state <= WR_IDLE;
        endcase
    end

    // request buffer: op、index、tag、offset、wstrb、wdata
    always @(posedge clk) begin
        if (~resetn) begin
            {op_reg, index_reg, tag_reg, offset_reg, wstrb_reg, wdata_reg} <= 'd0;
        end else if (valid & addr_ok) begin
            {op_reg, index_reg, tag_reg, offset_reg, wstrb_reg, wdata_reg} <= {op, index, tag, offset, wstrb, wdata};
        end
    end

    // write buffer
    always @(posedge clk) begin
        if (~resetn) begin
            {wrbuf_way, wrbuf_index, wrbuf_offset, wrbuf_wstrb, wrbuf_wdata} <= 'd0;
        end else if (hit_write) begin
            {wrbuf_way, wrbuf_index, wrbuf_offset, wrbuf_wstrb, wrbuf_wdata} <= {hit_way[1], index_reg, offset_reg, wstrb_reg, wdata_reg};
        end
    end

    // miss buffer
    always @(posedge clk) begin
        if (~resetn) begin
            ret_cnt <= 'd0;
        end else if (ret_valid) begin
            if (~ret_last) begin
                ret_cnt <= ret_cnt + 1'b1;
            end else begin
                ret_cnt <= 2'b0;
            end
        end
    end

    // hit / match
    assign hit_way[0] = tagv_rdata[0][0] & (tagv_rdata[0][20:1] == tag_reg);
    assign hit_way[1] = tagv_rdata[1][0] & (tagv_rdata[1][20:1] == tag_reg);
    assign cache_hit = |hit_way;

    assign hit_write = (current_state == LOOKUP) & cache_hit & op_reg;
    assign hit_write_conflict = (hit_write | wr_current_state == WR_WRITE) & valid & ~op & (index_reg == index) & (offset_reg[3:2] == offset[3:2]);
    assign hit_result = {32{hit_way[0]}} & data_bank_rdata[0][offset_reg[3:2]] 
                      | {32{hit_way[1]}} & data_bank_rdata[1][offset_reg[3:2]];

    // tagv related
    assign tagv_we[0] = ret_valid & ret_last[0] & (replace_way[index_reg] == 0);
    assign tagv_we[1] = ret_valid & ret_last[0] & (replace_way[index_reg] == 1);
    assign tagv_addr  = (current_state == IDLE || current_state == LOOKUP) ? index : index_reg;
    assign tagv_wdata = {tag_reg, 1'b1};

    // random replace
    always @(posedge clk) begin
        if (~resetn) begin
            replace_way <= 'd0;
        end else if (current_state == IDLE || current_state == LOOKUP) begin
            if (hit_way[0] & valid) begin
                replace_way[index_reg] <= 1'b1;
            end else if (hit_way[1] & valid) begin
                replace_way[index_reg] <= 1'b0;
            end
        end else if (current_state == REFILL && next_state == IDLE) begin
            replace_way[index_reg] <= ~replace_way[index_reg];
        end
    end

    // dirty array
    always @(posedge clk) begin
        if (~resetn) begin
            dirty_array[0] <= 'd0;
            dirty_array[1] <= 'd0;
        end else if (wr_current_state == WR_WRITE) begin
            dirty_array[wrbuf_way][wrbuf_index] <= 1'b1;
        end else if (ret_valid & (ret_last == 'd1)) begin
            dirty_array[wrbuf_way][wrbuf_index] <= op_reg;
        end
    end

    // RAM port
    generate
        for (i = 0; i < 4; i = i + 1) begin: data_bank
            for (way = 0; way < 2; way = way + 1) begin: data_bank_we_value
                assign data_bank_we[way][i] = {4{(wr_current_state == WR_WRITE) & (wrbuf_offset[3:2] == i) & (wrbuf_way == way)}} & wrbuf_wstrb
                                            | {4{ret_valid & (ret_cnt == i) & replace_way[index_reg] == way}} & 4'hf;
            end
            assign data_bank_addr[i]  = ((current_state == IDLE) || (current_state == LOOKUP)) ? index : index_reg;
            assign data_bank_wdata[i] = (wr_current_state == WR_WRITE) ? wrbuf_wdata :
                                        (offset_reg[3:2] != i || ~op_reg)? ret_data :
                                        {
                                        wstrb_reg[3] ? wdata_reg[31:24] : ret_data[31:24],
                                        wstrb_reg[2] ? wdata_reg[23:16] : ret_data[23:16],
                                        wstrb_reg[1] ? wdata_reg[15: 8] : ret_data[15: 8],
                                        wstrb_reg[0] ? wdata_reg[ 7: 0] : ret_data[ 7: 0]
                                        };
        end
    endgenerate

    // RAM interface
    generate
        for (way = 0; way < 2; way = way + 1) begin: ram_generate // 例化2块
            TAG_RAM tagv_ram (
                .ena(1'b1),
                .clka (clk),
                .wea  (tagv_we[way]),
                .addra({'b0,tagv_addr}),
                .dina (tagv_wdata),
                .douta(tagv_rdata[way]) 
            );
            for(i = 0; i < 4; i = i + 1) begin: bank_ram_generate // 例化 2*4=8 块
                DATA_BANK_RAM data_bank_ram(
                    .ena(1'b1),
                    .clka (clk),
                    .wea  (data_bank_we[way][i]),
                    .addra({'b0,data_bank_addr[i]}),
                    .dina (data_bank_wdata[i]),
                    .douta(data_bank_rdata[way][i])
                );
            end
        end
    endgenerate

    // CPU interface
    reg addr_ok_valid;
    always @(posedge clk) begin
        if (~resetn) begin
            addr_ok_valid <= 1'b1;
        end else if (addr_ok) begin
            addr_ok_valid <= 1'b0;
        end else if (current_state == IDLE) begin
            addr_ok_valid <= 1'b1;
        end
    end
    assign addr_ok =  ((current_state == IDLE) |
                     ((current_state == LOOKUP) & valid & cache_hit & (op | (~op & ~hit_write_conflict))));
    reg data_ok_valid;
    always @(posedge clk) begin
        if (~resetn) begin
            data_ok_valid <= 1'b1;
        end else if (data_ok) begin
            data_ok_valid <= 1'b0;
        end else if (current_state == IDLE) begin
            data_ok_valid <= 1'b1;
        end
    end
    assign data_ok = (((current_state == LOOKUP) & (cache_hit | op_reg)) |
                     ((current_state == REFILL) & ~op_reg & ret_valid & (ret_cnt == offset_reg[3:2])));
                     
    assign rdata   = ret_valid ? ret_data : hit_result; 

    // AXI interface
    assign rd_req = (current_state == REPLACE);
    assign rd_addr = {tag_reg, index_reg, 4'b0};
    assign rd_type = 3'b100;

    assign wr_req = (current_state == MISS) & (next_state == REPLACE);
    assign wr_addr = {tagv_rdata[replace_way[index_reg]][20:1], index_reg, 4'b0};
    assign wr_type = 3'b100;
    assign wr_wstrb = 4'hf;
    assign wr_data = {  data_bank_rdata[replace_way[index_reg]][3], data_bank_rdata[replace_way[index_reg]][2],
                        data_bank_rdata[replace_way[index_reg]][1], data_bank_rdata[replace_way[index_reg]][0]};

endmodule