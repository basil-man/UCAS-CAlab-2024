`include "width.h"
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
    output wire [  3:0] rd_type,    // 读请求类型。3’b000——字节，3’b001——半字，3’b010——字，3’b100——Cache行
    output wire [ 31:0] rd_addr,    // 读请求起始地址
    input  wire         rd_rdy,     // 读请求能否被接收的握手信号。高电平有效
    input  wire         ret_valid,  // 返回数据有效信号后。高电平有效
    input  wire [  1:0] ret_last,   // 返回数据是一次读请求对应的最后一个返回数据
    input  wire [ 32:0] ret_data,   // 读返回数据
    output wire         wr_req,     // 写请求有效信号。高电平有效
    output wire [  3:0] wr_type,    // 写请求类型。3’b000——字节，3’b001——半字，3’b010——字，3’b100——Cache行
    output wire [ 31:0] wr_addr,    // 写请求起始地址
    output wire [  3:0] wr_wstrb,   // 写操作的字节掩码。仅在写请求类型为3’b000、3’b001、3’b010情况下才有意义
    output wire [127:0] wr_data,    // 写数据
    input  wire         wr_rdy      // 写请求能否被接收的握手信号。高电平有效。此处要求wr_rdy要先于wr_req置起，wr_req看到wr_rdy后才可能置上1
);

    wire hit_write_conflict;
    wire cache_hit;
    wire hit_write;

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
                if (valid & hit_write_conflict) begin
                    next_state <= LOOKUP;
                end else begin
                    next_state <= IDLE;
                end
            LOOKUP:
                if (cache_hit & (~valid | hit_write_conflict)) begin
                    next_state <= IDLE;
                end else if (cache_hit & valid & (~hit_write_conflict)) begin
                    next_state <= LOOKUP;
                end else begin
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
                    next_state <= REFILL;
                end else begin
                    next_state <= IDLE;
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

endmodule