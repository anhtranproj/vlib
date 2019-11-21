//----------------------------------------------------------------------
// A barrel arithmetic left shifter with overflow/underflow protection
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

`ifndef __VLIB_ARITH_LSHIFT_V__
`define __VLIB_ARITH_LSHIFT_V__

module vlib_arith_lshift 
    #(parameter   BIT_CNT = 20,                         // the number of bits of the shifted data
      parameter   SHIFT_AMT_MAX = BIT_CNT,              // maximum value of shift_amt
      parameter   SHIFT_STG_CNT = $clog2(SHIFT_AMT_MAX) // the number of mux stages in the barrel shifter
    )
    (
    input [BIT_CNT-1:0]         in_data,
    input [SHIFT_STG_CNT-1:0]   shift_amt,   // how many bits would be shifted (< SHIFT_AMT_MAX)
    
    output [BIT_CNT-1:0]        out_data
    
    );
    
    //================== BODY ========================
    
    //------- overflow/underflow detection
    logic   overflow;
    logic   underflow;
    
generate
  if (SHIFT_STG_CNT==1) begin: GEN_SHIFT_STG_CNT_1
    always @* begin
        case (shift_amt)
            2'd0: begin
                overflow = 1'b0;
                underflow = 1'b0;
            end
            2'd1: begin
                overflow = ~in_data[BIT_CNT-1] & in_data[BIT_CNT-2];
                underflow = in_data[BIT_CNT-1] & ~in_data[BIT_CNT-2];                
            end
        endcase  
    end
  end
  
  if (SHIFT_STG_CNT==2) begin: GEN_SHIFT_STG_CNT_2
    always @* begin
        case (shift_amt)
            2'd0: begin
                overflow = 1'b0;
                underflow = 1'b0;
            end
            2'd1: begin
                overflow = ~in_data[BIT_CNT-1] & in_data[BIT_CNT-2];
                underflow = in_data[BIT_CNT-1] & ~in_data[BIT_CNT-2];                
            end
            2'd2: begin
                overflow = ~in_data[BIT_CNT-1] & |in_data[BIT_CNT-2:BIT_CNT-3];
                underflow = in_data[BIT_CNT-1] & ~&in_data[BIT_CNT-2:BIT_CNT-3];                
            end
            2'd3: begin
                overflow = ~in_data[BIT_CNT-1] & |in_data[BIT_CNT-2:BIT_CNT-4];
                underflow = in_data[BIT_CNT-1] & ~&in_data[BIT_CNT-2:BIT_CNT-4];                
            end
        endcase  
    end
  end
  
  if (SHIFT_STG_CNT==3) begin: GEN_SHIFT_STG_CNT_3
    always @* begin
        case (shift_amt)
            3'd0: begin
                overflow = 1'b0;
                underflow = 1'b0;
            end
            3'd1: begin
                overflow = ~in_data[BIT_CNT-1] & in_data[BIT_CNT-2];
                underflow = in_data[BIT_CNT-1] & ~in_data[BIT_CNT-2];                
            end
            3'd2: begin
                overflow = ~in_data[BIT_CNT-1] & |in_data[BIT_CNT-2:BIT_CNT-3];
                underflow = in_data[BIT_CNT-1] & ~&in_data[BIT_CNT-2:BIT_CNT-3];                
            end
            3'd3: begin
                overflow = ~in_data[BIT_CNT-1] & |in_data[BIT_CNT-2:BIT_CNT-4];
                underflow = in_data[BIT_CNT-1] & ~&in_data[BIT_CNT-2:BIT_CNT-4];                
            end
            3'd4: begin
                overflow = ~in_data[BIT_CNT-1] & |in_data[BIT_CNT-2:BIT_CNT-5];
                underflow = in_data[BIT_CNT-1] & ~&in_data[BIT_CNT-2:BIT_CNT-5];                
            end
            3'd5: begin
                overflow = ~in_data[BIT_CNT-1] & |in_data[BIT_CNT-2:BIT_CNT-6];
                underflow = in_data[BIT_CNT-1] & ~&in_data[BIT_CNT-2:BIT_CNT-6];                
            end
            3'd6: begin
                overflow = ~in_data[BIT_CNT-1] & |in_data[BIT_CNT-2:BIT_CNT-7];
                underflow = in_data[BIT_CNT-1] & ~&in_data[BIT_CNT-2:BIT_CNT-7];                
            end
            3'd7: begin
                overflow = ~in_data[BIT_CNT-1] & |in_data[BIT_CNT-2:BIT_CNT-8];
                underflow = in_data[BIT_CNT-1] & ~&in_data[BIT_CNT-2:BIT_CNT-8];                
            end
        endcase  
    end
  end
  
  if (SHIFT_STG_CNT==4) begin: GEN_SHIFT_STG_CNT_4
    always @* begin
        case (shift_amt)
            4'd0: begin
                overflow = 1'b0;
                underflow = 1'b0;
            end
            4'd1: begin
                overflow = ~in_data[BIT_CNT-1] & in_data[BIT_CNT-2];
                underflow = in_data[BIT_CNT-1] & ~in_data[BIT_CNT-2];                
            end
            4'd2: begin
                overflow = ~in_data[BIT_CNT-1] & |in_data[BIT_CNT-2:BIT_CNT-3];
                underflow = in_data[BIT_CNT-1] & ~&in_data[BIT_CNT-2:BIT_CNT-3];                
            end
            4'd3: begin
                overflow = ~in_data[BIT_CNT-1] & |in_data[BIT_CNT-2:BIT_CNT-4];
                underflow = in_data[BIT_CNT-1] & ~&in_data[BIT_CNT-2:BIT_CNT-4];                
            end
            4'd4: begin
                overflow = ~in_data[BIT_CNT-1] & |in_data[BIT_CNT-2:BIT_CNT-5];
                underflow = in_data[BIT_CNT-1] & ~&in_data[BIT_CNT-2:BIT_CNT-5];                
            end
            4'd5: begin
                overflow = ~in_data[BIT_CNT-1] & |in_data[BIT_CNT-2:BIT_CNT-6];
                underflow = in_data[BIT_CNT-1] & ~&in_data[BIT_CNT-2:BIT_CNT-6];                
            end
            4'd6: begin
                overflow = ~in_data[BIT_CNT-1] & |in_data[BIT_CNT-2:BIT_CNT-7];
                underflow = in_data[BIT_CNT-1] & ~&in_data[BIT_CNT-2:BIT_CNT-7];                
            end
            4'd7: begin
                overflow = ~in_data[BIT_CNT-1] & |in_data[BIT_CNT-2:BIT_CNT-8];
                underflow = in_data[BIT_CNT-1] & ~&in_data[BIT_CNT-2:BIT_CNT-8];                
            end
            4'd8: begin
                overflow = ~in_data[BIT_CNT-1] & |in_data[BIT_CNT-2:BIT_CNT-9];
                underflow = in_data[BIT_CNT-1] & ~&in_data[BIT_CNT-2:BIT_CNT-9];                
            end        
            4'd9: begin
                overflow = ~in_data[BIT_CNT-1] & |in_data[BIT_CNT-2:BIT_CNT-10];
                underflow = in_data[BIT_CNT-1] & ~&in_data[BIT_CNT-2:BIT_CNT-10];                
            end
            4'd10: begin
                overflow = ~in_data[BIT_CNT-1] & |in_data[BIT_CNT-2:BIT_CNT-11];
                underflow = in_data[BIT_CNT-1] & ~&in_data[BIT_CNT-2:BIT_CNT-11];                
            end
            4'd11: begin
                overflow = ~in_data[BIT_CNT-1] & |in_data[BIT_CNT-2:BIT_CNT-12];
                underflow = in_data[BIT_CNT-1] & ~&in_data[BIT_CNT-2:BIT_CNT-12];                
            end
            4'd12: begin
                overflow = ~in_data[BIT_CNT-1] & |in_data[BIT_CNT-2:BIT_CNT-13];
                underflow = in_data[BIT_CNT-1] & ~&in_data[BIT_CNT-2:BIT_CNT-13];                
            end
            4'd13: begin
                overflow = ~in_data[BIT_CNT-1] & |in_data[BIT_CNT-2:BIT_CNT-14];
                underflow = in_data[BIT_CNT-1] & ~&in_data[BIT_CNT-2:BIT_CNT-14];                
            end
            4'd14: begin
                overflow = ~in_data[BIT_CNT-1] & |in_data[BIT_CNT-2:BIT_CNT-15];
                underflow = in_data[BIT_CNT-1] & ~&in_data[BIT_CNT-2:BIT_CNT-15];                
            end
            4'd15: begin
                overflow = ~in_data[BIT_CNT-1] & |in_data[BIT_CNT-2:BIT_CNT-16];
                underflow = in_data[BIT_CNT-1] & ~&in_data[BIT_CNT-2:BIT_CNT-16];                
            end
        endcase  
    end
  end  
endgenerate

    //--------- left shifting
    logic [SHIFT_STG_CNT-1:0] [BIT_CNT-1:0]     shift_stg;
    
    assign shift_stg[0] = (shift_amt[0]) ? {in_data[BIT_CNT-2:0], 1'b0} :
                          in_data;

generate
    for (genvar ii=1; ii<SHIFT_STG_CNT; ii++) begin: stage_ii
        assign shift_stg[ii] = (shift_amt[ii]) ? {shift_stg[ii-1][BIT_CNT-(1<<ii)-1:0], {(1<<ii){1'b0}}} :
                               shift_stg[ii-1];
    end
endgenerate

    assign out_data = shift_stg[SHIFT_STG_CNT-1];

endmodule
`endif // __VLIB_ARITH_LSHIFT_V__
