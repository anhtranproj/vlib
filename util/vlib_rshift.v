//----------------------------------------------------------------------
// A barrel right shifter.
// The shifter is in "word" resolution.
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

`ifndef __VLIB_RSHIFT_V__
`define __VLIB_RSHIFT_V__

module vlib_rshift 
    #(parameter   WORD_WD = 8,                          // 1: bit, 8: byte, etc
      parameter   WORD_CNT = 20,                        // the number of words of the shifted data
      parameter   SHIFT_AMT_MAX = WORD_CNT,             // maximum value of shift_amt
      parameter   SHIFT_STG_CNT = $clog2(SHIFT_AMT_MAX) // the number of mux stages in the barrel shifter
    )
    (
    input [WORD_CNT*WORD_WD-1:0]     in_data,
    input [SHIFT_STG_CNT-1:0]        shift_amt,   // how many words would be shifted (< SHIFT_AMT_MAX)
    
    output [WORD_CNT*WORD_WD-1:0]    out_data
    
    );
    
    //================== BODY ========================
    logic [SHIFT_STG_CNT-1:0] [WORD_CNT*WORD_WD-1:0]     shift_stg;
    
    assign shift_stg[0] = (shift_amt[0]) ? {{WORD_WD{1'b0}}, in_data[WORD_CNT*WORD_WD-1:WORD_WD]} :
                          in_data;

generate
    for (genvar ii=1; ii<SHIFT_STG_CNT; ii++) begin: stage_ii
        assign shift_stg[ii] = (shift_amt[ii]) ? {{((1<<ii)*WORD_WD){1'b0}}, shift_stg[ii-1][WORD_CNT*WORD_WD-1:(1<<ii)*WORD_WD]} :
                               shift_stg[ii-1];
    end
endgenerate

    assign out_data = shift_stg[SHIFT_STG_CNT-1];
    
endmodule
`endif // __VLIB_RSHIFT_V__
