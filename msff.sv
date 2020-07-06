`timescale 1ns/1ps
// Master/slave (HATE that name!) flipflop emulating one flop of
// MC10176. Latch data on negedge of clk and present on following
// posedge.
module msff(input bit clk,
            output bit q,
            input bit d);

  bit master;
  always_ff @(negedge clk) master <= d;
  always_ff @(posedge clk) q <= master;
endmodule
