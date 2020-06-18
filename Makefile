SVFILES = apr.sv ccl.sv ccw.sv cha.sv chc.sv chd.sv chx.sv clk.sv	\
	con.sv cra.sv crc.sv crm.sv csh.sv ctl.sv decoder.sv dte.sv	\
	ebox.sv edp.sv ir.sv mb0.sv mbc.sv mbox.sv mbx.sv mbz.sv	\
	mc10179.sv mc10181.sv mcl.sv memory.sv mt0.sv mtr.sv		\
	mux2x4.sv mux4x2.sv mux.sv pag.sv pi.sv pma.sv pri8.sv scd.sv	\
	shm.sv top.sv ucr4.sv usr4.sv vma.sv tb/sim-mem.sv

VERILATOR_ROOT = /usr/local/share/verilator
VOBJDIR = ./obj_dir

DEBUG = -g
#OPTIMIZE = "-O3 --x-assign fast --x-initial fast"
#OPTIMIZE = -CFLAGS -O3 -O3
OPTIMIZE =
SVHFILES = ebox.svh
CXXFILES = tb/verilator-main.cc
CFILES = fe.c
HFILES =
TBOBJS = $(foreach F,$(CFILES:.c=.o) $(CXXFILES:.cc=.o),$(VOBJDIR)/$F)

EXE = kl10pvtb
MC10181_EXE = mc10181tb

DTE_INTF = dte.h dte.svh

KILL_WARNINGS = -Wno-LITENDIAN \
		-Wno-UNOPTFLAT \
		-Wno-DECLFILENAME \
		-Wno-CLKDATA

INCDIR = $(VERILATOR_ROOT)/include
CFLAGS += -I$(VOBJDIR) -I$(INCDIR) -I$(INCDIR)/vltstd -std=gnu++14 $(DEBUG)
CXXFLAGS += -I$(VOBJDIR) -I$(INCDIR) -I$(INCDIR)/vltstd $(DEBUG)

VERILATOR ?= verilator
VFLAGS = \
	$(KILL_WARNINGS) \
	--default-language 1800-2017 +1800-2017ext+sv \
	-DTB -DKL10PV_TB \
	--MMD \
	$(foreach F, $(CFLAGS), -CFLAGS $F) \
	$(foreach F, $(DEBUG), -LDFLAGS $F) \
	--trace --trace-structs \
	--timescale-override 1ns/1ps --top-module top --x-initial 0 \
	--cc --build --exe -j 4

.PHONY:	all
all:	$(EXE) $(MC10181_EXE)

$(EXE):	$(SVFILES) $(SVHFILES) $(CXXFILES) $(CFILES) $(HFILES) $(DTE_INTF)
	$(VERILATOR) $(VFLAGS) $(filter-out %.h, $^) -o $(EXE)

$(DTE_INTF): dte-interface.js
	node dte-interface.js -- $(DTE_INTF)

$(MC10181_EXE): mc10181.sv tb/mc10181-main.cc
	$(VERILATOR) -Wall $(KILL_WARNINGS) \
		--default-language 1800-2017 +1800-2017ext+sv \
		-DTESTBENCH \
		$(foreach F, $(CFLAGS), -CFLAGS $F) \
		$(foreach F, $(DEBUG), -LDFLAGS $F) \
		--trace --trace-structs \
		--timescale-override 1ns/1ps \
		--cc mc10181.sv --exe --build \
		tb/mc10181-main.cc \
		-o $@

.PHONY:	clean
clean:
	rm -rf $(VOBJDIR) $(DTE_INTF)
