`timescale 1ns/1ps
// Master/slave (HATE that name!) flipflop emulating one flop of
// MC10176. Master latches data while clk is low and presents to
// output on following posedge.
module msff(input bit clk,
            output bit q,
            input bit d);

  bit master;

  always_latch @(d) if (~clk) master <= d;
  always_ff @(posedge clk) q <= master;
endmodule
