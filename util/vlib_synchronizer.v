//----------------------------------------------------------------------
// A clock domain crossing synchronizer.
// (if multibit data: only used for sending grey code to another clock domain)
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

`ifndef __VLIB_SYNCHRONIZER_V__
`define __VLIB_SYNCHRONIZER_V__

module vlib_synchronizer
  #(parameter WIDTH = 8)
  (
    input [WIDTH-1:0]           tx_data,

    input                       rx_clk,
    output logic [WIDTH-1:0]    rx_data
  );
  
`ifdef FPGA
    // using FPGA synchronizer
    logic [WIDTH-1:0]   data_tmp;
    
    always @(posedge rx_clk) begin
        data_tmp <= tx_data;
        rx_data <= data_tmp;
    end
`else
  `ifndef SIMULATION
    // using ASIC synchronizer standard cell
  `else
    // using 2-flop synchronizer for simulation
    logic [WIDTH-1:0]   data_tmp;
    
    always @(posedge rx_clk) begin
        data_tmp <= tx_data;
        rx_data <= data_tmp;
    end
  `endif
`endif
endmodule
`endif // __VLIB_SYNCHRONIZER_V__
