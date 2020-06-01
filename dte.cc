#include <svdpi.h>
#include <iostream>

extern "C" {
  
void DTEtick(svBit CROBAR,
             long long tickCount) {
  static char lastCROBAR = 0;

  if (lastCROBAR != CROBAR) {
    std::cerr << tickCount << " CROBAR " << (CROBAR ? "asserted" : "deasserted") << std::endl;
    lastCROBAR = CROBAR;
  }
}

}
