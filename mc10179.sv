`timescale 1ns/1ps
module mc10179(input bit [0:3] G,
               input bit [0:3] P,
               input bit CIN,

               output bit GG,
               output bit PG,
               output bit C8OUT,
               output bit C2OUT);

  bit [3:0] Gle, Ple;
  assign Gle = {G[0], G[1], G[2], G[3]};
  assign Ple = {P[0], P[1], P[2], P[3]};
  assign C8OUT = Gle[3] &
                 (Ple[3] | Gle[2]) &
                 (Ple[3] | Ple[2] | Gle[1]) &
                 (Ple[3] | Ple[2] | Ple[1] | Gle[0]) &
                 (Ple[3] | Ple[2] | Ple[1] | Ple[0] | CIN);
  assign C2OUT = Gle[1] &
                 (Ple[1] | Gle[0]) &
                 (Ple[1] | Ple[0] | CIN);
  assign GG = Gle[3] &
              (Ple[3] | Gle[2]) &
              (Ple[3] | Ple[2] | Gle[1]) &
              (Ple[3] | Ple[2] | Ple[1] | Gle[0]);
  assign PG = |P;
endmodule // mc10179
