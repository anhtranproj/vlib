//----------------------------------------------------------------------
// A synchronous nearfull-triggered fifo with arbitrary DEPTH using shifted register.
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

`ifndef __VLIB_NFT_SHREG_FIFO_V__
`define __VLIB_NFT_SHREG_FIFO_V__

module vlib_nft_shreg_fifo
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
    

    logic [DEPTH-1:0] [WIDTH-1:0]   SHREG;

    logic full;
    
    //================== BODY ========================
    //------ wr_en and rd_en
    logic wr_en;
    logic rd_en;
        
    assign wr_en = push & ~full;
    assign rd_en = ~empty & pop;

    //------ write to the tail of the shifted reg; and shift if read
    logic [ADR_SZ:0]  tail_ptr;
    
    assign tail_ptr = usage;
    
    always @(posedge clk) begin
      for(int ii=0; ii<DEPTH; ii++) begin
        if (rd_en) begin
            if (wr_en & (tail_ptr[ADR_SZ-1:0] == ii[ADR_SZ-1:0])) begin
                SHREG[ii] <= wdata;
            end
            else begin
                SHREG[ii] <= SHREG[ii+1]
            end
        end
      end  
    end
    
    //------ read data is always at reg[0]
    assign rdata = SHREG[0];
    
    //------ full and empty check
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
                                      else $fatal(1, "%t ERROR: push while the fifo is full");

endmodule
`endif  // __VLIB_NFT_SHREG_FIFO_V__
