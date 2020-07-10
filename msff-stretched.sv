`timescale 1ns/1ps
// Master/slave (HATE that name!) flipflop emulating one flop of
// MC10176. Latch data on negedge of clk and present on following
// posedge.
//
// This version uses a pulse-stretcher on its output to stretch
// asserted time by 1/2 clock as an experiment.
module msff_stretched(input bit clk,
                      output bit q,
                      input bit d);

  bit master, stretcher, outState;
  initial outState = 0;
  initial master = 0;
  initial stretcher = 0;

  assign q = outState | stretcher;

  always_ff @(negedge clk) if (~master & stretcher) stretcher <= 0;
                           else if (master) stretcher <= 1;

  always_ff @(negedge clk) master <= d;
  always_ff @(posedge clk) outState <= master;
endmodule
