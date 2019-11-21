//----------------------------------------------------------------------
// A N-to-1 mux built from a binary tree of 2-to-1 muxes
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

`ifndef __VLIB_N_1_MUX_V__
`define __VLIB_N_1_MUX_V__

module vlib_n_1_mux
    #(parameter IN_WORD_CNT = 32,
      parameter WORD_SZ = 8,
      parameter SEL_SZ = $clog2(IN_WORD_CNT)
    )
    (
    input   [IN_WORD_CNT-1:0] [WORD_SZ-1:0]     in,
    input   [SEL_SZ-1:0]                        mux_sel,  

    output logic [WORD_SZ-1:0]                  out
    );
    localparam lvl_cnt = SEL_SZ;

    localparam [lvl_cnt-1:0] [31:0] lvl_mux_cnt = lvl_mux_cnt_calc();
    localparam [lvl_cnt-1:0] [0:0] lvl_in_remain = lvl_in_remain_calc();
    
    //================= BODY =====================
`ifdef FPGA
    assign out = in[mux_sel];
`else    

    logic   [lvl_cnt-1:0] [lvl_mux_cnt[0]:0] [WORD_SZ-1:0]    lvl; 
    
generate
  if (IN_WORD_CNT == 1) begin: in_cnt_1
    assign out = in[0];
  end

  else if (IN_WORD_CNT == 2) begin: in_cnt_2
    assign out = mux_sel[0] ? in[1] : in[0];
  end

  else begin: in_cnt_greater_2
    //-------- level 0
    for (genvar jj=0; jj<(lvl_mux_cnt[0]-1); jj++) begin: lvl_0_mux_jj
        assign lvl[0][jj] = mux_sel[0] ? in[2*jj+1] : in[2*jj];
    end    

    if (lvl_in_remain[0]==0) begin: lvl_0_in_remain_0
        assign lvl[0][lvl_mux_cnt[0]-1] = mux_sel[0] ? in[2*(lvl_mux_cnt[0]-1)+1] : in[2*(lvl_mux_cnt[0]-1)];
    end
    else begin: lvl_0_in_remain_1
        assign lvl[0][lvl_mux_cnt[0]-1] = in[2*(lvl_mux_cnt[0]-1)];
    end

    //-------- level ii
    for (genvar ii=1; ii<lvl_cnt; ii++) begin: lvl_ii
        for (genvar jj=0; jj<(lvl_mux_cnt[ii]-1); jj++) begin: lvl_ii_mux_jj
            assign lvl[ii][jj] = mux_sel[ii] ? lvl[ii-1][2*jj+1] : lvl[ii-1][2*jj];
        end

        if (lvl_in_remain[ii]==0) begin: lvl_ii_in_remain_0
            assign lvl[ii][lvl_mux_cnt[ii]-1] = mux_sel[ii] ? lvl[ii-1][2*(lvl_mux_cnt[ii]-1)+1] : lvl[ii-1][2*(lvl_mux_cnt[ii]-1)];
        end
        else begin: lvl_ii_in_remain_1
            assign lvl[ii][lvl_mux_cnt[ii]-1] = lvl[ii-1][2*(lvl_mux_cnt[ii]-1)];
        end
    end

    //------ final output
    assign out = lvl[lvl_cnt-1][0];
  end
endgenerate

    //=============== FUNCTIONS =====================
    function [lvl_cnt-1:0] [31:0] lvl_mux_cnt_calc;
        begin
            lvl_mux_cnt_calc[0] = (IN_WORD_CNT%2) ? (IN_WORD_CNT/2 + 1) : (IN_WORD_CNT/2);

            for (int kk=1; kk<lvl_cnt; kk++) begin
                lvl_mux_cnt_calc[kk] = (lvl_mux_cnt_calc[kk-1]%2) ? (lvl_mux_cnt_calc[kk-1]/2 + 1) : (lvl_mux_cnt_calc[kk-1]/2);
            end
        end    
    endfunction

    function [lvl_cnt-1:0] [0:0] lvl_in_remain_calc;
        begin
            lvl_in_remain_calc[0] = (IN_WORD_CNT%2);

            for (int kk=1; kk<lvl_cnt; kk++) begin
                lvl_in_remain_calc[kk] = (lvl_mux_cnt[kk-1]%2);
            end
        end    
    endfunction
`endif

endmodule
`endif // __VLIB_N_1_MUX_V__
