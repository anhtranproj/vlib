//----------------------------------------------------------------------
// A synchronous nearfull-triggered flop-based fifo with arbitrary DEPTH.
// The nearfull signal is triggered if the avaible entry count
// is less than or equal to a Triggered_Threshold.
//----------------------------------------------------------------------
// Author: Andrew (Anh) Tran
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

`ifndef __VLIB_NFT_FLOP_FIFO_V__
`define __VLIB_NFT_FLOP_FIFO_V__

module vlib_nft_flop_fifo
    #(parameter WIDTH = 32,
      parameter DEPTH = 8,
      parameter NFT_THRESHOLD = 2,              // nearfull triggerred threshold
      parameter DEASSERT_NEARFULL_IF_POP = 1,   // if pop is on and buffer is not empty, nearfull is deasserted
      parameter ADR_SZ = $clog2(DEPTH)
    )
    (
    input clk,
    input rst,

    input                   push,  
    output                  nearfull,
    input [WIDTH-1:0]       wdata, // wdata will be written to the fifo if push & ~full   
    
    output                  empty,    
    input                   pop,
    output [WIDTH-1:0]      rdata, // rdata is valid at the same cycle as pop if pop & ~empty
    
    output logic [ADR_SZ:0]      usage     // how many entries in the fifo have been used
    );
    
    localparam DEPTH_SUB_1 = DEPTH-1;
    

    logic [DEPTH-1:0] [WIDTH-1:0]   ARRY;

    logic full;
    
    //================== BODY ========================
    //------ wr_en and rd_en
    logic wr_en;
    logic rd_en;
        
    assign wr_en = push & ~full;
    assign rd_en = ~empty & pop;

    //------ write to and read from the ARRY
    logic [ADR_SZ-1:0] wr_addr, nxt_wr_addr;
    logic [ADR_SZ-1:0] rd_addr, nxt_rd_addr;

    always @(posedge clk) begin
        for(int ii=0; ii<DEPTH; ii++) begin
            if ((wr_addr == ii[ADR_SZ-1:0]) & wr_en) begin
                ARRY[ii] <= wdata;
            end
        end
    end
    
    assign rdata = ARRY[rd_addr];
    
    //-------- update wr_addr and rd_addr
    assign nxt_wr_addr = (wr_en) ? ((wr_addr==DEPTH_SUB_1[ADR_SZ-1:0]) ? {ADR_SZ{1'b0}} : wr_addr+1'b1) :
                         wr_addr;
    
    always @(posedge clk) begin
        if (rst)
            wr_addr <= {ADR_SZ{1'b0}};
        else
            wr_addr <= nxt_wr_addr;
    end

    assign nxt_rd_addr = (rd_en) ? ((rd_addr==DEPTH_SUB_1[ADR_SZ-1:0]) ? {ADR_SZ{1'b0}} : rd_addr+1'b1) :
                         rd_addr;
    
    always @(posedge clk) begin
        if (rst)
            rd_addr <= {ADR_SZ{1'b0}};
        else
            rd_addr <= nxt_rd_addr;
    end
    
    //--------- full/empty check
    always @(posedge clk) begin
        if (rst) begin
            usage <= {(ADR_SZ+1){1'b0}};
        end
        else begin
            if (wr_en & ~rd_en)
                usage <= usage + 1'b1;
            else if (~wr_en & rd_en)
                usage <= usage - 1'b1;
        end
    end
    
    assign empty = (~|usage);
    assign full = (usage == DEPTH[ADR_SZ:0]);
    
generate   
  if (DEASSERT_NEARFULL_IF_POP) begin: PROPAGATED_POP
    assign nearfull = ((usage + NFT_THRESHOLD[ADR_SZ-1:0]) >= DEPTH[ADR_SZ:0]) & 
                      ~rd_en;
  end
  else begin: NOT_PROPAGATED_POP
    assign nearfull = ((usage + NFT_THRESHOLD[ADR_SZ-1:0]) >= DEPTH[ADR_SZ:0]);  
  end
endgenerate               
               
    //================ ASSERTIONS ================
    logic overflow;
    assign overflow = push & full;
    
    OVERFLOW_CHECK_A: assert property (@(posedge clk) disable iff (rst) 
                                       (~overflow))
                                      else $fatal("%t ERROR: push while the fifo is full");

endmodule
`endif  // __VLIB_NFT_FLOP_FIFO_V__
