//----------------------------------------------------------------------
// A pool of available IDs with values from 0 to POOL_DEPTH-1.
// Memory array for containing IDs is built with flops.
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

`ifndef __VLIB_ID_POOL_V__
`define __VLIB_ID_POOL_V__

module vlib_id_pool 
    #(parameter ID_WD = 32,
      parameter POOL_DEPTH = 8,
      parameter ADR_SZ = $clog2(POOL_DEPTH)
    )
    (
    input   clk,
    input   rst,

    output logic              pool_avai,    
    input                     pool_take,
    output logic [ID_WD-1:0]  taking_id,
    
    input                     pool_push,  
    output                    pool_full,
    input [ID_WD-1:0]         pushing_id,    
    
    output logic [ADR_SZ:0]   avai_cnt     // how many available IDs in the pool
    );
    
    localparam POOL_DEPTH_SUB_1 = POOL_DEPTH-1;
    
    logic [POOL_DEPTH-1:0] [ID_WD-1:0]   ARRY;   // array IDs built on flops
    
    //---------- wr_en and rd_en
    logic   empty, full;
    logic   wr_en, rd_en;
    
    assign wr_en = pool_push & ~full;
    assign rd_en = pool_avai & pool_take;
    
    //---------- update wr_adr and rd_adr
    logic                  wr_c, rd_c;       // used for full/empty check
    logic [ADR_SZ-1:0]     wr_adr, rd_adr;    
    
    always @(posedge clk) begin
        if (rst) begin
            wr_c <= 1'b1;   // the Pool is initialized with full of IDs
            wr_adr <= {ADR_SZ{1'b0}};
        end    
        else if (wr_en) begin
            if (wr_adr == POOL_DEPTH_SUB_1[ADR_SZ-1:0]) begin
                wr_c <= ~wr_c;
                wr_adr <= {ADR_SZ{1'b0}};
            end
            else begin
                wr_adr <= wr_adr + 1'b1;
            end
        end    
    end

    always @(posedge clk) begin
        if (rst) begin
            rd_c <= 1'b0;
            rd_adr <= {ADR_SZ{1'b0}};
        end    
        else if (rd_en) begin
            if (rd_adr == POOL_DEPTH_SUB_1[ADR_SZ-1:0]) begin
                rd_c <= ~rd_c;
                rd_adr <= {ADR_SZ{1'b0}};
            end
            else begin
                rd_adr <= rd_adr + 1'b1;
            end
        end    
    end
    
    //--------- write to and read from the flop array
    always @(posedge clk) begin
        for(int ii=0; ii<POOL_DEPTH; ii++) begin
            if (rst) begin
                ARRY[ii] <= ii[ID_WD-1:0];  // in the beginning, the pool is initialized with all available IDs.
            end
            else if ((wr_adr == ii[ADR_SZ-1:0]) & wr_en) begin
                ARRY[ii] <= pushing_id;
            end
        end
    end

    assign taking_id = ARRY[rd_adr];
    
    //----------- full/empty check
    assign empty = ({wr_c, wr_adr} == {rd_c, rd_adr});
    assign full = (wr_c != rd_c) & (wr_adr == rd_adr);
    
    assign pool_full = full;
    assign pool_avai = ~empty;
    
    //----------- fifo avai_cnt
    logic [ADR_SZ:0]    ptr_diff;
    assign ptr_diff = {1'b0, wr_adr} + {1'b1, ~rd_adr} + 1'b1; // = wr_adr - rd_adr
    
    always @* begin
        if (wr_c == rd_c) begin
            avai_cnt = ptr_diff;
        end
        else begin
            avai_cnt = POOL_DEPTH[ADR_SZ:0] + ptr_diff; // ptr_diff is now negative
        end
    end
       
endmodule
`endif  // __VLIB_ID_POOL_V__
