// TODO: Should the lack ACKN pulse last until START releases? (For
// back-to-back cycles on the same phase I don't know that it will
// actually release.)
`timescale 1ns/1ps
`include "ebox.svh"

// This module pretends to be a MB20 core memory. The A phase is
// negedge of SBUS.CLK_INT and B phase is posedge.
//
// TODO:
// * Implement BLKO PI diagnostic cycle support.
// * Support interleaving.
// * Implement hardware memory through DMA to DRAM shared with Linux.
// * Support ACKN of next word while VALID on current word
module memory(input bit CROBAR,
              iSBUS.memory SBUS);

`ifdef TB
  bit [0:35] mem[`MEMSIZE];

  bit aClk, bClk;
  bit [0:35] aData, bData;
  bit aParity, bParity;

  assign aClk = ~SBUS.CLK_INT;
  assign bClk =  SBUS.CLK_INT;

  assign SBUS.D = aClk ? aData : bData;
  assign SBUS.DATA_PAR = aClk ? aParity : bParity;

  iRAM ramIntf();

  assign ramIntf.data = mem[$clog2(`MEMSIZE)'(ramIntf.addr)];
  always @(posedge ramIntf.we) mem[$clog2(`MEMSIZE)'(ramIntf.addr)] <= ramIntf.writeData;

  memPhase aPhase(.clk(aClk),
                  .mem(ramIntf),
                  .START(SBUS.START_A),
                  .ACKN(SBUS.ACKN_A),
                  .VALID(SBUS.DATA_VALID_A),
                  .D(aData),
                  .PARITY(aParity),
                  .*);
  memPhase bPhase(.clk(bClk),
                  .mem(ramIntf),
                  .START(SBUS.START_B),
                  .ACKN(SBUS.ACKN_B),
                  .VALID(SBUS.DATA_VALID_B),
                  .D(bData),
                  .PARITY(bParity),
                  .*);
`else
`error "this needs implementing"
`endif
endmodule


`timescale 1ns/1ps
// This is one phase of the MB20 core memory. For now, we implement
// only read cycles and only non-interleaved organization.
//
// NOTE: START may already be asserted for subsequent cycle while we
// are still finishing up the VALID pulses for the current one.
module memPhase(input bit CROBAR,
                input bit clk,
                iRAM mem,
                iSBUS.memory SBUS,
                output bit [0:35] D,
                output bit PARITY,
                input bit START,
                output bit ACKN,
                output bit VALID);

  bit [14:35] addr;             // Address base we start at for quadword
  bit [34:35] wo;               // Word offset of quadword
  bit [0:3] toAck;              // Words we have not yet ACKed

  assign ACKN = toAck[0];
  assign VALID = toAck[0];

  always_comb if (VALID) begin
    mem.addr = {addr[36 - $clog2(`MEMSIZE):33], wo};
    D = mem.data;
    PARITY = ^D;
  end else begin
    D = '0;
    PARITY = 0;
  end

  always_ff @(posedge clk) if (CROBAR) begin
    addr <= '0;
    wo <= '0;
    toAck <= '0;
  end else if (START && toAck == '0) begin     // A transfer is starting
    addr <= SBUS.ADR;           // Address of first word we do
    wo <= SBUS.ADR[34:35];      // Word offset we increment mod 4
    toAck <= SBUS.RQ;           // Addresses remaining to ACK
  end

  always_ff @(posedge clk) if (toAck != '0) begin
    wo <= wo + 1;
    toAck <= toAck << 1;
  end
endmodule
