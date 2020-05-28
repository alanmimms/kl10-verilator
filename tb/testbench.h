#include <verilated_vcd_c.h>
#define TRACECLASS      VerilatedVcdC


template<class MODULE> class TESTBENCH {
public: vluint64_t tickcount;
public: MODULE *mod;
public: TRACECLASS *trace;
public: bool done;

  TESTBENCH(void) {
    mod = new MODULE();
    tickcount = 0ull;
    trace = (TRACECLASS *) 0;
    done = false;
  }

  virtual ~TESTBENCH(void) {
    if (trace) trace->close();
    delete mod;
    mod = NULL;
  }

  virtual void reset(void) {
    mod->CROBAR = 1;
    // Make sure any inheritance gets applied
    this->tick();
    mod->CROBAR = 0;
  }

  virtual void opentrace(const char *vcdName) {
      trace = new TRACECLASS;
      mod->trace(trace, 99);
      trace->spTrace()->set_time_resolution("ps");
      trace->spTrace()->set_time_unit("ps");
      trace->open(vcdName);
  }

  virtual vluint64_t tick(void) {
    // Make sure any combinatorial logic depending upon
    // inputs that may have changed before we called tick()
    // has settled before the rising edge of the clock.
    mod->clk = 0;
    mod->eval();

    // Toggle the clock
    // Rising edge
    mod->clk = 1;
    ++tickcount;
    mod->eval();

    // Falling edge
    mod->clk = 0;
    ++tickcount;
    mod->eval();
    if (trace) trace->dump(tickcount);

    if (Verilated::gotFinish()) done = true;
    return tickcount;
  }
};
