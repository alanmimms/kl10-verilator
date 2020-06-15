`timescale 1ns/1ps
`include "ebox.svh"

module top(input clk60);
  bit CROBAR;

  bit EXTERNAL_CLK, clk30, clk31;

  bit [27:35] MBOX_GATE_VMA;
  bit [10:12] CACHE_CLEARER;

  bit mboxClk;

  // TEMPORARY?
  bit PWR_WARN;

  // While it might appear with an EBOX-centric viewpoint that EBUS is
  // entirely contained within the EBOX and should therefore be muxed
  // in ebox.v, note that control of RH20 and DTE20 devices relies on
  // EBUS as well. (See KL10_BlockDiagrams_May76.pdf p.3.) Therefore
  // top.v is where the EBUS mux belongs.

  // This is the multiplexed EBUS, enabled by the tEBUSdriver from
  // each module to determine who gets to provide EBUS its content.
  iEBUS EBUS();

  iAPR APR();
  iCCL CCL();
  iCCW CCW();
  iCHA CHA();
  iCHC CHC();
  iCLK CLK();
  iCON CON();
  iCRA CRA();
  iCRAM CRAM();
  iCRC CRC();
  iCRM CRM();
  iCSH CSH();
  iCTL CTL();
  iDTE DTE();
  iEDP EDP();
  iIR IR();
  iMBC MBC();
  iMBX MBX();
  iMBZ MBZ();
  iMCL MCL();
  iMTR MTR();
  iPAG PAG();
  iPI PIC();
  iPMA PMA();
  iSCD SCD();
  iSHM SHM();
  iVMA VMA();

  iMBOX MBOX();
  iSBUS SBUS();

  bit [18:35] hwOptions = {1'b0,      // [18] 50Hz
                           1'b0,      // [19] Cache (XXX note this is ZERO for now)
                           1'b1,      // [20] Internal channels
                           1'b1,      // [21] Extended KL
                           1'b0,      // [22] Has master oscillator (not needed here)
                           13'd4012}; // [23:35] Serial number (octal 7654)

  bit masterClk;

  var string indent = "";
  var int nSteps;

  bit [0:5] ucodeMajor;
  bit [6:8] ucodeMinor;
  bit [0:8] ucodeEdit;

`ifdef VERILATOR

  initial clk30 = 0;
  initial clk31 = 0;
  always_ff @(posedge clk60) clk30 <= ~clk30;
  always_ff @(posedge clk60) clk31 <= ~clk31; // For Verilator 31MHz = 30MHz
  assign masterClk = clk30;
  assign EXTERNAL_CLK = clk30;

  tCRAM cram136, cram137;

  initial begin
    $readmemh("images/DRAM.mem", ebox0.ir0.dram.mem);
    $readmemh("images/CRAM.mem", ebox0.crm0.cram.mem);

    cram136 = ebox0.crm0.cram.mem['o136];
    cram137 = ebox0.crm0.cram.mem['o137];
    ucodeMajor = cram136.MAGIC[0:5];
    ucodeMinor = cram136.MAGIC[6:8];
    ucodeEdit  = cram137.MAGIC[0:8];

    // Initialize our memories
    // Based on KLINIT.L20 $ZERAC subroutine.
    // Zero all ACs, including the ones in block #7 (microcode's ACs).
    // For now, MBOX memory is zero too.
    for (int a = 0; a < $size(ebox0.edp0.fm.mem); ++a) ebox0.edp0.fm.mem[a] = '0;
    for (int a = 0; a < $size(memory0.mem); ++a) memory0.mem[a] = '0;
  end
`endif

  ebox ebox0(.*);
  mbox mbox0(.SBUS(SBUS.mbox), .*);
  memory memory0(.SBUS(SBUS.memory), .*);
  dte dte0(.*);

  // Mux for EBUS data lines
  always_comb unique case (1'b1)
              default: EBUS.data = '0;
              APR.EBUSdriver.driving: EBUS.data = APR.EBUSdriver.data;
              CON.EBUSdriver.driving: EBUS.data = CON.EBUSdriver.data;
              CRA.EBUSdriver.driving: EBUS.data = CRA.EBUSdriver.data;
              CTL.EBUSdriver.driving: EBUS.data = CTL.EBUSdriver.data;
              DTE.EBUSdriver.driving: EBUS.data = DTE.EBUSdriver.data;
              EDP.EBUSdriver.driving: EBUS.data = EDP.EBUSdriver.data;
              IR.EBUSdriver.driving:  EBUS.data =  IR.EBUSdriver.data;
              MBZ.EBUSdriver.driving: EBUS.data = MBZ.EBUSdriver.data;
              MTR.EBUSdriver.driving: EBUS.data = MTR.EBUSdriver.data;
              PIC.EBUSdriver.driving: EBUS.data = PIC.EBUSdriver.data;
              SCD.EBUSdriver.driving: EBUS.data = SCD.EBUSdriver.data;
              SHM.EBUSdriver.driving: EBUS.data = SHM.EBUSdriver.data;
              VMA.EBUSdriver.driving: EBUS.data = VMA.EBUSdriver.data;
              endcase
endmodule
