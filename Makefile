ICOPTS = -DSIM -Wall -Wno-implicit-dimensions -g2012
SIMOPTS = -N
INCLUDES = kv10.svh alu.svh constants.svh disasm.svh functions.svh io.svh opcodes.svh
LINTOPTS = --lint-only -Wno-LITENDIAN -DLINT


check: alu.check apr.check sram.check mem-sram.check mem.check pag.check cache.check

ver:
	verilator $(LINTOPTS) --top-module apr_tb tb-apr.sv apr.sv barrel.sv pag.sv
#	verilator $(LINTOPTS) apr.v barrel.v
#	verilator $(LINTOPTS) pag.sv


apr.check: apr.sv alu.sv barrel.sv $(INCLUDES)
	iverilog -tnull $(ICOPTS) apr.sv alu.sv decode.sv barrel.sv
alu.check: alu.sv alu.svh barrel.sv
	iverilog -tnull $(ICOPTS) alu.sv barrel.sv
pag.check: pag.sv $(INCLUDES)

tb-apr.vvp: Makefile kv10.hex tb-apr.sv apr.sv alu.sv barrel.sv mem.sv decode.sv pag.sv $(INCLUDES)
	iverilog $(ICOPTS) -o tb-apr.vvp tb-apr.sv apr.sv alu.sv barrel.sv mem.sv decode.sv pag.sv

tb-alu.vvp: tb-alu.v alu.sv barrel.sv alu.svh
	iverilog -o tb-alu.vvp tb-alu.sv alu.sv barrel.sv

tb-alu.lxt: tb-alu.vvp
	./tb-alu.vvp

test.alu: tb-alu.lxt
	./tb-alu.vvp

kv10.hex: kv10.asm kv10.def
	uas kv10.def kv10.asm kv10.hex kv10.lst

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

KV10-PRM.pdf: KV10-PRM.tex
	pdflatex KV10-PRM.tex

.SUFFIXES: .sv .check

# Test compile to check for error
.sv.check:
	iverilog -tnull $(ICOPTS) $<
