`include "width.h"
module cache(
    input wire clk,
    input wire resetn,
    input wire valid,
    input wire op, // 1:write, 0:read
    input wire [7:0] index, // 地址的index域(addr[11:4])
    input wire [19:0] tag, // 经虚实地址转换后的paddr形成的tag，由于来自组合逻辑运算，故与index是同拍信号
    input wire [3:0] offset, // 地址的offset域(addr[3:0])
    input wire [3:0] wstrb, // 写字节使能信号
    input wire [31:0] wdata, // 写数据
    output wire addr_ok, // 该次请求的地址传输OK，读：地址被接收；写：地址和数据被接收
    output wire data_ok, // 该次请求的数据传输OK，读：数据返回；写：数据写入完成
    output wire [31:0] rdata // 读Cache的结果
);

endmodule