`timescale 1ns/1ps
module dte(iCLK CLK,
           iDTE DTE,
           iEBUS.dte EBUS,
           output bit CROBAR);

  typedef enum {dteDiagFunc, dteDiagRead, dteDiagWrite, dteMisc} tFEReqType;
  typedef enum {clrCROBAR} tMiscFuncType;

  import "DPI-C" function void DTEtick(input bit CROBAR, input longint ns);
  import "DPI-C" function void DTEinitial();
  import "DPI-C" function void DTEfinal(input longint ns);
  import "DPI-C" function longint DTEgetRequest(output int reqType,
                                                output int diagReq,
                                                output longint reqData);
  import "DPI-C" function void DTEreply(input longint t,
                                        input int reqType,
                                        input int diagReq,
                                        input longint replyData);

  bit clk;
  assign clk = CLK.EBUS_CLK;

  var tFEReqType reqType;
  var int diagReq;
  var bit [0:35] reqData, replyData;
  var longint reqTime;

  var longint dteTicks = '0;     // 60ns tick counter

  initial DTEinitial();
  final DTEfinal(dteTicks);

  always @(posedge clk) begin
    DTEtick(CROBAR, dteTicks);
    dteTicks <= dteTicks + 1;
//    if (dteTicks % 100 == '0) $display($time, " dteTicks=%d", dteTicks);
  end


  always @(posedge clk) begin
    reqTime = DTEgetRequest(reqType, diagReq, {28'b0, reqData});

    if (reqTime >= dteTicks) begin
      EBUS.ds <= 7'(diagReq);
      EBUS.diagStrobe <= '1;

      if (reqType == dteDiagWrite) begin
        DTE.EBUSdriver.driving <= 1;
        DTE.EBUSdriver.data <= 36'(reqData);
      end else begin
        DTE.EBUSdriver.driving <= 0;
        DTE.EBUSdriver.data <= '0;

        if (reqType == dteMisc) begin

          case (diagReq)
          clrCROBAR: begin CROBAR <= 0; $display($time, " clear CROBAR"); end
          default: ;
          endcase
        end
      end

      DTEreply(dteTicks, reqType, diagReq, {28'b0, EBUS.data});
    end
  end
endmodule
