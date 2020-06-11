#include <cstdlib>
#include <iostream>
#include <signal.h>

#include <verilated.h>
#include "Vtop.h"

#define TRACECLASS      VerilatedVcdC
#include <verilated_vcd_c.h>


// Probably we are building 64-bit anyway, but this emphasizes the
// point. These are 64-bit typedefs.
typedef unsigned long long W36;
typedef long long LL;           /* For ticks values from Verilator */


template<class MODULE> class TESTBENCH {
public: vluint64_t tickcount;
public: MODULE *mod;
public: TRACECLASS *trace;
public: bool done;
public: double nsPerClock;

  TESTBENCH(void) {
    mod = new MODULE();
    tickcount = 0ll;
    trace = (TRACECLASS *) 0;
    done = false;
    nsPerClock = 1.0e9/60.0e6; // 60MHz clock
  }

  virtual ~TESTBENCH(void) {
    if (trace) trace->close();
    delete mod;
    mod = NULL;
  }

  virtual void opentrace(const char *vcdName) {
    trace = new TRACECLASS;
    mod->trace(trace, 99);
    trace->spTrace()->set_time_resolution("ns");
    trace->spTrace()->set_time_unit("ns");
    trace->open(vcdName);
    trace->dump(0);
  }

  virtual vluint64_t tick(void) {
    // Toggle the clock
    // Rising edge
    mod->clk = 1;
    mod->eval();
    if (trace) trace->dump(tickcount * nsPerClock);

    // Falling edge
    mod->clk = 0;
    mod->eval();
    if (trace) trace->dump(((double) tickcount + 0.5) * nsPerClock);

    if (Verilated::gotFinish()) done = true;
    return ++tickcount;
  }
};


TESTBENCH<Vtop> *tb;


double sc_time_stamp () {       // Called by $time in Verilog
  return tb->tickcount * tb->nsPerClock;
}


static LL waitingForTicks = 0ll;


extern "C" void FEinitial(double nsPerClock);
extern "C" void FEfinal(LL ns);


void DTEinitial() {
  FEinitial(tb->nsPerClock);
}


void DTEfinal(LL ns) {
  FEfinal(ns);
}


static const double endTime = 1.5 * 1000 * 1000 * 1000; // 1.5 seconds


int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);
  tb = new TESTBENCH<Vtop>();
  Verilated::traceEverOn(true);
  Vtop *top = tb->mod;

  tb->opentrace("kl10pv-trace.vcd");

  while (!tb->done) {
    LL ticks = tb->tick();
    double ns = ticks * tb->nsPerClock;

    if (ns >= endTime) break;

    if ((LL) ns % 1000000 == 0)
      std::cout << (ns/1000) << "us" << std::endl;
  }

  exit(EXIT_SUCCESS);
}
