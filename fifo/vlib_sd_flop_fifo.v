//----------------------------------------------------------------------
// A synchronous Srdy/Drdy flop-based fifo with arbitrary DEPTH.
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

`ifndef __VLIB_SD_FLOP_FIFO_V__
`define __VLIB_SD_FLOP_FIFO_V__

module vlib_sd_flop_fifo 
    #(parameter WIDTH = 32,
      parameter DEPTH = 8,
      parameter OUT_REG = 0,
      parameter ADR_SZ = $clog2(DEPTH)
    )
    (
    input   clk,
    input   rst,

    input                   wr_srdy,  
    output                  wr_drdy,
    input [WIDTH-1:0]       wr_data,    
    
    output logic              rd_srdy,    
    input                     rd_drdy,
    output logic [WIDTH-1:0]  rd_data,
    
    output logic [ADR_SZ:0]   usage     
    );
    
    localparam DEPTH_SUB_1 = DEPTH-1;
    
    logic [DEPTH-1:0] [WIDTH-1:0]   ARRY;   // array of flops
    
    logic              rd_srdy_tmp;    
    logic              rd_drdy_tmp;
    logic [WIDTH-1:0]  rd_data_tmp;
    
    
    //---------- wr_en and rd_en
    logic   empty, full;
    logic   wr_en, rd_en;
    
    assign wr_en = wr_srdy & ~full;
    assign rd_en = rd_srdy_tmp & rd_drdy_tmp;
    
    //---------- update wr_adr and rd_adr
    logic                  wr_c, rd_c;       // used for full/empty check
    logic [ADR_SZ-1:0]     wr_adr, rd_adr;    
    
    always @(posedge clk) begin
        if (rst) begin
            wr_c <= 1'b0;
            wr_adr <= {ADR_SZ{1'b0}};
        end    
        else if (wr_en) begin
            if (wr_adr == DEPTH_SUB_1[ADR_SZ-1:0]) begin
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
            if (rd_adr == DEPTH_SUB_1[ADR_SZ-1:0]) begin
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
        for(int ii=0; ii<DEPTH; ii++) begin
            if ((wr_adr == ii[ADR_SZ-1:0]) & wr_en) begin
                ARRY[ii] <= wr_data;
            end
        end
    end

    assign rd_data_tmp = ARRY[rd_adr];
    
    //----------- full/empty check
    assign empty = ({wr_c, wr_adr} == {rd_c, rd_adr});
    assign full = (wr_c != rd_c) & (wr_adr == rd_adr);
    
    assign wr_drdy = ~full;
    assign rd_srdy_tmp = ~empty;
    
    //----------- fifo usage
    logic [ADR_SZ:0]    ptr_diff;
    assign ptr_diff = {1'b0, wr_adr} + {1'b1, ~rd_adr} + 1'b1; // = wr_adr - rd_adr
    
    always @* begin
        if (wr_c == rd_c) begin
            usage = ptr_diff;
        end
        else begin
            usage = DEPTH[ADR_SZ:0] + ptr_diff; // ptr_diff is now negative
        end
    end
    
    //----------- output pipeline option
generate
  if (OUT_REG == 0) begin: GEN_OUT_REG_0
    assign rd_srdy = rd_srdy_tmp;
    assign rd_drdy_tmp = rd_drdy;
    assign rd_data = rd_data_tmp;
  end
  else begin: GEN_OUT_REG_1
    always @(posedge clk) begin
        if (rst) begin
            rd_srdy <= 1'b0;
        end
        else begin
            if (rd_srdy_tmp)
                rd_srdy <= 1'b1;
            else if (rd_drdy_tmp)
                rd_srdy <= 1'b0;
        end
        
        if (rd_srdy_tmp & rd_drdy_tmp)
            rd_data <= rd_data_tmp;
    end
    
    assign rd_drdy_tmp = ~rd_srdy | rd_drdy;
  end
endgenerate
    
endmodule
`endif  // __VLIB_SD_FLOP_FIFO_V__
