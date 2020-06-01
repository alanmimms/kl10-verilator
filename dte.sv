module dte(input bit clk,
           input bit CROBAR,
           iDTE DTE,
           iEBUS.dte EBUS,
           iMBOX MBOX);

  import "DPI-C" function void DTEtick(input bit CROBAR,
                                       input longint ns);

  initial begin
    $display($time, " starting");

    repeat (100) begin
      @(negedge clk) ;
    end

    $display($time, " 100 clocks later");
  end

  final begin
  end

  always @(posedge clk) DTEtick(CROBAR, $time / 1000);
endmodule
