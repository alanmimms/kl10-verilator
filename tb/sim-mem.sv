`timescale 1ns/1ps
module sim_mem 
  #(parameter SIZE=0,
    parameter WIDTH=0,
    parameter NBYTES=0)
  (input bit clk /*verilator clocker*/,
   input bit [0:WIDTH-1] din,
   output bit [0:WIDTH-1] dout,
   input bit [0:$clog2(SIZE)-1] addr,
   input bit oe,                    // All enabled or not - no bytes for oe
   input bit [0:NBYTES-1] wea);

  localparam BYTE_WIDTH = WIDTH / NBYTES;

  typedef bit [0:NBYTES-1] [0:BYTE_WIDTH-1] tWord;
  tWord mem[SIZE-1:0];
  tWord lanes;

  // Convert to form that is simpler to address
  assign lanes = tWord'(din);

  genvar byteN;
  generate

//    for (byteN = 0; byteN < NBYTES; ++byteN)
//      always_ff @(posedge clk) if (wea[byteN]) mem[addr][byteN] <= lanes[byteN];

  endgenerate

  // Read data follows address unclocked.
  always_latch if(oe) dout = WIDTH'(mem[addr]);
endmodule
