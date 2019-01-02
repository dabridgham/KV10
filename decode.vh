//	-*- mode: Verilog; fill-column: 96 -*-
//
// Instruction Decode ROM
//

// Dispatch values
localparam
  dCommon = 0, // instructions that don't need special microcode handling
  dUnassigned = 1,		// unassigned opcode
  dTEST = 2,			// Test instructions
  dEXCH = 3,			// EXCH needs an extra cycle
  dJRST = 4,
  dJFCL = 5,
  dJSR = 6,
  dJSP = 7,
  dJSA = 8,
  dJRA = 9,
  dXCT = 10,
  dPUSHJ = 11,
  dPUSH = 12,
  dPOP = 13,
  dPOPJ = 14,
  dSHIFTC = 15,
  dJFFO = 16,
  dBLT = 17,

  dMUL = 20,
  dIMUL = 21,
  dDIV = 22,
  dIDIV = 23,
  dLDB = 24,
  dDPB = 25,
  dILDB = 26,
  dIDPB = 27,
     
  dIOread = 28,
  dIOwrite = 29,

  dMUUO = 31;

// Skip conditions
localparam
  skip_never = 3'o0,
  skipl = 3'o1,
  skipe = 3'o2,
  skiple = 3'o3,
  skipa = 3'o4,
  skipge = 3'o5,
  skipn = 3'o6,
  skipg = 3'o7;
