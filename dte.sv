module dte(input bit clk,
           input bit CROBAR,
           iDTE DTE,
           iEBUS.dte EBUS,
           iMBOX MBOX);

  import "DPI-C" function void DTEtick(input bit CROBAR,
                                       input longint tickCount);

  initial begin
  end

  final begin
  end

  always @(posedge clk) DTEtick(CROBAR, $time);
endmodule
