# What is this?
I built this as a "fork" from my real project which is
[here](https://github.com/alanmimms/kl10).

This repository is the code to build my FPGA RTL as a
[Verilator](https://www.veripool.org/projects/verilator/wiki/Intro)
simulation. It runs at least ten times faster than the simulator I had
been using that is part of Xilinx Vivado, and it's way more careful
about mistakes in coding -- reporting many things that were actual
bugs that needed fixing.

To use this you'll need to clone the repo and install Verilator and a
gmake and GCC build environment on Linux. I use Ubuntu 19.10 (for the
moment) and as I recall (it was a while ago) all I had to do was `sudo
apt-get install build-essential` to get set up.

I use [GTK Wave](https://github.com/gtkwave/gtkwave) (which I
installed using `sudo apt-get install gtkwave`) to view the resulting
trace data to help me debug.

This is going pretty well. I have found a couple of issues with
Verilator, but there wasn't anything I couldn't work around. I can
debug with GDB if I want to. Looking at the (very verbose and somewhat
tedious) generated C++ code coming out of Verilator has helped me
understand its interpretation of my SystemVerilog code better than
most things I have tried.

I do remember now why I hate C++ so much.
