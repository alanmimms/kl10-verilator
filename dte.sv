module dte(input bit clk,
           input bit CROBAR,
           iDTE DTE,
           iEBUS.dte EBUS,
           iMBOX MBOX);

  typedef enum {dteDiagFunc, dteDiagRead, dteDiagWrite} tDTEReq;
  typedef bit [0:6] tDTEDiag;

  import "DPI-C" function void DTEtick(input bit CROBAR, input longint ns);
  import "DPI-C" function void DTEinitial();
  import "DPI-C" function void DTEfinal(input longint ns);
  import "DPI-C" function longint DTEgetRequest(output int reqType,
                                                output int diagReq,
                                                output longint reqData);
  import "DPI-C" function void DTEreply(input longint t,
                                        tDTEReq reqType,
                                        bit [0:35] replyData);

  var tDTEReq reqType;
  var tDTEDiag diagReq;
  var bit [0:35] reqData, replyData;

  initial DTEinitial();
  final DTEfinal($time);

  always @(posedge clk) DTEtick(CROBAR, $time / 1000);

  bit [3:0] state;

  initial state = '0;

  always @(posedge clk)
    if (DTEnextReqTime(reqType diagReq, reqData) == $time || state != '0) begin

    if (state == 4'h0) begin
      EBUS.ds <= diagReq;
      EBUS.diagStrobe <= '1;

      if (reqType == dteDiagWrite) begin
        DTE.EBUSdriver.driving <= 1;
        DTE.EBUSdriver.data <= reqData;
      end
    end else if (state == 4'h8) begin
      EBUS.ds <= diagfIdle;
      EBUS.diagStrobe <= '0;
      if (reqType == dteDiagRead) replyData <= EBUS.data;
    end else if (state == 4'hF) begin
      DTEreply($time, reqType, replyData);
    end

    state <= state + 1;
  end
endmodule
