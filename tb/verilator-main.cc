#include <cstdlib>
#include "Vtop.h"
#include "testbench.h"

vluint64_t main_time = 0;       // Current simulation time
// This is a 64-bit integer to reduce wrap over issues and
// allow modulus.  This is in units of the timeprecision
// used in Verilog (or from --timescale-override)

double sc_time_stamp () {       // Called by $time in Verilog
  return main_time;           // converts to double, to match
  // what SystemC does
}


int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);
  TESTBENCH<Vtop> *tb = new TESTBENCH<Vtop>();

  while (!tb->done()) {
    tb->tick();
  }

  exit(EXIT_SUCCESS);
}
