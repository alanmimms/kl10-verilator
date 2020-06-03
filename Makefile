SVFILES = apr.sv ccl.sv ccw.sv cha.sv chc.sv chd.sv chx.sv clk.sv	\
con.sv cra.sv crc.sv crm.sv csh.sv ctl.sv decoder.sv dte.sv ebox.sv	\
edp.sv ir.sv mb0.sv mbc.sv mbox.sv mbx.sv mbz.sv mc10179.sv		\
mc10181.sv mcl.sv memory.sv mt0.sv mtr.sv mux2x4.sv mux4x2.sv mux.sv	\
pag.sv pi.sv pma.sv pri8.sv scd.sv shm.sv top.sv ucr4.sv usr4.sv	\
vma.sv tb/sim-mem.sv

VERILATOR_ROOT = /usr/local/share/verilator
VOBJDIR = ./obj_dir

DEBUG = -g
#OPTIMIZE = "-O3 --x-assign fast --x-initial fast"
#OPTIMIZE = -CFLAGS -O3 -O3
OPTIMIZE =
SVHFILES = ebox.svh
CCFILES = tb/verilator-main.cc
CFILES = fe.c
HFILES =
TBOBJS = $(foreach F,$(CFILES:.c=.o) $(CCFILES:.cc=.o),$(VOBJDIR)/$F)

EXE = kl10pvtb

VLIB = Vtop__ALL
VLIBPATH = $(VOBJDIR)/$(VLIB).a

KILL_WARNINGS = \
		-Wno-LITENDIAN \
		-Wno-UNOPTFLAT

### Constants...
# Perl executable (from $PERL)
PERL = perl
# Path to Verilator kit (from $VERILATOR_ROOT)
VERILATOR_ROOT = /usr/local/share/verilator
# SystemC include directory with systemc.h (from $SYSTEMC_INCLUDE)
SYSTEMC_INCLUDE ?= 
# SystemC library directory with libsystemc.a (from $SYSTEMC_LIBDIR)
SYSTEMC_LIBDIR ?= 

### Switches...
# Generate waveform trace code
VM_TRACE=1
# Generate coverage analysis code
VM_COVERAGE=0
# SystemC output mode?  0/1 (from --sc)
VM_SC = 0
# Legacy or SystemC output mode?  0/1 (from --sc)
VM_SP_OR_SC = $(VM_SC)
# Deprecated
VM_PCLI = 1
# Deprecated: SystemC architecture to find link library path (from $SYSTEMC_ARCH)
VM_SC_TARGET_ARCH = linux

### Vars...
# Design prefix (from --prefix)
VM_PREFIX = Vtop
# Module prefix (from --prefix)
VM_MODPREFIX = Vtop
# User CFLAGS (from -CFLAGS on Verilator command line)
VM_USER_CFLAGS = \
	-g \

# User LDLIBS (from -LDFLAGS on Verilator command line)
VM_USER_LDLIBS = \
	-g \

# User .cpp files (from .cpp's on Verilator command line)
VM_USER_CLASSES = \
	fe \
	verilator-main \

# User .cpp directories (from .cpp's on Verilator command line)
VM_USER_DIR = \
	. \
	tb \

#		-LDFLAGS "-Wl,--start-group" \
#		-LDLIBS "-Wl,--end-group" \

INCDIR = $(VERILATOR_ROOT)/include
CFLAGS += -I$(VOBJDIR) -I$(INCDIR) -I$(INCDIR)/vltstd
CXXFLAGS += -I$(VOBJDIR) -I$(INCDIR) -I$(INCDIR)/vltstd
#LDFLAGS += -L$(VOBJDIR) -l$(VLIB)

VERILATOR ?= verilator
VFLAGS = \
	$(KILL_WARNINGS) \
	--default-language 1800-2017 +1800-2017ext+sv \
	-DTB -DKL10PV_TB \
	--MMD \
	--trace --trace-structs \
	--timescale-override 1ns/1ps --top-module top --x-initial 0 \
	--cc --build -j 4 
#	$(foreach F,$(DEBUG),-CFLAGS $(DEBUG) -LDFLAGS $(DEBUG)) $(OPTIMIZE)

all:	$(EXE)
.PHONY:	all

-include Vtop_classes.mk
include $(VERILATOR_ROOT)/include/verilated.mk
VPATH += $(VM_USER_DIR)

.PHONY:	verilate
verilate:	$(SVFILES) $(SVHFILES) $(HFILES) $(VOBJDIR)/Vtop.h

$(VOBJDIR)/Vtop.h:
	mkdir -p $(VOBJDIR)/tb
	$(VERILATOR) $(VFLAGS) $(SVFILES)

$(VLIBPATH): verilate
	$(MAKE) -C $(VOBJDIR)/ -f Vtop.mk

.PHONY:	clean
clean:
	rm -rf $(VOBJDIR)

$(VOBJDIR)/%.o:	verilate %.c
	mkdir -p $(VOBJDIR)/tb
	$(CC) $(CFLAGS) -c $(filter %.c, $^) -o $@

$(VOBJDIR)/%.o:	verilate %.cc
	mkdir -p $(VOBJDIR)/tb
	$(CXX) $(CXXFLAGS) -c $(filter %.cc, $^) -o $@

$(EXE): $(TBOBJS) $(VLIBPATH)
#	$(CXX) $(DEBUG) -Wl,--start-group $^ -L$(VOBJDIR) -l$(VLIB) -Wl,--end-group -o $@
	$(CXX) $(DEBUG) -Wl,--start-group $(VOBJDIR)/tb/verilator-main.o $(VOBJDIR)/*.o -Wl,--end-group -o $@

DEPS := $(wildcard $(VOBJDIR)/*.d)
ifneq ($(DEPS),)
include $(DEPS)
endif

