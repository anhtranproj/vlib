//----------------------------------------------------------------------
// A 1-to-N demux built from a binary tree of 1-to-2 demuxes
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

`ifndef __VLIB_1_N_DEMUX_V__
`define __VLIB_1_N_DEMUX_V__

module vlib_1_n_demux
    #(parameter OUT_WORD_CNT = 32,
      parameter WORD_SZ = 8,
      parameter INVALID_OUT_DATA_TO_ZERO = 1,   // 0: mirror in_data to all; 1: make invalid data become zeros
      parameter IDX_SZ = $clog2(OUT_WORD_CNT)
    )
    (
    input [WORD_SZ-1:0]                             in_data,
    input [IDX_SZ-1:0]                              in_output_idx,  

    output logic [OUT_WORD_CNT-1:0] [WORD_SZ-1:0]   out_data,
    output logic [OUT_WORD_CNT-1:0]                 out_vldmask
    );
    
    //==================== BODY ===================
`ifdef FPGA    
    always @* begin
        out_vldmask = '0;
        out_vldmask[in_output_idx] = 1'b1;
    end
generate
  if (INVALID_OUT_DATA_TO_ZERO==1) begin
    always @* begin
        out_data = '0;
        out_data[in_output_idx] = in_data;
    end
  end
  else begin
    always @* begin
      for (int jj=0; jj<OUT_WORD_CNT; jj++) begin
        out_data[jj] = in_data;
      end
    end    
  end
endgenerate
    
`else    
generate
    logic [IDX_SZ-1:0] [2**(IDX_SZ-1)-1:0]                 lvl_vld;

if (OUT_WORD_CNT == 1) begin: out_cnt_1
    assign out_vldmask[0] = 1'b1;
    assign out_data[0] = in_data;
end

else if (OUT_WORD_CNT == 2) begin: out_cnt_2
    assign out_vldmask[0] = ~in_output_idx[0] ? 1'b1 : 1'b0;
    assign out_vldmask[1] = in_output_idx[0] ? 1'b1 : 1'b0;
    
  if (INVALID_OUT_DATA_TO_ZERO==1) begin
    assign out_data[0] = out_vldmask[0] ? in_data : {WORD_SZ{1'b0}};
    assign out_data[1] = out_vldmask[1] ? in_data : {WORD_SZ{1'b0}};
  end
  else begin
    assign out_data[0] = in_data;
    assign out_data[1] = in_data;
  end
end

else begin: out_cnt_greater_2
    assign lvl_vld[0][0] = 1'b1;

    for (genvar ii=1; ii<IDX_SZ; ii++) begin: lvl_ii
        for (genvar jj=0; jj<2**ii; jj++) begin: col_jj
            if (jj%2) begin: jj_even
                assign lvl_vld[ii][jj] = in_output_idx[IDX_SZ-ii] ? lvl_vld[ii-1][jj/2] : 1'b0;
            end
            else begin: jj_odd
                assign lvl_vld[ii][jj] = ~in_output_idx[IDX_SZ-ii] ? lvl_vld[ii-1][jj/2] : 1'b0;
            end
        end
    end

    for (genvar jj=0; jj<OUT_WORD_CNT; jj++) begin: last_lvl_col_jj 
        if (jj%2) begin: jj_even 
            assign out_vldmask[jj] = in_output_idx[0] ? lvl_vld[IDX_SZ-1][jj/2] : 1'b0;
        end
        else begin: jj_odd
            assign out_vldmask[jj] = ~in_output_idx[0] ? lvl_vld[IDX_SZ-1][jj/2] : 1'b0;
        end

    end
  if (INVALID_OUT_DATA_TO_ZERO==1) begin
    always @* begin
      for (int jj=0; jj<OUT_WORD_CNT; jj++) begin
        out_data[jj] = out_vldmask[jj] ? in_data : {WORD_SZ{1'b0}};
      end
    end
  end
  else begin
    always @* begin
      for (int jj=0; jj<OUT_WORD_CNT; jj++) begin
        out_data[jj] = in_data;
      end
    end
  end
end
endgenerate
`endif

endmodule
`endif // __VLIB_1_N_DEMUX_V__
