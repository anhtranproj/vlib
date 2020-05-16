//----------------------------------------------------------------------
// Convert a delayed flow-control input to srdy/drdy output.
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

`ifndef __VLIB_DFC2SD_CVT_V__
`define __VLIB_DFC2SD_CVT_V__

module vlib_dfc2sd_cvt
    #(parameter WIDTH = 32,
      parameter LATENCY = 2,
      parameter THRESHOLD = 1,
      parameter ASSERT_FC_N_IF_POP = 1,
      parameter FC_N_REG = 0,
      parameter USE_SHREG_FIFO = 1
    )
    (
    input clk,
    input rst,

    input               in_vld,  
    output              in_fc_n,
    input [WIDTH-1:0]   in_data, 
    
    output              out_srdy,    
    input               out_drdy,
    output [WIDTH-1:0]  out_data
    );
    
    localparam EFF_LATENCY = (FC_N_REG==0) ? LATENCY : (LATENCY+1);
    localparam DEPTH = EFF_LATENCY+THRESHOLD;
    
generate
  if (EFF_LATENCY==0) begin: EFF_LATENCY_0
    assign out_srdy = in_vld;
    assign in_fc_n = out_drdy;
    assign out_data = in_data;
  end
  else begin: EFF_LATENCY_GREATER_0
    logic   fifo_nearfull;
    logic   fifo_empty;
      
   if (USE_SHREG_FIFO) begin: USE_REG_FIFO_YES
    vlib_nft_shreg_fifo
    #(.WIDTH                    (WIDTH),
      .DEPTH                    (DEPTH),
      .NFT_THRESHOLD            (EFF_LATENCY),
      .DEASSERT_NEARFULL_IF_POP (ASSERT_FC_N_IF_POP)
    )
    nft_shreg_fifo_ins
    (
    .clk    (clk),
    .rst    (rst),

    .push       (in_vld),  
    .nearfull   (fifo_nearfull),
    .wdata      (in_data), // wdata will be written to the fifo if push & ~full   
    
    .empty      (fifo_empty),    
    .pop        (out_drdy),
    .rdata      (out_data),
    
    .usage      ()
    );    
   end
   else begin: USE_SHREG_FIFO_NO
    vlib_nft_flop_fifo
    #(.WIDTH                    (WIDTH),
      .DEPTH                    (DEPTH),
      .NFT_THRESHOLD            (EFF_LATENCY),
      .DEASSERT_NEARFULL_IF_POP (ASSERT_FC_N_IF_POP)
    )
    nft_flop_fifo_ins
    (
    .clk    (clk),
    .rst    (rst),

    .push       (in_vld),  
    .nearfull   (fifo_nearfull),
    .wdata      (in_data), // wdata will be written to the fifo if push & ~full   
    
    .empty      (fifo_empty),    
    .pop        (out_drdy),
    .rdata      (out_data),
    
    .usage      ()
    );
   end 
   
    if (FC_N_REG == 0) begin
        assign in_fc_n = ~fifo_nearfull;
    end
    else begin
        always @(posedge clk) begin
            if (rst)
                in_fc_n <= 1'b1;
            else
                in_fc_n <= ~fifo_nearfull;
        end
    end
    
    assign out_srdy = ~fifo_empty;
    
  end
endgenerate
    
    
endmodule
`endif  // __VLIB_DFC2SD_CVT_V__
