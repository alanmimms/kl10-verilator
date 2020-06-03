#define _GNU_SOURCE 1

#include <sys/types.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include <svdpi.h>

typedef long long LL;


// To be clear: "toDTE" is from the fork running from here to
// communicate BACK TO the simulated DTE20 hardware in the Verilator
// simulation process. "toFE" is to allow the simulator to communicate
// to this fork (the "front end" or FE).
static int toDTE[2], toFE[2];
static pid_t fePID;


static LL waitForMessage(const char *msgP) {
  int len;
  char buf[1024];
  LL ticks;

  for (;;) {
    len = read(toDTE[0], buf, sizeof(buf));

    if (len < 0) {
      perror("Read from toDTE pipe");
      exit(-1);
    }

    buf[len] = 0;

    if (strcmp(buf, msgP) != 0) {
      fprintf(stderr, "Expected '%s' message, but got '%s' instead\n", buf, msgP);
    } else {
      sscanf(buf, "%*s %llu", &ticks);
      return ticks;
    }
  }
}


static void runDTE(void) {
  LL ticks;
  
  ticks = waitForMessage("initial");
  printf("%llu DTE 'initial'\n", ticks);

  ticks = waitForMessage("final");
  printf("%llu DTE 'final'\n[exiting]\n", ticks);
}


void FEinitial(void) {
  int st;
  static char initialBuf[] = "initial";

  if (st = pipe2(toDTE, O_DIRECT | O_NONBLOCK)) {
    perror("Create toDTE pipe");
    exit(-1);
  }

  if (st = pipe2(toFE, O_DIRECT | O_NONBLOCK)) {
    perror("Create toFE pipe");
    exit(-1);
  }

  pid_t pid = fork();

  if (pid < 0) {
    perror("Fork");
    exit(-1);
  }

  if (pid == 0) {
    runDTE();
  } else {
    fePID = pid;
    write(toFE[1], initialBuf, sizeof(initialBuf));
  }
}


void FEfinal(void) {
  static char finalBuf[] = "final";

  if (toFE[1])
    write(toFE[1], finalBuf, sizeof(finalBuf));
  else if (fePID > 0)           /* Kill it if we can't talk to it */
    kill(fePID, SIGKILL);
}
