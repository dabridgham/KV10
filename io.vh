//	-*- mode: Verilog; fill-column: 90 -*-
//
// PDP-10 I/O Device definitions

`ifdef NOTDEF
// I/O operations put the Device Number and whether it's a condition or data register in
// the memory address.  The 1 bit in bit 1 is a hack to make the read and write
// multiplexors not think we're accessing the accumulators and so route the proper ack
// signal into the APR.
function [`ADDR] IO_ENCODE;
   input [0:6] dev;
   input       con;
   IO_ENCODE = { con, 1'b1, 9'b0, dev };
endfunction // IO_ENCODE
`endif

function [0:`DEVSIZE] IO_COND;
   input [`DEVICE] dev;
   IO_COND = { dev, 1'b1 };
endfunction

function [0:`DEVSIZE] IO_DATA;
   input [`DEVICE] dev;
   IO_DATA = { dev, 1'b0 };
endfunction


// Device Numbers (these are divided by 4)
localparam
  APR = 7'o000,			// 000
  PI  = 7'o001,			// 004
  PAG = 7'o010;			// 040

// The APR Device Condition Codes.  Since these will be compared with E, add 18 to each.
`define APR_SSE 18		// set soft error
`define APR_RIO 19		// reset the I/O system
`define APR_CSE 20		// clear soft error
`define APR_SF 21		// set the flags in the mask
`define APR_CF 22		// clear the flags in the mask
`define APR_LE 23 // load the error interrupt enables from the mask and load the error interrupt PI from IA
`define APR_LT 24 // load the trap interrupt enables from the mask and load the trap interrupt PI from IA
`define APR_MHE 25	  // mask for hard error enables and/or flags
`define APR_MSE 26	  // mask for soft error enables and/or flags
`define APR_ME2 27	  // mask for executive mode trap-2 enables and/or flags
`define APR_ME1 28	  // mask for executive mode trap-1 error enables and/or flags
`define APR_MU2 29	  // mask for user mode trap-2 error enables and/or flags
`define APR_MU1 30	  // mask for user mode trap-1 error enables and/or flags
`define APR_IA 33:35	  // the value for PI assignments for error and/or trap interrupts

// The PI Device Condition Codes
`ifdef NOTDEF
`define PI_CSR 22		// Clear the software request(s) specified in the mask
`define PI_RPI 23		// Reset the PI system
`define PI_SSR 24		// Set the software request(s) specified in the mask
`define PI_SLE 25		// Set the level enable bit(s) specified in the mask
`define PI_CLE 26		// Clear the level enable bit(s) specified in the mask
`define PI_CGE 27		// Clear the global enable
`define PI_SGE 28		// Set the global enable
`else
localparam
  PI_CSR = 22,		// Clear the software request(s) specified in the mask
  PI_RPI = 23,		// Reset the PI system
  PI_SSR = 24,		// Set the software request(s) specified in the mask
  PI_SLE = 25,		// Set the level enable bit(s) specified in the mask
  PI_CLE = 26,		// Clear the level enable bit(s) specified in the mask
  PI_CGE = 27,		// Clear the global enable
  PI_SGE = 28;		// Set the global enable
`endif
`define PI_Mask 29:35		// Level mask bits

