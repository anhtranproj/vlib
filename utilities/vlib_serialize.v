//----------------------------------------------------------------------
// Serialize a multi-word data input to single-word data output.
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

`ifndef __VLIB_SERIALIZE_V__
`define __VLIB_SERIALIZE_V__

module vlib_serialize 
    #(parameter   WORD_WD = 8,      // 1: bit, 8: byte, etc
      parameter   IN_WORD_CNT = 20, // the number of input words for serializing
      parameter   OUT_PPLN_OPT = 0  // 0: not pipelined; 1: sd_input; 2: sd_output; 3: sd_iofull
    )
    (
    input   clk,
    input   rst,
    
    input                                   in_srdy,
    output logic                            in_drdy,
    input [IN_WORD_CNT-1:0] [WORD_WD-1:0]   in_data,

    output                  out_srdy,
    input                   out_drdy,
    output [WORD_WD-1:0]    out_data
    );
    
    localparam IN_WORD_IDX_SZ = $clog2(IN_WORD_CNT);
    localparam IN_WORD_CNT_SUB_1 = IN_WORD_CNT - 1;
    
    //================== BODY ========================
    typedef enum {
        FSM_TAKE_INPUT,
        FSM_SERIALIZE
    } SERIAL_STATE_E;
    
    SERIAL_STATE_E  serial_state_e, nxt_serial_state_e;
    
    logic [IN_WORD_IDX_SZ-1:0]  word_idx, nxt_word_idx;    

    logic                  out_srdy_tmp;
    logic                  out_drdy_tmp;
    logic [WORD_WD-1:0]    out_data_tmp;    
    
    logic [IN_WORD_CNT-1:0] [WORD_WD-1:0]  in_data_reg;
    
    //-------- serialize
generate    
  if (IN_WORD_CNT == 1) begin: gen_identical
    assign out_srdy_tmp = in_srdy;
    assign in_drdy = out_drdy_tmp;
    assign out_data_tmp = in_data;
  end
  else begin: gen_serialize
    always @(posedge clk) begin
        if (in_srdy & in_drdy) begin
            in_data_reg <= in_data;
        end    
    end

    always @* begin
        nxt_serial_state_e = serial_state_e;
        
        in_drdy = 1'b1;
        out_srdy_tmp = 1'b0;
        out_data_tmp = in_data_reg[word_idx];
        nxt_word_idx = word_idx;
        
        case (serial_state_e)
            FSM_TAKE_INPUT: begin
                if (in_srdy) begin
                    in_drdy = out_drdy_tmp;
                    out_srdy_tmp = 1'b1;
                    out_data_tmp = in_data[0];
                    
                    nxt_word_idx = 1;
                    if (out_drdy_tmp) begin
                        nxt_serial_state_e = FSM_SERIALIZE;
                    end
                end
            end
            FSM_SERIALIZE: begin
                in_drdy = 1'b0;
                out_srdy_tmp = 1'b1;
                out_data_tmp = in_data_reg[word_idx];
                
                nxt_word_idx = word_idx + 1'b1;
                if (out_drdy_tmp & (word_idx==IN_WORD_CNT_SUB_1[IN_WORD_IDX_SZ-1:0])) begin
                    nxt_serial_state_e = FSM_TAKE_INPUT;
                end
            end
        endcase
    end
    
    always @(posedge clk) begin
        if (rst) begin
            serial_state_e <= FSM_TAKE_INPUT;
            word_idx <= '0;
        end
        else begin
            serial_state_e <= nxt_serial_state_e;
            
            if (out_srdy_tmp & out_drdy_tmp) begin
                word_idx <= nxt_word_idx;
            end
        end
    end
    
  end  
endgenerate
    
    //--------- output pipelined
    vlib_sd_ppln 
    #(.WIDTH    (WORD_WD),
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
`endif // __VLIB_SERIALIZE_V__
