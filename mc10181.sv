`timescale 1ns/1ps
// MC10181 from Fairchild ECL datasheet F10181.pdf.
//
// S3 S2 S1 S0    M=1 C0=X    M=0 C0=0     M=0 C0=1
//-------------------------------------------------------
//  0  0  0  0    ~A          A            A+1
//  0  0  0  1    ~A|~B       A+(A&~B)     A+(A&~B)+1
//  0  0  1  0    ~A|B        A+(A&B)      A+(A&B)+1
//  0  0  1  1    1111        A+A          A+A+1
//  0  1  0  0    ~A&~B       A|B          (A|B)+1
//  0  1  0  1    ~B          (A|B)+(A&~B) (A|B)+(A&~B)+1
//  0  1  1  0    ~(A^B)      A+B          A+B+1
//  0  1  1  1    A|~B        (A|B)+A      (A|B)+A+1
//  1  0  0  0    ~A&B        A|~B         (A|~B)+1
//  1  0  0  1    A^B         A-B-1        A-B
//  1  0  1  0    B           (A|~B)+(A&B) (A|~B)+(A&B)+1
//  1  0  1  1    A|B         (A|~B)+A     (A|~B)+A+1
//  1  1  0  0    0000        -1           0000
//  1  1  0  1    A&~B        (A&~B)-1     A&~B
//  1  1  1  0    A&B         (A&B)-1      A&B
//  1  1  1  1    A           A-1          A
module mc10181(input bit [0:3] S,
               input bit M,
               input bit [0:3] A,
               input bit [0:3] B,
               input bit CIN,
               output bit [0:3] F,
               output bit CG,
               output bit CP,
               output bit COUT);

  bit [0:3] G, P, Ale, Ble, Sle, Fle;
  bit notGG;

  // In the ECL datasheet, the e S3..S0 and A, B, and F fields are in
  // little-endian bit order. But of course PDP10 uses the
  // never-to-be-sufficently-damned big-endian bit ordering. We have to
  // swap this here.
  assign Sle = {S[3], S[2], S[1], S[0]};
  assign Ale = {A[3], A[2], A[1], A[0]};
  assign Ble = {B[3], B[2], B[1], B[0]};
  assign F = {Fle[3], Fle[2], Fle[1], Fle[0]};

  assign G = ~(~({4{Sle[3]}} | Ble | Ale) | ~({4{Sle[2]}} | Ale  | ~Ble));
  assign P = ~(~({4{Sle[1]}} | ~Ble   ) | ~({4{Sle[0]}} | Ble) | ~Ale);
  assign Fle = ~(G ^ P ^
                 {~(M | G[2]) |
                  ~(M | P[2] | G[1]) |
                  ~(M | P[2] | P[1] | G[0]) |
                  ~(M | P[2] | P[1] | P[0] | CIN),

                  ~(M | G[1]) |
                  ~(M | P[1] | G[0]) |
                  ~(M | P[1] | P[0] | CIN),

                  ~(M | G[0]) |
                  ~(M | P[0] | CIN),

                  ~(M | CIN)});
  assign notGG = ~G[3] |
                 ~(P[3] | G[2]) |
                 ~(P[3] | P[2] | G[1]) |
                 ~(P[3] | P[2] | P[1] | G[0]);
  assign CG = ~notGG;
  assign CP = ~|P;
  assign COUT = ~(notGG | ~(CP | CIN));
endmodule // mc10181


`ifdef TESTBENCH
module mc10181_tb(input bit clk);
  bit [0:3] S, A, B;
  bit [0:3] F;
  bit M, CIN;
  bit CG, CP, COUT;

  bit [7:0] tickCount;

  mc10181 mc10181(.*);

  /* verilator lint_off BLKSEQ */
  always @(posedge clk) begin
    ++tickCount;
    A = 0;
    B = 0;
    {M, S} = 5'o23;
    CIN = 0;

    $display($time, "M=%b S=%4b A=%4b B=%4b CIN=%b F=%4b CG=%b CP=%b COUT=%b",
             M, S, A, B, CIN, F, CG, CP, COUT);
  end
endmodule // mc10181_tb
`endif //  `ifdef TESTBENCH
