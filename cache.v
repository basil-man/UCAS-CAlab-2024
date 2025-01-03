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
    output wire         rd_cacheable,//是否可缓存,0——强序非缓存，1——一致可缓存;(maybe not used??)
    input  wire         rd_rdy,     // 读请求能否被接收的握手信号。高电平有效
    input  wire         ret_valid,  // 返回数据有效信号后。高电平有效
    input  wire [  1:0] ret_last,   // 返回数据是一次读请求对应的最后一个返回数据
    input  wire [ 31:0] ret_data,   // 读返回数据

    output wire         wr_req,     // 写请求有效信号。高电平有效
    output wire [  2:0] wr_type,    // 写请求类型。3’b000——字节，3’b001——半字，3’b010——字，3’b100——Cache行
    output wire [ 31:0] wr_addr,    // 写请求起始地址
    output wire [  3:0] wr_wstrb,   // 写操作的字节掩码。仅在写请求类型为3’b000、3’b001、3’b010情况下才有意义
    output wire [127:0] wr_data,    // 写数据
    output wire         wr_cacheable,//是否可缓存,0——强序非缓存，1——一致可缓存
    input  wire         wr_rdy,     // 写请求能否被接收的握手信号。高电平有效。此处要求wr_rdy要先于wr_req置起，wr_req看到wr_rdy后才可能置上1

    //exp22
    input  wire         cacheable,   //是否可缓存,0——强序非缓存，1——一致可缓存
    
    //exp23
    input  wire [4:0]   cacop_code,  //cacop code
    input  wire         cacop_req,
    input  wire [31:0]  cacop_addr,

    output wire         cacop_data_ok,
    input  wire         cache_type // 0: inst cache, 1: data cache
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
    reg  [4:0]  cacop_code_reg;
    reg         cacop_req_reg;
    reg  [31:0] cacop_addr_reg;

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

    wire cacop_store_tag       ;
    wire cacop_index_invalidate;
    wire cacop_hit_invalidate  ;

    reg [255:0] dirty_array [1:0];
    reg [255:0] replace_way;

    reg [1:0] ret_cnt;
    reg       ret_last_r;

    reg cacheable_reg;

    reg cacop_status;//0: idle, 1: cacop processing
    reg dealing_cacop_reg;
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

    wire [31:0] debug_addr_reg  = {tag_reg, index_reg, offset_reg}; 

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
                if (valid & ~hit_write_conflict | cacop_req) begin
                    next_state <= LOOKUP;
                end else begin
                    next_state <= IDLE;
                end
            LOOKUP:
                if((cacop_req_reg && cacop_index_invalidate) || (cacop_req_reg && cacop_hit_invalidate && cache_hit)) begin
                    next_state <= MISS;
                end else if (cache_hit & (~valid | hit_write_conflict) || (cacop_req_reg && cacop_store_tag) || (cacop_req_reg && cacop_hit_invalidate && ~cache_hit)) begin
                    next_state <= IDLE;
                end else if (cache_hit & valid & (~hit_write_conflict)) begin
                    next_state <= LOOKUP;
                end else if ((~dirty_array[replace_way[index_reg]][index_reg] | ~tagv_rdata[replace_way[index_reg]][0]) & cacheable_reg) begin 
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
                if(cacop_req_reg && ~cacop_store_tag && ~cache_type) begin
                    next_state <= IDLE;
                end else if (~rd_rdy & (cacheable_reg | ~op_reg)) begin //非缓存写并不需要读
                    next_state <= REPLACE;
                end else begin
                    next_state <= REFILL;
                end
            REFILL:
                if (ret_valid & (ret_last[0] == 1'd1) | ~(cacheable_reg | ~op_reg) | cacop_req_reg) begin //非缓存写并不需要等待读完成
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
            {op_reg, index_reg, tag_reg, offset_reg, wstrb_reg, wdata_reg,cacheable_reg,cacop_req_reg,cacop_code_reg,cacop_addr_reg} <= 'd0;
        end else if ((valid || cacop_req) & addr_ok) begin
            {op_reg, index_reg, tag_reg, offset_reg, wstrb_reg, wdata_reg,cacheable_reg,cacop_req_reg,cacop_code_reg,cacop_addr_reg} <= {op, index, tag, offset, wstrb, wdata,cacheable,cacop_req,cacop_code,cacop_addr};
        end
    end

    // write buffer
    always @(posedge clk) begin
        if (~resetn) begin
            {wrbuf_way, wrbuf_index, wrbuf_offset, wrbuf_wstrb, wrbuf_wdata} <= 'd0;
        end else if (hit_write) begin
            {wrbuf_way, wrbuf_index, wrbuf_offset, wrbuf_wstrb} <= {hit_way[1], index_reg, offset_reg, wstrb_reg};
            wrbuf_wdata <= {wstrb_reg[3] ? wdata_reg[31:24] : hit_result[31:24],
                            wstrb_reg[2] ? wdata_reg[23:16] : hit_result[23:16],
                            wstrb_reg[1] ? wdata_reg[15: 8] : hit_result[15: 8],
                            wstrb_reg[0] ? wdata_reg[ 7: 0] : hit_result[ 7: 0]
                            };//just for debug,the real strb control logic is in data_bank_we
        end
    end

    // miss buffer

    // always @(posedge clk) begin
    //     if(~resetn) begin
    //         ret_last_r <= 'd0;
    //     end else begin
    //         ret_last_r <= ret_last;
    //     end
    // end
    // reg debug_catch_ret_valid;
    always @(posedge clk) begin
        if (~resetn) begin
            ret_cnt <= 'd0;
            // debug_catch_ret_valid <= 'd0;
        end else if (ret_valid) begin
            // debug_catch_ret_valid <= ~debug_catch_ret_valid;
            if (~ret_last[0]) begin
                ret_cnt <= ret_cnt + 1'b1;
            end else begin
                ret_cnt <= 2'b0;
            end
        end
    end

    // hit / match
    assign hit_way[0] = tagv_rdata[0][0] & ((cacop_req_reg & cacop_hit_invalidate) ? tagv_rdata[0][20:1] == cacop_addr_reg[31:12] : (tagv_rdata[0][20:1] == tag_reg) & (cacheable_reg | (cacop_req_reg & cacop_index_invalidate)));
    assign hit_way[1] = tagv_rdata[1][0] & ((cacop_req_reg & cacop_hit_invalidate) ? tagv_rdata[1][20:1] == cacop_addr_reg[31:12] : (tagv_rdata[1][20:1] == tag_reg) & (cacheable_reg | (cacop_req_reg & cacop_index_invalidate)));
    assign cache_hit = (|hit_way); //cache_hit always = 0 when cacheable = 0

    assign hit_write = (current_state == LOOKUP) & cache_hit & op_reg;//hit_write always = 0 when cacheable = 0
    assign hit_write_conflict = (wr_current_state == WR_WRITE & valid & (~op) & (offset[3:2]==offset_reg[3:2]) )
                                |(current_state == LOOKUP & (op_reg) & valid & ~op & {tag,index,offset[3:2]} == {tag_reg,index_reg,offset[3:2]});
    assign hit_result = {32{hit_way[0]}} & data_bank_rdata[0][offset_reg[3:2]] 
                      | {32{hit_way[1]}} & data_bank_rdata[1][offset_reg[3:2]];

    // tagv related
    wire cacop_tagv_flush = (current_state == LOOKUP & cacop_req_reg & cacop_store_tag);
    wire cacop_index_invalidate_flush = (cacop_req_reg & cacop_index_invalidate);
    wire cacop_hit_invalidate_flush = ((cacop_req_reg | cacop_req) & cacop_hit_invalidate);
    assign tagv_we[0] = (cacop_hit_invalidate_flush & current_state == MISS & next_state ==REPLACE) ? hit_way[0] :
                        (cacop_tagv_flush | cacop_index_invalidate_flush & current_state == MISS & next_state ==REPLACE) ? cacop_addr_reg[0]==0 : 
                        ret_valid & ret_last[0] & (replace_way[index_reg] == 0)& cacheable_reg;
    assign tagv_we[1] = (cacop_hit_invalidate_flush & current_state == MISS & next_state ==REPLACE) ? hit_way[1] :
                        (cacop_tagv_flush | cacop_index_invalidate_flush & current_state == MISS & next_state ==REPLACE) ? cacop_addr_reg[0]==1 : 
                        ret_valid & ret_last[0] & (replace_way[index_reg] == 1)& cacheable_reg;
    assign tagv_addr  = (cacop_hit_invalidate_flush) ? (cacop_req ? cacop_addr[11:4] :cacop_addr_reg[11:4]) :
                        (cacop_tagv_flush | cacop_index_invalidate_flush) ? cacop_addr_reg[11:4] : 
                        (current_state == IDLE || current_state == LOOKUP) ? index : index_reg;
    assign tagv_wdata = cacop_hit_invalidate_flush ? {tagv_rdata[~hit_way[0]][20:1], 1'b0} :
                        cacop_index_invalidate_flush ? {tagv_rdata[cacop_addr_reg[0]][20:1], 1'b0} :
                        cacop_tagv_flush ? {20'b0,{tagv_rdata[cacop_addr_reg[0]][0]}} : 
                        {tag_reg, 1'b1};

    // random(??) replace
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
        end else if (ret_valid & (ret_last[0] == 1'd1)) begin
            dirty_array[wrbuf_way][wrbuf_index] <= op_reg;
        end
    end

    wire [31:0] final_wdata = {wstrb_reg[3] ? wdata_reg[31:24] : ret_data[31:24],
                              wstrb_reg[2] ? wdata_reg[23:16] : ret_data[23:16],
                              wstrb_reg[1] ? wdata_reg[15: 8] : ret_data[15: 8],
                              wstrb_reg[0] ? wdata_reg[ 7: 0] : ret_data[ 7: 0]
                              };

    // RAM port
    generate
        for (i = 0; i < 4; i = i + 1) begin: data_bank
            for (way = 0; way < 2; way = way + 1) begin: data_bank_we_value
                assign data_bank_we[way][i] = ({4{(wr_current_state == WR_WRITE) & (wrbuf_offset[3:2] == i) & (wrbuf_way == way)}} & wrbuf_wstrb //hit
                                            | {4{ret_valid & (ret_cnt == i) & replace_way[index_reg] == way}} & {4{cacheable_reg}}) & {4{~cacop_req_reg}};
            end
            assign data_bank_addr[i]  = (cacop_req_reg && cacop_hit_invalidate) ? cacop_addr_reg[11:4] : ((wr_current_state == WR_WRITE) & (wrbuf_offset[3:2] == i)) ? wrbuf_index : ((current_state == IDLE) || (current_state == LOOKUP)) ? index : index_reg;
            assign data_bank_wdata[i] = (wr_current_state == WR_WRITE) ? wrbuf_wdata :
                                        (offset_reg[3:2] != i || ~op_reg)? ret_data :
                                        final_wdata;
        end
    endgenerate

    // RAM interface
    generate
        for (way = 0; way < 2; way = way + 1) begin: ram_generate // 例化2块
            TAG_RAM tagv_ram (
                .clka (clk),
                .wea  (tagv_we[way]),
                .addra(tagv_addr),
                .dina (tagv_wdata),
                .douta(tagv_rdata[way]) 
            );
            for(i = 0; i < 4; i = i + 1) begin: bank_ram_generate // 例化 2*4=8 块
                DATA_BANK_RAM data_bank_ram(
                    .clka (clk),
                    .wea  (data_bank_we[way][i]),
                    .addra(data_bank_addr[i]),
                    .dina (data_bank_wdata[i]),
                    .douta(data_bank_rdata[way][i])
                );
            end
        end
    endgenerate

    // CPU interface
    assign addr_ok =  ((current_state == IDLE) |
                     ((current_state == LOOKUP) & valid & cache_hit & (op | (~op & ~hit_write_conflict)) & (cacheable|cacheable_reg)))
                     & ~hit_write_conflict;
    assign data_ok = ((current_state == LOOKUP) & (cache_hit | op_reg | cacop_req_reg & cacop_store_tag | ~cache_hit & cacop_req_reg & cacop_hit_invalidate)) |//write or read hit 
                     ((current_state == REFILL) & ~op_reg & ret_valid & 
                        ((ret_cnt == offset_reg[3:2]) & rd_cacheable | ~rd_cacheable)) & (~dealing_cacop_reg) | //read miss
                     (current_state==MISS & next_state == REPLACE & cacop_req_reg);
                     
    assign rdata   = ret_valid ? ret_data : hit_result; 

    // AXI interface
    assign rd_req = (current_state == REPLACE) & (cacheable_reg | ~op_reg) & ~cacop_req_reg; //非缓存写不会产生读请求
    assign rd_addr = rd_cacheable?{tag_reg, index_reg, 4'b0}:debug_addr_reg;
    assign rd_type = rd_cacheable?3'b100:3'b010;
    assign rd_cacheable = cacheable_reg & ~op_reg;

    assign wr_req = (current_state == MISS) & (next_state == REPLACE) & (~(cacop_req_reg & ~cache_type)) & (op_reg | cacheable_reg);
    wire [31:0] cacheable_wr_addr = {tagv_rdata[replace_way[index_reg]][20:1], index_reg, 4'b0};
    wire cacop_hit_invalidate_wr_hit_way = ~hit_way[0];
    wire [31:0] cacop_hit_invalidate_wr_addr = {tagv_rdata[cacop_hit_invalidate_wr_hit_way][20:1], cacop_addr_reg[11:4], 4'b0};
    wire [31:0] cacop_wr_addr = {tagv_rdata[cacop_addr_reg[0]][20:1], cacop_addr_reg[11:4], 4'b0};
    assign wr_addr = (cacop_req_reg & cacop_hit_invalidate) ? cacop_hit_invalidate_wr_addr : (cacop_req_reg & cacop_index_invalidate) ? cacop_wr_addr : wr_cacheable ? cacheable_wr_addr : debug_addr_reg;
    assign wr_type = (wr_cacheable | cacop_req_reg) ? 3'b100
                    : 3'b010;
    assign wr_wstrb = (wr_cacheable | cacop_req_reg) ? 4'hf
                    : wstrb_reg;
    assign wr_data =    (cacop_req_reg & cacop_hit_invalidate) ? {data_bank_rdata[cacop_hit_invalidate_wr_hit_way][3], data_bank_rdata[cacop_hit_invalidate_wr_hit_way][2],
                                        data_bank_rdata[cacop_hit_invalidate_wr_hit_way][1], data_bank_rdata[cacop_hit_invalidate_wr_hit_way][0]} :
                        (cacop_req_reg & cacop_index_invalidate) ? {data_bank_rdata[cacop_addr_reg[0]][3], data_bank_rdata[cacop_addr_reg[0]][2], 
                                        data_bank_rdata[cacop_addr_reg[0]][1], data_bank_rdata[cacop_addr_reg[0]][0]} :
                        wr_cacheable? {data_bank_rdata[replace_way[index_reg]][3], data_bank_rdata[replace_way[index_reg]][2],
                                        data_bank_rdata[replace_way[index_reg]][1], data_bank_rdata[replace_way[index_reg]][0]}
                        : {4{wdata_reg}};
    assign wr_cacheable = cacheable_reg & op_reg;

    //cacop
    assign cacop_store_tag        = cacop_code_reg[4:3]==3'd0;
    assign cacop_index_invalidate = cacop_code_reg[4:3]==3'd1;
    assign cacop_hit_invalidate   = cacop_code_reg[4:3]==3'd2 | cacop_code[4:3]==3'd2;

    always @(posedge clk) begin
        if (~resetn) begin
            dealing_cacop_reg <= 1'b0;
        end else if (cacop_req&&current_state==IDLE) begin
            dealing_cacop_reg <= 1'b1;
        end else if (current_state==IDLE) begin
            dealing_cacop_reg <= 1'b0;
        end
    end
    assign cacop_data_ok = dealing_cacop_reg & data_ok;

endmodule