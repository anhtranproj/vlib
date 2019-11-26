//----------------------------------------------------------------------
// An asynchronous Srdy/Drdy flop-based fifo with power-of-2 DEPTH.
//
// NOTE: async fifo is mostly used to transfer data crossing clock domains,
//       so a shadow fifo with power-of-2 depth is normally used.
//       If you see the need of using an async fifo with non-power-of-2 depth,
//       please let me know, I will make one.
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

`ifndef __VLIB_SD_FLOP_ASYNC_FIFO_V__
`define __VLIB_SD_FLOP_ASYNC_FIFO_V__

module vlib_sd_flop_async_fifo 
    #(parameter WIDTH = 32,
      parameter DEPTH = 8,
      parameter RD_OUT_REG = 0,
      parameter ADR_SZ = $clog2(DEPTH)
    )
    (
    input                   wr_clk,
    input                   wr_rst,
    input                   wr_srdy,  
    output                  wr_drdy,
    input [WIDTH-1:0]       wr_data,    
    
    input                     rd_clk,
    input                     rd_rst,    
    output logic              rd_srdy,    
    input                     rd_drdy,
    output logic [WIDTH-1:0]  rd_data,
    
    output logic [ADR_SZ:0]   wclk_usage, // fifo usage seen in the wr_clk domain
    output logic [ADR_SZ:0]   rclk_usage  // fifo usage seen in the rd_clk domain
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
    
    //---------- update wr_ptr
    logic [ADR_SZ:0]     wr_ptr;    
    
    always @(posedge wr_clk) begin
        if (wr_rst) begin
            wr_ptr <= {(ADR_SZ+1){1'b0}};
        end    
        else if (wr_en) begin
            wr_ptr <= wr_ptr + 1'b1;
        end    
    end

    //--------- update rd_ptr
    logic [ADR_SZ:0]     rd_ptr;    
    
    always @(posedge rd_clk) begin
        if (rd_rst) begin
            rd_ptr <= {(ADR_SZ+1){1'b0}};
        end    
        else if (rd_en) begin
            rd_ptr <= rd_ptr + 1'b1;
        end    
    end
    
    //--------- write to and read from the flop array
    always @(posedge wr_clk) begin
        for(int ii=0; ii<DEPTH; ii++) begin
            if ((wr_ptr[ADR_SZ-1:0] == ii[ADR_SZ-1:0]) & wr_en) begin
                ARRY[ii] <= wr_data;
            end
        end
    end

    assign rd_data_tmp = ARRY[rd_ptr[ADR_SZ-1:0]];
    
    //--------- transfer wr_ptr to rd_clk domain,
    logic [ADR_SZ:0]     grey_wr_ptr, rclk_grey_wr_ptr, rclk_wr_ptr;    
    
    assign grey_wr_ptr = bin2grey(.bwr_in(wr_ptr));
    
    vlib_synchronizer
    #(.WIDTH    (ADR_SZ+1))
    grey_wr_ptr_to_rclk_sync_ins
    (
    .tx_data    (grey_wr_ptr),

    .rx_clk     (rd_clk),
    .rx_data    (rclk_grey_wr_ptr)
    );
    
    assign rclk_wr_ptr = grey2bin(.grey_in(rclk_grey_wr_ptr));
    
    //--------- transfer rd_ptr to wr_clk domain
    logic [ADR_SZ:0]     grey_rd_ptr, wclk_grey_rd_ptr, wclk_rd_ptr;    
    
    assign grey_rd_ptr = bin2grey(.bwr_in(rd_ptr));
    
    vlib_synchronizer
    #(.WIDTH    (ADR_SZ+1))
    grey_rd_ptr_to_wclk_sync_ins
    (
    .tx_data    (grey_rd_ptr),

    .rx_clk     (wr_clk),
    .rx_data    (wclk_grey_rd_ptr)
    );
    
    assign wclk_rd_ptr = grey2bin(.grey_in(wclk_grey_rd_ptr));
    
    //--------- full/empty check
    assign full = (wr_ptr[ADR_SZ] != wclk_rd_ptr[ADR_SZ]) &
                  (wr_ptr[ADR_SZ-1:0] == wclk_rd_ptr[ADR_SZ-1:0]);
    
    assign empty = (rclk_wr_ptr == rd_ptr);
    
    
    assign wr_drdy = ~full;
    assign rd_srdy_tmp = ~empty;
    
    //----------- fifo usage
    always @* begin
        if (wr_ptr[ADR_SZ] == wclk_rd_ptr[ADR_SZ])
            wclk_usage = wr_ptr - wclk_rd_ptr;
        else
            wclk_usage = DEPTH[ADR_SZ:0] + wr_ptr[ADR_SZ-1:0] - wclk_rd_ptr[ADR_SZ-1:0];    
    end    
    
    
    always @* begin
        if (rclk_wr_ptr[ADR_SZ] == rd_ptr[ADR_SZ])
            rclk_usage = rclk_wr_ptr - rd_ptr;
        else
            wclk_usage = DEPTH[ADR_SZ:0] + rclk_wr_ptr[ADR_SZ-1:0] - rd_ptr[ADR_SZ-1:0];    
    end        
    
    //----------- output pipeline option
generate
  if (RD_OUT_REG == 0) begin: GEN_RD_OUT_REG_0
    assign rd_srdy = rd_srdy_tmp;
    assign rd_drdy_tmp = rd_drdy;
    assign rd_data = rd_data_tmp;
  end
  else begin: GEN_RD_OUT_REG_1
    always @(posedge rd_clk) begin
        if (rd_rst) begin
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
    
    
  //========== FUNCTIONS
  //----- copy bin2grey and grey2bin functions from SDLIB
  function [ADR_SZ:0] bin2grey;
    input [ADR_SZ:0] bwr_in;
    begin
      bin2grey[ADR_SZ] = bwr_in[ADR_SZ];
      for (int b=0; b<ADR_SZ; b=b+1)
        bin2grey[b] = bwr_in[b] ^ bwr_in[b+1]; // cn_lint_off_line CN_RANGE_UFLOW
    end
  endfunction // for

  function [ADR_SZ:0] grey2bin;
    input [ADR_SZ:0] grey_in;
    begin
      grey2bin[ADR_SZ] = grey_in[ADR_SZ];
      for (int b=ADR_SZ-1; b>=0; b=b-1)
        grey2bin[b] = grey_in[b] ^ grey2bin[b+1]; // cn_lint_off_line CN_RANGE_UFLOW
    end
  endfunction    
    
endmodule
`endif  // __VLIB_SD_FLOP_ASYNC_FIFO_V__
