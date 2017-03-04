ICOPTS = -DSIM -Wall
SIMOPTS = -N
INCLUDES =  alu.vh constants.vh disasm.vh functions.vh io.vh opcodes.vh

ALL: alu.check apr.check sram.check mem-sram.check mem.check pag.check cache.check

apr.check: apr.v alu.v $(INCLUDES)
	iverilog -tnull $(ICOPTS) apr.v alu.v
alu.check: alu.v alu.vh
pag.check: pag.v $(INCLUDES)

tb-apr.vvp: Makefile tb-apr.v apr.v alu.v pag.v cache.v mem.v $(INCLUDES)
	iverilog $(ICOPTS) -o tb-apr.vvp tb-apr.v apr.v alu.v pag.v cache.v mem.v

tb-alu.vvp: tb-alu.v alu.v alu.vh
	iverilog -o tb-alu.vvp tb-alu.v alu.v

tb-alu.lxt: tb-alu.vvp
	./tb-alu.vvp

save:
	cp -a Makefile *.v *.vh saved

test: test.aa test.ab test.ac test.ad test.ae test.af test.ag test.ai test.aj test.ak test.al test.am

test.aa: tb-apr.vvp
	./tb-apr.vvp $(SIMOPTS) +file=dgcaa.mif
test.ab: tb-apr.vvp
	./tb-apr.vvp $(SIMOPTS) +file=dgcab.mif
test.ac: tb-apr.vvp
	./tb-apr.vvp $(SIMOPTS) +file=dgcac.mif
test.ad: tb-apr.vvp
	./tb-apr.vvp $(SIMOPTS) +file=dgcad.mif
test.ae: tb-apr.vvp
	./tb-apr.vvp $(SIMOPTS) +file=dgcae.mif
test.af: tb-apr.vvp
	./tb-apr.vvp $(SIMOPTS) +file=dgcaf.mif
test.ag: tb-apr.vvp
	./tb-apr.vvp $(SIMOPTS) +file=dgcag.mif
test.ah: tb-apr.vvp
	./tb-apr.vvp $(SIMOPTS) +file=dgcah.mif
test.ai: tb-apr.vvp
	./tb-apr.vvp $(SIMOPTS) +file=dgcai.mif
test.aj: tb-apr.vvp
	./tb-apr.vvp $(SIMOPTS) +file=dgcaj.mif
test.ak: tb-apr.vvp
	./tb-apr.vvp $(SIMOPTS) +file=dgcak.mif
test.al: tb-apr.vvp
	./tb-apr.vvp $(SIMOPTS) +file=dgcal.mif
test.am: tb-apr.vvp
	./tb-apr.vvp $(SIMOPTS) +file=dgcam.mif

test.qa: tb-apr.vvp
	./tb-apr.vvp $(SIMOPTS) +file=dabqa.mif


.SUFFIXES: .v .check

# Test compile to check for error
.v.check:
	iverilog -tnull $(ICOPTS) $<
