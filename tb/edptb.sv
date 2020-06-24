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

  edp edp0(.*);

  bit [0:35] sb;
  bit [5:0] state;
  initial state = '0;
  
  always @(posedge clk) state <= state + 1;

  assign CLK.EDP = clk;

  // Mock CTL
  assign CTL.ARL_SEL = CRAM.AR;
  assign CTL.AD_CRY_36 = CRAM.AD[0];

  always @(posedge clk) begin
    unique case (state)
    6'o00: begin                // Initialization
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
    6'o01: begin
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
    6'o02: begin
      CTL.AR00to08_LOAD <= 0;
      CTL.AR09to17_LOAD <= 0;
      CTL.ARR_LOAD <= 0;
    end
    
    6'o04: $display($time, " AR=h%09X SB=h%09X", EDP.AR[0:35], sb);

    // Try AD/A first
    6'o10: begin
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
    
    6'o11: begin
      $display($time, " result: AD/A, ADA/AR, AR/AR AD=h%09x SB=h%09X", EDP.AD[-2:35], sb);
      CTL.AR00to08_LOAD <= 0;
      CTL.AR09to17_LOAD <= 0;
      CTL.ARR_LOAD <= 0;
    end

    // Load BR with 987654321
    6'o20: begin
      $display($time, " set BR=h987654321");
      sb = 36'h987654321;
      MBOX.CACHE_DATA[0:35] <= 36'h987654321;
      CRAM.AR <= arCACHE;
      CTL.AR00to08_LOAD <= 1;
      CTL.AR09to17_LOAD <= 1;
      CTL.ARR_LOAD <= 1;
    end
    6'o21: begin
      CTL.AR00to08_LOAD <= 0;
      CTL.AR09to17_LOAD <= 0;
      CTL.ARR_LOAD <= 0;
      CRAM.BR <= brAR;
      CRAM.ARX <= arxARX;
      CRAM.BRX <= brxRECIRC;
    end
    6'o22: begin
      $display($time, " BR=h%09X SB=h%09X", EDP.BR[0:35], sb);
      CRAM.BR <= brRECIRC;
    end
    
    // Try AD/B
    6'o30: begin
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
    
    6'o31: $display($time, " result: AD/B, ADA/AR, ADB/BR AD=h%09x SB=h%09X", EDP.AD[-2:35], sb);

    // Try AD/A+B
    6'o40: begin
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
    
    6'o41: $display($time, " result: AD/A+B, ADA/AR, ADB/BR AD=h%09x SB=h%09X", EDP.AD[-2:35], sb);

    // Try AD/ORCB+1
    6'o47: begin
      MBOX.CACHE_DATA[0:35] <= 36'o007757777;
      CRAM.AR <= arCACHE;
      CTL.AR00to08_LOAD <= 1;
      CTL.AR09to17_LOAD <= 1;
      CTL.ARR_LOAD <= 1;
    end

    6'o50: begin
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
    
    6'o51: $display($time, " result: AD/ORCB+1, ADA/AR, ADB/BR AD=h%09x SB=h%09X", EDP.AD[-2:35], sb);

    // Try AD/Ax2
    6'o57: begin
      MBOX.CACHE_DATA[0:35] <= 36'h123456789;
      CRAM.AR <= arCACHE;
      CTL.AR00to08_LOAD <= 1;
      CTL.AR09to17_LOAD <= 1;
      CTL.ARR_LOAD <= 1;
    end

    6'o60: begin
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
    
    6'o61: $display($time, " result: AD/Ax2, ADA/AR, ADB/BR AD=h%09x SB=h%09X", EDP.AD[-2:35], sb);

    6'o77: $finish;
    default: ;
    endcase
  end
endmodule
