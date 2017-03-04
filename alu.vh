// ALU defines	-*- mode: Verilog; fill-column: 90 -*-
//
// 2013-01-31 dab	initial version


// ALU commands

// the logical operations are 0 to 15 as they're mapped directly from four bits of the
// opcode
`define aluSETZ 0
`define aluAND 1
`define aluANDCA 2
`define aluSETM 3
`define aluANDCM 4
`define aluSETA 5
`define aluXOR 6
`define aluIOR 7
`define aluANDCB 8
`define aluEQV 9
`define aluSETCA 10
`define aluORCA 11
`define aluSETCM 12
`define aluORCM 13
`define aluORCB 14
`define aluSETO 15

`ifdef NOTDEF
// as these half-word ALU commands are extracted directly from the opcode, they must be in
// this order and aluHLL mod 4 must equal 0
`define aluHLL 16
`define aluHRL 17
`define aluHRR 18
`define aluHLR 19
`define aluHLLx 20		// sign-extend
`define aluHRLx 21
`define aluHRRx 22
`define aluHLRx 23
`else // !`ifdef NOTDEF
 `define aluLL1 16
 `define aluLL2 17
 `define aluRL1 18
 `define aluRL2 19

 `define aluRR1 17		// RR1 = LL2
 `define aluRR2 16		// RR2 = LL1
 `define aluLR1 19		// LR1 = RL2 iff op1 and op2 are swapped
 `define aluLR2 18		// LR2 = RL1 iff op1 and op2 are swapped

 `define aluRDUP2 20
`endif

`define aluADD 24
`define aluSUB 25

`define aluLSH 29
`define aluASH 30
`define aluROT 31

`define aluLSHC 33
`define aluASHC 34
`define aluROTC 35
`define aluCIRC 36

`define aluMAGNITUDE 37		// find magnitude of op2
`define aluSWAP 38		// swap half-words in op2
`define aluNEGATE 39		// negate op2

`define aluIBP 40		// increment byte pointer in op2

`define aluAOB 43		// add one to both halves
`define aluSOB 44		// subtract one from both halves

// how big a word do I need to contain all the alu commands
`define aluCMDwidth 6

