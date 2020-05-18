//------------------------------------------------------------------------------
// Filename: vlib_wrr_arbiter.v
//
// A weighted round-robin arbiter.
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
      parameter WGT_SZ = 4,      // the bit-width of weights
      parameter ID_SZ = $clog2(REQ_CNT)
    )
    (
    input clk,
    input rst,
        
    //----- config
    input [REQ_CNT-1:0] [WGT_SZ-1:0]     cfg_wgt_vec,    // a vector of initial weights

    //----- I/Os
    input                                   arb_ready,  // if ready=0, then grt_vec=0 regardless of req_vec
    
    input [REQ_CNT-1:0]                     req_vec,    // bit vector represents input requests
    output [REQ_CNT-1:0]                    grt_vec,    // bit vector represents output grants; at most 1 bit in this vector is '1'
    output [ID_SZ-1:0]                      grt_id
    );
    
    //================== BODY ========================
    //----------- update weights
    logic [REQ_CNT-1:0] [WGT_SZ-1:0]    wgt_vec, nxt_wgt_vec, nxt_wgt_vec_tmp;
    logic [REQ_CNT-1:0]                 req_vec_chk; 
    
generate
    for(genvar ii=0; ii<REQ_CNT; ii++) begin
        assign nxt_wgt_vec_tmp[ii] = (grt_vec[ii] & |wgt_vec[ii]) ? (wgt_vec[ii]-1'b1) : wgt_vec[ii];
                                        
        assign req_vec_chk[ii] = req_vec[ii] & |nxt_wgt_vec_tmp[ii];
            
        assign nxt_wgt_vec[ii] = (|req_vec_chk) ? nxt_wgt_vec_tmp[ii] : cfg_wgt_vec[ii];
                                    
        always @(posedge clk) begin
            if (rst)
                wgt_vec[ii] <=  cfg_wgt_vec[ii];
            else
                wgt_vec[ii] <=  nxt_wgt_vec[ii];
        end
    end
endgenerate
    
    //----------- update req_vec_msk
    logic [REQ_CNT-1:0]        req_vec_msk, req_vec_msk_tmp; // which requests have non-zero weight
    
generate
    for(genvar ii=0; ii<REQ_CNT; ii++) begin
        assign req_vec_msk_tmp[ii] = (req_vec[ii] & |wgt_vec[ii]);
    end
endgenerate
    
    // if weight==0 but there are requests, then one of those requests could get granted
    assign req_vec_msk = (~|req_vec_msk_tmp & |req_vec) ? req_vec : 
                          req_vec_msk_tmp;
    
    //---------- update state_vec
    logic [REQ_CNT-1:0]        state_vec, nxt_state_vec;
    assign nxt_state_vec = ((|grt_vec) ? grt_vec : state_vec);
    
    always @(posedge clk) begin
        if (rst) begin
            state_vec <=  {1'b1,{(REQ_CNT-1){1'b0}}};    // initial priority is given for req[0]
        end
        else begin
            state_vec <=  nxt_state_vec;
        end
    end
    
    //---------- update grt_vec and grt_id
    assign grt_vec = (arb_ready) ? grt_vec_func(.state_vec(state_vec), .req_vec(req_vec_msk)) : '0;
    
    assign grt_id = onehot_to_id_func(.bit_vec(grt_vec));
    
    //=================== FUNCTIONS ==============
    // (based on sd_rrmux module in the SDLIB library)
    function automatic [REQ_CNT-1:0] grt_vec_func;
        input [REQ_CNT-1:0] state_vec;
        input [REQ_CNT-1:0] req_vec;
        
        reg [REQ_CNT-1:0] msk_req;
        reg [REQ_CNT-1:0] grt_tmp;
        begin
            msk_req = req_vec & ~((state_vec - 1'b1) | state_vec);
            grt_tmp = msk_req & (~msk_req + 1'b1);

            if (|msk_req)
                grt_vec_func = grt_tmp;
            else
                grt_vec_func = req_vec & (~req_vec + 1'b1);
        end
    endfunction

    //============= bit_one_cnt_func function 
    function automatic [ID_SZ:0]  bit_one_cnt_func;
        input [REQ_CNT-1:0] bit_vec;
        
        logic [ID_SZ:0] bit_one_cnt_func_tmp;
        
        begin
            bit_one_cnt_func_tmp = '0;
            for (int ii=0; ii<REQ_CNT; ii++) begin
                bit_one_cnt_func_tmp = bit_one_cnt_func_tmp + bit_vec[ii];
            end
            
            bit_one_cnt_func = bit_one_cnt_func_tmp;
        end
    endfunction
    
    //=========== convert from 1-hot bit-vector to an id
    function automatic [ID_SZ-1:0] onehot_to_id_func;
        input [REQ_CNT-1:0] bit_vec;
        
        logic [REQ_CNT-1:0] msk;
        
        begin
            msk = ~bit_vec + 1'b1;
            
            onehot_to_id_func = bit_one_cnt_func(.bit_vec(~msk));
        end
        
    endfunction   
    
endmodule
`endif // __VLIB_WRR_ARBITER_V__
