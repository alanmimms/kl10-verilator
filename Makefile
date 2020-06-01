SVFILES = apr.sv ccl.sv ccw.sv cha.sv chc.sv chd.sv chx.sv clk.sv	\
con.sv cra.sv crc.sv crm.sv csh.sv ctl.sv decoder.sv dte.sv ebox.sv	\
edp.sv ir.sv mb0.sv mbc.sv mbox.sv mbx.sv mbz.sv mc10179.sv		\
mc10181.sv mcl.sv memory.sv mt0.sv mtr.sv mux2x4.sv mux4x2.sv mux.sv	\
pag.sv pi.sv pma.sv pri8.sv scd.sv shm.sv top.sv ucr4.sv usr4.sv	\
vma.sv tb/sim-mem.sv

DEBUG = -CFLAGS -g -LDFLAGS -g
#OPTIMIZE = "-O3 --x-assign fast --x-initial fast"
#OPTIMIZE = -CFLAGS -O3 -O3
OPTIMIZE =
SVHFILES = ebox.svh
CPPFILES = tb/verilator-main.cc
CFILES = dte.c
HPPFILES = tb/testbench.h

KILL_WARNINGS = \
		-Wno-LITENDIAN \
		-Wno-UNOPTFLAT


all:	$(SVFILES) $(SVHFILES) $(CPPFILES) $(HPPFILES)
	verilator \
		$(KILL_WARNINGS) \
		--default-language 1800-2017 +1800-2017ext+sv \
		-DTB -DKL10PV_TB \
		--trace --trace-structs \
		--timescale-override 1ns/1ps \
		tb/verilator-main.cc \
		$(SVFILES) \
		$(CPPFILES) \
		$(CFILES) \
		--top-module top \
		--cc --build --exe -j 4 \
		$(DEBUG) $(OPTIMIZE) \
		-o kl10pvtb

clean:
	rm -rf obj_dir
