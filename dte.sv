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

  bit clk;
  assign clk = CLK.EBUS_CLK;

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

  always @(posedge reqPending, negedge reqPending)
    $display("D %0d reqPending=%0d", ticks, reqPending);

  always @(posedge clk) ticks <= ticks + 1;
  always @(posedge clk) if (reqPending) $display("D ticks=%0d reqTime=%0d", ticks, reqTime);

  always @(posedge clk) if (DTErequestIsPending()) begin
    DTEgetRequest(reqTime, reqType, diagReq, {28'b0, reqData});
    $display("D %0d: DTEgetRequest %s/%s at %0d ==========",
             ticks, reqType.name, diagReq.name, reqTime);
    reqPending <= 1;
  end

  always @(posedge clk) if (reqPending && ticks >= reqTime && reqType == dteMisc) begin

    case (int'(diagReq))
    clrCROBAR: CROBAR <= 0;
    default: ;
    endcase

    DTEreply(ticks, reqType, diagReq, {28'b0, EBUS.data});
    $display("D %0d: clear reqPending", ticks);
    reqPending <= 0;           // No longer waiting to do request
  end

  always @(posedge clk) if (reqPending && ticks >= reqTime && reqType == dteWrite) begin
    EBUS.ds <= 7'(diagReq);
    EBUS.diagStrobe <= '1;

    DTE.EBUSdriver.driving <= 1;
    DTE.EBUSdriver.data <= 36'(reqData);
    $display("D %0d: %s %s", ticks, diagReq.name, octW(reqData));

    DTEreply(ticks, reqType, diagReq, {28'b0, EBUS.data});
    $display("D %0d: clear reqPending", ticks);
    reqPending <= 0;           // No longer waiting to do request
  end

  always @(posedge clk) if (reqPending && ticks >= reqTime && reqType == dteDiagFunc) begin
    EBUS.ds <= 7'(diagReq);
    EBUS.diagStrobe <= '1;

    DTEreply(ticks, reqType, diagReq, {28'b0, EBUS.data});
    $display("D %0d: clear reqPending", ticks);
    reqPending <= 0;           // No longer waiting to do request
  end

  always @(posedge clk) if (reqPending && ticks >= reqTime && reqType == dteRead) begin
    $display("D %0d: %s", ticks, diagReq.name);

    DTEreply(ticks, reqType, diagReq, {28'b0, EBUS.data});
    $display("D %0d: clear reqPending", ticks);
    reqPending <= 0;           // No longer waiting to do request
  end

  always @(posedge clk) if (reqPending && ticks >= reqTime && reqType == dteReleaseEBUSData) begin
    $display("D %0d: %s", ticks, diagReq.name);
    DTE.EBUSdriver.driving <= 0;
    DTE.EBUSdriver.data <= '0;

    DTEreply(ticks, reqType, diagReq, {28'b0, EBUS.data});
    $display("D %0d: clear reqPending", ticks);
    reqPending <= 0;           // No longer waiting to do request
  end

  function string octW(input bit [0:35] w);
    $sformat(octW, "%06o,,%06o", w[0:17], w[18:35]);
  endfunction
endmodule
