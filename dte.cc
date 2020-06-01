#include <svdpi.h>
#include <iostream>

#ifdef __cplusplus
extern "C" {
#endif

typedef long long LL;

#ifdef notdef
// A TimedHandler is a lambda function that executes at a specific
// time in terms of our 60ns clock tick counter. It returns a number
// of ticks to wait until the next handler in sequence should be
// called. The DTEtick() function acts as a scheduler for these
// handler functions to execute them at the proper time.
typedef LL (*TimedHandlerP)(LL ticks);

static const LL timeMasterReset = 10ll;


static LL startDiagFunc(func, ebusP) {
  ebusP->ds = func;
  ebusP->diagStrobe = 1;
  return 8;
}


static LL endDiagFunc(ebusP) {
  ebusP->diagStrobe = 0;
  ebusP->ds = diagfIdle;
  return 4;
}


#define DO_DIAG_FUNC(F)                         \
    [](LL ticks) -> LL {                        \
     return startDiagFunc(F, ebusP);            \
    },                                          \
                                                \
    [](LL ticks) -> LL {                        \
      return endDiagFunc(ebusP);                \
    },
#endif


void DTEtick(svBit CROBAR, LL ticks, iEBUS *ebusP) {
#ifdef notdef
  static LL startTime = 0;

  static TimedHandlerP handlers[] = {

    [](LL ticks) -> LL {
      std::cerr << ticks << "ticks KLMasterReset() START" << std::endl;
      return 1;
    },

    // $DFXC(.CLRUN=010)    ; Clear run
    DO_DIAG_FUNC(diagfCLR_RUN),
    // This is the first phase of DMRMRT table operations.
    DO_DIAG_WRITE(diagfCLR_CLK_SRC_RATE, 0),
    DO_DIAG_FUNC(diagfSTOP_CLOCK),
    DO_DIAG_FUNC(diagfSET_RESET),
    DO_DIAG_WRITE(diagfRESET_PAR_REGS, 0),
    DO_DIAG_WRITE(diagfCLR_MBOXDIS_PARCHK_ERRSTOP, 0),
    DO_DIAG_WRITE(diagfRESET_PAR_REGS, 0),
    // PARITY CHECK, ERROR STOP ENABLE
    DO_DIAG_WRITE(diagfCLR_BURST_CTR_RH, 0);           // LOAD BURST COUNTER (8,4,2,1)
    DO_DIAG_WRITE(diagfCLR_BURST_CTR_LH, 0);           // LOAD BURST COUNTER (128,64,32,16)
    DO_DIAG_WRITE(diagfSET_EBOX_CLK_DISABLES, 0);      // LOAD EBOX CLOCK DISABLE
    DO_DIAG_FUNC(diagfSTART_CLOCK);                    // START THE CLOCK
    DO_DIAG_WRITE(diagfINIT_CHANNELS, 0);              // INIT CHANNELS
    DO_DIAG_WRITE(diagfCLR_BURST_CTR_RH, 0);           // LOAD BURST COUNTER (8,4,2,1)
  };

  /*    // $DFXC(.CLRUN=010)    ; Clear run
    doDiagFunc(diagfCLR_RUN);

    // This is the first phase of DMRMRT table operations.
    doDiagWrite(diagfCLR_CLK_SRC_RATE, '0);           // CLOCK LOAD FUNC #44
    doDiagFunc(diagfSTOP_CLOCK);                      // STOP THE CLOCK
    doDiagFunc(diagfSET_RESET);                       // SET RESET
    doDiagWrite(diagfRESET_PAR_REGS, '0);             // LOAD CLK PARITY CHECK & FS CHECK
    doDiagWrite(diagfCLR_MBOXDIS_PARCHK_ERRSTOP, '0); // LOAD CLK MBOX CYCLE DISABLES,
    // PARITY CHECK, ERROR STOP ENABLE
    doDiagWrite(diagfCLR_BURST_CTR_RH, '0);           // LOAD BURST COUNTER (8,4,2,1)
    doDiagWrite(diagfCLR_BURST_CTR_LH, '0);           // LOAD BURST COUNTER (128,64,32,16)
    doDiagWrite(diagfSET_EBOX_CLK_DISABLES, '0);      // LOAD EBOX CLOCK DISABLE
    doDiagFunc(diagfSTART_CLOCK);                     // START THE CLOCK
    doDiagWrite(diagfINIT_CHANNELS, '0);              // INIT CHANNELS
    doDiagWrite(diagfCLR_BURST_CTR_RH, '0);           // LOAD BURST COUNTER (8,4,2,1)

    // Loop up to three times:
    //   Do diag function 162 via $DFRD test (A CHANGE COMING A L)=EBUS[32]
    //   If not set, $DFXC(.SSCLK=002) to single step the MBOX
    $display($time, " [step up to 5 clocks to syncronize MBOX]");
    repeat (5) begin
      #500 ;
      if (!mbox0.mbc0.MBC.A_CHANGE_COMING) break;
      #500 ;
      doDiagFunc(diagfSTEP_CLOCK);
    end

    if (mbox0.mbc0.MBC.A_CHANGE_COMING) begin
      $display($time, " ERROR: STEP of MBOX five times did not clear MBC.A_CHANGE_COMING");
    end

    // Phase 2 from DMRMRT table operations.
    doDiagFunc(diagfCOND_STEP);          // CONDITIONAL SINGLE STEP
    doDiagFunc(diagfCLR_RESET);          // CLEAR RESET
    doDiagWrite(diagfENABLE_KL, '0);     // ENABLE KL STL DECODING OF CODES & AC'S
    doDiagWrite(diagfEBUS_LOAD, '0);     // SET KL10 MEM RESET FLOP
    doDiagWrite(diagfWRITE_MBOX, 'o120); // WRITE M-BOX

    $display($time, " DONE");
    */

  if (!startTime) {
    std::cerr << ticks << "ticks CROBAR " << (CROBAR ? "asserted" : "deasserted") << std::endl;
    startTime = ticks;
    t1 = startTime + timeMasterReset;
    return;
  }
#endif
}

#ifdef __cplusplus
}
#endif
