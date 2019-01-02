// ALU definitions	-*- mode: Verilog; fill-column: 90 -*-
//
// 2013-01-31 dab	initial version


// ALU commands

// how big a word do I need to contain all the alu commands? !!!
`define aluCMDwidth 6
`define aluCMD `aluCMDwidth-1:0

// the logical operations are 0 to 15 as they're mapped directly from four bits of the
// opcode
`define aluSETZ `aluCMDwidth'd0
`define aluAND `aluCMDwidth'd1
`define aluANDCA `aluCMDwidth'd2
`define aluSETM `aluCMDwidth'd3
`define aluANDCM `aluCMDwidth'd4
`define aluSETA `aluCMDwidth'd5
`define aluXOR `aluCMDwidth'd6
`define aluIOR `aluCMDwidth'd7
`define aluANDCB `aluCMDwidth'd8
`define aluEQV `aluCMDwidth'd9
`define aluSETCA `aluCMDwidth'd10
`define aluORCA `aluCMDwidth'd11
`define aluSETCM `aluCMDwidth'd12
`define aluORCM `aluCMDwidth'd13
`define aluORCB `aluCMDwidth'd14
`define aluSETO `aluCMDwidth'd15

// Halfword operations
`define aluHMN `aluCMDwidth'd16	// LEFT(M),RIGHT(A)
`define aluHMZ `aluCMDwidth'd17	// LEFT(M),0
`define aluHMO `aluCMDwidth'd18	// LEFT(M),-1
`define aluHME `aluCMDwidth'd19	// LEFT(M),sign(A)

`define aluADD `aluCMDwidth'd20	      // A+M
`define aluSUB `aluCMDwidth'd21	      // A-M
`define aluMAGNITUDE `aluCMDwidth'd22 // |M|
`define aluNEGATE `aluCMDwidth'd23    // -M

`define aluLSH `aluCMDwidth'd24	 // A << M (logical)
`define aluASH `aluCMDwidth'd25	 // A << M (arithmetic)
`define aluROT `aluCMDwidth'd26	 // A << M (rotate)
`define aluLSHC `aluCMDwidth'd27 // A,Alow << M (logical)
`define aluASHC `aluCMDwidth'd28 // A,Alow << M (arithmetic)
`define aluROTC `aluCMDwidth'd29 // A,Alow << M (rotate)
`define aluCIRC `aluCMDwidth'd30 // Circulate (not really implemented (yet?))
`define aluJFFO `aluCMDwidth'd31 // calculate number of leading zeros in A

`define aluIBP `aluCMDwidth'd35	    // increment byte pointer in M
`define aluSETAlow `aluCMDwidth'd36 // Swap A and Alow

`define aluAOB `aluCMDwidth'd37	// add one to both halves
`define aluSOB `aluCMDwidth'd38	// subtract one from both halves

`define aluMUL_ADD `aluCMDwidth'd39 // add and shift (for multiplication)
`define aluMUL_SUB `aluCMDwidth'd40 // subtract and shift (for MUL)
`define aluIMUL_SUB `aluCMDwidth'd41 // subtract and shift (for IMUL)
`define aluDIV_MAG72 `aluCMDwidth'd42 // initial 72-bit negate for DIV
`define aluDIV_MAG36 `aluCMDwidth'd43 // initial 36-bit negate for IDIV
`define aluDIV_OP `aluCMDwidth'd44    // add or subtract and ROTC with a sign change
`define aluDIV_FIXR `aluCMDwidth'd45  // un-Rotate A
`define aluDIV_FIXUP `aluCMDwidth'd46  // fixup for negative dividend

`define aluDPB `aluCMDwidth'd47	// do the masking for Deposit Byte
