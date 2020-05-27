#include <cstdlib>
#include <iostream>
#include "Vtop.h"
#include "testbench.h"

TESTBENCH<Vtop> *tb;


double sc_time_stamp () {       // Called by $time in Verilog
  return tb->tickcount;
}


int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);
  tb = new TESTBENCH<Vtop>();
  Vtop *top = tb->mod;
  top->CROBAR = 1;

  while (!tb->done()) {
    top->CROBAR = tb->tickcount < 100000ull;
    tb->tick();

    if (tb->tickcount % 1000000ull == 0ull)
      std::cout << (tb->tickcount / 1000000ull) << "us" << std::endl;
  }

  exit(EXIT_SUCCESS);
}
