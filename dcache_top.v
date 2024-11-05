`timescale 10ns / 1ns

`define CACHE_SET	8
`define CACHE_WAY	4
`define TAG_LEN		24
`define LINE_LEN	256
`define DATA_LENGTH 32
//`include "icache_top.v"

module dcache_top (
	input	      clk,
	input	      rst,
  
	//CPU interface
	/** CPU memory/IO access request to Cache: valid signal */
	input         from_cpu_mem_req_valid,
	/** CPU memory/IO access request to Cache: 0 for read; 1 for write (when req_valid is high) */
	input         from_cpu_mem_req,
	/** CPU memory/IO access request to Cache: address (4 byte alignment) */
	input  [31:0] from_cpu_mem_req_addr,
	/** CPU memory/IO access request to Cache: 32-bit write data */
	input  [31:0] from_cpu_mem_req_wdata,
	/** CPU memory/IO access request to Cache: 4-bit write strobe */
	input  [ 3:0] from_cpu_mem_req_wstrb,
	/** Acknowledgement from Cache: ready to receive CPU memory access request */
	output        to_cpu_mem_req_ready,
		
	/** Cache responses to CPU: valid signal */
	output        to_cpu_cache_rsp_valid,
	/** Cache responses to CPU: 32-bit read data */
	output [31:0] to_cpu_cache_rsp_data,
	/** Acknowledgement from CPU: Ready to receive read data */
	input         from_cpu_cache_rsp_ready,
		
	//Memory/IO read interface
	/** Cache sending memory/IO read request: valid signal */
	output        to_mem_rd_req_valid,
	/** Cache sending memory read request: address
	  * 4 byte alignment for I/O read 
	  * 32 byte alignment for cache read miss */
	output [31:0] to_mem_rd_req_addr,
        /** Cache sending memory read request: burst length
	  * 0 for I/O read (read only one data beat)
	  * 7 for cache read miss (read eight data beats) */
	output [ 7:0] to_mem_rd_req_len,
        /** Acknowledgement from memory: ready to receive memory read request */
	input	      from_mem_rd_req_ready,

	/** Memory return read data: valid signal of one data beat */
	input	      from_mem_rd_rsp_valid,
	/** Memory return read data: 32-bit one data beat */
	input  [31:0] from_mem_rd_rsp_data,
	/** Memory return read data: if current data beat is the last in this burst data transmission */
	input	      from_mem_rd_rsp_last,
	/** Acknowledgement from cache: ready to receive current data beat */
	output        to_mem_rd_rsp_ready,

	//Memory/IO write interface
	/** Cache sending memory/IO write request: valid signal */
	output        to_mem_wr_req_valid,
	/** Cache sending memory write request: address
	  * 4 byte alignment for I/O write 
	  * 4 byte alignment for cache write miss
          * 32 byte alignment for cache write-back */
	output [31:0] to_mem_wr_req_addr,
        /** Cache sending memory write request: burst length
          * 0 for I/O write (write only one data beat)
          * 0 for cache write miss (write only one data beat)
          * 7 for cache write-back (write eight data beats) */
	output [ 7:0] to_mem_wr_req_len,
        /** Acknowledgement from memory: ready to receive memory write request */
	input         from_mem_wr_req_ready,

	/** Cache sending memory/IO write data: valid signal for current data beat */
	output        to_mem_wr_data_valid,
	/** Cache sending memory/IO write data: current data beat */
	output [31:0] to_mem_wr_data,
	/** Cache sending memory/IO write data: write strobe
	  * 4'b1111 for cache write-back 
	  * other values for I/O write and cache write miss according to the original CPU request*/ 
	output [ 3:0] to_mem_wr_data_strb,
	/** Cache sending memory/IO write data: if current data beat is the last in this burst data transmission */
	output        to_mem_wr_data_last,
	/** Acknowledgement from memory/IO: ready to receive current data beat */
	input	      from_mem_wr_data_ready
);

  //TODO: Please add your D-Cache code here
	wire hit,hit1,hit2,hit3,hit4;
	reg [14:0] current_state;
	reg [14:0] next_state;
	wire [`CACHE_WAY-1:0] wen;
	wire [`TAG_LEN-1:0] tag_rdata [`CACHE_WAY-1:0];
	wire [`LINE_LEN-1:0] data_wdata;
	wire [`LINE_LEN-1:0] data_rdata [`CACHE_WAY-1:0];
	localparam  WAIT     = 15'b000000000000001,
				TAG_RD   = 15'b000000000000010,
				EVICT    = 15'b000000000000100,
				MEM_RD   = 15'b000000000001000,
				RECV     = 15'b000000000010000,
				REFILL   = 15'b000000000100000,
				//CACHE_RD =17'b00000000001000000,
				RESP     = 15'b000000001000000,
				MEM_WR   = 15'b000000010000000,
				SEND     = 15'b000000100000000,
			    CACHE_DR = 15'b000001000000000,
				CACHE_WR = 15'b000010000000000,
				BP_MEM_WR= 15'b000100000000000,
				BP_SEND  = 15'b001000000000000,
				BP_MEM_RD= 15'b010000000000000,
				BP_RECV  = 15'b100000000000000;
				//BP_SEND_WAIT  = 17'b10000000000000000;
	wire state_WAIT;
	wire state_TAG_RD;
	wire state_EVICT;
	wire state_MEM_RD;
	wire state_RECV;
	wire state_REFILL;
	wire state_CACHE_RD;
	wire state_RESP;
	wire state_MEM_WR;
	wire state_SEND;
	wire state_CACHE_DR;
	wire state_CACHE_WR;
	wire state_BP_MEM_WR;
	wire state_BP_SEND  ;
	wire state_BP_MEM_RD;
	wire state_BP_RECV  ;
	wire bypass;
	assign state_WAIT= current_state[0];
	assign state_TAG_RD= current_state[1];
	assign state_EVICT= current_state[2];
	assign state_MEM_RD= current_state[3];
	assign state_RECV= current_state[4];
	assign state_REFILL= current_state[5];
	//assign state_CACHE_RD= current_state[6];
	assign state_RESP= current_state[6];
	assign state_MEM_WR= current_state[7];
	assign state_SEND= current_state[8];
	assign  state_CACHE_DR= current_state[9];
	assign  state_CACHE_WR  = current_state[10];
	assign  state_BP_MEM_WR= current_state[11];
	assign  state_BP_SEND  = current_state[12];
	assign  state_BP_MEM_RD= current_state[13];
	assign  state_BP_RECV  = current_state[14];
	assign bypass = |from_cpu_mem_req_addr[31:30] | ~|from_cpu_mem_req_addr[31:5];
	reg reg_bypass;
//FSM part 1
	always @(posedge clk) begin
		if(rst)
			current_state <= WAIT;
		else
			current_state <= next_state;
	end

//FSM part 2

	always @(*) begin
		case (current_state)
			WAIT:begin
				if(from_cpu_mem_req_valid)begin
					if(!bypass)
						next_state = TAG_RD;
					else if(bypass&&from_cpu_mem_req)
						next_state = BP_MEM_WR;
					else 
						next_state = BP_MEM_RD;
				end
				else 
					next_state = WAIT;
			end

			TAG_RD:begin
				if(!hit)
					next_state = EVICT;
				else if(hit&&reg_from_cpu_mem_req)
					next_state = CACHE_DR;
				else if(hit&&from_cpu_cache_rsp_ready&&!reg_from_cpu_mem_req)
					next_state = WAIT;
				else
					next_state = TAG_RD;
			end

			EVICT:begin
				if(pop_data_dirty)
					next_state = MEM_WR;
				else 
					next_state = MEM_RD;
			end

			MEM_RD:begin
				if(from_mem_rd_req_ready)
					next_state=RECV;
				else
					next_state=MEM_RD;
			end

			RECV:begin
				if(from_mem_rd_rsp_valid&from_mem_rd_rsp_last)
					next_state=REFILL;
				else
					next_state=RECV;
			end

			REFILL:begin
				if(reg_from_cpu_mem_req)
					next_state = CACHE_WR;
				else
					next_state = RESP;
			end


			RESP:begin
				if(from_cpu_cache_rsp_ready)
					next_state=WAIT;
				else
					next_state=RESP;
			end

			MEM_WR:begin
				if(from_mem_wr_req_ready)
					next_state = SEND;
				else
					next_state = MEM_WR;
			end

			SEND:begin
				if(from_mem_wr_data_ready&&to_mem_wr_data_last)
						next_state = MEM_RD;
				else
					next_state = SEND;
			end

			CACHE_DR:begin
				next_state = WAIT;
			end

			CACHE_WR:begin
				next_state = WAIT;
			end

			BP_MEM_WR:begin
				if(from_mem_wr_req_ready)
					next_state = BP_SEND;
				else
					next_state = BP_MEM_WR;
			end	

			BP_SEND:begin
				if(from_mem_wr_data_ready&&to_mem_wr_data_last)
					next_state = WAIT;
				else
					next_state = BP_SEND;
			end


			BP_MEM_RD:begin
				if(from_mem_rd_req_ready)
					next_state=BP_RECV;
				else
					next_state=BP_MEM_RD;
			end

			BP_RECV:begin
				if(from_mem_rd_rsp_valid&from_mem_rd_rsp_last)
					next_state = RESP;
				else
					next_state = BP_RECV;
			end

			default: begin
				next_state = WAIT;
			end
		endcase
	end

//FSM part 3
	reg        reg_from_cpu_mem_req;
	reg [`DATA_LENGTH-1:0] reg_from_cpu_mem_req_addr;
	reg [`DATA_LENGTH-1:0] reg_from_cpu_mem_req_wdata;
	reg [3:0]  reg_from_cpu_mem_req_wstrb;
	always @(posedge clk)begin
		if(rst)
			reg_from_cpu_mem_req      <=1'b0;
		if(state_WAIT&&from_cpu_mem_req_valid)begin
			reg_from_cpu_mem_req      <=from_cpu_mem_req;
		end
	end	
	always @(posedge clk)begin
		if(rst)
			reg_from_cpu_mem_req_addr <=32'b0;
		if(state_WAIT&&from_cpu_mem_req_valid)begin
			reg_from_cpu_mem_req_addr <=from_cpu_mem_req_addr;
		end
	end	
	always @(posedge clk)begin
		if(rst)
			reg_from_cpu_mem_req_wdata<=32'b0;
		if(state_WAIT&&from_cpu_mem_req_valid)begin
			reg_from_cpu_mem_req_wdata<=from_cpu_mem_req_wdata;
		end
	end	
	always @(posedge clk)begin
		if(rst)
			reg_from_cpu_mem_req_wstrb<=4'b0;
		if(state_WAIT&&from_cpu_mem_req_valid)begin
			reg_from_cpu_mem_req_wstrb<=from_cpu_mem_req_wstrb;
		end
	end	
    reg Valid_Array [`CACHE_WAY-1:0][`CACHE_SET-1:0];
	reg Dirty_Array [`CACHE_WAY-1:0][`CACHE_SET-1:0];
	always@(posedge clk)begin
		if(rst)
			reg_bypass<=1'b0;
		if(state_WAIT&&from_cpu_mem_req_valid)begin
			reg_bypass<=bypass;
		end
	end

	assign to_cpu_mem_req_ready=state_WAIT;
	assign to_cpu_cache_rsp_valid=state_RESP|(state_TAG_RD&hit);
	assign to_cpu_cache_rsp_data=reg_bypass?temp_data[0]:target_data;

	assign to_mem_rd_req_valid=(state_BP_MEM_RD|state_MEM_RD)&~rst;
	assign to_mem_rd_req_addr=reg_bypass?{reg_from_cpu_mem_req_addr[31:2],2'b0}:{reg_from_cpu_mem_req_addr[31:5],5'b0};
	assign to_mem_rd_req_len=reg_bypass?0:7;
	assign to_mem_rd_rsp_ready=state_RECV|state_BP_RECV|rst;

	assign to_mem_wr_req_valid=(state_MEM_WR|state_BP_MEM_WR)&~rst;
	assign to_mem_wr_req_addr=reg_bypass?{reg_from_cpu_mem_req_addr[31:2],2'b0}:{tag_rdata[replace_addr],index,5'b0};
	assign to_mem_wr_req_len=reg_bypass?0:7;
	
	
	assign to_mem_wr_data=send_data;
	assign to_mem_wr_data_strb=reg_bypass?reg_from_cpu_mem_req_wstrb:4'b1111;
	assign to_mem_wr_data_last=(send_cnt==7&state_SEND)|state_BP_SEND;

	wire [2:0]index;
	wire [`TAG_LEN-1:0] tag;
	wire [4:0] offset;
	assign {tag,index,offset}=reg_from_cpu_mem_req_addr;

	//get hit
	assign hit1=Valid_Array[0][index] & tag_rdata[0]==tag;
    assign hit2=Valid_Array[1][index] & tag_rdata[1]==tag;
    assign hit3=Valid_Array[2][index] & tag_rdata[2]==tag;
    assign hit4=Valid_Array[3][index] & tag_rdata[3]==tag;
    assign hit=hit1|hit2|hit3|hit4;
	wire [1:0]hit_addr;
    assign hit_addr =   ({2{hit1}}&2'd0)|
                        ({2{hit2}}&2'd1)|
                        ({2{hit3}}&2'd2)|
                        ({2{hit4}}&2'd3);
	
	//get write back data
	wire [`DATA_LENGTH-1:0] target_data = data_rdata[hit?hit_addr:replace_addr][{offset,3'b000}+:8'd32];

	//replace algo
	reg [1:0] replace_addr;
	reg pop_data_dirty;
	integer i,j;
    always @(posedge clk)begin
		if(rst)begin
			pop_data_dirty<=1'b0;
		end
		else if(state_WAIT)begin
			pop_data_dirty<=1'b0;
		end
        else if(state_TAG_RD&&!hit)begin//EVICT
			if(Dirty_Array[replace_addr][index])
				pop_data_dirty<=1'b1;
        end
    end

    always @(posedge clk)begin
		if(rst)begin
			for(i=0;i<4;i=i+1)begin
				for(j=0;j<8;j=j+1)begin
					Valid_Array[i][j]<=1'b0;
				end
			end	
		end
        else if(state_TAG_RD&&!hit)begin//EVICT
            Valid_Array[replace_addr][index] <= 1'b0;
        end
		else if(state_REFILL)begin
			Valid_Array[replace_addr][index]<=1'b1;
		end
    end

	always @(posedge clk)begin
		if(rst)begin
			for(i=0;i<4;i=i+1)begin
				for(j=0;j<8;j=j+1)begin
					Dirty_Array[i][j]<=1'b0;
				end
			end	
		end
		else if(state_CACHE_DR|state_CACHE_WR)
			Dirty_Array[state_CACHE_WR?replace_addr:hit_addr][index]<=1'b1;
		else if(state_MEM_WR)
			Dirty_Array[replace_addr][index]<=1'b0;
		
    end

	always @(posedge clk)begin
		if(rst)begin
			replace_addr<=2'b0;
		end
		else if(state_WAIT)begin
			replace_addr <= replace_addr+1'b1;
		end
    end

	//recieve data
	reg [`DATA_LENGTH-1:0] temp_data[`CACHE_SET-1:0];
    reg [2:0] temp_data_offset;
	always @(posedge clk)begin
		if(rst)begin
			temp_data[0]<=32'b0;
			temp_data[1]<=32'b0;
			temp_data[2]<=32'b0;
			temp_data[3]<=32'b0;
			temp_data[4]<=32'b0;
			temp_data[5]<=32'b0;
			temp_data[6]<=32'b0;
			temp_data[7]<=32'b0;
		end
		if(state_RECV)begin
			if(from_mem_rd_rsp_valid)begin
				temp_data[temp_data_offset]<=from_mem_rd_rsp_data;
			end
		end
		else if(state_BP_RECV)begin
			if(from_mem_rd_rsp_valid)begin
				temp_data[0]<=from_mem_rd_rsp_data;
			end
		end	
	end

	always @(posedge clk)begin
		if(rst)begin
			temp_data_offset<=3'b0;
		end
		if(state_RECV)begin
			if(from_mem_rd_rsp_valid)begin
				temp_data_offset<=temp_data_offset+1'b1;
			end
		end
	end

	//write cache
	assign wen[0]=(replace_addr==2'd0 & (state_REFILL|state_CACHE_WR))|(hit1 & (state_CACHE_DR));
	assign wen[1]=(replace_addr==2'd1 & (state_REFILL|state_CACHE_WR))|(hit2 & (state_CACHE_DR));
	assign wen[2]=(replace_addr==2'd2 & (state_REFILL|state_CACHE_WR))|(hit3 & (state_CACHE_DR));
	assign wen[3]=(replace_addr==2'd3 & (state_REFILL|state_CACHE_WR))|(hit4 & (state_CACHE_DR));

	wire [`LINE_LEN-1:0] strb_mask;
	assign strb_mask={
						{8{reg_from_cpu_mem_req_wstrb[3]}},
						{8{reg_from_cpu_mem_req_wstrb[2]}},
						{8{reg_from_cpu_mem_req_wstrb[1]}},
						{8{reg_from_cpu_mem_req_wstrb[0]}}
					}<<{offset,3'b0};
	assign data_wdata=	state_REFILL?({
												temp_data[7],
												temp_data[6],
												temp_data[5],
												temp_data[4],
												temp_data[3],
												temp_data[2],
												temp_data[1],
												temp_data[0]
											})
											:
											((({
												224'b0,
												{
													{8{reg_from_cpu_mem_req_wstrb[3]}}&reg_from_cpu_mem_req_wdata[31:24],
													{8{reg_from_cpu_mem_req_wstrb[2]}}&reg_from_cpu_mem_req_wdata[23:16],
													{8{reg_from_cpu_mem_req_wstrb[1]}}&reg_from_cpu_mem_req_wdata[15:8],
													{8{reg_from_cpu_mem_req_wstrb[0]}}&reg_from_cpu_mem_req_wdata[7:0]
												}
											})<<{offset,3'b0})|((~strb_mask)&data_rdata[state_CACHE_DR?hit_addr:replace_addr])
											);

	//send data
	reg [2:0] send_cnt;
	assign to_mem_wr_data_valid=(state_SEND|state_BP_SEND)&~rst;
	always @(posedge  clk)begin
		if(rst)begin
			send_cnt<=3'b0;
		end
		else if(state_SEND&&from_mem_wr_data_ready)begin
			send_cnt<=send_cnt+1'b1;
		end	
	end

	wire [`DATA_LENGTH-1:0] send_data=state_SEND?data_rdata[replace_addr][{send_cnt[2:0],5'b0}+:8'd32]:reg_from_cpu_mem_req_wdata;




	/*data array and tag array*/
	tag_array tag_0 (
		.clk(clk),
		.waddr(index),
		.raddr(index),
		.wen(wen[0]),
		.wdata(tag),
		.rdata(tag_rdata[0])
    	);
	tag_array tag_1 (
		.clk(clk),
		.waddr(index),
		.raddr(index),
		.wen(wen[1]),
		.wdata(tag),
		.rdata(tag_rdata[1])
	);
	tag_array tag_2 (
		.clk(clk),
		.waddr(index),
		.raddr(index),
		.wen(wen[2]),
		.wdata(tag),
		.rdata(tag_rdata[2])
	);
	tag_array tag_3 (
		.clk(clk),
		.waddr(index),
		.raddr(index),
		.wen(wen[3]),
		.wdata(tag),
		.rdata(tag_rdata[3])
	);


	data_array data_0 (
		.clk(clk),
		.waddr(index),
		.raddr(index),
		.wen(wen[0]),
		.wdata(data_wdata),
		.rdata(data_rdata[0])
	);
	data_array data_1 (
		.clk(clk),
		.waddr(index),
		.raddr(index),
		.wen(wen[1]),
		.wdata(data_wdata),
		.rdata(data_rdata[1])
	);
	data_array data_2 (
		.clk(clk),
		.waddr(index),
		.raddr(index),
		.wen(wen[2]),
		.wdata(data_wdata),
		.rdata(data_rdata[2])
	);
	data_array data_3 (
		.clk(clk),
		.waddr(index),
		.raddr(index),
		.wen(wen[3]),
		.wdata(data_wdata),
		.rdata(data_rdata[3])
	);
endmodule

