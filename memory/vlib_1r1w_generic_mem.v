//----------------------------------------------------------------------
// A generic dual-port 1R1W memory based on flops or FPGA-BRAM.
//----------------------------------------------------------------------
// Author: Anh Tran (Andrew)
//
// This is free and unencumbered software released into the public domain.
//
// Anyone is free to copy, modify, publish, use, compile, sell, or
// distribute this software, either in source code form or as a compiled
// binary, for any purpose, commercial or non-commercial, and by any
// means.
//
// In jurisdictions that recognize copyright laws, the author or authors
// of this software dedicate any and all copyright interest in the
// software to the public domain. We make this dedication for the benefit
// of the public at large and to the detriment of our heirs and
// successors. We intend this dedication to be an overt act of
// relinquishment in perpetuity of all present and future rights to this
// software under copyright law.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
// IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
// OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
//
// For more information, please refer to <http://unlicense.org/> 
//----------------------------------------------------------------------

`ifndef __VLIB_1R1W_GENERIC_MEM_V__
`define __VLIB_1R1W_GENERIC_MEM_V__

module vlib_1r1w_generic_mem 
    #(parameter WIDTH = 32,
      parameter DEPTH = 8,
      parameter WR_REQ_REG = 0,
      parameter RD_REQ_REG = 0,
      parameter USE_BRAM = 0,   // 0: use flops; 1: use FPGA BRAM
      parameter RD_LAT = 1,     // total read latency. Must be >= 1 if using FPGA BRAM
      parameter ADDR_SZ = $clog2(DEPTH)
    )
    (
    input clk,
    input rst,

    input                   wr_en,
    input [ADDR_SZ-1:0]     wr_addr,
    input [WIDTH-1:0]       wr_data,

    input                       rd_en,
    input [ADDR_SZ-1:0]         rd_addr,
    
    output                      rd_out_vld,
    output [WIDTH-1:0]          rd_out_data
    );
    
    localparam RD_OUT_PPLN_STG_CNT = RD_LAT-RD_REQ_REG;
    
    //================== BODY ========================

    //--------- write req reg
    logic                   wr_en_d;
    logic [ADDR_SZ-1:0]     wr_addr_d;
    logic [WIDTH-1:0]       wr_data_d;
    
generate
  if (WR_REQ_REG == 0) begin: GEN_WR_REQ_REG_0
    assign wr_en_d = wr_en;
    assign wr_addr_d = wr_addr;
    assign wr_data_d = wr_data;
  end
  else begin: GEN_WR_REQ_REG_1
    always @(posedge clk) begin
        if (rst) begin
            wr_en_d <= 1'b0;
        end
        else begin
            wr_en_d <= wr_en;
        end
        
        if (wr_en) begin
            wr_addr_d <= wr_addr;
            wr_data_d <= wr_data;
        end
    end
  end
endgenerate
    
    //--------- read req reg
    logic                       rd_en_d;
    logic [ADDR_SZ-1:0]         rd_addr_d;    
    
generate
  if (RD_REQ_REG == 0) begin: GEN_RD_REQ_REG_0
    assign rd_en_d = rd_en;
    assign rd_addr_d = rd_addr;
  end
  else begin: GEN_RD_REQ_REG_1
    always @(posedge clk) begin
        if (rst) begin
            rd_en_d <= 1'b0;
        end
        else begin
            rd_en_d <= rd_en;
        end
        
        if (rd_en) begin
            rd_addr_d <= rd_addr;
        end
    end
  end
endgenerate
    
    //---------- write is always one cycle latency
    //---------- read latency is at least 1 for FPGA
    logic [RD_OUT_PPLN_STG_CNT:0]                  rd_out_vld_pipe;
    logic [RD_OUT_PPLN_STG_CNT:0] [WIDTH-1:0]      rd_out_data_pipe;   

generate   
  if (USE_BRAM == 1) begin: GEN_BRAM_MEM
    (* ram_style = "block" *)
    reg [WIDTH-1:0]     MEM [0:DEPTH-1];
    
    always @(posedge clk) begin
        rd_out_data_pipe[0] <= MEM[rd_addr_d];
        
        if (wr_en_d)
            MEM[wr_addr_d] <= wr_data_d;
    end
    
    always @(posedge clk) begin
        if (rst)
            rd_out_vld_pipe[0] <= 1'b0;
        else
            rd_out_vld_pipe[0] <= rd_en_d;
    
        for (int jj=1; jj<RD_OUT_PPLN_STG_CNT; jj++) begin
            if (rst) begin
                rd_out_vld_pipe[jj] <= 1'b0;
            end
            else begin
                rd_out_vld_pipe[jj] <= rd_out_vld_pipe[jj-1];
                
                if (rd_out_vld_pipe[jj-1]) 
                    rd_out_data_pipe[jj] <= rd_out_data_pipe[jj-1];
            end
        end
    end   
    
    assign rd_out_vld = rd_out_vld_pipe[RD_OUT_PPLN_STG_CNT-1];
    assign rd_out_data = rd_out_data_pipe[RD_OUT_PPLN_STG_CNT-1];      
  end   
  
  else begin: GEN_FLOP_MEM
    logic [DEPTH-1:0] [WIDTH-1:0]     MEM;
    
    always @(posedge clk) begin
        for (int ii=0; ii<DEPTH; ii++) begin
            if (wr_en_d & (wr_addr_d==ii[ADDR_SZ-1:0])) begin
                MEM[ii] <= wr_data_d;
            end
        end
    end

    assign rd_out_vld_pipe[0] = rd_en_d;
    assign rd_out_data_pipe[0] = MEM[rd_addr_d];
    
    always @(posedge clk) begin
        for (int jj=1; jj<=RD_OUT_PPLN_STG_CNT; jj++) begin
            if (rst) begin
                rd_out_vld_pipe[jj] <= 1'b0;
            end
            else begin
                rd_out_vld_pipe[jj] <= rd_out_vld_pipe[jj-1];
                
                if (rd_out_vld_pipe[jj-1]) 
                    rd_out_data_pipe[jj] <= rd_out_data_pipe[jj-1];
            end
        end
    end    

    assign rd_out_vld = rd_out_vld_pipe[RD_OUT_PPLN_STG_CNT];
    assign rd_out_data = rd_out_data_pipe[RD_OUT_PPLN_STG_CNT];    
  end  
endgenerate
    
endmodule
`endif  // __VLIB_1R1W_GENERIC_MEM_V__
