#include "Vusr4tb.h"
#include "verilated.h"
#define TRACECLASS      VerilatedVcdC
#include <verilated_vcd_c.h>


static unsigned long long ticks;
static const double nsPerClock = 10.0;


double sc_time_stamp () {       // Called by $time in Verilog
  return ticks * nsPerClock;
}


int main(int argc, char** argv, char** env) {
  Verilated::commandArgs(argc, argv);
  Vusr4tb* top = new Vusr4tb;

  Verilated::traceEverOn(true);
  TRACECLASS *trace = new TRACECLASS;
  top->trace(trace, 99);
  trace->spTrace()->set_time_resolution("ns");
  trace->spTrace()->set_time_unit("ns");
  trace->open("usr4tb.vcd");

  while (!Verilated::gotFinish()) {
    top->clk = 1;
    top->eval();
    trace->dump(sc_time_stamp());

    top->clk = 0;
    top->eval();
    trace->dump(sc_time_stamp() + nsPerClock/2.0);
    ++ticks;
  }

  trace->close();
  delete top;
  exit(0);
}
