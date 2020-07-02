`timescale 1ns/1ps
// Hex master/slave (HATE that name!) flipflop emulating one flop of
// MC10176. Latch data on negedge of clk and present on following
// posedge.
module msff6(input bit clk,
             input bit [0:5] d,
            output bit [0:5] q);

  bit [0:5] master;
  always @(negedge clk) master <= d;
  always @(posedge clk) q <= master;
endmodule
