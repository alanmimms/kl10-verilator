SVFILES = apr.sv ccl.sv ccw.sv cha.sv chc.sv chd.sv chx.sv clk.sv	\
con.sv cra.sv crc.sv crm.sv csh.sv ctl.sv decoder.sv dte.sv ebox.sv	\
edp.sv ir.sv mb0.sv mbc.sv mbox.sv mbx.sv mbz.sv mc10179.sv		\
mc10181.sv mcl.sv memory.sv mt0.sv mtr.sv mux2x4.sv mux4x2.sv mux.sv	\
pag.sv pi.sv pma.sv priority-encoder8.sv scd.sv shm.sv top.sv		\
universal-counter.sv universal-shift-register.sv vma.sv \
tb/sim-mem.sv


SVHFILES = ebox.svh
CPPFILES = tb/verilator-main.cc
HPPFILES = tb/testbench.h

all:	$(SVFILES) $(SVHFILES) $(CPPFILES) $(HPPFILES)
	verilator \
		-Wno-UNOPTFLAT -Wno-LITENDIAN \
		--default-language 1800-2017 +1800-2017ext+sv \
		-DTB -DKL10PV_TB \
		--trace --timescale-override 1ns/1ps \
		tb/verilator-main.cc \
		$(SVFILES) \
		--top-module top \
		--cc --build --exe -o kl10pvtb
