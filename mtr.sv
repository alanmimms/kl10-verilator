`timescale 1ns/1ps
`include "ebox.svh"
// M8538 MTR
module mtr(iCHC CHC,
           iCLK CLK,
           iCON CON,
           iCRAM CRAM,
           iCRC CRC,
           iCSH CSH,
           iCTL CTL,
           iMTR MTR,
           iPI PIC,
           iSCD SCD,
           iVMA VMA,
           iMBOX MBOX,
           iEBUS.mod EBUS
           );

  bit clk  /*noverilator clocker*/;
  bit RESET;
  bit MBOX_CLK;
  bit EBOX_CNT_CLK, CACHE_CNT_CLK, TIME_CLK, PERF_CNT_CLK;
  bit INTERVAL_CLK;
  bit CLR_EBOX_CNT, CLR_CACHE_CNT, CLR_TIME, CLR_PERF_CNT, CLR_INTERVAL;
  bit INTERVAL_CRY, EBOX_HALF_COUNT, TIME_ON;
  bit CONO_MTR;
  bit CONO_TIM;
  bit TEN_USEC, COUNT_TEN_USEC;
  bit EBOX_CNT_EN, CACHE_CNT_EN, PI_ACCT_EN, EXEC_ACCT_EN, ACCT_ON;
  bit [0:2] PI_LEVEL;
  bit [6:17] PERIOD;
  bit NO_MATCH_06to09, NO_MATCH_10to13, NO_MATCH_14to17, INTERVAL_MATCH;
  bit INTERVAL_MATCH_INH, INTERVAL_ON, INTERVAL_OFF, RESET_INTERVAL;
  bit INTERVAL_OVRFLO, INTERVAL_DONE;
  bit RESET_TIME;
  bit RESET_PLSD;
  bit LOAD_PA_LEFT;
  bit LOAD_PA_RIGHT;
  bit RESET_PERF;
  bit [0:7] PI_PA_EN;
  bit NO_PI_PA_EN, USER_PA_EN, MODE_PA_DONT_CARE, PA_EVENT_MODE, CURRENT_PI_PA_EN;
  bit CACHE_REF_PA_EN, CACHE_FILL_PA_EN, CACHE_EWB_PA_EN, CACHE_SWB_PA_EN;
  bit CACHE_PA_DONT_CARE, EBOX_WAITING, READ_MTR;
  bit FILL_CACHE_RD, E_WRITEBACK, CCA_WRITEBACK, READ_INTERVAL, HOLD_INTERRUPT_SEL;
  bit READ_TIME, READ_PERF_CNT, VECTOR_REQ, PI_IN_PROG;
  bit CHAN_PA_DONT_CARE, UCODE_PA_DONT_CARE;
  bit PROBE_LOW_PA_EN, PROBE_PA_DONT_CARE;
  bit [0:1] CHAN_BUSY;
  bit [0:7] CHAN_PA_EN;

  bit [18:35] mtrEBUS;
  bit [20:35] mtrEBUS_IN;
  bit [4:6] DS;
  bit [0:1] INCR_SEL;
  bit [2:18] EBOX_COUNT, CACHE_COUNT, TIME, PERF_COUNT;
  bit [6:18] INTERVAL;


  // MTR1 p.324
  MTRcounter EBOX_COUNT0(.clk(EBOX_CNT_CLK),
                         .clear(CLR_EBOX_CNT),
                         .carry());

  MTRcounter CACHE_COUNT0(.clk(CACHE_CNT_CLK),
                          .clear(CLR_CACHE_CNT),
                          .carry());

  MTRcounter TIME0(.clk(TIME_CLK),
                    .clear(CLR_TIME),
                    .carry());

  MTRcounter PERF_COUNT0(.clk(PERF_CNT_CLK),
                         .clear(CLR_PERF_CNT),
                         .carry());

  MTRcounter #(6) INTERVAL0(.clk(INTERVAL_CLK),
                            .clear(CLR_INTERVAL),
                            .carry());


  assign EBOX_COUNT = {1'b0, EBOX_COUNT0.count};
  assign CACHE_COUNT = {1'b0, CACHE_COUNT0.count};
  assign TIME = {1'b0, TIME0.count};
  assign PERF_COUNT = {1'b0, PERF_COUNT0.count};
  assign INTERVAL = {1'b0, INTERVAL0.count};


  // MTR2 p.325
  bit e5q2, e5q15;
  bit [0:3] e88Q;
  assign clk = CLK.MTR;
  assign MBOX_CLK = clk;
  assign RESET = CLK.MR_RESET;
  assign PI_IN_PROG = |PI_LEVEL;
  assign CACHE_CNT_EN = ACCT_ON &
                        (~PI_IN_PROG | PI_ACCT_EN | SCD.USER) &
                        (~PI_IN_PROG | EXEC_ACCT_EN | SCD.USER) &
                        ~CON.UCODE_STATE3 & ~CON.PI_CYCLE;
  assign e5q2 = e5q2 & ~TIME_CLK |
                (CLR_TIME | TIME_ON) & MTR._1_MHZ;
  assign e5q15 = e5q15 & ~INTERVAL_CLK |
                 (INTERVAL_ON | RESET_INTERVAL) & MTR._1_MHZ;
  assign COUNT_TEN_USEC = e88Q[0] | e88Q[3];

  msff e48q3ff(.clk(MBOX_CLK), .d(CLR_CACHE_CNT | MBOX.CNT_MB_XFER & CACHE_CNT_EN), .q(CACHE_CNT_CLK));
  msff e39q4ff(.clk(MBOX_CLK), .d(~READ_MTR & ~EBOX_WAITING & CACHE_CNT_EN), .q(EBOX_CNT_EN));
  msff e48q4ff(.clk(MBOX_CLK), .d(~(EBOX_CNT_EN ^ ~EBOX_HALF_COUNT) & ~RESET), .q(EBOX_HALF_COUNT));
  msff e48q15ff(.clk(MBOX_CLK), .d(CLR_EBOX_CNT & ~EBOX_CNT_CLK | EBOX_HALF_COUNT & EBOX_CNT_EN),
                .q(EBOX_CNT_CLK));
  msff e48q14ff(.clk(MBOX_CLK), .d(~READ_TIME & e5q2), .q(TIME_CLK));
  msff e48q13ff(.clk(MBOX_CLK), .d(MTR._1_MHZ & RESET | ~READ_INTERVAL & e5q15), .q(INTERVAL_CLK));
  bit e16Clk;
  assign e16Clk = (CONO_MTR | RESET_PLSD) & (mtrEBUS[18] | RESET_PLSD);
  msff e16q3ff(.clk(e16Clk), .d(mtrEBUS[21]), .q(PI_ACCT_EN));
  msff e16q4ff(.clk(e16Clk), .d(mtrEBUS[22]), .q(EXEC_ACCT_EN));
  msff e16q13ff(.clk(e16Clk), .d(mtrEBUS[23]), .q(ACCT_ON));

  always_ff @(posedge CONO_MTR, posedge RESET) if (RESET) TIME_ON <= 0;
                                               else TIME_ON <= TIME_ON & ~mtrEBUS[24] | mtrEBUS[25];

  UCR4 e88(.CIN(1'b1),
           .SEL({1'b0, COUNT_TEN_USEC}),
           .D({4{~RESET}}),
           .CLK(INTERVAL_CLK),
           .Q(e88Q),
           .COUT(TEN_USEC));

  bit e60COUT;
  UCR4 e60(.CIN(1'b1),
           .CLK(MBOX_CLK),
           .SEL({RESET | MTR._1_MHZ, 1'b0}),
           .D(4'b0000),         // Note assumes MBOX_CLK of 33MHz
           .Q(),
           .COUT(e60COUT));

  bit [1:3] e59Unused;
  UCR4 e59(.CIN(e60COUT),
           .COUT(),
           .SEL({RESET | MTR._1_MHZ, 1'b0}),
           .CLK(MBOX_CLK),
           .D({1'b0, ~RESET, ~RESET_PLSD, 1'b0}),
           .Q({MTR._1_MHZ, e59Unused}));


  // MTR3 p.326
  bit e42q6;
  bit [0:7] e1Q;
  assign NO_MATCH_06to09 = PERIOD[6:9] != INTERVAL[6:9];
  assign NO_MATCH_10to13 = PERIOD[10:13] != INTERVAL[10:13];
  assign NO_MATCH_14to17 = PERIOD[14:17] != INTERVAL[14:17];
  assign INTERVAL_MATCH = ~NO_MATCH_06to09 & ~NO_MATCH_10to13 & ~NO_MATCH_14to17 &
                          ~INTERVAL_MATCH_INH;
  assign INTERVAL_OFF = ~INTERVAL_ON;
  assign CLR_INTERVAL = RESET_INTERVAL | INTERVAL_MATCH;
  assign e42q6 = ~RESET_INTERVAL & ~INTERVAL_MATCH & INTERVAL_CRY;
  assign MTR.VECTOR_INTERRUPT = ~INTERVAL_DONE;
  assign MTR.CONO_MTR = CONO_MTR | RESET;
  assign RESET_PERF = (LOAD_PA_RIGHT | e1Q[1]) &
                      (mtrEBUS[30] & e1Q[1]);
  assign CLR_EBOX_CNT = e1Q[2] | RESET;
  assign CLR_CACHE_CNT = e1Q[3] & RESET_PLSD;
  assign LOAD_PA_LEFT = e1Q[4] & RESET_PLSD;
  assign LOAD_PA_RIGHT = e1Q[5] & RESET_PLSD;
  assign CONO_MTR = e1Q[6];
  assign CONO_TIM = e1Q[7] & RESET_PLSD;

  decoder  e1(.en(CTL.SPEC_MTR_CTL & CLK.EBOX_SYNC),
              .sel(CRAM.MAGIC[6:8]),
              .q(e1Q));

  msff6 e45ff(.clk(CONO_TIM), .d(mtrEBUS[24:29]), .q(PERIOD[6:11]));
  msff6 e82ff(.clk(CONO_TIM), .d(mtrEBUS[30:35]), .q(PERIOD[12:17]));

  always_ff @(posedge INTERVAL_CLK) if (CONO_TIM) INTERVAL_MATCH_INH <= 1;
                                    else INTERVAL_MATCH_INH <= INTERVAL_OFF;

  always_ff @(posedge INTERVAL_CLK) if (CONO_TIM & mtrEBUS[18]) RESET_INTERVAL <= 1;
                                    else RESET_INTERVAL <= RESET;

  always_ff @(posedge INTERVAL_CLK) if ((CONO_TIM | RESET) & (mtrEBUS[22] & RESET)) INTERVAL_OVRFLO <= 0;
                                    else INTERVAL_OVRFLO <= e42q6 | INTERVAL_OVRFLO;

  always_ff @(posedge INTERVAL_CLK) if ((CONO_TIM | RESET) & (mtrEBUS[22] & RESET)) INTERVAL_DONE <= 0;
                                    else INTERVAL_DONE <= INTERVAL_DONE | e42q6 | INTERVAL_MATCH;

  bit clk1;
  assign clk1 = TIME_CLK | RESET_PLSD;
  always @(posedge clk1, posedge RESET_TIME) if (RESET_TIME) CLR_TIME <= 1;
                                             else CLR_TIME <= RESET;

  bit clk2;
  assign clk2 = PERF_CNT_CLK | RESET_PLSD;
  always @(posedge clk2, posedge RESET_PERF) if (RESET_PERF) CLR_PERF_CNT <= 1;
                                             else CLR_PERF_CNT <= RESET;


  // MTR4 p.327
  bit e39q14, e39q2;
  bit [0:3] e36Q;
  bit ignoredE81;
  msff6 e26ff(.clk(LOAD_PA_RIGHT), .d(mtrEBUS[18:23]), .q(PI_PA_EN[0:5]));
  msff6 e44ff(.clk(LOAD_PA_RIGHT), .d(mtrEBUS[24:29]),
              .q({PI_PA_EN[6:7], NO_PI_PA_EN, USER_PA_EN, MODE_PA_DONT_CARE, PA_EVENT_MODE}));

  msff6 e61ff(.clk(LOAD_PA_LEFT), .d(mtrEBUS[18:23]), .q(CHAN_PA_EN[0:5]));
  msff6 e56ff(.clk(LOAD_PA_LEFT), .d(mtrEBUS[24:29]),
              .q({CHAN_PA_EN[6:7], CHAN_PA_DONT_CARE, UCODE_PA_DONT_CARE,
                  PROBE_LOW_PA_EN, PROBE_PA_DONT_CARE}));
  msff6 e81ff(.clk(LOAD_PA_LEFT), .d({mtrEBUS[30:34], ignoredE81}),
              .q({CACHE_REF_PA_EN, CACHE_FILL_PA_EN,
                  CACHE_EWB_PA_EN, CACHE_SWB_PA_EN,
                  CACHE_PA_DONT_CARE, 1'b0}));

  msff e39q14ff(.clk(MBOX_CLK), .d(e36Q[0]), .q(e39q14));
  msff e39q3ff(.clk(MBOX_CLK), .d(e36Q[1]), .q(PI_LEVEL[0]));
  msff e39q15ff(.clk(MBOX_CLK), .d(e36Q[2]), .q(PI_LEVEL[1]));
  msff e39q13ff(.clk(MBOX_CLK), .d(e36Q[3]), .q(PI_LEVEL[2]));
  msff e39q2ff(.clk(MBOX_CLK), .d(MBOX.PROBE), .q(e39q2));

  mux e31(.en(1'b1),
          .sel(PI_LEVEL),
          .d({e39q14, PI_PA_EN[1:7]}),
          .q(CURRENT_PI_PA_EN));

  mux4x2 e36(.SEL(CON.PI_CYCLE),
             .D0({NO_PI_PA_EN, PIC.HOLD}),
             .D1({PI_PA_EN[0], PIC.PIC}),
             .B(e36Q));

  bit e54q3;

  // Note this is the ONLY place in all of KL10PV where I've found
  // XXX H and XXX L signals not logically identical except in
  // sense. I picked the PERF CNT CLK L logic and made PERF_CNT_CLK
  // be the inverse of it.
  msff e48q2ff(.clk(MBOX_CLK), .d(~((e54q3 ^ ~RESET) & ~RESET)), .q(PERF_CNT_CLK));

  bit e58q3, e72q3, e86q3;
  assign FILL_CACHE_RD = CSH.FILL_CACHE_RD;
  assign E_WRITEBACK = CSH.E_WRITEBACK;
  assign CCA_WRITEBACK = CSH.CCA_WRITEBACK;

  assign EBOX_WAITING = ~VMA.AC_REF & CLK.EBOX_SYNC & CON.MBOX_WAIT;

  assign e58q3 = (((SCD.USER ^ ~USER_PA_EN) & ~RESET) | MODE_PA_DONT_CARE) &
                 (CON.UCODE_STATE1 | UCODE_PA_DONT_CARE) &
                 ((e39q2 ^ PROBE_LOW_PA_EN) & ~RESET) &
                 ~CLR_PERF_CNT;

  assign e72q3 = (e86q3 | CACHE_PA_DONT_CARE) &
                 CURRENT_PI_PA_EN &
                 (PA_EVENT_MODE | ~PERF_CNT_CLK) &
                 (CHAN_BUSY[0] | CHAN_BUSY[1] | CHAN_PA_DONT_CARE);

  assign e86q3 = EBOX_WAITING & CACHE_REF_PA_EN |
                 CSH.FILL_CACHE_RD & CACHE_FILL_PA_EN & EBOX_WAITING |
                 CSH.E_WRITEBACK & CACHE_EWB_PA_EN & EBOX_WAITING |
                 CSH.CCA_WRITEBACK & CACHE_SWB_PA_EN & EBOX_WAITING;

  assign e54q3 = ~PERF_CNT_CLK & CLR_PERF_CNT |
                 e58q3 & e72q3 & ~READ_PERF_CNT;

  bit e66Q;
  mux e66(.en(CHC.CBUS_READY),
          .sel(CRC.SEL),
          .d(CHAN_PA_EN),
          .q(e66Q));

  bit [2:3] unusedE71;
  UCR4 e71(.CIN(1'b1),
           .SEL({e66Q | |CHAN_BUSY[0:1], e66Q | RESET}),
           .CLK(MBOX.CH_T1),
           .D({4{e66Q}}),
           .COUT(),
           .Q({CHAN_BUSY, unusedE71}));


  // MTR5 p.328
  bit [0:7] e18D;
  assign DS = CTL.DIAG[4:6];

  msff6 e21ff(.clk(MBOX_CLK), .d(EBUS.data[18:23]), .q(mtrEBUS[18:23]));
  msff6 e50ff(.clk(MBOX_CLK), .d(EBUS.data[24:29]), .q(mtrEBUS[24:29]));
  msff6 e76ff(.clk(MBOX_CLK), .d(EBUS.data[30:35]), .q(mtrEBUS[30:35]));

  always_latch if (HOLD_INTERRUPT_SEL) e18D <= {TIME[2],
                                                PERF_COUNT[2],
                                                EBOX_COUNT[2],
                                                CACHE_COUNT[2],
                                                PIC.MTR_HONOR,
                                                3'b000};

  bit [1:2] unusedE37a;
  bit [5:6] unusedE37b;
  decoder e37(.en(READ_MTR),
              .sel(DS),
              .q({READ_TIME, READ_PERF_CNT, unusedE37a,
                  READ_INTERVAL, unusedE37b, HOLD_INTERRUPT_SEL}));

  priority_encoder8 e18(.d(e18D),
                        .q({VECTOR_REQ, INCR_SEL}),
                        .any(MTR.INTERRUPT_REQ));

  mux e23(.en(READ_MTR),
          .sel(DS),
          .d({TIME[2], PERF_COUNT[2], EBOX_COUNT[2], CACHE_COUNT[2],
              3'b000, VECTOR_REQ}),
          .q(mtrEBUS_IN[20]));

  mux e22(.en(READ_MTR),
          .sel(DS),
          .d({TIME[3], PERF_COUNT[3], EBOX_COUNT[3], CACHE_COUNT[3],
              1'b0, INTERVAL_ON, PI_ACCT_EN, INCR_SEL[0]}),
          .q(mtrEBUS_IN[21]));

  mux e17(.en(READ_MTR),
          .sel(DS),
          .d({TIME[4], PERF_COUNT[4], EBOX_COUNT[4], CACHE_COUNT[4],
              1'b0, INTERVAL_DONE, EXEC_ACCT_EN, INCR_SEL[1]}),
          .q(mtrEBUS_IN[22]));

  mux e13(.en(READ_MTR),
          .sel(DS),
          .d({TIME[5], PERF_COUNT[5], EBOX_COUNT[5], CACHE_COUNT[5],
              1'b0, INTERVAL_OVRFLO, ACCT_ON, 1'b0}),
          .q(mtrEBUS_IN[23]));

  mux e12(.en(READ_MTR),
          .sel(DS),
          .d({TIME[6], PERF_COUNT[6], EBOX_COUNT[6], CACHE_COUNT[6],
              INTERVAL[6], PERIOD[6], 2'b00}),
          .q(mtrEBUS_IN[24]));

  /* verilator lint_off CLKDATA */
  mux e32(.en(READ_MTR),
          .sel(DS),
          .d({TIME[7], PERF_COUNT[7], EBOX_COUNT[7], CACHE_COUNT[7],
              INTERVAL[7], PERIOD[7], TIME_ON, ~CONO_MTR}),
          .q(mtrEBUS_IN[25]));
  /* verilator lint_on CLKDATA */

  mux e27(.en(READ_MTR),
          .sel(DS),
          .d({TIME[8], PERF_COUNT[8], EBOX_COUNT[8], CACHE_COUNT[8],
              INTERVAL[8], PERIOD[8], 2'b00}),
          .q(mtrEBUS_IN[26]));

  mux e33(.en(READ_MTR),
          .sel(DS),
          .d({TIME[9], PERF_COUNT[9], EBOX_COUNT[9], CACHE_COUNT[9],
              INTERVAL[9], PERIOD[9], 2'b00}),
          .q(mtrEBUS_IN[27]));

  mux e73(.en(READ_MTR),
          .sel(DS),
          .d({TIME[10], PERF_COUNT[10], EBOX_COUNT[10], CACHE_COUNT[10],
              INTERVAL[10], PERIOD[10], 2'b00}),
          .q(mtrEBUS_IN[28]));

  mux e62(.en(READ_MTR),
          .sel(DS),
          .d({TIME[11], PERF_COUNT[11], EBOX_COUNT[11], CACHE_COUNT[11],
              INTERVAL[11], PERIOD[11], 2'b00}),
          .q(mtrEBUS_IN[29]));

  mux e68(.en(READ_MTR),
          .sel(DS),
          .d({TIME[12], PERF_COUNT[12], EBOX_COUNT[12], CACHE_COUNT[12],
              INTERVAL[12], PERIOD[12], 2'b00}),
          .q(mtrEBUS_IN[30]));

  mux e67(.en(READ_MTR),
          .sel(DS),
          .d({TIME[13], PERF_COUNT[13], EBOX_COUNT[13], CACHE_COUNT[13],
              INTERVAL[13], PERIOD[13], 2'b00}),
          .q(mtrEBUS_IN[31]));

  mux e77(.en(READ_MTR),
          .sel(DS),
          .d({TIME[14], PERF_COUNT[14], EBOX_COUNT[14], CACHE_COUNT[14],
              INTERVAL[14], PERIOD[14], 2'b00}),
          .q(mtrEBUS_IN[32]));

  mux e83(.en(READ_MTR),
          .sel(DS),
          .d({TIME[15], PERF_COUNT[15], EBOX_COUNT[15], CACHE_COUNT[15],
              INTERVAL[15], PERIOD[15], PIC.MTR_PIA[0], 1'b0}),
          .q(mtrEBUS_IN[33]));

  mux e79(.en(READ_MTR),
          .sel(DS),
          .d({TIME[16], PERF_COUNT[16], EBOX_COUNT[16], CACHE_COUNT[16],
              INTERVAL[16], PERIOD[16], PIC.MTR_PIA[1], 1'b0}),
          .q(mtrEBUS_IN[34]));

  mux e78(.en(READ_MTR),
          .sel(DS),
          .d({TIME[17], PERF_COUNT[17], EBOX_COUNT[17], CACHE_COUNT[17],
              INTERVAL[17], PERIOD[17], PIC.MTR_PIA[2], 1'b0}),
          .q(mtrEBUS_IN[35]));
endmodule


module MTRcounter
  #(N=2, M=17)
  (input bit clk,
   input bit clear,
   output bit carry);

  bit [N:M] count;
  always_ff @(posedge clk) if (clear) count <= 0;
                           else count <= count + 1;
endmodule
