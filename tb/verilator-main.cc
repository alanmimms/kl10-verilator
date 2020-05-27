#include <stdlib.h>
#include "verilated.h"
#include "Vtop.h"
#include <iostream>

Vtop *topP;
vluint64_t MainTime = 0;


int main(int argc, char **argv) {
  // Initialize Verilators variables
  Verilated::commandArgs(argc, argv);

  topP = new Vtop;              // Create top module instance
  topP->CROBAR = 1;             // Assert CROBAR at beginning of time

  // Create an instance of our module under test
  Vmodule *tb = new Vmodule;

  // Tick the clock until we are done
  while (!Verilated::gotFinish()) {
    topP->clk = tb->i_clk = 1;
    tb->eval();
    topP->clk = tb->i_clk = 0;
    tb->eval();
  }

  exit(EXIT_SUCCESS);
}
