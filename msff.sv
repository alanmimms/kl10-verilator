`timescale 1ns/1ps
// Master/slave (HATE that name!) flipflop emulating one flop of
// MC10176. Latch data on negedge of clk and present on following
// posedge.
module msff(input bit clk,
            input bit d,
            output bit q);

  bit master;
  always_comb if (~clk) master = d;
  always @(posedge clk) q <= master;
endmodule
