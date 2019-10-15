//----------------------------------------------------------------------
// Filename: vlib_rr_arbiter.v
//
// A round-robin arbiter
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


`ifndef __VLIB_RR_ARBITER_V__
`define __VLIB_RR_ARBITER_V__

module vlib_rr_arbiter 
    #(parameter REQ_CNT = 8,
      parameter ID_SZ = $clog2(REQ_CNT) 
    )
    (

    input   clk,
    input   rst,
    
    input                  arb_ready, // if ready=0, then grt_vec=0 regardless of req_vec
    
    input [REQ_CNT-1:0]    req_vec,
    output [REQ_CNT-1:0]   grt_vec,
    output [ID_SZ-1:0]     grt_id
    );

    //================== BODY ==================
    //----- round-robin state
    logic [REQ_CNT-1:0] state_vec, nxt_state_vec;
    
    always @(posedge clk) begin
        if (rst) begin
            state_vec <=  {1'b1,{(REQ_CNT-1){1'b0}}};    
        end
        else begin
            state_vec <=  nxt_state_vec;
        end
    end

    //----- update grt_vec based on req_vec and state_vec
    assign grt_vec = (arb_ready) ? grt_vec_func(.state_vec(state_vec), .req_vec(req_vec)) : 
                     {REQ_CNT{1'b0}};

    assign grt_id = onehot_to_id_func(.bit_vec(grt_vec));
                     
    //----- compute nxt_state_vec based on grt_vec
    assign nxt_state_vec = (|grt_vec) ? grt_vec : state_vec;
    
    //=================== FUNCTIONS ==============
    //============== strict-priority granting function
    // (based on sd_rrmux module in the sdlib library developed by Guy Hutchison)
    function automatic [REQ_CNT-1:0] grt_vec_func;
        input [REQ_CNT-1:0] state_vec;
        input [REQ_CNT-1:0] req_vec;
        
        reg [REQ_CNT-1:0] msk_req;
        reg [REQ_CNT-1:0] grt_tmp;
        begin
            msk_req = req_vec & ~((state_vec - 1'b1) | state_vec);
            grt_tmp = msk_req & (~msk_req + 1'b1);

            if (msk_req != {REQ_CNT{1'b0}})
                grt_vec_func = grt_tmp;
            else
                grt_vec_func = req_vec & (~req_vec + 1'b1);
        end
    endfunction

    //============= bit_one_cnt_func function 
    function automatic [ID_SZ:0]  bit_one_cnt_func;
        input [REQ_CNT-1:0] bit_vec;
        
        logic [ID_SZ:0] bit_one_cnt_func_tmp;
        
        integer i;
        
        begin
            bit_one_cnt_func_tmp = {(ID_SZ+1){1'b0}};
            for (i=0; i<REQ_CNT; i++) begin
                bit_one_cnt_func_tmp = bit_one_cnt_func_tmp + bit_vec[i];
            end
            
            bit_one_cnt_func = bit_one_cnt_func_tmp;
        end
    endfunction
    
    //=========== convert from 1-hot bit-vector to an id
    function automatic [ID_SZ-1:0] onehot_to_id_func;
        input [REQ_CNT-1:0] bit_vec;
        
        logic [REQ_CNT-1:0] mask, not_mask;
        
        begin
            mask = ~bit_vec + 1'b1;
            not_mask = ~mask;
            
            onehot_to_id_func = bit_one_cnt_func(not_mask);
        end
        
    endfunction    
endmodule
`endif //__VLIB_RR_ARBITER_V__
