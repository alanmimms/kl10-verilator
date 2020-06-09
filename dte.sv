`timescale 1ns/1ps
module dte(iCLK CLK,
           iDTE DTE,
           iEBUS.dte EBUS,
           output bit CROBAR);

  typedef enum {dteNone,
                dteDiagFunc,
                dteDiagRead,
                dteDiagWrite,
                dteReleaseEBUSData,
                dteMisc} tFEReqType;

  typedef enum {clrCROBAR} tMiscFuncType;

  import "DPI-C" function void DTEinitial();
  import "DPI-C" function void DTEfinal(input longint ns);
  import "DPI-C" function bit DTErequestIsPending();
  import "DPI-C" function void DTEgetRequest(output longint reqTime,
                                             output int reqType,
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
  initial reqTime = '0;

  var longint ticks = '0;     // 60ns tick counter
  var tDiagFunction func;

  var enum {stIdle, stPending} state = stIdle;
  initial state = stIdle;

  initial DTEinitial();
  final DTEfinal(ticks);

  always @(posedge clk) begin

    if (state == stIdle) begin

      if (DTErequestIsPending()) begin
        DTEgetRequest(reqTime, reqType, diagReq, {28'b0, reqData});
//        $display("%8d DTE: DTEgetRequest req ticks %0d ==========", ticks, reqTime);
        state <= stPending;
      end
    end

    ticks <= ticks + 1;
//    $display("%8d DTE: ticks=%0d reqTime=%0d", ticks, ticks, reqTime);

    if (ticks >= reqTime) begin
      state <= stIdle;

      if (reqType == dteMisc) begin

        case (diagReq)
        clrCROBAR: CROBAR <= 0;
        default: ;
        endcase
      end else if (reqType == dteDiagWrite || reqType == dteDiagFunc) begin
        EBUS.ds <= 7'(diagReq);
        EBUS.diagStrobe <= '1;
        func = tDiagFunction'(diagReq);

        if (reqType == dteDiagWrite) begin
          DTE.EBUSdriver.driving <= 1;
          DTE.EBUSdriver.data <= 36'(reqData);
//          $display("%8d DTE: %s %s", ticks, func.name, octW(reqData));
        end else begin          // Simply diagnostic function
//          $display("%8d DTE: %s", ticks, func.name);
        end
      end else if (reqType == dteDiagRead) begin
//          $display("%8d DTE: %s", ticks, func.name);
        // We always include EBUS.data in our reply
      end else if (reqType == dteReleaseEBUSData) begin
//        $display("%8d DTE: %s", ticks, func.name);
        DTE.EBUSdriver.driving <= 0;
        DTE.EBUSdriver.data <= '0;
      end else $display("%8d DTE: reqType=%0d is not one we know how to do", ticks, reqType);

      DTEreply(ticks, reqType, diagReq, {28'b0, EBUS.data});
    end
  end

  always @(posedge clk) begin
  end


  function string octW(input bit [0:35] w);
    $sformat(octW, "%06o,,%06o", w[0:17], w[18:35]);
  endfunction
endmodule
