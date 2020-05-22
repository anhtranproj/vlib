//----------------------------------------------------------------------
// Filename: vlib_uc_xbar_arbiter.v
//
// Round-robin arbitration for a normal unicast Crossbar
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

`ifndef __VLIB_UC_XBAR_ARBITER_V__
`define __VLIB_UC_XBAR_ARBITER_V__

module vlib_uc_xbar_arbiter #(
    parameter IN_CNT = 8,     // the number of Xbar's input ports
    parameter OUT_CNT = 20,   // the number of Xbar's output ports
    parameter IN_ID_SZ = $clog2(IN_CNT)   
    )(
    input clk,
    input rst,
    
    input [OUT_CNT-1:0]                 arb_ready,  // which output arbiters are ready to accept the requests
    
    input [IN_CNT-1:0] [OUT_CNT-1:0]    req_vec,   // request-vector each input to all outputs
    
    output [IN_CNT-1:0]                 grt,       // grant for each input 

    output  [OUT_CNT-1:0]                   arb_grt_vld,    // whether the arbiter grants to an input
    output  [OUT_CNT-1:0] [IN_ID_SZ-1:0]    arb_grt_id      // = mux_sel of each output port
    );

    logic [OUT_CNT-1:0] [IN_CNT-1:0]  req_vec_to_arb;
    logic [OUT_CNT-1:0] [IN_CNT-1:0]  rr_state_vec, nxt_rr_state_vec;
    logic [OUT_CNT-1:0] [IN_CNT-1:0]  grt_vec_by_arb;
    
    //================== BODY ==================
    //------------ output rr_arbiter
generate
    for (genvar jj=0; jj<OUT_CNT; jj++) begin

        // req_vec_to_arb of each arbiter
        for (genvar ii=0; ii<IN_CNT; ii++) begin
            assign req_vec_to_arb[jj][ii] = req_vec[ii][jj];
        end
        
        // update grt_vec_by_arb based on req_vec_to_arb and rr_state_vec
        assign grt_vec_by_arb[jj] = (arb_ready[jj]) ? grt_vec_f(.state_vec(rr_state_vec[jj]), 
                                                                   .req_vec(req_vec_to_arb[jj])) : 
                                    '0;
    
        // update nxt_rr_state_vec based on grt_vec_by_arb
        // rr_state_vec is a round-robin vector that gives the first priority to its first left request bit    
        assign nxt_rr_state_vec[jj] = (|grt_vec_by_arb[jj]) ? grt_vec_by_arb[jj] : 
                                  rr_state_vec[jj];
                                  
        // update rr_state_vec
        always @(posedge clk) begin
            if (rst) begin
                rr_state_vec[jj] <= {1'b1,{(IN_CNT-1){1'b0}}};    // initial priority is given to req[0]
            end
            else begin
                rr_state_vec[jj] <= nxt_rr_state_vec[jj];
            end
        end
    end
endgenerate

    //--------- final grt to each input req
    logic [IN_CNT-1:0] [OUT_CNT-1:0] grt_vec ;
    
generate
    for (genvar ii=0; ii<IN_CNT; ii++) begin
        for (genvar jj=0; jj<OUT_CNT; jj++) begin
            assign grt_vec[ii][jj] = grt_vec_by_arb[jj][ii];
        end
        
        assign grt[ii] = (grt_vec[ii] == req_vec[ii]) & |req_vec[ii];   // grant to req[ii] if req[ii] is !=0  and all reqs of [ii] get granted
    end
endgenerate

    //--------- arb_grt_id for each output port of the Xbar
generate
    for (genvar jj=0; jj<OUT_CNT; jj++) begin
        assign arb_grt_vld[jj] = |grt_vec_by_arb[jj];
        assign arb_grt_id[jj] = onehot_to_id_f(.bit_vec(grt_vec_by_arb[jj]));
    end
endgenerate    

    //============= FUNCTIONS ====================
    //============== strict-priority granting function
    // (based on the sd_rrmux module in the SDLIB library)
    function automatic [IN_CNT-1:0] grt_vec_f;
        input [IN_CNT-1:0] state_vec;
        input [IN_CNT-1:0] req_vec;
        
        reg [IN_CNT-1:0] msk_req;
        reg [IN_CNT-1:0] tmp_grant;
        begin
            msk_req = req_vec & ~((state_vec - 1'b1) | state_vec);
            tmp_grant = msk_req & (~msk_req + 1'b1);

            if (|msk_req)
                grt_vec_f = tmp_grant;
            else
                grt_vec_f = req_vec & (~req_vec + 1'b1);
        end
    endfunction

    //============= bit_one_cnt_f function 
    function automatic [IN_ID_SZ:0]  bit_one_cnt_f;
        input [IN_CNT-1:0] bit_vec;
        
        logic [IN_ID_SZ:0] out_tmp;
        
        begin
            out_tmp = '0;
            for (int ii=0; ii<IN_CNT; ii++) begin
/* verilator lint_off WIDTH */            
                out_tmp = out_tmp + bit_vec[ii];
/* verilator lint_on WIDTH */                
            end
            
            bit_one_cnt_f = out_tmp;
        end
    endfunction
    
    //=========== convert from 1-hot bit-vector to an id
    function automatic [IN_ID_SZ-1:0] onehot_to_id_f;
        input [IN_CNT-1:0] bit_vec;
        
        logic [IN_CNT-1:0] msk;
        
        begin
            msk = ~bit_vec + 1'b1;
            
/* verilator lint_off WIDTH */            
            onehot_to_id_f = bit_one_cnt_f(.bit_vec(~msk)); 
/* verilator lint_on WIDTH */            
        end
        
    endfunction
    
endmodule
`endif //__VLIB_UC_XBAR_ARBITER_V__
