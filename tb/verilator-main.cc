#include <cstdlib>
#include <iostream>
#include <verilated.h>
#include "Vtop.h"
#include "testbench.h"

TESTBENCH<Vtop> *tb;


double sc_time_stamp () {       // Called by $time in Verilog
  return tb->tickcount;
}


int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);
  tb = new TESTBENCH<Vtop>();
  Verilated::traceEverOn(true);
  Vtop *top = tb->mod;
  tb->opentrace("kl10pv-trace.vcd");
  top->CROBAR = 1;

  while (!tb->done) {
    top->CROBAR = tb->tickcount < 100000ull;
    if (tb->tick() > 1500000ull) break;

    if (tb->tickcount % 1000000ull == 0ull)
      std::cout << (tb->tickcount / 1000000ull) << "us" << std::endl;
  }

  exit(EXIT_SUCCESS);
}
