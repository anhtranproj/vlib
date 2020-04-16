//----------------------------------------------------------------------
// A data width resizer with s/drdy flowcontrol.
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

`ifndef __VLIB_DTWD_RESIZE_V__
`define __VLIB_DTWD_RESIZE_V__

module vlb_dtwd_resize 
    #(parameter   IN_DATA_WD = 20,  // must be multiple or divided by OUT_DATA_WD
      parameter   OUT_DATA_WD = 4,  // must be multiple or divided by IN_DATA_WD
      parameter   OUT_PPLN_OPT = 0  // 0: not pipelined; 1: sd_input; 2: sd_output; 3: sd_iofull
    )
    (
    input   clk,
    input   rst,
    
    input                       in_srdy,
    output                      in_drdy,
    input [IN_DATA_WD-1:0]      in_data,

    output                       out_srdy,
    input                        out_drdy,
    output [OUT_DATA_WD-1:0]     out_data
    );
    
    //================== BODY ========================
generate    
  if (IN_DATA_WD < OUT_DATA_WD) begin: GEN_UPSIZE
    vlb_dtwd_upsize 
    #(.WORD_WD      (IN_DATA_WD),               // 1: bit, 8: byte, etc
      .OUT_WORD_CNT (OUT_DATA_WD/IN_DATA_WD),   // the number of output words for oarallelizing
      .OUT_PPLN_OPT (OUT_PPLN_OPT)              // 0: not pipelined; 1: sd_input; 2: sd_output; 3: sd_iofull
    )
    upsize_ins
    (
    .clk    (clk),
    .rst    (rst),
    
    .in_srdy    (in_srdy),
    .in_drdy    (in_drdy),
    .in_data    (in_data),

    .out_srdy   (out_srdy),
    .out_drdy   (out_drdy),
    .out_data   (out_data)
    );
  end
  else begin: GEN_DOWNSIZE
    vlib_dtwd_downsize 
    #(.WORD_WD      (OUT_DATA_WD),              // 1: bit, 8: byte, etc
      .IN_WORD_CNT  (IN_DATA_WD/OUT_DATA_WD),   // the number of input words for serializing
      .OUT_PPLN_OPT (OUT_PPLN_OPT)              // 0: not pipelined; 1: sd_input; 2: sd_output; 3: sd_iofull
    )
    downsize_ins
    (
    .clk    (clk),
    .rst    (rst),
    
    .in_srdy    (in_srdy),
    .in_drdy    (in_drdy),
    .in_data    (in_data),

    .out_srdy   (out_srdy),
    .out_drdy   (out_drdy),
    .out_data   (out_data)
    );
  end
endgenerate
    
endmodule
`endif // __VLIB_DTWD_RESIZE_V__
