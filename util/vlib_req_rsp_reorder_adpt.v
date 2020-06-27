//----------------------------------------------------------------------
// An adapter that reorders the receiving responses in order for 
// they have the same order as the sent requests.
// Interfaces follow srdy/drdy protocol.
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

`ifndef __VLIB_REQ_RSP_REORDER_ADPT_V__
`define __VLIB_REQ_RSP_REORDER_ADPT_V__

module vlib_req_rsp_reorder_adpt 
    #(parameter     REORDER_BUF_DEPTH = 8,      // total entries of the reordering buffer, normally a power of 2
      parameter     REORDER_BUF_MEM_TYPE = 0,   // 0: flop; 1: BRAM; 2: SRAM
      parameter     REORDER_BUF_MEM_RD_LAT = 1, // latency of the memory (>=1 if using BRAM or SRAM)
      parameter     REQ_INFO_WD = 16,           // may include req addr info
      parameter     RSP_INFO_WD = 20,           // may include resp data
      parameter     OUT_REQ_PPLN_OPT = 0,       // 0: not pipelined; 1: sd_input; 2: sd_output; 3: sd_iofull
      parameter     OUT_RSP_PPLN_OPT = 0,       // 0: not pipelined; 1: sd_input; 2: sd_output; 3: sd_iofull    
      parameter     REQ_ID_WD = $clog2(REORDER_BUF_DEPTH)   
    )
    (
    input   clk,
    input   rst,
    
    //--- in-order interface of the adapter
    input                                   in_req_srdy,
    output logic                            in_req_drdy,
    input [REQ_INFO_WD-1:0]                 in_req_info,

    output                                  out_rsp_srdy,
    input                                   out_rsp_drdy,
    output [RSP_INFO_WD-1:0]                out_rsp_info,
    
    //--- out-of-order (maybe) interface of the adapter
    output logic                            out_req_srdy,
    input                                   out_req_drdy,
    output logic [REQ_INFO_WD-1:0]          out_req_info,
    output logic [REQ_ID_WD-1:0]            out_req_reqid,

    input                                   in_rsp_srdy,
    output logic                            in_rsp_drdy,
    input [RSP_INFO_WD-1:0]                 in_rsp_info,
    input [REQ_ID_WD-1:0]                   in_rsp_reqid
    );
    
    //================== BODY ========================
    //----- generate reqid
    logic                               reqid_assigned;
    logic                               reqid_released;
    
    logic [REQ_ID_WD-1:0]     reqid;
    logic                     reorder_buf_full;    // whether the reordering buffer is full
    logic [REQ_ID_WD:0]       reorder_buf_credit, nxt_reorder_buf_credit;
    
    assign reqid_assigned = in_req_srdy & in_req_drdy & ~reorder_buf_full;
    
    always @* begin
        case ({reqid_assigned, reqid_released})
            2'b00:  nxt_reorder_buf_credit = reorder_buf_credit;
            2'b01:  nxt_reorder_buf_credit = reorder_buf_credit + 1'b1;
            2'b10:  nxt_reorder_buf_credit = reorder_buf_credit - 1'b1;
            2'b11:  nxt_reorder_buf_credit = reorder_buf_credit;
        endcase
    end
    
    assign reorder_buf_full = (reorder_buf_credit == '0);
    
    always @(posedge clk) begin
        if (rst) begin
            reqid <= '0;
            
            reorder_buf_credit <= REORDER_BUF_DEPTH[REQ_ID_WD:0];
        end
        else begin
            if (reqid_assigned) begin
                reqid <= (reqid + 1'b1);
            end
                
            reorder_buf_credit <= nxt_reorder_buf_credit;    
        end
    end
    
    //----- send out req with associated reqid
    logic                            out_req_srdy_tmp;
    logic                            out_req_drdy_tmp;
    logic [REQ_INFO_WD-1:0]          out_req_info_tmp;
    logic [REQ_ID_WD-1:0]            out_req_reqid_tmp;
    
    assign out_req_srdy_tmp = reqid_assigned;
    assign in_req_drdy = out_req_drdy_tmp & ~reorder_buf_full;
    
    assign out_req_info_tmp = in_req_info;
    assign out_req_reqid_tmp = reqid;
    
    vlib_sd_ppln 
    #(.WIDTH    (REQ_INFO_WD + REQ_ID_WD),
      .PPLN_OPT (OUT_REQ_PPLN_OPT) // 0: not pipelined; 1: sd_input; 2: sd_output; 3: sd_iofull
    )
    out_req_ppln_ins
    (
    .clk    (clk),  
    .rst    (rst),  
   
    .c_srdy     (out_req_srdy_tmp),
    .c_drdy     (out_req_drdy_tmp),
    .c_data     ({out_req_info_tmp, out_req_reqid_tmp}),
    
    .p_srdy     (out_req_srdy),
    .p_drdy     (out_req_drdy),
    .p_data     ({out_req_info, out_req_reqid})
    );
    
    //----- reorder buffer entry valid check
    logic [REORDER_BUF_DEPTH-1:0]    entry_valid_arry, nxt_entry_valid_arry;
    
    logic                               reorder_buf_wr_en;
    logic [REQ_ID_WD-1:0]               reorder_buf_wr_prt;
    logic [RSP_INFO_WD-1:0]             reorder_buf_wr_data;                              
    
    logic                               reorder_buf_rd_en;
    logic [REQ_ID_WD-1:0]               reorder_buf_rd_ptr; 
    logic                               reorder_buf_rd_out_vld;
    logic [RSP_INFO_WD-1:0]             reorder_buf_rd_out_data;
    
    always @* begin
        for(int ii=0; ii<REORDER_BUF_DEPTH; ii++) begin
            nxt_entry_valid_arry[ii] = entry_valid_arry[ii];
        
            if (reorder_buf_rd_en & (reorder_buf_rd_ptr==ii[REQ_ID_WD-1:0])) begin
                nxt_entry_valid_arry[ii] = 1'b0;
            end
        
            if (reorder_buf_wr_en & (reorder_buf_wr_prt == ii[REQ_ID_WD-1:0])) begin
                nxt_entry_valid_arry[ii] = 1'b1;
            end
        end
    end    
    
    always @(posedge clk) begin
        if (rst) begin
            entry_valid_arry <= '0;
        end
        else begin
            entry_valid_arry <= nxt_entry_valid_arry;
        end
    end

    //----- write out-of-order responses into the reordering buffer
    assign in_rsp_drdy = 1'b1; // outstanding responses are always accepted because request was only sent when buffer was not full
    
    assign reorder_buf_wr_en = in_rsp_srdy & in_rsp_drdy;
    assign reorder_buf_wr_prt = in_rsp_reqid;
    assign reorder_buf_wr_data = in_rsp_info;    

    //----- read rsp from the head of the reorder buffer
    logic   reorder_buf_head_valid;
    logic   mem_out_dfcbuf_fc_n;
    
    assign reorder_buf_head_valid = entry_valid_arry[reorder_buf_rd_ptr];
    assign reorder_buf_rd_en = reorder_buf_head_valid & mem_out_dfcbuf_fc_n;
    
//     assign dbuf_req_rid_released = reorder_buf_rd_en;
    
    always @(posedge clk) begin
        if (rst) begin
            reorder_buf_rd_ptr <= '0;
        end
        else begin
            if (reorder_buf_rd_en)
                reorder_buf_rd_ptr <= (reorder_buf_rd_ptr + 1'b1);
        end
    end

    //----- using 1r1r memory for reordering buffer
    vlib_1r1w_generic_mem 
    #(.WIDTH        (RSP_INFO_WD),
      .DEPTH        (REORDER_BUF_DEPTH),
      .WR_REQ_REG   (0),
      .RD_REQ_REG   (0),
      .USE_BRAM     (REORDER_BUF_MEM_TYPE),   // 0: use flops; 1: use FPGA BRAM
      .RD_LAT       (REORDER_BUF_MEM_RD_LAT)  // total read latency. Must be >= 1 if using FPGA BRAM
    )
    reorder_buf_mem_ins
    (
    .clk    (clk),
    .rst    (rst),

    .wr_en      (reorder_buf_wr_en),
    .wr_addr    (reorder_buf_wr_prt),
    .wr_data    (reorder_buf_wr_data),

    .rd_en      (reorder_buf_rd_en),
    .rd_addr    (reorder_buf_rd_ptr),
    
    .rd_out_vld     (reorder_buf_rd_out_vld),
    .rd_out_data    (reorder_buf_rd_out_data)
    );
    
    //----- dfc2sd converter at memory read output
    logic                                  out_rsp_srdy_tmp;
    logic                                  out_rsp_drdy_tmp;
    logic [RSP_INFO_WD-1:0]                out_rsp_info_tmp;
    
    vlib_dfc2sd_convert
    #(.WIDTH                (RSP_INFO_WD),
      .LATENCY              (REORDER_BUF_MEM_RD_LAT),
      .THRESHOLD            (1),
      .ASSERT_FC_N_IF_POP   (1)
    )
    dfc2sd_convert_ins
    (
    .clk    (clk),
    .rst    (rst),

    .in_vld     (reorder_buf_rd_out_data),  
    .in_fc_n    (mem_out_dfcbuf_fc_n),
    .in_data    (reorder_buf_rd_out_data), 
    
    .out_srdy   (out_rsp_srdy_tmp),    
    .out_drdy   (out_rsp_drdy_tmp),
    .out_data   (out_rsp_info_tmp)
    );
    
    //------ rsp output pipeline option
    vlib_sd_ppln 
    #(.WIDTH    (RSP_INFO_WD),
      .PPLN_OPT (OUT_RSP_PPLN_OPT) // 0: not pipelined; 1: sd_input; 2: sd_output; 3: sd_iofull
    )
    out_rsp_ppln_ins
    (
    .clk    (clk),  
    .rst    (rst),  
   
    .c_srdy     (out_rsp_srdy_tmp),
    .c_drdy     (out_rsp_drdy_tmp),
    .c_data     (out_rsp_info_tmp),
    
    .p_srdy     (out_rsp_srdy),
    .p_drdy     (out_rsp_drdy),
    .p_data     (out_rsp_info)
    );
    
endmodule
`endif // __VLIB_REQ_RSP_REORDER_ADPT_V__
