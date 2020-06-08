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
  var tDiagFunction func;

  bit reqPending = 0;

  initial DTEinitial();
  final DTEfinal(dteTicks);

  always @(posedge clk) begin
    DTEtick(CROBAR, dteTicks);
    dteTicks <= dteTicks + 1;
  end


  always @(posedge clk) begin

    if (~reqPending) begin
      reqTime = DTEgetRequest(reqType, diagReq, {28'b0, reqData});

      if (reqTime != '1) $display($time, " DTE: DTEgetRequest got one ==========");

      // Remember we have a request already pending 
      if (reqTime < dteTicks) reqPending <= 1;
    end

    if (reqTime >= dteTicks) begin
      reqPending <= 0;          // No longer pending
      EBUS.ds <= 7'(diagReq);
      EBUS.diagStrobe <= '1;
      func = tDiagFunction'(diagReq);

      if (reqType == dteDiagWrite) begin
        DTE.EBUSdriver.driving <= 1;
        DTE.EBUSdriver.data <= 36'(reqData);
        $display($time, " DTE: %s write %s", func.name, octW(reqData));
      end else begin
        $display($time, " DTE: %s", func.name);
        DTE.EBUSdriver.driving <= 0;
        DTE.EBUSdriver.data <= '0;

        if (reqType == dteMisc) begin

          case (diagReq)
          clrCROBAR: begin CROBAR <= 0; $display($time, " DTE: clear CROBAR"); end
          default: ;
          endcase
        end
      end

      DTEreply(dteTicks, reqType, diagReq, {28'b0, EBUS.data});
    end
  end


  function string octW(input bit [0:35] w);
    $sformat(octW, "%06o,,%06o", w[0:17], w[18:35]);
  endfunction
endmodule
