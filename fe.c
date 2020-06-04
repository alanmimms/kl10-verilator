// The FE protocol is communicated over pipes in text form from the
// fork to this same code running in Verilator simulation process.
// Every message FE->TB is of the form:
//
// TIME-CONSTRAINT TICKS OP ARGS ...
//
// Where TIME-CONSTRAINT is '=' for "should be at the specified ticks
// count" or it is '>' for "should be at specified ticks count or
// later". There is no space between the TIME-CONSTRAINT and the TICKS
// value, but there is one space between each other part of the
// request.
//
// Where TICKS is a 64-bit tick count in nanoseconds.
//
// Where OP is one of the operations below and ARGS is the list of
// space separated parameters needed by the operation. Each operation
// excutes at the constrained time and the result of the operation is
// sent as a reply in format shown in the next section.
//
// * DiagFunc DIAG
//   Do an EBUS DS diagnostic function with DIAG on EBUS.DS.
//
// * DiagRead DIAG
//   Do an EBUS DS diagnostic function with DIAG on EBUS.DS and return
//   the resulting EBUS.data as part of the reply.
//
// * DiagWrite DIAG EBUS-DATA
//   Do an EBUS DS diagnostic write with DIAG on EBUS.DS and EBUS-DATA
//   on EBUS.data.
//
// * wait TICKS
//   Wait until the specified ticks count.
//
// Every operation returns a reply TB->FE of the form
// TICKS OP RESULT ...
//
// Where TICKS is the tick count of when the operation actually executed.
//
// Where OP is the OP this reply is associated with. One special case
// is where OP is the string "FINAL", which is sent by the simulation
// to indicate the end of the simulation.
//
// Where RESULT is a possibly empty series of response data values
// from the operation.
//
// In all of the above, numeric values are 36-bit octal (perversely)
// except for TICKS which are are 64-bit decimal (even more
// perversely).
#define _GNU_SOURCE 1

#include <sys/types.h>
#include <sys/prctl.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include <svdpi.h>

static const int verbose = 1;

// Probably we are building 64-bit anyway, but this emphasizes the
// point. These are 64-bit typedefs.
typedef unsigned long long W36;

typedef long long LL;           /* For ticks values from Verilator */


// PDP10 bit constants
static const W36 B0  = 1ull << (35 - 0);
static const W36 B1  = 1ull << (35 - 1);
static const W36 B2  = 1ull << (35 - 2);
static const W36 B3  = 1ull << (35 - 3);
static const W36 B4  = 1ull << (35 - 4);
static const W36 B5  = 1ull << (35 - 5);
static const W36 B6  = 1ull << (35 - 6);
static const W36 B7  = 1ull << (35 - 7);
static const W36 B8  = 1ull << (35 - 8);
static const W36 B9  = 1ull << (35 - 9);
static const W36 B10 = 1ull << (35 - 10);
static const W36 B11 = 1ull << (35 - 11);
static const W36 B12 = 1ull << (35 - 12);
static const W36 B13 = 1ull << (35 - 13);
static const W36 B14 = 1ull << (35 - 14);
static const W36 B15 = 1ull << (35 - 15);
static const W36 B16 = 1ull << (35 - 16);
static const W36 B17 = 1ull << (35 - 17);

static const W36 B18 = 1ull << (35 - 18);
static const W36 B19 = 1ull << (35 - 19);
static const W36 B20 = 1ull << (35 - 20);
static const W36 B21 = 1ull << (35 - 21);
static const W36 B22 = 1ull << (35 - 22);
static const W36 B23 = 1ull << (35 - 23);
static const W36 B24 = 1ull << (35 - 24);
static const W36 B25 = 1ull << (35 - 25);
static const W36 B26 = 1ull << (35 - 26);
static const W36 B27 = 1ull << (35 - 27);
static const W36 B28 = 1ull << (35 - 28);
static const W36 B29 = 1ull << (35 - 29);
static const W36 B30 = 1ull << (35 - 30);
static const W36 B31 = 1ull << (35 - 31);
static const W36 B32 = 1ull << (35 - 32);
static const W36 B33 = 1ull << (35 - 33);
static const W36 B34 = 1ull << (35 - 34);
static const W36 B35 = 1ull << (35 - 35);


// Diagnostic (DS[4:6]) functions
static const int diagfSTOP_CLOCK = 000;
static const int diagfSTART_CLOCK = 001;
static const int diagfSTEP_CLOCK = 002;
static const int diagfCOND_STEP = 004;
static const int diagfBURST = 005;

static const int diagfCLR_RESET = 006;
static const int diagfSET_RESET = 007;
static const int diagfCLR_RUN = 010;
static const int diagfSET_RUN = 011;
static const int diagfCONTINUE = 012;

static const int diagfCLR_BURST_CTR_RH = 042;
static const int diagfCLR_BURST_CTR_LH = 043;
static const int diagfCLR_CLK_SRC_RATE = 044;
static const int diagfSET_EBOX_CLK_DISABLES = 045;
static const int diagfRESET_PAR_REGS = 046;
static const int diagfCLR_MBOXDIS_PARCHK_ERRSTOP = 047;

static const int diagfCLR_CRAM_DIAG_ADR_RH = 051;
static const int diagfCLR_CRAM_DIAG_ADR_LH = 052;

static const int diagfENABLE_KL = 067;

static const int diagfINIT_CHANNELS = 070;
static const int diagfWRITE_MBOX = 071;
static const int diagfEBUS_LOAD = 076;

static const int diagfIdle = 007;


static LL ticks;                /* Time stamp of most recent reply */


// To be clear: "toDTE" is from the fork running from here to
// communicate BACK TO the simulated DTE20 hardware in the Verilator
// simulation process. "toFE" is to allow the simulator to communicate
// to this fork (the "front end" or FE).
static int toDTE[2], toFE[2];
static pid_t fePID;


static void fatalError(const char *msgP) {
  perror(msgP);
  exit(-1);
}


static LL sendAndGetResult(const char *msgP, char *resultP, int maxResultSize) {
  int len, sendLen;
  char buf[1024];

  sendLen = strlen(msgP);
  len = write(toDTE[1], msgP, sendLen);
  if (len < sendLen) fatalError("write to DTE pipe");
  if (verbose) fprintf(stderr, "toDTE '%s'\n", msgP);

  len = read(toFE[0], resultP, maxResultSize - 1);
  if (len < 0) fatalError("read from DTE pipe");
  resultP[len] = 0;
  if (verbose) fprintf(stderr, "fromDTE '%s'\n", resultP);
  sscanf(resultP, "%llu %s", &ticks, buf);

  if (strcmp(buf, "FINAL") == 0) {
    fprintf(stderr, "%llu DTE 'final'\n[exiting]\n", ticks);
    exit(0);
  }

  return ticks;
}


// * DiagWrite DIAG EBUS-DATA
//   Do an EBUS DS diagnostic write with DIAG on EBUS.DS and EBUS-DATA
//   on EBUS.data.
static void doDiagWrite(int func, W36 value) {
  char result[1024];
  char msg[1024];

  // * DiagFunc DIAG
  //   Do an EBUS DS diagnostic function with DIAG on EBUS.DS.
  sprintf(msg, "DiagWrite %o %llo", func, value);
  sendAndGetResult(msg, result, sizeof(result));
}


static void doDiagFunc(int func) {
  char result[1024];
  char msg[1024];

  // * DiagFunc DIAG
  //   Do an EBUS DS diagnostic function with DIAG on EBUS.DS.
  sprintf(msg, "DiagFunc %o", func);
  sendAndGetResult(msg, result, sizeof(result));
}


static void waitFor(LL nTicks) {
  char result[1024];
  char msg[1024];

  // * wait TICKS
  //   Wait until the specified ticks count.
  sprintf(msg, "wait %lld", nTicks);
  sendAndGetResult(msg, result, sizeof(result));
}


// * DiagRead DIAG
//   Do an EBUS DS diagnostic function with DIAG on EBUS.DS and return
//   the resulting EBUS.data as part of the reply.
static W36 doDiagRead(int func) {
  char result[1024];
  char msg[1024];

  // * DiagFunc DIAG
  //   Do an EBUS DS diagnostic function with DIAG on EBUS.DS.
  sprintf(msg, "DiagRead %o", func);
  sendAndGetResult(msg, result, sizeof(result));

  // Every operation returns a reply TB->FE of the form
  // TICKS OP RESULT ...
  W36 valueRead;
  sscanf(result, "%*d diagRead %llo", &valueRead);
  return valueRead;
}


static void klMasterReset() {
  fprintf(stderr, "%lld ticks KLMasterReset() START\n", ticks);

  // $DFXC(.CLRUN=010)    ; Clear run
  doDiagFunc(diagfCLR_RUN);

  // This is the first phase of DMRMRT table operations.
  doDiagWrite(diagfCLR_CLK_SRC_RATE, 0);
  doDiagFunc(diagfSTOP_CLOCK);
  doDiagFunc(diagfSET_RESET);
  doDiagWrite(diagfRESET_PAR_REGS, 0);
  doDiagWrite(diagfCLR_MBOXDIS_PARCHK_ERRSTOP, 0);
  doDiagWrite(diagfRESET_PAR_REGS, 0);
                                                  // PARITY CHECK, ERROR STOP ENABLE
  doDiagWrite(diagfCLR_BURST_CTR_RH, 0);          // LOAD BURST COUNTER (8,4,2,1)
  doDiagWrite(diagfCLR_BURST_CTR_LH, 0);          // LOAD BURST COUNTER (128,64,32,16)
  doDiagWrite(diagfSET_EBOX_CLK_DISABLES, 0);     // LOAD EBOX CLOCK DISABLE
  doDiagFunc(diagfSTART_CLOCK);                   // START THE CLOCK
  doDiagWrite(diagfINIT_CHANNELS, 0);             // INIT CHANNELS
  doDiagWrite(diagfCLR_BURST_CTR_RH, 0);          // LOAD BURST COUNTER (8,4,2,1)

  // Loop up to three times:
  //   Do diag function 162 via $DFRD test (A CHANGE COMING A L)=EBUS[32]
  //   If not set, $DFXC(.SSCLK=002) to single step the MBOX
  fprintf(stderr, "%08llu [step up to 5 clocks to syncronize MBOX]", ticks);

  for (int k = 0; k < 5; ++k) {
    waitFor(1000);

    if (doDiagRead(0162) & B32) break;

    waitFor(1000);
    doDiagFunc(diagfSTEP_CLOCK);
  }
  
  /*

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
}


static void HUPhandler(int sig) {
  fprintf(stderr, "\n[SIGHUP from parent death - exiting]\n");
  exit(-1);
}


static void runFE(void) {
  // Arrange to have our HUP handler called when parent exits
  static const struct sigaction HUPaction = {HUPhandler};

  int st = sigaction(SIGHUP, &HUPaction, 0);
  if (st) fatalError("SIGHUP sigaction");
  
  prctl(PR_SET_PDEATHSIG, SIGHUP);
  
  klMasterReset();
  waitFor(10000000000ll);
}


extern "C" void FEinitial(void) {
  int st;

  if (st = pipe2(toDTE, O_DIRECT)) fatalError("Create toDTE pipe");

  if (st = pipe2(toFE, O_DIRECT)) fatalError("Create toFE pipe");

  pid_t pid = fork();
  if (pid < 0) fatalError("fork FE");

  /* FE never returns. It blocks waiting for messages. */
  if (pid == 0) runFE();
}


extern "C" void FEfinal(LL ns) {
  char finalMsg[200];

  sprintf(finalMsg, "%llu FINAL", ns);

  if (toFE[1])
    write(toFE[1], finalMsg, strlen(finalMsg));
  else if (fePID > 0)           /* Kill it if we can't talk to it */
    kill(fePID, SIGKILL);
}
