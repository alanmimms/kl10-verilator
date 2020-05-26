`timescale 1ns/1ps
`include "ebox.svh"

module dte(input bit clk,
           input bit CROBAR,
           iDTE DTE);

  assign DTE.CLK = clk;
endmodule
