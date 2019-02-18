//	-*- mode: Verilog; fill-column: 90 -*-
//
// Barrel Shifter for the kv10 processor
//

// verilator lint_off LITENDIAN

`timescale 1 ns / 1 ns

module barrel_shift_36
  (
   input [0:35]  inword,
   input [0:8] 	 shift, // if negative, shift right
   input 	 arith, // shift is arithmetic
   input 	 rotate, // rotate instead of shift
   output [0:35] outword,
   output 	 overflow // if we shift out significant bits during an arithmetic left shift
   );

   function [0:35] LSHL;	// Logical Shift Left
      input [0:35] v;
      input [0:8]  shift;
      LSHL = v << shift;
   endfunction
   function [0:35] ASHL;	// Arithmetic Shift Left
      input [0:35] v;
      input [0:8]  shift;
      ASHL = { v[0], v[1:35] <<< shift};
   endfunction
   function [0:35] ROTL;	// Rotate Left
      input [0:35] v;
      input [0:8]  shift;
      reg [0:8]    mshift;
      reg [0:71]   dv;
      begin
	 mshift = shift % 36;
	 dv = {v, v};
	 ROTL = dv[mshift+:36];
      end
   endfunction
      

   //
   // left shifter
   //

   wire 	 sign = inword[0];  // sign of input word
   wire 	 right_shift = shift[0];
   wire [0:35] 	 fill = arith ? (right_shift ? {36{sign}} : { sign, {35{1'b0}}}) : {36{1'b0}};
   
   // intermediate stages in the left shifter
   wire [0:35] lterm8 = inword;	// set up input
`ifdef NOTDEF
   wire [0:35] lterm7 = shift[8] ? { arith ? lterm8[0:0] : lterm8[1:1],
				  lterm8[2:35], rotate ? lterm8[0:0] : fill[35:35] } : lterm8;
   
   wire [0:35] lterm6 = shift[7] ? { arith ? lterm7[0:0] : lterm7[2:2],
				  lterm7[3:35], rotate ? lterm7[0:1] : fill[34:35] } : lterm7;
   wire [0:35] lterm5 = shift[6] ? { arith ? lterm6[0:0] : lterm6[4:4],
				  lterm6[5:35], rotate ? lterm6[0:3] : fill[32:35] } : lterm6;
   wire [0:35] lterm4 = shift[5] ? { arith ? lterm5[0:0] : lterm5[8:8],
				  lterm5[9:35], rotate ? lterm5[0:7] : fill[28:35] } : lterm5;
   wire [0:35] lterm3 = shift[4] ? { arith ? lterm4[0:0] : lterm4[16:16],
				  lterm4[17:35], rotate ? lterm4[0:15] : fill[20:35] } : lterm4;
   wire [0:35] lterm2 = shift[3] ? { arith ? lterm3[0:0] : lterm3[32:32],
				  lterm3[33:35], rotate ? lterm3[0:31] : fill[4:35] } : lterm3;
   wire [0:35] lterm1 = shift[2] ? { rotate ? { lterm2[28:35], lterm2[0:27] } : fill[0:35] } : lterm2;
   wire [0:35] lterm0 = shift[1] ? { rotate ? { lterm1[20:35], lterm1[0:19] } : fill[0:35] } : lterm1;
`else
   wire [0:35] lterm7 = shift[8] ? rotate ? ROTL(lterm8, 1) : arith ? ASHL(lterm8, 1) : LSHL(lterm8, 1) : lterm8;
   wire [0:35] lterm6 = shift[7] ? rotate ? ROTL(lterm7, 2) : arith ? ASHL(lterm7, 2) : LSHL(lterm7, 2) : lterm7;
   wire [0:35] lterm5 = shift[6] ? rotate ? ROTL(lterm6, 4) : arith ? ASHL(lterm6, 4) : LSHL(lterm6, 4) : lterm6;
   wire [0:35] lterm4 = shift[5] ? rotate ? ROTL(lterm5, 8) : arith ? ASHL(lterm5, 8) : LSHL(lterm5, 8) : lterm5;
   wire [0:35] lterm3 = shift[4] ? rotate ? ROTL(lterm4, 16) : arith ? ASHL(lterm4, 16) : LSHL(lterm4, 16) : lterm4;
   wire [0:35] lterm2 = shift[3] ? rotate ? ROTL(lterm3, 32) : arith ? ASHL(lterm3, 32) : LSHL(lterm3, 32) : lterm3;
   wire [0:35] lterm1 = shift[2] ? rotate ? ROTL(lterm2, 64) : arith ? ASHL(lterm2, 64) : LSHL(lterm2, 64) : lterm2;
   wire [0:35] lterm0 = shift[1] ? rotate ? ROTL(lterm1, 128) : arith ? ASHL(lterm1, 128) : LSHL(lterm1, 128) : lterm1;
`endif //  `ifdef NOTDEF
   
   // look for an overflow
   wire [0:7] 	 ora;
   assign ora[7] = shift[8] && (lterm8[1:1] != {1{sign}});
   assign ora[6] = shift[7] && (lterm7[1:2] != {2{sign}});
   assign ora[5] = shift[6] && (lterm6[1:4] != {4{sign}});
   assign ora[4] = shift[5] && (lterm5[1:8] != {8{sign}});
   assign ora[3] = shift[4] && (lterm4[1:16] != {16{sign}});
   assign ora[2] = shift[3] && (lterm3[1:32] != {32{sign}});
   assign ora[1] = shift[2] && (lterm2[1:35] != {35{sign}});
   assign ora[0] = shift[1] && (lterm1[1:35] != {35{sign}});
   assign overflow = arith && ~right_shift && |ora; // only on a left, arithmetic shift

   //
   // right shifter
   //

   // in order to support the largest negative number, we need one more stage in the right
   // shifter than in the left
   wire [0:8] 	 negshift = -shift;
   // intermediate stages in the right shifter
   wire [0:35] rterm9 = inword;	    // set up input
   wire [0:35] rterm8 = negshift[8] ?
		     { rotate ? rterm9[35:35] : fill[0:0], rterm9[0:34] } : rterm9;
   wire [0:35] rterm7 = negshift[7] ?
		     { rotate ? rterm8[34:35] : fill[0:1], rterm8[0:33] } : rterm8;
   wire [0:35] rterm6 = negshift[6] ?
		     { rotate ? rterm7[32:35] : fill[0:3], rterm7[0:31] } : rterm7;
   wire [0:35] rterm5 = negshift[5] ?
		     { rotate ? rterm6[28:35] : fill[0:7], rterm6[0:27] } : rterm6;
   wire [0:35] rterm4 = negshift[4] ? 
		     { rotate ? rterm5[20:35] : fill[0:15], rterm5[0:19] } : rterm5;
   wire [0:35] rterm3 = negshift[3] ? 
		     { rotate ? rterm4[4:35] : fill[0:31], rterm4[0:3] } : rterm4;
   wire [0:35] rterm2 = negshift[2] ? 
		     { rotate ? { rterm3[8:35], rterm3[0:7] } : fill[0:35] } : rterm3;
   wire [0:35] rterm1 = negshift[1] ? 
		     { rotate ? { rterm2[16:35], rterm2[0:15] } : fill[0:35] } : rterm2;
   wire [0:35] rterm0 = negshift[0] ? 
		     { rotate ? { rterm1[32:35], rterm1[0:31] } : fill[0:35] } : rterm1;
   
   // select the result, if the shift is negative, then use the right shifter
   assign outword = right_shift ? rterm0 : lterm0;

endmodule

module barrel_shift_72
  (
   input [0:71]  inword,
   input [0:8] 	 shift, // if negative, shift right
   input 	 arith, // shift is arithmetic
   input 	 rotate, // rotate instead of shift
   output [0:71] outword,
   output 	 overflow // if we shift out significant bits during an arithmetic left shift
   );

   //
   // left shifter
   //

   wire 	 sign = inword[0];  // sign of input word
   wire 	 right_shift = shift[0];
   wire [0:71] 	 fill = arith ? (right_shift ? {72{sign}} : { sign, {71{1'b0}}}) : {72{1'b0}};
   // intermediate stages in the left shifter
   wire [0:71] 	 lterm8 = inword;	// set up input
   wire [0:71] lterm7 = shift[8] ? { arith ? lterm8[0:0] : lterm8[1:1],
				  lterm8[2:71], rotate ? lterm8[0:0] : fill[71:71] } : lterm8;
   wire [0:71] lterm6 = shift[7] ? { arith ? lterm7[0:0] : lterm7[2:2],
				  lterm7[3:71], rotate ? lterm7[0:1] : fill[70:71] } : lterm7;
   wire [0:71] lterm5 = shift[6] ? { arith ? lterm6[0:0] : lterm6[4:4],
				  lterm6[5:71], rotate ? lterm6[0:3] : fill[68:71] } : lterm6;
   wire [0:71] lterm4 = shift[5] ? { arith ? lterm5[0:0] : lterm5[8:8],
				  lterm5[9:71], rotate ? lterm5[0:7] : fill[64:71] } : lterm5;
   wire [0:71] lterm3 = shift[4] ? { arith ? lterm4[0:0] : lterm4[16:16],
				  lterm4[17:71], rotate ? lterm4[0:15] : fill[56:71] } : lterm4;
   wire [0:71] lterm2 = shift[3] ? { arith ? lterm3[0:0] : lterm3[32:32],
				  lterm3[33:71], rotate ? lterm3[0:31] : fill[40:71] } : lterm3;
   wire [0:71] lterm1 = shift[2] ? { arith ? lterm2[0:0] : lterm2[64:64],
				  lterm2[65:71], rotate ? lterm2[0:63] : fill[8:71] } : lterm2;
   wire [0:71] lterm0 = shift[1] ? { rotate ? { lterm1[56:71], lterm1[0:55] } : fill[0:71] } : lterm1;
   
   // look for an overflow
   wire [0:7] 	 ora;
   assign ora[7] = shift[8] && (lterm8[1:1] != {1{sign}});
   assign ora[6] = shift[7] && (lterm7[1:2] != {2{sign}});
   assign ora[5] = shift[6] && (lterm6[1:4] != {4{sign}});
   assign ora[4] = shift[5] && (lterm5[1:8] != {8{sign}});
   assign ora[3] = shift[4] && (lterm4[1:16] != {16{sign}});
   assign ora[2] = shift[3] && (lterm3[1:32] != {32{sign}});
   assign ora[1] = shift[2] && (lterm2[1:64] != {64{sign}});
   assign ora[0] = shift[1] && (lterm1[1:71] != {71{sign}});
   assign overflow = arith && ~right_shift && |ora; // only on a left, arithmetic shift

   //
   // right shifter
   //

   // in order to support the largest negative number, we need one more stage in the right
   // shifter than in the left
   wire [0:8] 	 negshift = -shift;
   // intermediate stages in the right shifter
   wire [0:71] rterm9 = inword;	    // set up input
   wire [0:71] rterm8 = negshift[8] ?
		     { rotate ? rterm9[71:71] : fill[0:0], rterm9[0:70] } : rterm9;
   wire [0:71] rterm7 = negshift[7] ?
		     { rotate ? rterm8[70:71] : fill[0:1], rterm8[0:69] } : rterm8;
   wire [0:71] rterm6 = negshift[6] ?
		     { rotate ? rterm7[68:71] : fill[0:3], rterm7[0:67] } : rterm7;
   wire [0:71] rterm5 = negshift[5] ?
		     { rotate ? rterm6[64:71] : fill[0:7], rterm6[0:63] } : rterm6;
   wire [0:71] rterm4 = negshift[4] ? 
		     { rotate ? rterm5[56:71] : fill[0:15], rterm5[0:55] } : rterm5;
   wire [0:71] rterm3 = negshift[3] ? 
		     { rotate ? rterm4[40:71] : fill[0:31], rterm4[0:39] } : rterm4;
   wire [0:71] rterm2 = negshift[2] ? 
		     { rotate ? rterm3[8:71] : fill[0:63], rterm3[0:7] } : rterm3;
   wire [0:71] rterm1 = negshift[1] ? 
		     { rotate ? { rterm2[16:71], rterm2[0:15] } : fill[0:71] } : rterm2;
   wire [0:71] rterm0 = negshift[0] ? 
		     { rotate ? { rterm1[32:71], rterm1[0:31] } : fill[0:71] } : rterm1;
   
   // select the result, if the shift is negative, then use the right shifter
   assign outword = right_shift ? rterm0 : lterm0;
   

endmodule
