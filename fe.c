// The FE protocol is communicated via shared memory form from the
// fork to this same code running in Verilator simulation process.
// Every message FE->TB and TB->FE is tPipeMessage.
//
// Where time specifies the ticks count to do the action or is zero
// for asynchronous (do it NOW) operations.
//
// Where `type` is one of the operations below and ARGS is the list of
// space separated parameters needed by the operation. Each operation
// excutes at the constrained time and the result of the operation is
// sent as a reply in format shown in the next section.
//
// * dteDiagFunc
//   Do an EBUS DS diagnostic function with DIAG on EBUS.DS.
//
// * dteDiagRead
//   Do an EBUS DS diagnostic function with DIAG on EBUS.DS and return
//   the resulting EBUS.data as part of the reply.
//
// * dteDiagWrite
//   Do an EBUS DS diagnostic write with DIAG on EBUS.DS and EBUS-DATA
//   on EBUS.data.
//
// Every operation returns a reply TB->FE tPipeMessage.
//
// Where `time` is the tick count of when the operation actually
// executed.
//
// Where `type` is the operation type this reply is associated with.

// Where `data` is the EBUS data value returned after the operation.
#define _GNU_SOURCE 1

#include <sys/types.h>
#include <sys/select.h>
#include <sys/prctl.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
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

static const int diagfIdle = 077;


// To be clear: "toDTE" is from the fork running from here to
// communicate BACK TO the simulated DTE20 hardware in the Verilator
// simulation process. "toFE" is to allow the simulator to communicate
// to this fork (the "front end" or FE).
// Recall that [0] is the read end of the pipe, [1] is the write end.
static int toDTE[2], toFE[2];
static pid_t fePID;

static const LL ticksPerClk = 16000ll;

static LL ticks;                /* Time stamp of most recent reply */


typedef enum {dteDiagFunc, dteDiagRead, dteDiagWrite} tReqType;
static const char *typeNames[] = {"dteDiagFunc", "dteDiagRead", "dteDiagWrite"};

// Struct used in both directions on the pipe.
struct tPipeMessage {
  LL time;
  tReqType type;
  int diag;
  W36 data;
};


static const char *diagNames[] = {
  /* 000 */ "STOP_CLOCK",
  /* 001 */ "START_CLOCK",
  /* 002 */ "STEP_CLOCK",
  /* 003 */ 0,
  /* 004 */ "COND_STEP",
  /* 005 */ "BURST",
  /* 006 */ "CLR_RESET",
  /* 007 */ "SET_RESET",
  /* 010 */ "CLR_RUN",
  /* 011 */ "SET_RUN",
  /* 012 */ "CONTINUE",
  /* 013 */ 0,
  /* 014 */ 0,
  /* 015 */ 0,
  /* 016 */ 0,
  /* 017 */ 0,
  /* 020 */ 0,
  /* 021 */ 0,
  /* 022 */ 0,
  /* 023 */ 0,
  /* 024 */ 0,
  /* 025 */ 0,
  /* 026 */ 0,
  /* 027 */ 0,
  /* 030 */ 0,
  /* 031 */ 0,
  /* 032 */ 0,
  /* 033 */ 0,
  /* 034 */ 0,
  /* 035 */ 0,
  /* 036 */ 0,
  /* 037 */ 0,
  /* 040 */ 0,
  /* 041 */ 0,
  /* 042 */ "CLR_BURST_CTR_RH",
  /* 043 */ "CLR_BURST_CTR_LH",
  /* 044 */ "CLR_CLK_SRC_RATE",
  /* 045 */ "SET_EBOX_CLK_DISABLES",
  /* 046 */ "RESET_PAR_REGS",
  /* 047 */ "CLR_MBOXDIS_PARCHK_ERRSTOP",
  /* 050 */ 0,
  /* 051 */ "CLR_CRAM_DIAG_ADR_RH",
  /* 052 */ "CLR_CRAM_DIAG_ADR_LH",
  /* 053 */ 0,
  /* 054 */ 0,
  /* 055 */ 0,
  /* 056 */ 0,
  /* 057 */ 0,
  /* 060 */ 0,
  /* 061 */ 0,
  /* 062 */ 0,
  /* 063 */ 0,
  /* 064 */ 0,
  /* 065 */ 0,
  /* 066 */ 0,
  /* 067 */ "ENABLE_KL",
  /* 070 */ "INIT_CHANNELS",
  /* 071 */ "WRITE_MBOX",
  /* 072 */ 0,
  /* 073 */ 0,
  /* 074 */ 0,
  /* 075 */ 0,
  /* 076 */ "EBUS_LOAD",
  /* 077 */ "idle",
};

// Only one request can be outstanding at one time. The ticks value at
// which it should execute is `nextReqTicks`, the request type is
// `reqType`, the EBUS.DS code is `reqDiag`, and the EBUS.data word is
// `reqData` (if it is needed at all).
static LL nextReqTicks = 0;            /* Ticks count to do next request */
static tReqType reqType = dteDiagFunc; /* Type for next request */
static int reqDiag = diagfSTOP_CLOCK;  /* Diagnostic code for next request */
static LL reqData = 0;                 /* EBUS data (if any) for next request */

static LL replyTime;
static tReqType replyType;
static W36 replyData;


static void fatalError(const char *msgP) {
  perror(msgP);
  exit(-1);
}


static LL sendAndGetResult(LL aTicks, tReqType aType, int aDiag, W36 aData) {
  tPipeMessage req;
  req.time = aTicks;
  req.type = aType;
  req.diag = aDiag;
  req.data = aData;
  int len = write(toDTE[1], &req, sizeof(req));
  if (len < sizeof(req)) fatalError("write to DTE pipe");
  if (verbose) fprintf(stderr, "%8lld FE-->DTE: %s %s %lld\n",
                       aTicks, typeNames[aType], diagNames[aDiag], aData);

  len = read(toFE[0], &req, sizeof(req));
  if (len < sizeof(req)) fatalError("read from DTE pipe");

  if (verbose) fprintf(stderr, "%8lld DTE-->FE: %s %lld\n",
                       req.time, typeNames[req.type], req.data);
  return req.data;
}


//   Do an EBUS DS diagnostic write with DIAG on EBUS.DS and EBUS-DATA
//   on EBUS.data.
static void doDiagWrite(int func, W36 value) {
  nextReqTicks = sendAndGetResult(nextReqTicks, dteDiagWrite, func, value);
}


//   Do an EBUS DS diagnostic function with DIAG on EBUS.DS.
static void doDiagFunc(int func) {
  nextReqTicks = sendAndGetResult(nextReqTicks, dteDiagFunc, func, 0);
}


//   Do an EBUS DS diagnostic function with DIAG on EBUS.DS and return
//   the resulting EBUS.data as part of the reply.
static W36 doDiagRead(int func) {
  nextReqTicks = sendAndGetResult(nextReqTicks, dteDiagRead, func, 0);
  return replyData;
}


static void waitFor(LL ticks) {
  sendAndGetResult(nextReqTicks + ticks, dteDiagRead, diagfIdle, 0);
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
    waitFor(8ll * ticksPerClk);
    if (doDiagRead(0162) & B32) break;
    waitFor(8ll * ticksPerClk);
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


static void klBoot(void) {
  fprintf(stderr, "%8lld [KL boot goes here]\n", ticks);
}


static void HUPhandler(int sig) {
  fprintf(stderr, "\n[SIGHUP from parent - exiting]\n");
  exit(-1);
}


static void runFE(void) {
  // Arrange to have our HUP handler called when parent exits
  static const struct sigaction HUPaction = {HUPhandler};

  int st = sigaction(SIGHUP, &HUPaction, 0);
  if (st) fatalError("SIGHUP sigaction");
  
  prctl(PR_SET_PDEATHSIG, SIGHUP);
  
  klMasterReset();
  klBoot();
  waitFor(10000000000ll);
}


static int dteReadNFDs;
static fd_set dteReadFDs;


// This function runs in sim context and is called from RTL.
extern "C" LL DTEgetRequest(int *reqTypeP, int *diagReqP, LL *reqDataP) {
  struct timeval justPollTimeVal;
  justPollTimeVal.tv_sec = 0;
  justPollTimeVal.tv_usec = 0;
  int st = select(dteReadNFDs, &dteReadFDs, NULL, NULL, &justPollTimeVal);

  if (st < 0) fatalError("DTEgetRequest select");
  if (st == 0) return 0;

  // If we get here we have a message in the pipe. Read it.
  tPipeMessage req;
  st = read(toDTE[0], &req, sizeof(req));
  if (st < 0) fatalError("DTEgetRequest pipe read");
  *reqTypeP = (int) req.type;
  *diagReqP = (int) req.diag;
  *reqDataP = req.data;
  nextReqTicks = req.time + 1;
  return req.time;
}


// This function runs in sim context.
extern "C" void DTEreply(LL aReplyTime, int aReplyType, LL aReplyData) {
  struct tPipeMessage reply;
  reply.time = aReplyTime;
  reply.type = (tReqType) aReplyType;
  reply.data = aReplyData;
  int st = write(toFE[1], &reply, sizeof(reply));
  if (st < 0) fatalError("write toFE");
}


extern "C" void FEinitial(void) {
  int st;

  if (st = pipe2(toDTE, O_DIRECT)) fatalError("Create toDTE pipe");
  if (st = pipe2(toFE, O_DIRECT)) fatalError("Create toFE pipe");

  dteReadNFDs = toDTE[0] + 1;
  FD_SET(toDTE[0], &dteReadFDs);

  pid_t pid = fork();
  if (pid < 0) fatalError("fork FE");

  if (pid == 0) {               /* Running in the child (FE context) */
    for (;;) runFE();           /* FE blocks waiting for messages - never returns */
  } else {                      /* Running in the parent (sim context) */
    fePID = pid;                /* Save PID of child */
  }
}


extern "C" void FEfinal(LL ns) {
  /* Kill our kid */
  if (fePID > 0) kill(fePID, SIGHUP);
}
