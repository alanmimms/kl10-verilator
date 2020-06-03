module dte(input bit clk,
           input bit CROBAR,
           iDTE DTE,
           iEBUS.dte EBUS,
           iMBOX MBOX);

  import "DPI-C" function void DTEtick(input bit CROBAR, input longint ns);
  import "DPI-C" function void DTEinitial();
  import "DPI-C" function void DTEfinal();

  initial DTEinitial();
  final DTEfinal();

  always @(posedge clk) DTEtick(CROBAR, $time / 1000);
endmodule
