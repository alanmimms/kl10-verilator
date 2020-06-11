// The FE protocol is communicated via shared memory form from the
// fork to this same code running in Verilator simulation process.
// Every message FE->TB and TB->FE is tPipeMessage.
//
// Time in measured in terms of 10/11 clocks - 60ns per tick. The
// request time specifies the ticks count to do the action or is zero
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
// * dteRead
//   Do an EBUS DS diagnostic function with DIAG on EBUS.DS and return
//   the resulting EBUS.data as part of the reply.
//
// * dteWrite
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

static const int verbose = 0;
static const int rVerbose = 0;
static const int wVerbose = 0;

// Probably we are building 64-bit anyway, but this emphasizes the
// point. These are 64-bit typedefs.
typedef unsigned long long W36;

typedef unsigned long long LL;           /* For ticks values from Verilator */


// Halfword mask
static const LL HALF = 0777777LL;


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


// Number of DTE clock ticks to leave a diag function asserted
#define DIAG_DURATION   10


// To be clear: "toDTE" is from the fork running from here to
// communicate BACK TO the simulated DTE20 hardware in the Verilator
// simulation process. "toFE" is to allow the simulator to communicate
// to this fork (the "front end" or FE).
// Recall that [0] is the read end of the pipe, [1] is the write end.
static int toDTE[2], toFE[2];
static pid_t fePID;


#include "dte.h"

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
// which it should execute is `nextReqTicks`.
static LL nextReqTicks = 0;            /* Ticks count to do next request */

static double nsPerClock;       /* Nanoseconds in each of our ticks */


#define RLOG(...) do {                          \
if (rVerbose) printf(__VA_ARGS__);              \
} while (0)                                     \


#define WLOG(...) do {                          \
if (wVerbose) printf(__VA_ARGS__);              \
} while (0)                                     \

#define VLOG(...) do {                          \
if (verbose) printf(__VA_ARGS__);               \
} while (0)                                     \


static void fatalError(const char *msgP) {
  perror(msgP);
  exit(-1);
}


static LL LH(LL w) {
  return (w >> 36) & HALF;
}


static LL RH(LL w) {
  return w & HALF;
}


static char *octW(LL w) {
  static char buf[64];
  sprintf(buf, "%06llo,,%06llo", LH(w), RH(w));
  return buf;
}


static const char *pipeN(int fd) {
  if (fd == toDTE[0]) return "fromFE";
  else if (fd == toDTE[1]) return "toDTE";
  else if (fd == toFE[0]) return "fromDTE";
  else if (fd == toFE[1]) return "toFE";
  else return "???";
}


static LL sendAndGetResult(LL aTicks,
                           LL duration,
                           tReqType aType,
                           int aDiag = diagfIdle,
                           W36 aData = 0) {
  tPipeMessage req;
  req.time = aTicks;
  req.type = aType;
  req.diag = aDiag;
  req.data = aData;
  WLOG("F write(%s) %ld bytes\n", pipeN(toDTE[1]), sizeof(req));
  int len = write(toDTE[1], &req, sizeof(req));
  if (len < sizeof(req)) fatalError("write to DTE pipe");
  WLOG("F %lld: send %s %s %s\n",
       req.time, reqTypeNames[aType],
       aType == dteMisc ? miscFuncNames[aDiag] : diagNames[aDiag],
       octW(aData));

  RLOG("F read(%s) %ld bytes\n", pipeN(toFE[0]), sizeof(req));
  len = read(toFE[0], &req, sizeof(req));
  if (len < sizeof(req)) fatalError("read from DTE pipe");

  RLOG("F %lld: reply received from DTE: %s %s\n",
       nextReqTicks + req.time, reqTypeNames[req.type], octW(req.data));
  nextReqTicks += duration;
  return req.data;
}


//   Do an EBUS DS diagnostic write with DIAG on EBUS.DS and EBUS-DATA
//   on EBUS.data.
static void doWrite(int func, W36 value) {
  VLOG("F diag write %s %s\n", diagNames[func], octW(value));
  sendAndGetResult(nextReqTicks, DIAG_DURATION, dteWrite, func, value);
  sendAndGetResult(nextReqTicks, 1, dteReleaseEBUSData);
}


//   Do a miscellaneous control function in DTE.
static void doMiscFunc(int func) {
  VLOG("F misc func %s\n", miscFuncNames[func]);
  sendAndGetResult(nextReqTicks, 17, dteMisc, func);
}


//   Do an EBUS DS diagnostic function with DIAG on EBUS.DS.
static void doDiagFunc(int func) {
  VLOG("F diag func %s\n", diagNames[func]);
  sendAndGetResult(nextReqTicks, DIAG_DURATION, dteDiagFunc, func);
  sendAndGetResult(nextReqTicks, 1, dteReleaseEBUSData);
}


//   Do an EBUS DS diagnostic function with DIAG on EBUS.DS and return
//   the resulting EBUS.data as part of the reply.
static W36 doRead(int func) {
  //  VLOG("F diag func %s\n", diagNames[func]);

  /* Send function and delay 1us until EBUS.data is stable */
  sendAndGetResult(nextReqTicks, (LL) (1000 / nsPerClock), dteDiagFunc, func);

  VLOG("F diag %s read\n", diagNames[func]);
  W36 result = sendAndGetResult(nextReqTicks, DIAG_DURATION, dteRead);
  VLOG("      result=%s\n", octW(result));
  sendAndGetResult(nextReqTicks, 1, dteReleaseEBUSData);
  return result;
}


static void waitFor(LL ticks) {
  VLOG("F %lld: wait %lld ticks until %lld\n", nextReqTicks, ticks, nextReqTicks + ticks);
  nextReqTicks += ticks;
}


static void klMasterReset() {
  printf("[KL master reset]\n");

  // $DFXC(.CLRUN=010)    ; Clear run
  doDiagFunc(diagfCLR_RUN);

  // This is the first phase of DMRMRT table operations.
  doWrite(diagfCLR_CLK_SRC_RATE, 0);
  doDiagFunc(diagfSTOP_CLOCK);
  doDiagFunc(diagfSET_RESET);
  doWrite(diagfRESET_PAR_REGS, 0);
  doWrite(diagfCLR_MBOXDIS_PARCHK_ERRSTOP, 0);
  doWrite(diagfRESET_PAR_REGS, 0);
                                                  // PARITY CHECK, ERROR STOP ENABLE
  doWrite(diagfCLR_BURST_CTR_RH, 0);          // LOAD BURST COUNTER (8,4,2,1)
  doWrite(diagfCLR_BURST_CTR_LH, 0);          // LOAD BURST COUNTER (128,64,32,16)
  doWrite(diagfSET_EBOX_CLK_DISABLES, 0);     // LOAD EBOX CLOCK DISABLE
  doDiagFunc(diagfSTART_CLOCK);                   // START THE CLOCK
  doWrite(diagfINIT_CHANNELS, 0);             // INIT CHANNELS
  doWrite(diagfCLR_BURST_CTR_RH, 0);          // LOAD BURST COUNTER (8,4,2,1)

  // Loop up to three times:
  //   Do diag function 162 via $DFRD test (A CHANGE COMING A L)=EBUS[32]
  //   If not set, $DFXC(.SSCLK=002) to single step the MBOX
  printf("[step up to 5 clocks to synchronize MBOX]\n");
  bool mboxInitSuccess = false;

  for (int k = 0; k < 5; ++k) {
    waitFor(8);

    if ((doRead(0162) & B32) == 0) {
      printf("[success]\n");
      mboxInitSuccess = true;
      break;
    }

    waitFor(8);
    doDiagFunc(diagfSTEP_CLOCK);
  }

  if (!mboxInitSuccess) printf("[WARNING: MBOX initializatin (A CHANGE COMING L) failed]\n");
  
  // Phase 2 from DMRMRT table operations.
  doDiagFunc(diagfCOND_STEP);             // CONDITIONAL SINGLE STEP
  doDiagFunc(diagfCLR_RESET);             // CLEAR RESET
  doWrite(diagfENABLE_KL, 0);             // ENABLE KL STL DECODING OF CODES & AC'S
  doWrite(diagfEBUS_LOAD, 0);             // SET KL10 MEM RESET FLOP
  doWrite(diagfWRITE_MBOX, 0120);         // WRITE M-BOX
  printf("[KL master reset complete]\n\n");
}


static void klBoot(void) {
  printf("[KL boot goes here]\n");
}


static void HUPhandler(int sig) {
  printf("\n[SIGHUP from parent - exiting]\n");
  exit(-1);
}


static void runFE(void) {
  // Arrange to have our HUP handler called when parent exits
  static const struct sigaction HUPaction = {HUPhandler};

  int st = sigaction(SIGHUP, &HUPaction, 0);
  if (st) fatalError("SIGHUP sigaction");
  
  prctl(PR_SET_PDEATHSIG, SIGHUP);
  
  // Release CROBAR (power on RESET) signal
  waitFor(13);
  doMiscFunc(clrCROBAR);

  klMasterReset();
  klBoot();
  for (;;) waitFor(99999999LL);
}


static int dteReadNFDs;
static fd_set dteReadFDs;


// This function runs in sim context and is called from RTL. Returns
// true if there is a request to do.
extern "C" bool DTErequestIsPending(void) {
  struct timeval justPollTimeVal = {0, 0};
  fd_set fds = dteReadFDs;
  int st = select(dteReadNFDs, &fds, NULL, NULL, &justPollTimeVal);
  if (st < 0) fatalError("DTEgetRequest select");
  return st != 0 && FD_ISSET(toDTE[0], &fds);
}


// This function runs in sim context and is called from RTL. Only call
// this if `DTErequestIsPending()` returns `true` or you'll block.
extern "C" void DTEgetRequest(LL *reqTimeP, int *reqTypeP, int *diagReqP, LL *reqDataP) {
  // If we get here we have a message in the pipe. Read it.
  tPipeMessage req;
  RLOG("S read(%s) %ld bytes\n", pipeN(toDTE[0]), sizeof(req));
  int st = read(toDTE[0], &req, sizeof(req));
  if (st < 0) fatalError("DTEgetRequest pipe read");
  *reqTimeP = req.time;
  *reqTypeP = (int) req.type;
  *diagReqP = (int) req.diag;
  *reqDataP = req.data;
}


// This function runs in sim context.
extern "C" void DTEreply(LL aReplyTime, int aReplyType, LL aReplyData) {
  struct tPipeMessage reply;
  reply.time = aReplyTime;
  reply.type = (tReqType) aReplyType;
  reply.data = aReplyData;
  WLOG("S write(%s) %ld bytes\n", pipeN(toFE[1]), sizeof(reply));
  int st = write(toFE[1], &reply, sizeof(reply));
  if (st < 0) fatalError("write toFE");
  //  VLOG("S %lld: reply sent to FE %s %lld\n",
  //       aReplyTime, reqTypeNames[reply.type], reply.data);
}


extern "C" void FEinitial(double aNsPerClock) {
  int st;

  if (st = pipe2(toDTE, O_DIRECT)) fatalError("Create toDTE pipe");
  if (st = pipe2(toFE, O_DIRECT)) fatalError("Create toFE pipe");

  dteReadNFDs = toDTE[0] + 1;
  FD_SET(toDTE[0], &dteReadFDs);

  nsPerClock = aNsPerClock;
  VLOG("[%g ns per DTE clock]\n", nsPerClock);

  pid_t pid = fork();
  if (pid < 0) fatalError("fork FE");

  if (pid == 0) {               /* Running in the child (FE context) */
    runFE();                    /* FE blocks waiting for messages - never returns */
  } else {                      /* Running in the parent (sim context) */
    fePID = pid;                /* Save PID of child */
  }
}


extern "C" void FEfinal(LL ticks) {
  /* Kill our kid */
  if (fePID > 0) kill(fePID, SIGHUP);
}
