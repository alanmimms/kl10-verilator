// XXX This needs to be manually checked against the schematics.
//
// I have tried to make most of this FPGA based design as close to the
// original schematics as possible. But the DRAM ("DISPATCH RAM" - not
// "DYNAMIC RAM") addressing architecture in the KL10 is arse -- a
// bridge too far. Even the microcode guys made fun of the choice as
// is evidenced by this quip from the microcode listing:
//
//     The J field is the starting location of the microroutine to
//     execute the instruction.  Note that the 40 and 20 bits must
//     always be zero.  Also, even-odd pairs of DRAM J fields may
//     differ only in the low order three bits.  (Someone thought he
//     was being very clever when he designed the machine this way.
//     It probably reduced our transfer cost by at least five dollars,
//     after all, and the microcode pain that occurred later didn't cost
//     anything, in theory.)
//
// Indeed, the intrepid microcoders bore the brunt of that complexity.
//
// I didn't waste my (well, ... hobby) time tediously cramming DRAM
// into 256 words with a rubegoldbergian 256x3 even/odd scheme. Here
// we implement all 512 words of A[0:2], B:[0,2], P, J[1:4], J[7:10]
// without the padding used in the microcode listings as or 512*15 = a
// big throbbing 7.5Kb of RAM.
//
// The design is simplified by "wasting" a small amount of RAM. Sue
// me. It's the fucking 21st Century and we stand SO TALL on the
// shoulders of giants that we don't have to dick around to save a few
// kilobits.
`timescale 1ns/1ps
`include "ebox.svh"

// M8522 IR
module ir(iIR IR,
          iCRAM CRAM,
          iCLK CLK,
          iCON CON,
          iCTL CTL,
          iEDP EDP,
          iEBUS.mod EBUS,
          iMBOX MBOX
          );

  localparam DRAM_WIDTH=15;
  localparam DRAM_SIZE=512;
  localparam DRAM_ADDR_BITS=$clog2(DRAM_SIZE);

  bit [0:DRAM_WIDTH-1] DRAMdata;
  bit [0:DRAM_ADDR_BITS - 1] DRADR;

  bit IR_CLK;
  assign IR_CLK = CLK.IR;

  // p.210 shows older KL10 DRAM addressing.

  // JRST is 0o254,F
  bit JRST;
  assign JRST = enIO_JRST && (IR.IR[0:8] == 9'o254);
  assign IR.JRST0 = JRST & (IR.IR[9:12] == 4'b0000);

  bit enIO_JRST;
  bit enAC;
  bit instr7XX;
  bit instr3thru6;
  bit enableAC;
  bit magic7eq8;
  bit AgtB;

  // This mess is p.128 E55,E70,E71,E75,E76
  assign instr7XX = IR.IR[0] & IR.IR[1] & IR.IR[2] & enIO_JRST;
  assign instr3thru6 = &IR.IR[3:6];

  bit [3:8] ioDRADR;
  assign ioDRADR[3:5] = instr7XX ? (IR.IR[7:9] | {3{instr3thru6}}) : IR.IR[3:5];
  assign ioDRADR[6:8] = instr7XX ? IR.IR[6:8] : IR.IR[10:12];

  always @(posedge CON.LOAD_DRAM) DRADR <= {IR.IR[0:2], instr7XX ? IR.IR[3:8] : ioDRADR};

  bit [7:10] DRAM_PAR_J;
  bit DRAM_PAR;

  bit HOLD_DRAM, HOLD_IR;
  assign HOLD_DRAM = ~CON.LOAD_DRAM | CLK.IR;
  assign HOLD_IR = ~CON.LOAD_IR | CLK.IR;

  // Latch-mux es

  // In this design, the DRADR[8] address pin simply goes to our DRAM
  // RAM to avoid having to do this messy muxing. I wrote this code
  // before I realized this completely, so here it is in case I have
  // to go back to the frugality of RAM bits that was only somewhat
  // justified in the 1970s.
  //
  // E52
  // always_latch if (HOLD_DRAM) IR.DRAM_A = DRADR[8] ? DRAM_A_Y : DRAM_A_X;
  // always_latch if (HOLD_DRAM) DRAM_PAR = DRADR[8] ? DRAM_PAR_Y : DRAM_PAR_X;
  // E33
  // always_latch if (HOLD_DRAM) IR.DRAM_B = DRADR[8] ? DRAM_B_Y : DRAM_B_X;
  // E63
  // always_latch if (HOLD_DRAM) IR.DRAM_J[1:4] = DRADR[8] ? DRAM_J_Y[7:10] : DRAM_J_Y[7:10];

  always_latch if (HOLD_DRAM) IR.DRAM_J[1:4] = ~IR_JRST ? DRAM_J[1:4] : {DRAM_J[1:3], 1'b0};
  always_latch if (HOLD_DRAM) IR.DRAM_J[7:10] = ~IR_JRST ? IR.IR[9:12] : DRAM_PAR_J[7:10];
  always_latch if (HOLD_DRAM) IR.AC[9:12] = ~IR_EN_AC ? 4'b0000 : IR.IR[9:12];

  bit INSTR_7xx, e75q2;
  assign INSTR_7xx = |IR[0:2] | IR_EN_IO_JRST;
  assign e75q2 = ~&(~IR[3:6]);
  always_comb DR_ADR[3:5] == INSTR_7xx ? {3{e75q2}} | IR.IR[7:9] : IR.IR[3:5];
  always_comb DR_ADR[6:8] == INSTR_7xx ? IR.IR[10:12] : IR.IR[6:8];

  // XXX In addition to the below, this has two mystery OR-term
  // signals on each input to the AND that are unlabeled except for
  // backplane references <ES2> and <ER2>. See E66 p.128.
  assign IR.IO_LEGAL = &IR.IR[3:6];
  assign IR.ACeq0 = IR.IR[9:12] == 4'b0;

  // The actual IR register is built out of 10173 latch-muxes.
  always_latch if (HOLD_IR) IR.IR[0:12] = CLK.MB_XFER ? MBOX.CACHE_DATA[0:12] : EDP.AD[0:12];


  // IR2 p.129
`ifdef KL10PV_TB
  sim_mem
    #(.SIZE(DRAM_SIZE), .WIDTH(DRAM_WIDTH), .NBYTES(1))
  dram
    (.clk(IR_CLK),
     .din('0),                  // XXX
     .dout(DRAMdata),
     .addr(DRADR),
     .oe(1'b1),
     .wea(1'b0));               // XXX
`else
  dram_mem dram(.clka(IR_CLK),
                .addra(DRADR),
                .douta(DRAMdata),
                .dina('0),
                .wea(1'b0),
                .ena(1'b1));
`endif

/*
  // always_latch if (HOLD_DRAM) IR.DRAM_A = DRADR[8] ? DRAM_A_Y : DRAM_A_X;
  // always_latch if (HOLD_DRAM) DRAM_PAR = DRADR[8] ? DRAM_PAR_Y : DRAM_PAR_X;
  // E33
  // always_latch if (HOLD_DRAM) IR.DRAM_B = DRADR[8] ? DRAM_B_Y : DRAM_B_X;
  // E63
  // always_latch if (HOLD_DRAM) IR.DRAM_J[1:4] = DRADR[8] ? DRAM_J_Y[7:10] : DRAM_J_Y[7:10];

  always_latch if (HOLD_DRAM) IR.DRAM_J[1:4] = ~IR_JRST ? DRAM_J[1:4] : {DRAM_J[1:3], 1'b0};
  always_latch if (HOLD_DRAM) IR.DRAM_J[7:10] = ~IR_JRST ? IR.IR[9:12] : DRAM_PAR_J[7:10];
  always_latch if (HOLD_DRAM) IR.AC[9:12] = ~IR_EN_AC ? 4'b0000 : IR.IR[9:12];
*/

  // These bit field definitions come from the tools/write-dram-mem.js
  // packing.
  assign IR.DRAM_A = DRAMdata[0:2];
  assign IR.DRAM_B = DRAMdata[3:5];
  assign IR.DRAM_PAR = DRAMdata[6];
  assign IR.DRAM_J[1:4] = DRAMdata[7:10];
  assign IR.DRAM_J[7:10] = DRAMdata[11:14];


  assign magic7eq8 = CRAM.MAGIC[7] ^ CRAM.MAGIC[8];
  assign AgtB = EDP.AD[0] ^ EDP.AD_CRY[-2];
  assign IR.ADeq0 = ~|EDP.AD;
  assign IR.TEST_SATISFIED = |{IR.DRAM_B[1] & IR.ADeq0,                  // EQ
                               IR.DRAM_B[2] & AgtB & CRAM.MAGIC[7],      // GT
                               IR.DRAM_B[2] & EDP.AD[0] & CRAM.MAGIC[8], // LT
                               ~magic7eq8 & EDP.AD_CRY[-2]               // X
                               } ^ IR.DRAM_B[0];

  // p.130 E57 and friends
  bit [0:7] e57Q;
  // This is modeled as one-hot active high unlike the MC10161.
  always_comb if (CTL.DIAG_LOAD_FUNC_06x) case (CTL.DIAG[4:6])
                                          3'b000: e57Q = 8'b10000000;
                                          3'b001: e57Q = 8'b01000000;
                                          3'b010: e57Q = 8'b00100000;
                                          3'b011: e57Q = 8'b00010000;
                                          3'b100: e57Q = 8'b00001000;
                                          3'b101: e57Q = 8'b00000100;
                                          3'b110: e57Q = 8'b00000010;
                                          3'b111: e57Q = 8'b00000001;
                                          endcase
              else e57Q = 8'b0;

  assign EN_IO_JRST = ~e57Q[5] & (e57Q[7] | EN_IO_JRST);
  assign EN_AC      = ~e57Q[6] & (e57Q[7] | EN_AC);;
                                          
  priority_encoder8 e67(.d({1'b0,
                            EDP.AD[0],
                            EDP.AD[6] | (|EDP.AD[0:5]),
                            EDP.AD[7:10],
                            |EDP.AD}),
                        .any(),
                        .q(IR.NORM));

  assign IR.DRAM_ODD_PARITY = ^{IR.DRAM_A,
                                IR.DRAM_B,
                                DRAM_PAR,
                                IR.DRAM_J[1:4],
                                DRAM_PAR_J[7:10]};

  // Diagnostics to drive EBUS
  assign IR.EBUSdriver.driving = CTL.DIAG_READ_FUNC_13x;

  always_comb if (IR.EBUSdriver.driving)
    case (CTL.DIAG[4:6])
    3'b000: IR.EBUSdriver.data[0:5] = {IR.NORM, DRADR[0:2]};
    3'b001: IR.EBUSdriver.data[0:5] = DRADR[3:8];
    3'b010: IR.EBUSdriver.data[0:5] = {enIO_JRST, enAC, IR.AC};
    3'b011: IR.EBUSdriver.data[0:5] = {IR.DRAM_A, IR.DRAM_B};
    3'b100: IR.EBUSdriver.data[0:5] = {IR.TEST_SATISFIED, IR.JRST0, IR.DRAM_J[1:4]};
    3'b101: IR.EBUSdriver.data[0:5] = {DRAM_PAR, IR.DRAM_ODD_PARITY, IR.DRAM_J[7:10]};
    3'b110: IR.EBUSdriver.data[0:5] = {IR.ADeq0, IR.IO_LEGAL,
                                       CTL.INH_CRY_18, CTL.SPEC_GEN_CRY_18,
                                       CTL.SPEC_GEN_CRY_18, EDP.AD_CRY[-2]};
    3'b111: IR.EBUSdriver.data[0:5] = {EDP.AD_CRY[12], EDP.AD_CRY[18],
                                       EDP.AD_CRY[24], EDP.AD_CRY[36],
                                       EDP.ADX_CRY[12], EDP.ADX_CRY[24]};
    endcase
              else IR.EBUSdriver.data = '0;

  // Look-ahead carry functions have been moved from IR to EDP.
endmodule // ir
// Local Variables:
// verilog-library-files:("../ip/dram_mem/dram_mem_stub.v")
// End:
