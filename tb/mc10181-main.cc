#include "Vmc10181tb.h"
#include "verilated.h"
#define TRACECLASS      VerilatedVcdC
#include <verilated_vcd_c.h>


static unsigned long long ticks;
static const double nsPerClock = 1.0;


double sc_time_stamp () {       // Called by $time in Verilog
  return ticks * nsPerClock;
}

int main(int argc, char** argv, char** env) {
  Verilated::commandArgs(argc, argv);
  Vmc10181tb* top = new Vmc10181tb;

  Verilated::traceEverOn(true);
  TRACECLASS *trace = new TRACECLASS;
  top->trace(trace, 99);
  trace->dump(0);

  while (!Verilated::gotFinish()) {
    top->clk = 1;
    top->eval();

    top->clk = 0;
    top->eval();
  }

  delete top;
  exit(0);
}
