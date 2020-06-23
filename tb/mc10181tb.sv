`timescale 1ns/1ps
module mc10181tb(input bit clk);
  bit [0:3] S, A, B;
  bit [0:3] F;
  bit M, CIN;
  bit CG, CP, COUT;

  mc10181 mc10181(.*);

  var bit [0:3] a, b;

  initial a = '0;
  initial b = '0;

  always @(posedge clk) begin
    if (b == 4'b1111) a = a + 1;
    b = b + 1;
    A = a;
    B = b;
    {M, S} = 5'b01001;    // A-B
    CIN = 1;
  end

  // Display values from previous iteration
  always @(negedge clk) if (F != 4'(A-B)) $display("%04b-%04b sb %04b was %04b Cout=%b",
                                                   A, B, A-B, F, COUT);
endmodule
