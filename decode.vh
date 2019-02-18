//	-*- mode: Verilog; fill-column: 96 -*-
//
// Instruction Decode ROM
//

// Dispatch values
localparam
  dCommon = 5'd0, // instructions that don't need special microcode handling
  dUnassigned = 5'd1,		// unassigned opcode
  dTEST = 5'd2,			// Test instructions
  dEXCH = 5'd3,			// EXCH needs an extra cycle
  dJRST = 5'd4,
  dJFCL = 5'd5,
  dJSR = 5'd6,
  dJSP = 5'd7,
  dJSA = 5'd8,
  dJRA = 5'd9,
  dXCT = 5'd10,
  dPUSHJ = 5'd11,
  dPUSH = 5'd12,
  dPOP = 5'd13,
  dPOPJ = 5'd14,
  dSHIFTC = 5'd15,
  dJFFO = 5'd16,
  dBLT = 5'd17,

  dMUL = 5'd20,
  dIMUL = 5'd21,
  dDIV = 5'd22,
  dIDIV = 5'd23,
  dLDB = 5'd24,
  dDPB = 5'd25,
  dILDB = 5'd26,
  dIDPB = 5'd27,
     
  dIOread = 5'd28,
  dIOwrite = 5'd29,

  dMUUO = 5'd31;

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
