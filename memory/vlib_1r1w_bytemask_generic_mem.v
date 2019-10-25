//----------------------------------------------------------------------
// A generic dual-port 1R1W memory with write bytemask
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

`ifndef __VLIB_1R1W_BYTEMASK_GENERIC_MEM_V__
`define __VLIB_1R1W_BYTEMASK_GENERIC_MEM_V__

module vlib_1r1w_bytemask_generic_mem 
    #(parameter WIDTH = 32,     // must be multiple of bytes
      parameter DEPTH = 8,
      parameter USE_BRAM = 0,   // 0: use flops; 1: use FPGA BRAM
      parameter RD_LAT = 1,     // must be >=1 if using BRAM
      parameter integer BYTE_CNT = WIDTH/8,
      parameter ADDR_SZ = $clog2(DEPTH)
    )
    (
    input clk,
    input rst,

    input                       wr_en,
    input [ADDR_SZ-1:0]         wr_addr,
    input [WIDTH-1:0]           wr_data,
    input [BYTE_CNT-1:0]        wr_bytemask,

    input                   rd_en,
    input [ADDR_SZ-1:0]     rd_addr,
    
    output                  rd_out_vld,
    output [WIDTH-1:0]      rd_out_data
    );
    
    //================== BODY ========================
    logic [RD_LAT:0]                  rd_out_vld_pipe;
    logic [RD_LAT:0] [WIDTH-1:0]      rd_out_data_pipe;       

    //---------- write (always one cycle latency)
generate
 if (USE_BRAM==1) begin: GEN_BRAM_MEM
    (* ram_style = "block" *)
    reg [WIDTH-1:0]     MEM [0:DEPTH-1];   
    
    always @(posedge clk) begin
        rd_out_data_pipe[0] <= MEM[rd_addr];
        
        if (wr_en) begin
          for (int jj=0; jj<BYTE_CNT; jj++) begin
            if (wr_bytemask[jj])
              MEM[wr_addr][jj*8 +: 8] <= wr_data[jj*8 +: 8];
          end 
        end    
    end
    
    always @(posedge clk) begin
        if (rst)
            rd_out_vld_pipe[0] <= 1'b0;
        else
            rd_out_vld_pipe[0] <= rd_en;
    
        for (int kk=1; kk<RD_LAT; kk++) begin
            if (rst) begin
                rd_out_vld_pipe[kk] <= 1'b0;
            end
            else begin
                rd_out_vld_pipe[kk] <= rd_out_vld_pipe[kk-1];
                
                if (rd_out_vld_pipe[kk-1]) 
                    rd_out_data_pipe[kk] <= rd_out_data_pipe[kk-1];
            end
        end
    end   
    
    assign rd_out_vld = rd_out_vld_pipe[RD_LAT-1];
    assign rd_out_data = rd_out_data_pipe[RD_LAT-1];          
 end
 
 else begin: GEN_FLOP_MEM
    logic [DEPTH-1:0] [WIDTH-1:0]     MEM;    
    
    always @(posedge clk) begin
        for (int ii=0; ii<DEPTH; ii++) begin
            for (int jj=0; jj<BYTE_CNT; jj++) begin
                if (wr_en & (wr_addr==ii[ADDR_SZ-1:0]) & wr_bytemask[jj]) begin
                    MEM[ii][jj*8 +: 8] <= wr_data[jj*8 +: 8];
                end    
            end
        end
    end
    
    //--------- read
    assign rd_out_vld_pipe[0] = rd_en;
    assign rd_out_data_pipe[0] = MEM[rd_addr];
    
    always @(posedge clk) begin
        for (int kk=1; kk<=RD_LAT; kk++) begin
            if (rst) begin
                rd_out_vld_pipe[kk] <= 1'b0;
            end
            else begin
                rd_out_vld_pipe[kk] <= rd_out_vld_pipe[kk-1];
                
                if (rd_out_vld_pipe[kk-1]) 
                    rd_out_data_pipe[kk] <= rd_out_data_pipe[kk-1];
            end
        end
    end
    
    assign rd_out_vld = rd_out_vld_pipe[RD_LAT];
    assign rd_out_data = rd_out_data_pipe[RD_LAT];
  end    
endgenerate    
    
    //=========== ASSERTIONS ============
    //------ WIDTH must be in multiple of bytes
    ILLEGAL_WIDTH_CHECK_A: assert property (@(posedge clk) disable iff (rst) 
                                            ((WIDTH%8)==0))
                                           else $fatal(1, "%t ERROR: WIDTH is not multiple of bytes");    
    
endmodule
`endif  // __VLIB_1R1W_BYTEMASK_GENERIC_MEM_V__
