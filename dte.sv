module dte(input bit clk,
           output bit CROBAR,
           iDTE DTE,
           iEBUS.dte EBUS,
           iMBOX MBOX);

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

  var tFEReqType reqType;
  var int diagReq;
  var bit [0:35] reqData, replyData;
  var longint reqTime;

  initial DTEinitial();
  final DTEfinal($time);

  always @(posedge clk) DTEtick(CROBAR, $time / 1000);

  always @(posedge clk) begin
    reqTime = DTEgetRequest(reqType, diagReq, {28'b0, reqData});

    if (reqTime == '0 || reqTime == $time) begin
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
          clrCROBAR: CROBAR <= 0;
          default: ;
          endcase
        end
      end

      DTEreply($time, reqType, diagReq, {28'b0, EBUS.data});
    end
  end
endmodule
