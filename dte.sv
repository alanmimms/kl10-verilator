`timescale 1ns/1ps
`include "ebox.svh"

module dte(iCLK CLK,
           iCRA CRA,
           iDTE DTE,
           iEBUS.dte EBUS,
           iEDP EDP,
           input bit [0:5] ucodeMajor,
           input bit [6:8] ucodeMinor,
           input bit [0:8] ucodeEdit,
           input bit [18:35] hwOptions,
           output bit CROBAR);


  import "DPI-C" function void DTEinitial();
  import "DPI-C" function void DTEfinal(input longint ns);
  import "DPI-C" function bit DTErequestIsPending();
  import "DPI-C" function void DTEgetRequest(output longint reqTime,
                                             output tReqType reqType,
                                             output tDiagFunction diagReq,
                                             output longint reqData1,
                                             output longint reqData2);
  import "DPI-C" function void DTEreply(input longint replyTime,
                                        input int replyLH,
                                        input int replyRH);

  initial CROBAR = 1;

  bit clk /*notverilator notclocker*/;
  assign clk = CLK.MHZ16_FREE;

  var tReqType reqType;
  var tDiagFunction diagReq;
  var longint reqData1, reqData2;

  var longint reqTime;
  initial reqTime = '0;

  var longint ticks;            // 16.667ns tick counter
  initial ticks = '0;

  bit reqPending;
  initial reqPending = 0;

  initial DTEinitial();
  final DTEfinal(ticks);

  always @(posedge clk) ticks <= ticks + 1;

  always @(posedge clk) if (DTErequestIsPending()) begin
    DTEgetRequest(reqTime, reqType, diagReq, reqData1, reqData2);
    reqPending <= 1;
  end

  var int lh;
  var int rh;

  always @(posedge clk) if (reqPending && ticks >= reqTime) begin

    if (reqType == dteMisc) begin

      case (int'(diagReq))
      clrCROBAR: CROBAR = 0;

      getAPRID: begin
        lh = 32'({ucodeMajor, ucodeMinor, ucodeEdit});
        rh = 32'(hwOptions);
      end
      
      // XXX fix these to use size of mem to adjust width of index.
      readMemory: begin
        lh = 32'(memory0.mem[18'(reqData1)][0:17]);
        rh = 32'(memory0.mem[18'(reqData1)][18:35]);
      end

      writeMemory: begin
        memory0.mem[18'(reqData1)] = 36'(reqData2);
        $display($time, " DTE: write mem[%09o]=%s", 22'(reqData1), octW(36'(reqData2)));
      end

      getDiagWord1: begin       // We don't bother being bit level compatible with DTE20
        lh = '0;
        rh = {30'b0, CON.RUN, CON.EBOX_HALTED};
      end

/*
      loadAR: EDP.AR = {reqData1[18:35], reqData2[18:35]};
      loadCRADR: CRA.CRADR = reqData1[25:35];
*/

      default: ;
      endcase

      DTEreply(ticks, lh, rh);
      reqPending <= 0;           // No longer waiting to do request
    end else if (reqType == dteWrite) begin
      EBUS.ds <= 7'(diagReq);
      EBUS.diagStrobe <= '1;

      DTE.EBUSdriver.driving <= 1;
      DTE.EBUSdriver.data <= 36'(reqData1);

      DTEreply(ticks, 32'(EBUS.data[0:17]), 32'(EBUS.data[18:35]));
      reqPending <= 0;           // No longer waiting to do request
    end else if (reqType == dteDiagFunc) begin
      EBUS.ds <= 7'(diagReq);
      EBUS.diagStrobe <= 1;

      DTEreply(ticks, 32'(EBUS.data[0:17]), 32'(EBUS.data[18:35]));
      reqPending <= 0;           // No longer waiting to do request
    end else if (reqType == dteRead) begin
      DTEreply(ticks, 32'(EBUS.data[0:17]), 32'(EBUS.data[18:35]));
      reqPending <= 0;           // No longer waiting to do request
    end else if (reqType == dteReleaseEBUSData) begin
      DTE.EBUSdriver.driving <= 0;
      DTE.EBUSdriver.data <= '0;
      EBUS.diagStrobe <= 0;

      DTEreply(ticks, 32'(EBUS.data[0:17]), 32'(EBUS.data[18:35]));
      reqPending <= 0;           // No longer waiting to do request
    end
  end

  function string octW(input bit [0:35] w);
    $sformat(octW, "%06o,,%06o", w[0:17], w[18:35]);
  endfunction
endmodule
