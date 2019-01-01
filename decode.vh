//	-*- mode: Verilog; fill-column: 96 -*-
//
// Instruction Decode ROM
//

// Dispatch values
localparam
  Common = 0, // instructions that don't need special microcode handling
  Unassigned = 1,		// unassigned opcode
  Test = 2,			// Test instructions
  Exch = 3,			// EXCH needs an extra cycle
  Jrst = 4,
  Jfcl = 5,
  Jsr = 6,
  Jsp = 7,
  Jsa = 8,
  Jra = 9,
  Xct = 10,
  Pushj = 11,
  Push = 12,
  Pop = 13,
  Popj = 14,
  ShiftC = 15,

  Mul = 20,
  IMul = 21,
  Div = 22,
  IDiv = 23,
  Ldb = 24,
  Dpb = 25,
  Ildb = 26,
  Idpb = 27,
     
  IOread = 28,
  IOwrite = 29,
  MUUO = 31;

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
