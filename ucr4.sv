`timescale 1ns/1ps
// This is like MC10136 ECL universal up-down counter but all positive logic
module UCR4(input bit [0:3] D,
            input bit CIN /*verilator clocker*/,
            input bit [0:1] SEL,
            input bit CLK /*verilator clocker*/,
            output bit [0:3] Q,
            output bit COUT);

  // Not LOAD or HOLD
  bit incOrDec = SEL[0] ^ SEL[1];

  // CIN overrides CLK when in INC or DEC mode. This signal is the
  // real clock we have to pay attention to as a result.
  bit carryClk /*verilator clocker*/;
  assign carryClk = incOrDec ? CIN : CLK;

  always_comb unique case (SEL)
              2'b00: COUT = 1;            // LOAD
              2'b01: COUT = Q == 4'b0000; // DEC
              2'b10: COUT = Q == 4'b1111; // INC
              2'b11: COUT = 0;            // HOLD
              endcase
  
  always_ff @(posedge carryClk) unique case (SEL)
                                2'b00: Q <= D;                    // LOAD
                                2'b01: Q <= Q - {3'b000, CIN};    // DEC
                                2'b10: Q <= Q + {3'b000, CIN};    // INC
                                2'b11: ;                          // HOLD
                                endcase
endmodule
