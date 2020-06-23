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

  bit [3:0] G, P, Ale, Ble, Sle, Fle;

  // In the ECL datasheet, the e S3..S0 and A, B, and F fields are in
  // little-endian bit order. But of course PDP10 uses the
  // never-to-be-sufficently-damned big-endian bit ordering. We have to
  // swap this here.
  assign Sle = {S[0], S[1], S[2], S[3]};
  assign Ale = {A[0], A[1], A[2], A[3]};
  assign Ble = {B[0], B[1], B[2], B[3]};

  assign G = ~(~({4{Sle[3]}} | Ale |  Ble) |
               ~({4{Sle[2]}} | Ale | ~Ble));

  assign P = ~(~({4{Sle[1]}} | ~Ble) |
               ~({4{Sle[0]}} |  Ble) |
               ~Ale);

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
  bit notCG;
  assign notCG = ~G[3] |
                 ~(P[3] | G[2]) |
                 ~(P[3] | P[2] | G[1]) |
                 ~(P[3] | P[2] | P[1] | G[0]);
  assign CG = ~notCG;
  assign CP = ~|P;
  assign F = {Fle[3], Fle[2], Fle[1], Fle[0]};
  assign COUT = ~(notCG | ~(~CP | CIN));
endmodule // mc10181
