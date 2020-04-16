//----------------------------------------------------------------------
// Upsize/deserialize a sequence of single-word input data to a multi-word output data.
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

`ifndef __VLIB_DTWD_UPSIZE_V__
`define __VLIB_DTWD_UPSIZE_V__

module vlib_dtwd_upsize 
    #(parameter   WORD_WD = 8,          // 1: bit, 8: byte, etc
      parameter   OUT_WORD_CNT = 20,    // the number of output words for parallelizing
      parameter   OUT_PPLN_OPT = 0      // 0: not pipelined; 1: sd_input; 2: sd_output; 3: sd_iofull
    )
    (
    input   clk,
    input   rst,
    
    input                in_srdy,
    output               in_drdy,
    input [WORD_WD-1:0]  in_data,

    output                                      out_srdy,
    input                                       out_drdy,
    output [OUT_WORD_CNT-1:0] [WORD_WD-1:0]     out_data
    );
    
    localparam OUT_WORD_IDX_SZ = $clog2(OUT_WORD_CNT);
    localparam OUT_WORD_CNT_SUB_1 = OUT_WORD_CNT - 1;
    
    //================== BODY ========================
    logic                                   out_srdy_tmp;
    logic                                   out_drdy_tmp;
    logic [OUT_WORD_CNT-1:0] [WORD_WD-1:0]  out_data_tmp;    
    
    //-------- upsize
generate    
  if (OUT_WORD_CNT == 1) begin: gen_identical
    assign out_srdy_tmp = in_srdy;
    assign in_drdy = out_drdy_tmp;
    assign out_data_tmp = in_data;
  end
  else begin: gen_upsize  
    logic [OUT_WORD_IDX_SZ-1:0]  word_idx, nxt_word_idx;
    
    assign nxt_word_idx = (out_srdy_tmp & out_drdy_tmp) ? '0 :
                          (in_srdy & in_drdy) ? (word_idx + 1'b1) :
                          word_idx;
                          
    always @(posedge clk) begin
        if (rst) begin
            word_idx <= '0;
        end
        else begin
            word_idx <= nxt_word_idx;
        end
    end
    
    //--------- hold register
    logic [OUT_WORD_CNT-1:0] [WORD_WD-1:0]  hold_data, nxt_hold_data;
    
    always @* begin
        nxt_hold_data = hold_data;
    
        for (int ii=0; ii<OUT_WORD_CNT; ii++) begin
            if (word_idx == ii[OUT_WORD_IDX_SZ-1:0]) begin
                nxt_hold_data[ii] = in_data;
            end
        end
    end
    
    always @(posedge clk) begin
        if (in_srdy & in_drdy)
            hold_data <= nxt_hold_data;
    end
    
    assign out_srdy_tmp = in_srdy & 
                          (word_idx == OUT_WORD_CNT_SUB_1[OUT_WORD_IDX_SZ-1:0]);
    assign in_drdy = out_drdy_tmp;
    assign out_data_tmp = nxt_hold_data;
  end     
endgenerate
    
    //--------- output pipelined
    vlib_sd_ppln 
    #(.WIDTH    (OUT_WORD_CNT*WORD_WD),
      .PPLN_OPT (OUT_PPLN_OPT) // 0: not pipelined; 1: sd_input; 2: sd_output; 3: sd_iofull
    )
    output_ppln_ins
    (
    .clk    (clk),  
    .rst    (rst),  
   
    .c_srdy     (out_srdy_tmp),
    .c_drdy     (out_drdy_tmp),
    .c_data     (out_data_tmp),
    
    .p_srdy     (out_srdy),
    .p_drdy     (out_drdy),
    .p_data     (out_data)
    );
    
endmodule
`endif // __VLIB_DTWD_UPSIZE_V__
