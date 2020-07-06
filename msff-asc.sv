`timescale 1ns/1ps
// Master/slave (HATE that name!) flipflop emulating one flop of
// MC10131. Latch data on negedge of clk and present on following
// posedge.
module msffAsyncSetClear(input bit clk,
                         output bit q,
                         input bit d,
                         input bit set,
                         input bit clear);

  bit master;

  always_ff @(negedge clk, posedge set, posedge clear)
    if (set) master <= 1; else if (clear) master <= 0; else master <= d;

  always_ff @(posedge clk, posedge set, posedge clear)
    if (set)      q <= 1; else if (clear)      q <= 0; else q <= master;
endmodule
