`timescale 1ns/1ps
`include "ebox.svh"

// M8540 SHM
module shm(iCRAM CRAM,
           iCON CON,
           iEDP EDP,
           iSCD SCD,
           iSHM SHM
);

  //  CRAM   FUNC      SIGNALS
  //   00    SHIFT
  //   01     AR       SHIFT_INH
  //   10     ARX      SHIFT_INH,SHIFT_36
  //   11   AR SWAP    SHIFT_INH,SHIFT_50

  bit INSTR_FORMAT, notSHIFT_INH, SHIFT_36, SHIFT_50;

  // XXX temporary
  initial begin
    SHM.SH = '0;
    SHM.EBUSdriver.driving = 0;
  end

  // SHM1 p.334
  assign SHM.AR_PAR_ODD = ^{EDP.AR, CON.AR_36};
  assign SHM.ARX_PAR_ODD = ^{EDP.ARX, CON.ARX_36};
  assign SHM.AR_EXTENDED = ~EDP.AR[0] & |EDP.AR[6:17];
  assign INSTR_FORMAT = ~CON.LONG_EN | EDP.ARX[0];
  assign SHM.XR = INSTR_FORMAT ? EDP.ARX[14:17] : EDP.ARX[2:5];
  assign SHM.INDEXED = |SHM.XR;

  assign notSHIFT_INH = ~((CRAM.SH != '0) | SCD.SC_GE_36 | SCD.SC_36_TO_63);
  assign SHIFT_50 = &CRAM.SH;
  assign SHIFT_36 = ~CRAM.SH[1] & ~notSHIFT_INH;

  bit [0:5] sc;
  assign sc = SCD.SC[4:9] & {6{notSHIFT_INH}} |
              {SHIFT_36 | SHIFT_50, SHIFT_50, 1'b0, SHIFT_36, SHIFT_50, 1'b0};
  
  // SHM2 p.335
  bit [0:71] ar_arx;
  assign ar_arx = {EDP.AR, EDP.ARX} << sc;
  always_comb case (CRAM.SH)
              2'b00: SHM.SH = ar_arx[0:35];
              2'b01: SHM.SH = EDP.AR;
              2'b10: SHM.SH = EDP.ARX;
              2'b11: SHM.SH = {EDP.AR[18:35], EDP.AR[0:17]};
              endcase
endmodule
