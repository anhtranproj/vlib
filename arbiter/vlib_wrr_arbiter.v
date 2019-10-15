//------------------------------------------------------------------------------
// Filename: vlib_wrr_arbiter.v
//
// A weighted round-robin arbiter:
//  . each request is associated with an initial weight
//  . the arbiter grants to the requests having non-zero weights in a round-robin manner
//  . if a request gets granted, its weight is decremented by 1
//  . the weights would be reset to the initial values if ~(req[i] & (weight[i]>0)) for all i
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

`ifndef __VLIB_WRR_ARBITER_V__
`define __VLIB_WRR_ARBITER_V__

module vlib_wrr_arbiter 
    #(parameter REQ_CNT = 8,     // the number of requests
      parameter WEIGHT_WD = 4    // the bit-width of weights
    )
    (
    input clk,
    input rst,
        
    //--------- I/O
    input [REQ_CNT-1:0] [WEIGHT_WD-1:0]     init_weight,    // a vector of N initial weights

    input                                   arb_ready,  // whether the resource using this arbiter is ready; if ready=0 --> grt_vec=0 regardless of req_vec
    
    input [REQ_CNT-1:0]                     req_vec, // bit vector represents N requests
    output [REQ_CNT-1:0]                    grt_vec    // bit vector represents N grants; no more than 1 bit in this vector is '1'
    
    );
    
    logic [REQ_CNT-1:0] [WEIGHT_WD-1:0]    weight, nxt_weight, nxt_weight_tmp;
    
    logic [REQ_CNT-1:0]        req_vec_chk;  
    
    logic [REQ_CNT-1:0]        req_vec_mask, req_vec_mask_tmp; // which requests have non-zero weight
    
    logic [REQ_CNT-1:0]        state_vec, nxt_state_vec;
    
    //================== BODY ========================
    //----------- update weight
    generate
        for(genvar ii=0; ii<REQ_CNT; ii++) begin: weight_update
            assign nxt_weight_tmp[ii] = (grt_vec[ii] & |weight[ii]) ? (weight[ii]-1'b1) : 
                                        weight[ii];
            assign req_vec_chk[ii] = req_vec[ii] & |nxt_weight_tmp[ii];
            
            assign nxt_weight[ii] = (|req_vec_chk) ? nxt_weight_tmp[ii] : 
                                    init_weight[ii];
                                    
            always @(posedge clk) begin
                if (rst)
                    weight[ii] <=  init_weight[ii];
                else
                    weight[ii] <=  nxt_weight[ii];
            end
        end
    endgenerate
    
    //----------- update req_vec_mask
    generate
        for(genvar ii=0; ii<REQ_CNT; ii++) begin: req_vec_mask_update
            assign req_vec_mask_tmp[ii] = (req_vec[ii] & |weight[ii]);
        end
    endgenerate
    
    // if weight==0 but there are requests, then one of those requests could get granted
    assign req_vec_mask = (~|req_vec_mask_tmp & |req_vec) ? req_vec : 
                          req_vec_mask_tmp;
    
    //---------- update state_vec
    assign nxt_state_vec = ((|grt_vec) ? grt_vec : state_vec);
    
    always @(posedge clk) begin
        if (rst) begin
            state_vec <=  {1'b1,{(REQ_CNT-1){1'b0}}};    // initial priority is given for req[0]
        end
        else begin
            state_vec <=  nxt_state_vec;
        end
    end
    
    //---------- update grt_vec
    assign grt_vec = (arb_ready) ? grt_vec_func(.state_vec(state_vec), .req_vec(req_vec_mask)) : 
                     {REQ_CNT{1'b0}};
    
    //=================== FUNCTIONS ==============
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
    
endmodule
`endif // __VLIB_WRR_ARBITER_V__
