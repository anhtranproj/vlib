//----------------------------------------------------------------------
// A pipeline cell without flowcontrol
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

`ifndef __VLIB_NOFC_PPLN_V__
`define __VLIB_NOFC_PPLN_V__

module vlib_nofc_ppln 
    #(parameter WIDTH = 64,
      parameter PPLN_OPT = 1 // 0: not pipelined; 1: pipelined
      
    )
    (
    input   clk,
    input   rst,
    
    input               in_vld,
    input [WIDTH-1:0]   in_data,
    
    output logic              out_vld,
    output logic [WIDTH-1:0]  out_data
    );

    //================== BODY ==================
generate    
if (PPLN_OPT == 0) begin: GEN_PPLN_OPT_0
    assign out_vld = in_vld;
    assign out_data = in_data;
end
else begin: GEN_PPLN_OPT_1
    always @(posedge clk) begin
        if (rst) begin
            out_vld <= 1'b0;
        end
        else begin
            out_vld <= in_vld;
        end
        
        if (in_vld)
            out_data <= in_data;
    end
end    
endgenerate

endmodule
`endif //__VLIB_NOFC_PPLN_V__
