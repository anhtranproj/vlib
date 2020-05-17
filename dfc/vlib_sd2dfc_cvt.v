//----------------------------------------------------------------------
// Convert a srdy/drdy input to delayed flow-control output.
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

`ifndef __VLIB_SD2DFC_CVT_V__
`define __VLIB_SD2DFC_CVT_V__

module vlib_sd2dfc_cvt
    #(parameter WIDTH = 32,
      parameter VLD_REG = 0,    // whether out_vld is flopped before being sent out
      parameter FC_N_REG = 0    // whether out_fc_n is flopped before being used
    )
    (
    input   clk,
    input   rst,

    input                       in_srdy,    
    output logic                in_drdy,
    input [WIDTH-1:0]           in_data,    
    
    output logic                out_vld,  
    input                       out_fc_n,
    output logic [WIDTH-1:0]    out_data 
    );
    
    logic out_vld_tmp;
    assign out_vld_tmp = in_srdy & in_drdy;
    
generate
  if (VLD_REG) begin: VLD_REG_1
    always @(posedge clk) begin
        if (rst) begin
            out_vld <= 1'b0;
        end
        else begin
            out_vld <= out_vld_tmp;
        end
        
        if (out_vld_tmp)
            out_data <= in_data;
    end
  end
  else begin: VLD_REG_0
    assign out_vld = out_vld_tmp;
    assign out_data = in_data;
  end
endgenerate

generate
  if (FC_N_REG) begin: FC_N_REG_1
    always @(posedge clk) begin
        if (rst) begin
            in_drdy <= 1'b0;
        end
        else begin
            in_drdy <= out_fc_n;
        end
    end
  end
  else begin: FC_N_REG_0
    assign in_drdy = out_fc_n;
  end
endgenerate

    
endmodule
`endif  // __VLIB_SD2DFC_CVT_V__
