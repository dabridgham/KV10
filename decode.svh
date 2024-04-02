//	-*- mode: Verilog; fill-column: 96 -*-
//
// Instruction Decode ROM
//

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
