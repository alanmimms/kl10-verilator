`timescale 1ns/1ps
`include "ebox.svh"

module dte(iCLK CLK,
           iDTE DTE,
           iEBUS.dte EBUS,
           output bit CROBAR);


  import "DPI-C" function void DTEinitial();
  import "DPI-C" function void DTEfinal(input longint ns);
  import "DPI-C" function bit DTErequestIsPending();
  import "DPI-C" function void DTEgetRequest(output longint reqTime,
                                             output tReqType reqType,
                                             output tDiagFunction diagReq,
                                             output longint reqData);
  import "DPI-C" function void DTEreply(input longint t,
                                        input tReqType reqType,
                                        input tDiagFunction diagReq,
                                        input longint replyData);

  initial CROBAR = 1;

  bit clk;
  assign clk = CLK.MHZ16_FREE;

  var tReqType reqType;
  var tDiagFunction diagReq;
  var bit [0:35] reqData, replyData;

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
    DTEgetRequest(reqTime, reqType, diagReq, {28'b0, reqData});
    reqPending <= 1;
  end

  always @(posedge clk) if (reqPending && ticks >= reqTime) begin

    if (reqType == dteMisc) begin
      case (int'(diagReq))
      clrCROBAR: CROBAR <= 0;
      default: ;
      endcase

      DTEreply(ticks, reqType, diagReq, {28'b0, EBUS.data});
      reqPending <= 0;           // No longer waiting to do request
    end else if (reqType == dteWrite) begin
      EBUS.ds <= 7'(diagReq);
      EBUS.diagStrobe <= '1;

      DTE.EBUSdriver.driving <= 1;
      DTE.EBUSdriver.data <= 36'(reqData);

      DTEreply(ticks, reqType, diagReq, {28'b0, EBUS.data});
      reqPending <= 0;           // No longer waiting to do request
    end else if (reqType == dteDiagFunc) begin
      EBUS.ds <= 7'(diagReq);
      EBUS.diagStrobe <= 1;

      DTEreply(ticks, reqType, diagReq, {28'b0, EBUS.data});
      reqPending <= 0;           // No longer waiting to do request
    end else if (reqType == dteRead) begin
      DTEreply(ticks, reqType, diagReq, {28'b0, EBUS.data});
      reqPending <= 0;           // No longer waiting to do request
    end else if (reqType == dteReleaseEBUSData) begin
      DTE.EBUSdriver.driving <= 0;
      DTE.EBUSdriver.data <= '0;
      EBUS.diagStrobe <= 0;

      DTEreply(ticks, reqType, diagReq, {28'b0, EBUS.data});
      reqPending <= 0;           // No longer waiting to do request
    end
  end

  function string octW(input bit [0:35] w);
    $sformat(octW, "%06o,,%06o", w[0:17], w[18:35]);
  endfunction
endmodule
