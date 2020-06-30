`timescale 1ns/1ps
`include "ebox.svh"
module edptb(input clk);

  iAPR APR();
  iCLK CLK();
  iCON CON();
  iCTL CTL();
  iDTE DTE();
  iEDP EDP();
  iIR  IR();
  iPI  PIC();
  iSCD SCD();
  iSHM SHM();
  iVMA VMA();

  iEBUS EBUS();
  iMBOX MBOX();

  iCRAM CRAM();

  bit [18:35] hwOptions = {1'b0,      // [18] 50Hz
                           1'b0,      // [19] Cache (XXX note this is ZERO for now)
                           1'b1,      // [20] Internal channels
                           1'b1,      // [21] Extended KL
                           1'b0,      // [22] Has master oscillator (not needed here)
                           13'd4001}; // [23:35] Serial number

  bit [0:35] sb;
  bit [17:0] state;
  initial state = '0;
  
  edp edp0(.*);

  bit [0:3] s1, a1, b1, f1;
  bit m1, cin1, cg1, cp1, cout1;
  bit [-1:3] result1, sb1;

  assign a1 = 4'(state[3:0]);
  assign b1 = 4'(state[7:4]);
  assign cin1 = 1'(state[8]);
  assign m1 = 0;
  assign s1 = 4'h3;
  assign result1 = {cout1, f1};

  mc10181 alu1(.S(s1), .M(m1), .A(a1), .B(b1), .CIN(cin1), .F(f1), .CG(cg1), .CP(cp1), .COUT(cout1));

  always @(posedge clk) state <= state + 1;

  assign CLK.EDP = clk;

  // Mock CTL
  assign CTL.ARL_SEL = CRAM.AR;
  assign CTL.AD_CRY_36 = CRAM.AD[0];

  always @(posedge clk) begin
    case (state)
    18'o00: begin                // Initialization
      $display($time, " [Start EDP test bench]");

      CTL.ADX_CRY_36 <= 0;

      CTL.AR00to11_CLR <= 0;
      CTL.AR12to17_CLR <= 0;
      CTL.ARR_CLR <= 0;

      CTL.ARXL_SEL <= 0;
      CTL.ARXR_SEL <= 0;
      CTL.ARX_LOAD <= 0;

      CTL.MQ_SEL <= 0;
      CTL.MQM_SEL <= 0;
      CTL.MQM_EN <= 0;

      CTL.INH_CRY_18 <= 0;
      CTL.SPEC_GEN_CRY_18 <= 0;

      CTL.AD_TO_EBUS_L <= 0;
      CTL.AD_TO_EBUS_R <= 0;

      EBUS.data <= 0;

      SHM.SH <= 0;

      CRAM.FMADR <= fmadrAC0;
      APR.FM_BLOCK <= 0;           // Select a good block number
      APR.FM_ADR <= 7;             // And a good FM AC #

      CON.FM_WRITE00_17 <= 0;      // No writing to FM
      CON.FM_WRITE18_35 <= 0;

      EDP.ARMM_SCD <= 0;
      EDP.ARMM_VMA <= 0;

      VMA.HELD_OR_PC <= 0;         // Reset PC for now
    end

    // Load AR with 123456789
    18'o01: begin
      $display($time, " set AR=h555555555");
      sb = 36'h555555555;
      MBOX.CACHE_DATA[0:35] <= 36'h555555555;
      CRAM.AR <= arCACHE;
      CTL.AR00to08_LOAD <= 1;
      CTL.AR09to17_LOAD <= 1;
      CTL.ARR_LOAD <= 1;
      CRAM.BR <= brRECIRC;
      CRAM.ARX <= arxARX;
      CRAM.BRX <= brxRECIRC;
    end
    18'o02: begin
      CTL.AR00to08_LOAD <= 0;
      CTL.AR09to17_LOAD <= 0;
      CTL.ARR_LOAD <= 0;
    end
    
    18'o04: $display($time, " AR=h%09X SB=h%09X", EDP.AR[0:35], sb);

    // Try AD/A first
    18'o10: begin
      sb = 36'h123456789;
      MBOX.CACHE_DATA[0:35] <= 36'h123456789;
      CRAM.AR <= arCACHE;
      CTL.AR00to08_LOAD <= 1;
      CTL.AR09to17_LOAD <= 1;
      CTL.ARR_LOAD <= 1;
      CRAM.AD <= adA;
      CRAM.ADA <= adaAR;
      CRAM.BR <= brRECIRC;
      CRAM.ARX <= arxARX;
      CRAM.BRX <= brxRECIRC;
    end
    
    18'o11: begin
      $display($time, " result: AD/A, ADA/AR, AR/AR AD=h%09x SB=h%09X", EDP.AD[-2:35], sb);
      CTL.AR00to08_LOAD <= 0;
      CTL.AR09to17_LOAD <= 0;
      CTL.ARR_LOAD <= 0;
    end

    // Load BR with 987654321
    18'o20: begin
      $display($time, " set BR=h987654321");
      sb = 36'h987654321;
      MBOX.CACHE_DATA[0:35] <= 36'h987654321;
      CRAM.AR <= arCACHE;
      CTL.AR00to08_LOAD <= 1;
      CTL.AR09to17_LOAD <= 1;
      CTL.ARR_LOAD <= 1;
    end
    18'o21: begin
      CTL.AR00to08_LOAD <= 0;
      CTL.AR09to17_LOAD <= 0;
      CTL.ARR_LOAD <= 0;
      CRAM.BR <= brAR;
      CRAM.ARX <= arxARX;
      CRAM.BRX <= brxRECIRC;
    end
    18'o22: begin
      $display($time, " BR=h%09X SB=h%09X", EDP.BR[0:35], sb);
      CRAM.BR <= brRECIRC;
    end
    
    // Try AD/B
    18'o30: begin
      $display($time, " try AD/B AR=%09X BR=%09X SB=h%09X", EDP.AR, EDP.BR, sb);
      sb = 36'h987654321;
      CRAM.AD <= adB;
      CRAM.ADA <= adaAR;
      CRAM.ADB <= adbBR;
      CRAM.AR <= arAD;
      CTL.AR00to08_LOAD <= 1;
      CTL.AR09to17_LOAD <= 1;
      CTL.ARR_LOAD <= 1;
      CRAM.BR <= brRECIRC;
      CRAM.ARX <= arxARX;
      CRAM.BRX <= brxRECIRC;
    end
    
    18'o31: $display($time, " result: AD/B, ADA/AR, ADB/BR AD=h%09x SB=h%09X", EDP.AD[-2:35], sb);

    // Try AD/A+B
    18'o40: begin
      $display($time, " try AD/A+B AR=%09X BR=%09X SB=h%09X", EDP.AR, EDP.BR, sb);
      sb = 36'hAAAAAAAAA;
      CRAM.AD <= adAplusB;
      CRAM.ADA <= adaAR;
      CRAM.ADB <= adbBR;
      MBOX.CACHE_DATA[0:35] <= 36'h123456789;
      CRAM.AR <= arCACHE;
      CTL.AR00to08_LOAD <= 1;
      CTL.AR09to17_LOAD <= 1;
      CTL.ARR_LOAD <= 1;
      CRAM.BR <= brRECIRC;
      CRAM.ARX <= arxARX;
      CRAM.BRX <= brxRECIRC;
    end
    
    18'o41: $display($time, " result: AD/A+B, ADA/AR, ADB/BR AD=h%09x SB=h%09X", EDP.AD[-2:35], sb);

    // Try AD/ORCB+1
    // TODO: LH of AD is wrong
    18'o47: begin
      MBOX.CACHE_DATA[0:35] <= 36'o007757777;
      CRAM.AR <= arCACHE;
      CTL.AR00to08_LOAD <= 1;
      CTL.AR09to17_LOAD <= 1;
      CTL.ARR_LOAD <= 1;
    end

    18'o50: begin
      $display($time, " try AD/ORCB+1 AR=%09X BR=%09X SB=h%09X", EDP.AR, EDP.BR, sb);
      sb = 36'hFFFFFFFF;
      CRAM.AD <= adORCBplus1;
      CRAM.ADA <= adaAR;
      CRAM.ADB <= adbBR;
      MBOX.CACHE_DATA[0:35] <= 36'o007757777;
      CRAM.AR <= arCACHE;
      CTL.AR00to08_LOAD <= 0;
      CTL.AR09to17_LOAD <= 0;
      CTL.ARR_LOAD <= 0;
      CRAM.BR <= brAR;
      CRAM.ARX <= arxARX;
      CRAM.BRX <= brxRECIRC;
    end
    
    18'o51: $display($time, " result: AD/ORCB+1, ADA/AR, ADB/BR AD=h%09x SB=h%09X", EDP.AD[-2:35], sb);

    // Try AD/Ax2
    18'o57: begin
      MBOX.CACHE_DATA[0:35] <= 36'h123456789;
      CRAM.AR <= arCACHE;
      CTL.AR00to08_LOAD <= 1;
      CTL.AR09to17_LOAD <= 1;
      CTL.ARR_LOAD <= 1;
    end

    18'o60: begin
      $display($time, " try AD/Ax2 AR=%09X BR=%09X SB=h%09X", EDP.AR, EDP.BR, sb);
      sb = 36'h2468ACF12;
      CRAM.AD <= adAx2;
      CRAM.ADA <= adaAR;
      CRAM.ADB <= adbBR;
      CRAM.AR <= arAR;
      CTL.AR00to08_LOAD <= 0;
      CTL.AR09to17_LOAD <= 0;
      CTL.ARR_LOAD <= 0;
      CRAM.BR <= brAR;
      CRAM.ARX <= arxARX;
      CRAM.BRX <= brxRECIRC;
    end
    
    18'o61: $display($time, " result: AD/Ax2, ADA/AR, ADB/BR AD=h%09x SB=h%09X", EDP.AD[-2:35], sb);

    // Try overflow
    18'o67: begin
      MBOX.CACHE_DATA[0:35] <= 36'hFFFFFFFFF;
      CRAM.AR <= arCACHE;
      CTL.AR00to08_LOAD <= 1;
      CTL.AR09to17_LOAD <= 1;
      CTL.ARR_LOAD <= 1;
    end

    18'o70: begin
      $display($time, " try overflow AD/A+1 AR=%09X BR=%09X SB=h%09X", EDP.AR, EDP.BR, sb);
      sb = 36'h000000000;
      CRAM.AD <= adAplus1;
      CRAM.ADA <= adaAR;
      CRAM.ADB <= adbBR;
      CRAM.AR <= arCACHE;
      CTL.AR00to08_LOAD <= 1;
      CTL.AR09to17_LOAD <= 1;
      CTL.ARR_LOAD <= 1;
      CRAM.BR <= brAR;
      CRAM.ARX <= arxARX;
      CRAM.BRX <= brxRECIRC;
    end
    
    18'o71: $display($time, " result: AD/A+1, ADA/AR, ADB/BR AD=h%09x SB=h%09X", EDP.AD[-2:35], sb);

    // Try every value of A and B for S=3 (A*2) with CIN and COUT.
    default: begin
      sb1 = {1'b0, a1} * 5'h2 + 5'(cin1);
      if (result1 != sb1) $display(" MISMATCH: %0b*2 was %0b sb %0b", a1, result1, sb1);
    end

    18'o002001: $finish;

    endcase
  end
endmodule
