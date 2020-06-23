SVFILES = apr.sv ccl.sv ccw.sv cha.sv chc.sv chd.sv chx.sv clk.sv	\
	con.sv cra.sv crc.sv crm.sv csh.sv ctl.sv decoder.sv dte.sv	\
	ebox.sv edp.sv ir.sv mb0.sv mbc.sv mbox.sv mbx.sv mbz.sv	\
	mc10179.sv mc10181.sv mcl.sv memory.sv mt0.sv mtr.sv		\
	mux2x4.sv mux4x2.sv mux.sv pag.sv pi.sv pma.sv pri8.sv scd.sv	\
	shm.sv top.sv ucr4.sv usr4.sv vma.sv tb/sim-mem.sv

VERILATORROOT = /usr/local/share/verilator
VOBJDIR = ./obj_dir

DEBUG = -g
#OPTIMIZE = "-O3 --x-assign fast --x-initial fast"
#OPTIMIZE = -CFLAGS -O3 -O3
OPTIMIZE =
DTEINTF = dte.h dte.svh
SVHFILES = ebox.svh $(DTEINTF)
CXXFILES = tb/verilator-main.cc
CFILES = fe.c
HFILES =
TBOBJS = $(foreach F,$(CFILES:.c=.o) $(CXXFILES:.cc=.o),$(VOBJDIR)/$F)

EXEs = $(EXE) $(MC10181EXE) $(EDPEXE)
EXE = kl10pvtb
MC10181EXE = mc10181tb
EDPEXE = edptb

KILLWARNINGS = \
	-Wno-LITENDIAN \
	-Wno-UNOPTFLAT \
	-Wno-DECLFILENAME \
	-Wno-CLKDATA \
	-Wno-TIMESCALEMOD

INCDIR = $(VERILATORROOT)/include
CFLAGS += -I$(VOBJDIR) -I$(INCDIR) -I$(INCDIR)/vltstd -std=gnu++14 $(DEBUG)
CXXFLAGS += -I$(VOBJDIR) -I$(INCDIR) -I$(INCDIR)/vltstd $(DEBUG)

VERILATOR ?= verilator
VFLAGS = \
	$(KILLWARNINGS) \
	--default-language 1800-2017 +1800-2017ext+sv \
	-DTB -DKL10PV_TB -DTESTBENCH \
	--MMD \
	$(foreach F, $(CFLAGS), -CFLAGS $F) \
	$(foreach F, $(DEBUG), -LDFLAGS $F) \
	--trace --trace-structs \
	--timescale 1ns/1ps --timescale-override 1ns/1ps \
	--x-initial 0 \
	--cc --build --exe -j 4

.PHONY:	all
all:	$(EXE) $(MC10181EXE) $(EDPEXE)

$(EXE):	$(SVFILES) $(CXXFILES) $(CFILES) $(HFILES) $(SVHFILES)
	$(VERILATOR) $(VFLAGS) $(filter-out %.h, $^) --top-module top -o $@

$(DTEINTF): dte-interface.js
	node dte-interface.js -- $(DTEINTF)

$(MC10181EXE): mc10181.sv tb/mc10181tb.sv tb/mc10181-main.cc $(SVHFILES)
	$(VERILATOR) $(VFLAGS) $(filter-out %.h, $^) --top-module mc10181tb -o $@

$(EDPEXE): edp.sv tb/edptb.sv tb/edp-main.cc tb/sim-mem.sv usr4.sv $(SVHFILES)
	$(VERILATOR) $(VFLAGS) $(filter-out %.h, $^) --top-module edptb -o $@

.PHONY:	clean
clean:
	rm -rf $(VOBJDIR) $(DTEINTF) $(foreach F,$(EXE),tb/$(EXE))

