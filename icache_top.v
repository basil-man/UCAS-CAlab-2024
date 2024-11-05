`timescale 10ns / 1ns

`define CACHE_SET	8
`define CACHE_WAY	4
`define TAG_LEN		24
`define LINE_LEN	256
`define DATA_LEN    32

module icache_top (
	input	      clk,
	input	      rst,
	
	//CPU interface
	/** CPU instruction fetch request to Cache: valid signal */
	input         from_cpu_inst_req_valid,
	/** CPU instruction fetch request to Cache: address (4 byte alignment) */
	input  [31:0] from_cpu_inst_req_addr,
	/** Acknowledgement from Cache: ready to receive CPU instruction fetch request */
	output        to_cpu_inst_req_ready,
	
	/** Cache responses to CPU: valid signal */
	output        to_cpu_cache_rsp_valid,
	/** Cache responses to CPU: 32-bit Instruction value */
	output [31:0] to_cpu_cache_rsp_data,
	/** Acknowledgement from CPU: Ready to receive Instruction */
	input	      from_cpu_cache_rsp_ready,

	//Memory interface (32 byte aligned address)
	/** Cache sending memory read request: valid signal */
	output        to_mem_rd_req_valid,
	/** Cache sending memory read request: address (32 byte alignment) */
	output [31:0] to_mem_rd_req_addr,
	/** Acknowledgement from memory: ready to receive memory read request */
	input         from_mem_rd_req_ready,

	/** Memory return read data: valid signal of one data beat */
	input         from_mem_rd_rsp_valid,
	/** Memory return read data: 32-bit one data beat */
	input  [31:0] from_mem_rd_rsp_data,
	/** Memory return read data: if current data beat is the last in this burst data transmission */
	input         from_mem_rd_rsp_last,
	/** Acknowledgement from cache: ready to receive current data beat */
	output        to_mem_rd_rsp_ready
);

//TODO: Please add your I-Cache code here
	wire hit,hit1,hit2,hit3,hit4;
	reg [5:0] current_state;
	reg [5:0] next_state;
	wire [`CACHE_WAY-1:0] wen;
	wire [`TAG_LEN-1:0] tag_rdata [`CACHE_WAY-1:0];
	wire [`LINE_LEN-1:0] data_wdata;
	wire [`LINE_LEN-1:0] data_rdata [`CACHE_WAY-1:0];
	localparam  WAIT    = 6'b000001,
				EVICT   = 6'b000010,
				MEM_RD  = 6'b000100,
				RECV    = 6'b001000,
				REFILL  = 6'b010000,
				RESP    = 6'b100000;
	wire state_WAIT;
	//wire state_TAG_RD;
	wire state_EVICT;
	wire state_MEM_RD;
	wire state_RECV;
	wire state_REFILL;
	//wire state_CACHE_RD;
	wire state_RESP;
	assign state_WAIT= current_state[0];
	//assign state_TAG_RD= current_state[1];
	assign state_EVICT= current_state[1];
	assign state_MEM_RD= current_state[2];
	assign state_RECV= current_state[3];
	assign state_REFILL= current_state[4];
	//assign state_CACHE_RD= current_state[6];
	assign state_RESP= current_state[5];
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
				if(from_cpu_inst_req_valid&&!(hit&&from_cpu_cache_rsp_ready))
						next_state = EVICT;
				else
					next_state = WAIT;
			end

			EVICT:begin
				next_state=MEM_RD;
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
				next_state=RESP;
			end

			RESP:begin
				if(from_cpu_cache_rsp_ready)
					next_state=WAIT;
				else
					next_state=RESP;
			end

			default: begin
				next_state = WAIT;
			end
		endcase
	end

//FSM part 3

    reg  Valid_Array [`CACHE_WAY-1:0][`CACHE_SET-1:0];


	/*WAIT*/
	assign to_cpu_inst_req_ready=state_WAIT;

	/*TAG_RD*/
	wire [2:0]index;
	wire [`TAG_LEN-1:0] tag;
	wire [4:0] offset;
	assign {tag,index,offset}=from_cpu_inst_req_addr;
    
    assign hit1=Valid_Array[0][index] & tag_rdata[0]==tag;
    assign hit2=Valid_Array[1][index] & tag_rdata[1]==tag;
    assign hit3=Valid_Array[2][index] & tag_rdata[2]==tag;
    assign hit4=Valid_Array[3][index] & tag_rdata[3]==tag;
    assign hit=hit1|hit2|hit3|hit4;

	/*CACHE_RD*/
    
    wire [1:0]hit_addr;
    assign hit_addr =   ({2{hit1}}&2'd0)|
                        ({2{hit2}}&2'd1)|
                        ({2{hit3}}&2'd2)|
                        ({2{hit4}}&2'd3);
	assign to_cpu_cache_rsp_data = data_rdata[hit?hit_addr:replace_addr][{offset,3'b000}+:8'd32];
	
    /*RESP*/
    assign to_cpu_cache_rsp_valid=state_RESP|(state_WAIT&hit);

    /*EVICT*/
	//replace algorithm
	integer i,j;
	reg  [3:0] LRU_Array [`CACHE_WAY-1:0][`CACHE_SET-1:0];
	always @(posedge clk) begin
		if(rst)begin
			for(i=0;i<4;i=i+1)begin
				for(j=0;j<8;j=j+1)begin
					LRU_Array[i][j]<=4'b0;
				end
			end	
		end
		else if(state_WAIT&&from_cpu_inst_req_valid&&hit&&from_cpu_cache_rsp_ready)begin
			//read hit
			//hit cnt<=0, lower cnt+=1
			if(hit_addr!=2'b00)begin
				if(LRU_Array[0][index]<LRU_Array[hit_addr][index])
					LRU_Array[0][index]<=LRU_Array[0][index]+1;
			end
			else LRU_Array[1][index]<=0;

			if(hit_addr!=2'b01)begin
				if(LRU_Array[1][index]<LRU_Array[hit_addr][index])
					LRU_Array[1][index]<=LRU_Array[1][index]+1;
			end
			else LRU_Array[1][index]<=0;

			if(hit_addr!=2'b10)begin
				if(LRU_Array[2][index]<LRU_Array[hit_addr][index])
					LRU_Array[2][index]<=LRU_Array[2][index]+1;
			end
			else LRU_Array[3][index]<=0;

			if(hit_addr!=2'b11)begin
				if(LRU_Array[3][index]<LRU_Array[hit_addr][index])
					LRU_Array[3][index]<=LRU_Array[3][index]+1;
			end
			else LRU_Array[3][index]<=0;
		end
		else if(state_REFILL)begin
			if(Valid_Array[replace_addr][index])begin
				LRU_Array[replace_addr][index]<=4'b0;//mis-hit and no free block
			end
			else begin
				//mis-hit and have free block
				LRU_Array[replace_addr][index]<=4'b0;
				if(replace_addr!=2'b00&&Valid_Array[0][index]) LRU_Array[0][index]<=LRU_Array[0][index]+1;
				if(replace_addr!=2'b01&&Valid_Array[0][index]) LRU_Array[1][index]<=LRU_Array[1][index]+1;
				if(replace_addr!=2'b10&&Valid_Array[0][index]) LRU_Array[2][index]<=LRU_Array[2][index]+1;
				if(replace_addr!=2'b11&&Valid_Array[0][index]) LRU_Array[3][index]<=LRU_Array[3][index]+1;
			end
		end
	end

    wire [1:0] replace_addr;
	wire [3:0] empty_block=	{
								~Valid_Array[3][index],
								~Valid_Array[2][index],
								~Valid_Array[1][index],
								~Valid_Array[0][index]
							};
	wire [1:0] temp_empty_addr1=(~Valid_Array[0][index])?2'd0:2'd1;
	wire [1:0] temp_empty_addr2=(~Valid_Array[2][index])?2'd2:2'd3;
	wire [1:0] empty_addr=(~Valid_Array[temp_empty_addr1][index])?temp_empty_addr1:temp_empty_addr2;

	wire [1:0] LRU_temp_empty_addr1=(LRU_Array[0][index]>LRU_Array[1][index])?2'd0:2'd1;
	wire [1:0] LRU_temp_empty_addr2=(LRU_Array[2][index]>LRU_Array[3][index])?2'd2:2'd3;
	wire [1:0] LRU_empty_addr=(LRU_Array[LRU_temp_empty_addr1][index]>LRU_Array[LRU_temp_empty_addr2][index])?LRU_temp_empty_addr1:LRU_temp_empty_addr2;
	assign replace_addr=(|empty_block)?empty_addr:LRU_empty_addr;

	
    always @(posedge clk)begin
		if(rst)begin
			for(i=0;i<4;i=i+1)begin
				for(j=0;j<8;j=j+1)begin
					Valid_Array[i][j]<=1'b0;
				end
			end	
		end
		else if(state_WAIT&&!hit)begin
            Valid_Array[replace_addr][index] <= 1'b0;
        end
		else if(state_REFILL)begin
			Valid_Array[replace_addr][index]<=1'b1;
		end
    end


    /*MEM_RD*/
    assign to_mem_rd_req_valid=state_MEM_RD;
    assign to_mem_rd_req_addr={from_cpu_inst_req_addr[31:5],5'b0};

    /*RECV*/
    assign to_mem_rd_rsp_ready=state_RECV;
    reg [`DATA_LEN-1:0] temp_data[`CACHE_SET-1:0];
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
		else if(from_mem_rd_rsp_valid&&!from_mem_rd_rsp_last)begin
			temp_data[temp_data_offset]<=from_mem_rd_rsp_data;
		end
		else if(from_mem_rd_rsp_valid&&from_mem_rd_rsp_last)begin
			temp_data[temp_data_offset]<=from_mem_rd_rsp_data;
		end
	end
	always @(posedge clk) begin
		if(rst)
			temp_data_offset<=3'b0;
		else if(from_mem_rd_rsp_valid&&!from_mem_rd_rsp_last)
			temp_data_offset<=temp_data_offset+1'b1;
		else if(from_mem_rd_rsp_valid&&from_mem_rd_rsp_last)
			temp_data_offset<=3'b0;
	end


    /*REFILL*/
    assign wen[0]=replace_addr==2'd0 & state_REFILL;
	assign wen[1]=replace_addr==2'd1 & state_REFILL;
	assign wen[2]=replace_addr==2'd2 & state_REFILL;
	assign wen[3]=replace_addr==2'd3 & state_REFILL;
	assign data_wdata={
		temp_data[7],
		temp_data[6],
		temp_data[5],
		temp_data[4],
		temp_data[3],
		temp_data[2],
		temp_data[1],
		temp_data[0]
	};


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

