template<class MODULE> class TESTBENCH {
 public: unsigned long long tickcount;
 public: MODULE *mod;

  TESTBENCH(void) {
    mod = new MODULE();
    tickcount = 0ull;
  }

  virtual ~TESTBENCH(void) {
    delete mod;
    mod = NULL;
  }

  virtual void reset(void) {
    mod->CROBAR = 1;
    // Make sure any inheritance gets applied
    this->tick();
    mod->CROBAR = 0;
  }

  virtual unsigned long long tick(void) {
    // Increment our own internal time reference
    ++tickcount;

    // Make sure any combinatorial logic depending upon
    // inputs that may have changed before we called tick()
    // has settled before the rising edge of the clock.
    mod->clk = 0;
    mod->eval();

    // Toggle the clock

    // Rising edge
    mod->clk = 1;
    mod->eval();

    // Falling edge
    mod->clk = 0;
    mod->eval();

    return tickcount;
  }

  virtual bool done(void) { return (Verilated::gotFinish()); }
};
