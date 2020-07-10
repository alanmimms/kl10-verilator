`timescale 1ns/1ps
// Hex master/slave (HATE that name!) flipflop emulating one flop of
// MC10176. Latch data on negedge of clk and present on following
// posedge.
module msff6(input bit clk,
             input bit [0:5] d,
            output bit [0:5] q);

  genvar k;
  for (k = 0; k < 6; ++k) begin: g
    msff ff(.clk(clk), .d(d[k]), .q(q[k]));
  end
endmodule
