//----------------------------------------------------------------------
// A delay pipe without flowcontrol
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

`ifndef __VLIB_NOFC_DLYPP_V__
`define __VLIB_NOFC_DLYPP_V__

module vlib_nofc_dlypp 
    #(parameter WIDTH = 64,
      parameter DELAY = 3
    )
    (
    input   clk,
    input   rst,
    
    input               in_vld,
    input [WIDTH-1:0]   in_data,
    
    output logic              out_vld,
    output logic [WIDTH-1:0]  out_data
    );

    logic [DELAY:0]               vld;
    logic [DELAY:0] [WIDTH-1:0]   data_arry;
    
    //================== BODY ==================
generate
  if (DELAY == 0) begin: GEN_DELAY_0
    assign out_vld = in_vld;
    assign out_data = in_data;
  end
  else begin: GEN_DELAY_LARGER_0
    assign vld[0] = in_vld;
    assign data_arry[0] = in_data;

    for (genvar ii=0; ii<DELAY; ii=ii+1) begin: GEN_NOFC_PPLN
        vlib_nofc_ppln 
        #(.WIDTH (WIDTH)
        )
        nofc_ppln_ins
        (
            .clk    (clk),   
            .rst    (rst),
    
            .in_vld     (vld[ii]),
            .in_data    (data_arry[ii]),
    
            .out_vld    (vld[ii+1]),
            .out_data   (data_arry[ii+1])
        );
    end

    assign out_vld = vld[DELAY];
    assign out_data = data_arry[DELAY];
  end    
endgenerate

endmodule
`endif //__VLIB_NOFC_DLYPP_V__
