//----------------------------------------------------------------------
// A Srdy/Drdy delay pipe
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

`ifndef __VLIB_SD_DLYPP_V__
`define __VLIB_SD_DLYPP_V__

module vlib_sd_dlypp 
    #(parameter WIDTH = 32,
      parameter DELAY = 2,
      parameter C_DRDY_REG = 0
    )
    (
    input clk,
    input rst,
   
    input               c_srdy,
    output logic        c_drdy,
    input [WIDTH-1:0]   c_data,
    
    output logic                p_srdy,
    input                       p_drdy,
    output logic [WIDTH-1:0]    p_data
    );

    //================== BODY ==================
    logic               c_srdy_tmp;
    logic               c_drdy_tmp;
    logic [WIDTH-1:0]   c_data_tmp;
 
    logic [DELAY:0]             p_srdy_tmp;
    logic [DELAY:0]             p_drdy_tmp;
    logic [DELAY:0] [WIDTH-1:0] p_data_tmp; 
 
generate
  if (C_DRDY_REG == 0) begin: GEN_C_DRDY_REG_0
    assign c_srdy_tmp = c_srdy;
    assign c_drdy = c_drdy_tmp;
    assign c_data_tmp = c_data;
  end
  else begin: GEN_C_DRDY_REG_1
    sd_input
    #(.width    (WIDTH))
    sd_input_ins
    (
    .clk    (clk),
    .reset  (rst),
    
    .c_srdy (c_srdy),
    .c_drdy (c_drdy),
    .c_data (c_data),

    .ip_srdy    (c_srdy_tmp),
    .ip_drdy    (c_drdy_tmp),
    .ip_data    (c_data_tmp)
    );
  end
endgenerate
 
generate
  if (DELAY == 0) begin: GEN_DELAY_0
    assign p_srdy = c_srdy_tmp;
    assign c_drdy_tmp = p_drdy;
    assign p_data = c_data_tmp;
  end

  else begin: GEN_DELAY_GREATER_0
    assign p_srdy_tmp[0] = c_srdy_tmp;
    assign c_drdy_tmp = p_drdy_tmp[0];
    assign p_data_tmp[0] = c_data_tmp;
  
    for(genvar ii=0; ii<DELAY; ii++) begin: GEN_SD_PPLN
        vlib_sd_ppln 
        #(.WIDTH    (WIDTH),
          .PPLN_OPT (2) // 0: not pipelined; 1: sd_input; 2: sd_output; 3: sd_iofull
        )
        sd_ppln_ins
        (
        .clk    (clk),  // ri lint_check_waive INPUT_NOT_READ
        .rst    (rst),  // ri lint_check_waive INPUT_NOT_READ
   
        .c_srdy (p_srdy_tmp[ii]),
        .c_drdy (p_drdy_tmp[ii]),
        .c_data (p_data_tmp[ii]),
    
        .p_srdy (p_srdy_tmp[ii+1]),
        .p_drdy (p_drdy_tmp[ii+1]),
        .p_data (p_data_tmp[ii+1])
        );
    end
    
    assign p_srdy = p_srdy_tmp[DELAY];
    assign p_drdy_tmp[DELAY] = p_drdy;
    assign p_data = p_data_tmp[DELAY];
  end

endgenerate

endmodule
`endif // __VLIB_SD_DLYPP_V__
