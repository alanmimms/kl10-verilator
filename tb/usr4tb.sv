`timescale 1ns/1ps
module usr4tb(input bit clk);
  bit [0:3] Q, D, sb;
  bit S0, S3, CLK;
  bit [31:0] state;

  enum bit [0:1] {
                  selLOAD = 2'b00,
                  selS0in = 2'b01,
                  selS3in = 2'b10,
                  selHOLD = 2'b11
                  } SEL;

  USR4 sr(.*);

  assign CLK = clk;

  always @(posedge clk) begin
    state <= state + 1;

    case (state)
    'h000: begin                // Initialization
      $display($time, " [Start USR4 test bench]");

      S0 <= 0;
      S3 <= 0;
      D <= '0;
      SEL <= selLOAD;
    end

    'h001: begin
      $display($time, " load 1010");
      sb <= 4'b1010;
      D <= sb;
    end
    'h002: $display($time, " Q=%04b sb=%04b", Q, sb);
    'h003: $display($time, " Q=%04b sb=%04b", Q, sb);

    'hFFF: $finish;
    endcase
  end
endmodule
