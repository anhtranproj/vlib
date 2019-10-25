//----------------------------------------------------------------------
// A Srdy/Drdy pipeline cell
//----------------------------------------------------------------------
// Author: Anh Tran (Tran)
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

`ifndef __VLIB_SD_PPLN_V__
`define __VLIB_SD_PPLN_V__

module vlib_sd_ppln 
    #(parameter WIDTH = 32,
      parameter PPLN_OPT = 2 // 0: not pipelined; 1: sd_input; 2: sd_output; 3: sd_iofull; 4: sd_iofull_isinput
    )
    (
    input clk,  
    input rst,  
   
    input logic                 c_srdy,
    output logic                c_drdy,
    input logic [WIDTH-1:0]     c_data,
    
    output logic                p_srdy,
    input logic                 p_drdy,
    output logic [WIDTH-1:0]    p_data
    );

    //================== BODY ==================

  generate
    if (PPLN_OPT == 0) begin: GEN_PPLN_OPT_0
        assign p_srdy = c_srdy;
        assign c_drdy = p_drdy;
        assign p_data = c_data;
    end

    if (PPLN_OPT == 1) begin: GEN_PPLN_OPT_1
        sd_input
        #(.width    (WIDTH))
        sd_input_ins
        (
        .clk    (clk),
        .reset  (rst),
            
        .c_srdy (c_srdy),
        .c_drdy (c_drdy),
        .c_data (c_data),

        .ip_srdy    (p_srdy),
        .ip_drdy    (p_drdy),
        .ip_data    (p_data)
        );
    end
        
    if (PPLN_OPT == 2) begin: GEN_PPLN_OPT_2
        sd_output
        #(.width    (WIDTH))
        sd_output_ins
        (
        .clk    (clk),
        .reset  (rst),
        
        .ic_srdy    (c_srdy),
        .ic_drdy    (c_drdy),
        .ic_data    (c_data),

        .p_srdy (p_srdy),
        .p_drdy (p_drdy),
        .p_data (p_data)
        );
    end

    if (PPLN_OPT == 3) begin: GEN_PPLN_OPT_3
        sd_iofull 
        #(.width    (WIDTH),
          .isinput  (0)
        ) 
        sd_iofull_ins
        (
        .clk    (clk),
        .reset  (rst),
            
        .c_srdy (c_srdy),
        .c_drdy (c_drdy),
        .c_data (c_data),

        .p_srdy (p_srdy),
        .p_drdy (p_drdy),
        .p_data (p_data)
        );        
    end
    
    if (PPLN_OPT == 4) begin: GEN_PPLN_OPT_4
        sd_iofull 
        #(.width    (WIDTH),
          .isinput  (1)
        )  
        sd_iofull_isinput_ins
        (
        .clk    (clk),
        .reset  (rst),
            
        .c_srdy (c_srdy),
        .c_drdy (c_drdy),
        .c_data (c_data),

        .p_srdy (p_srdy),
        .p_drdy (p_drdy),
        .p_data (p_data)
        );        
    end    
  endgenerate

endmodule
`endif // __VLIB_SD_PPLN_V__
