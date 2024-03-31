// ALU definitions	-*- mode: Verilog; fill-column: 90 -*-


// ALU commands

// how big a word do I need to contain all the alu commands? !!!
`define aluCMDwidth 6
`define aluCMD `aluCMDwidth-1:0

 // Use the aluCMD that was previously saved
`define aluSAVED `aluCMDwidth'd0

`define aluIBP `aluCMDwidth'd01	    // increment byte pointer in M
`define aluSETAlow `aluCMDwidth'd02 // Swap A and Alow

`define aluAOB `aluCMDwidth'd03	// add one to both halves
`define aluSOB `aluCMDwidth'd04	// subtract one from both halves

`define aluMUL_ADD `aluCMDwidth'd05 // add and shift (for multiplication)
`define aluMUL_SUB `aluCMDwidth'd06 // subtract and shift (for MUL)
`define aluIMUL_SUB `aluCMDwidth'd07 // subtract and shift (for IMUL)
`define aluDIV_MAG72 `aluCMDwidth'd08 // initial 72-bit negate for DIV
`define aluDIV_MAG36 `aluCMDwidth'd09 // initial 36-bit negate for IDIV
`define aluDIV_OP `aluCMDwidth'd10    // add or subtract and ROTC with a sign change
`define aluDIV_FIXR `aluCMDwidth'd11  // un-Rotate A
`define aluDIV_FIXUP `aluCMDwidth'd12  // fixup for negative dividend

`define aluDPB `aluCMDwidth'd13	  // do the masking for Deposit Byte

// Halfword operations
`define aluHLL `aluCMDwidth'd16 // LEFT(M),RIGHT(A)
`define aluHLR `aluCMDwidth'd17 // LEFT(A),LEFT(M)


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
`define aluJFFO `aluCMDwidth'd31 // calculate number of leading zeros in M

// the logical operations
`define aluSETZ `aluCMDwidth'd32   // 0
`define aluAND `aluCMDwidth'd33	   // A & M
`define aluANDCA `aluCMDwidth'd34  // ~A & M
`define aluSETM `aluCMDwidth'd35   // M
`define aluANDCM `aluCMDwidth'd36  // A & ~M
`define aluSETA `aluCMDwidth'd37   // A
`define aluXOR `aluCMDwidth'd38	   // A xor M
`define aluIOR `aluCMDwidth'd39	   // A | M
`define aluANDCB `aluCMDwidth'd40  // ~A & ~M
`define aluEQV `aluCMDwidth'd41	   // ~(A xor M)
`define aluSETCA `aluCMDwidth'd42  // ~A
`define aluORCA `aluCMDwidth'd43   // ~A | M
`define aluSETCM `aluCMDwidth'd44  // ~M
`define aluORCM `aluCMDwidth'd45   // A | ~M
`define aluORCB `aluCMDwidth'd46   // ~A | ~M
`define aluSETO `aluCMDwidth'd47   // -1

`define aluBPMASK `aluCMDwidth'd48 // bitmask from the size field of a byte pointer in M
`define aluBPSHIFT `aluCMDwidth'd49 // shift from the pointer field of a byte pointer in M
