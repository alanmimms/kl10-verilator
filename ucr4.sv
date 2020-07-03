`timescale 1ns/1ps
// This is like MC10136 ECL universal up-down counter but all positive logic
module UCR4(input bit [0:3] D,
            input bit CIN /*verilator clocker*/,
            input bit [0:1] SEL,
            input bit CLK /*verilator clocker*/,
            output bit [0:3] Q,
            output bit COUT);

  // CIN overrides CLK when in INC or DEC mode. This signal is the
  // real clock for Q.
  bit carryClk /*verilator clocker*/;

  always_comb unique case (SEL)
              2'b00: begin COUT = 1;            carryClk = CLK; end // LOAD
              2'b01: begin COUT = Q == 4'b0000; carryClk = CIN; end // DEC
              2'b10: begin COUT = Q == 4'b1111; carryClk = CIN; end // INC
              2'b11: begin COUT = 0;            carryClk = CLK; end // HOLD
              endcase
  
  always_ff @(posedge carryClk) unique case (SEL)
                                2'b00: Q <= D;                    // LOAD
                                2'b01: Q <= Q - {3'b000, CIN};    // DEC
                                2'b10: Q <= Q + {3'b000, CIN};    // INC
                                2'b11: Q <= Q;                    // HOLD
                                endcase
endmodule
