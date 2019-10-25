//----------------------------------------------------------------------
// A generic single-port 1RW memory based on flops or FPGA-BRAM.
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

`ifndef __VLIB_1RW_GENERIC_MEM_V__
`define __VLIB_1RW_GENERIC_MEM_V__

module vlib_1rw_generic_mem 
    #(parameter WIDTH = 32,
      parameter DEPTH = 8,
      parameter REQ_REG = 0,        // whether input request signals are registered
      parameter USE_BRAM = 1,       // 0: use flops; 1: use FPGA BRAM
      parameter RD_LAT = 1,         // must be >= 1 if using FPGA BRAM
      parameter ADDR_SZ = $clog2(DEPTH)
    )
    (
    input clk,
    input rst,

    input                       req_vld,
    input                       req_rw, // 1: read, 0: write
    input  [ADDR_SZ-1:0]        req_addr,
    input  [WIDTH-1:0]          req_wdata,
    
    output reg                  rsp_rvld,
    output reg [WIDTH-1:0]      rsp_rdata    
    );
    
    localparam RD_OUT_PPLN_STG_CNT = RD_LAT-REQ_REG;
    
    //================== BODY ========================
    //-------- input reg
    logic                      req_vld_tmp, req_rw_tmp;
    logic [ADDR_SZ-1:0]        req_addr_tmp;
    logic [WIDTH-1:0]          req_wdata_tmp;
    
generate
  if (REQ_REG==0) begin: GEN_REQ_REG_0
    assign req_vld_tmp = req_vld;
    assign req_rw_tmp = req_rw;
    assign req_addr_tmp = req_addr;
    assign req_wdata_tmp = req_wdata;
  end
  else begin: GEN_REQ_REG_1
    always @(posedge clk) begin
        if (rst) begin
            req_vld_tmp <= 1'b0;
            req_rw_tmp <= 1'b0;
        end
        else begin
            req_vld_tmp <= req_vld;
            req_rw_tmp <= req_rw;
        end
        
        if (req_vld) begin
            req_addr_tmp <= req_addr;
            req_wdata_tmp <= req_wdata;
        end
    end
  end
endgenerate
    
    //---------- write is always one cycle latency after the input reged
    logic   ren_tmp, wen_tmp;
    assign ren_tmp = req_vld_tmp & req_rw_tmp;
    assign wen_tmp = req_vld_tmp & ~req_rw_tmp;
    
    
    //---------- read latency is at least 1 for FPGA
    logic [RD_OUT_PPLN_STG_CNT:0]                  rsp_rvld_pipe;
    logic [RD_OUT_PPLN_STG_CNT:0] [WIDTH-1:0]      rsp_rdata_pipe;   

generate   
  if (USE_BRAM == 1) begin: GEN_BRAM_MEM
    (* ram_style = "block" *)
    reg [WIDTH-1:0]     MEM [0:DEPTH-1];
    
    always @(posedge clk) begin
        rsp_rdata_pipe[0] <= MEM[req_addr_tmp];
        
        if (wen_tmp)
            MEM[req_addr_tmp] <= req_wdata_tmp;
    end
    
    always @(posedge clk) begin
        if (rst)
            rsp_rvld_pipe[0] <= 1'b0;
        else
            rsp_rvld_pipe[0] <= ren_tmp;
    
        for (int jj=1; jj<RD_OUT_PPLN_STG_CNT; jj++) begin
            if (rst) begin
                rsp_rvld_pipe[jj] <= 1'b0;
            end
            else begin
                rsp_rvld_pipe[jj] <= rsp_rvld_pipe[jj-1];
                
                if (rsp_rvld_pipe[jj-1]) 
                    rsp_rdata_pipe[jj] <= rsp_rdata_pipe[jj-1];
            end
        end
    end   
    
    assign rsp_rvld = rsp_rvld_pipe[RD_OUT_PPLN_STG_CNT-1];
    assign rsp_rdata = rsp_rdata_pipe[RD_OUT_PPLN_STG_CNT-1];      
  end   
  
  else begin: GEN_FLOP_MEM
    logic  [DEPTH-1:0] [WIDTH-1:0]     MEM;
    
    always @(posedge clk) begin
        for (int ii=0; ii<DEPTH; ii++) begin
            if (wen_tmp & (req_addr_tmp==ii[ADDR_SZ-1:0])) begin
                MEM[ii] <= req_wdata_tmp;
            end
        end
    end

    assign rsp_rvld_pipe[0] = ren_tmp;
    assign rsp_rdata_pipe[0] = MEM[req_addr_tmp];
    
    always @(posedge clk) begin
        for (int jj=1; jj<=RD_OUT_PPLN_STG_CNT; jj++) begin
            if (rst) begin
                rsp_rvld_pipe[jj] <= 1'b0;
            end
            else begin
                rsp_rvld_pipe[jj] <= rsp_rvld_pipe[jj-1];
                
                if (rsp_rvld_pipe[jj-1]) 
                    rsp_rdata_pipe[jj] <= rsp_rdata_pipe[jj-1];
            end
        end
    end    

    assign rsp_rvld = rsp_rvld_pipe[RD_OUT_PPLN_STG_CNT];
    assign rsp_rdata = rsp_rdata_pipe[RD_OUT_PPLN_STG_CNT];    
  end  
endgenerate
    
endmodule
`endif  // __VLIB_1RW_GENERIC_MEM_V__
