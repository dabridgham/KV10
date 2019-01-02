//	-*- mode: Verilog; fill-column: 90 -*-
//
// Barrel Shifter for the kv10 processor
//
// 2017-01 dab	Initial ideas

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

   //
   // left shifter
   //

   wire 	 sign = inword[0];  // sign of input word
   wire 	 right_shift = shift[0];
   wire [0:35] 	 fill = arith ? (right_shift ? {36{sign}} : { sign, {35{1'b0}}}) : {36{1'b0}};
   
   wire [0:35] 	 lterm [0:8];	// intermediate stages in the left shifter

   assign lterm[8] = inword;	// set up input
   assign lterm[7] = shift[8] ? { arith ? lterm[8][0:0] : lterm[8][1:1],
				  lterm[8][2:35], rotate ? lterm[8][0:0] : fill[35:35] } : lterm[8];
   assign lterm[6] = shift[7] ? { arith ? lterm[7][0:0] : lterm[7][2:2],
				  lterm[7][3:35], rotate ? lterm[7][0:1] : fill[34:35] } : lterm[7];
   assign lterm[5] = shift[6] ? { arith ? lterm[6][0:0] : lterm[6][4:4],
				  lterm[6][5:35], rotate ? lterm[6][0:3] : fill[32:35] } : lterm[6];
   assign lterm[4] = shift[5] ? { arith ? lterm[5][0:0] : lterm[5][8:8],
				  lterm[5][9:35], rotate ? lterm[5][0:7] : fill[28:35] } : lterm[5];
   assign lterm[3] = shift[4] ? { arith ? lterm[4][0:0] : lterm[4][16:16],
				  lterm[4][17:35], rotate ? lterm[4][0:15] : fill[20:35] } : lterm[4];
   assign lterm[2] = shift[3] ? { arith ? lterm[3][0:0] : lterm[3][32:32],
				  lterm[3][33:35], rotate ? lterm[3][0:31] : fill[4:35] } : lterm[3];
   assign lterm[1] = shift[2] ? { rotate ? { lterm[2][28:35], lterm[2][0:27] } : fill[0:35] } : lterm[2];
   assign lterm[0] = shift[1] ? { rotate ? { lterm[1][20:35], lterm[1][0:19] } : fill[0:35] } : lterm[1];
   
   // look for an overflow
   wire [0:7] 	 ora;
   assign ora[7] = shift[8] && (lterm[8][1:1] != {1{sign}});
   assign ora[6] = shift[7] && (lterm[7][1:2] != {2{sign}});
   assign ora[5] = shift[6] && (lterm[6][1:4] != {4{sign}});
   assign ora[4] = shift[5] && (lterm[5][1:8] != {8{sign}});
   assign ora[3] = shift[4] && (lterm[4][1:16] != {16{sign}});
   assign ora[2] = shift[3] && (lterm[3][1:32] != {32{sign}});
   assign ora[1] = shift[2] && (lterm[2][1:35] != {35{sign}});
   assign ora[0] = shift[1] && (lterm[1][1:35] != {35{sign}});
   assign overflow = arith && ~right_shift && |ora; // only on a left, arithmetic shift

   //
   // right shifter
   //

   // in order to support the largest negative number, we need one more stage in the right
   // shifter than in the left
   wire [0:9] 	 negshift = -shift; // one bit wider to handle the max negative number
   wire [0:35] 	 rterm [0:9];	    // intermediate stages in the right shifter
   assign rterm[9] = inword;	    // set up input
   assign rterm[8] = negshift[9] ?
		     { rotate ? rterm[9][35:35] : fill[0:0], rterm[9][0:34] } : rterm[9];
   assign rterm[7] = negshift[8] ?
		     { rotate ? rterm[8][34:35] : fill[0:1], rterm[8][0:33] } : rterm[8];
   assign rterm[6] = negshift[7] ?
		     { rotate ? rterm[7][32:35] : fill[0:3], rterm[7][0:31] } : rterm[7];
   assign rterm[5] = negshift[6] ?
		     { rotate ? rterm[6][28:35] : fill[0:7], rterm[6][0:27] } : rterm[6];
   assign rterm[4] = negshift[5] ? 
		     { rotate ? rterm[5][20:35] : fill[0:15], rterm[5][0:19] } : rterm[5];
   assign rterm[3] = negshift[4] ? 
		     { rotate ? rterm[4][4:35] : fill[0:31], rterm[4][0:3] } : rterm[4];
   assign rterm[2] = negshift[3] ? 
		     { rotate ? { rterm[3][8:35], rterm[3][0:7] } : fill[0:35] } : rterm[3];
   assign rterm[1] = negshift[2] ? 
		     { rotate ? { rterm[2][16:35], rterm[2][0:15] } : fill[0:35] } : rterm[2];
   assign rterm[0] = negshift[1] ? 
		     { rotate ? { rterm[1][32:35], rterm[1][0:31] } : fill[0:35] } : rterm[1];
   
   // select the result, if the shift is negative, then use the right shifter
   assign outword = right_shift ? rterm[0] : lterm[0];
   

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
   
   wire [0:71] 	 lterm [0:8];	// intermediate stages in the left shifter

   assign lterm[8] = inword;	// set up input
   assign lterm[7] = shift[8] ? { arith ? lterm[8][0:0] : lterm[8][1:1],
				  lterm[8][2:71], rotate ? lterm[8][0:0] : fill[71:71] } : lterm[8];
   assign lterm[6] = shift[7] ? { arith ? lterm[7][0:0] : lterm[7][2:2],
				  lterm[7][3:71], rotate ? lterm[7][0:1] : fill[70:71] } : lterm[7];
   assign lterm[5] = shift[6] ? { arith ? lterm[6][0:0] : lterm[6][4:4],
				  lterm[6][5:71], rotate ? lterm[6][0:3] : fill[68:71] } : lterm[6];
   assign lterm[4] = shift[5] ? { arith ? lterm[5][0:0] : lterm[5][8:8],
				  lterm[5][9:71], rotate ? lterm[5][0:7] : fill[64:71] } : lterm[5];
   assign lterm[3] = shift[4] ? { arith ? lterm[4][0:0] : lterm[4][16:16],
				  lterm[4][17:71], rotate ? lterm[4][0:15] : fill[56:71] } : lterm[4];
   assign lterm[2] = shift[3] ? { arith ? lterm[3][0:0] : lterm[3][32:32],
				  lterm[3][33:71], rotate ? lterm[3][0:31] : fill[40:71] } : lterm[3];
   assign lterm[1] = shift[2] ? { arith ? lterm[2][0:0] : lterm[2][64:64],
				  lterm[2][65:71], rotate ? lterm[2][0:63] : fill[8:71] } : lterm[2];
   assign lterm[0] = shift[1] ? { rotate ? { lterm[1][56:71], lterm[1][0:55] } : fill[0:71] } : lterm[1];
   
   // look for an overflow
   wire [0:7] 	 ora;
   assign ora[7] = shift[8] && (lterm[8][1:1] != {1{sign}});
   assign ora[6] = shift[7] && (lterm[7][1:2] != {2{sign}});
   assign ora[5] = shift[6] && (lterm[6][1:4] != {4{sign}});
   assign ora[4] = shift[5] && (lterm[5][1:8] != {8{sign}});
   assign ora[3] = shift[4] && (lterm[4][1:16] != {16{sign}});
   assign ora[2] = shift[3] && (lterm[3][1:32] != {32{sign}});
   assign ora[1] = shift[2] && (lterm[2][1:64] != {64{sign}});
   assign ora[0] = shift[1] && (lterm[1][1:71] != {71{sign}});
   assign overflow = arith && ~right_shift && |ora; // only on a left, arithmetic shift

   //
   // right shifter
   //

   // in order to support the largest negative number, we need one more stage in the right
   // shifter than in the left
   wire [0:9] 	 negshift = -shift; // one bit wider to handle the max negative number
   wire [0:71] 	 rterm [0:9];	    // intermediate stages in the right shifter
   assign rterm[9] = inword;	    // set up input
   assign rterm[8] = negshift[9] ?
		     { rotate ? rterm[9][71:71] : fill[0:0], rterm[9][0:70] } : rterm[9];
   assign rterm[7] = negshift[8] ?
		     { rotate ? rterm[8][70:71] : fill[0:1], rterm[8][0:69] } : rterm[8];
   assign rterm[6] = negshift[7] ?
		     { rotate ? rterm[7][68:71] : fill[0:3], rterm[7][0:67] } : rterm[7];
   assign rterm[5] = negshift[6] ?
		     { rotate ? rterm[6][64:71] : fill[0:7], rterm[6][0:63] } : rterm[6];
   assign rterm[4] = negshift[5] ? 
		     { rotate ? rterm[5][56:71] : fill[0:15], rterm[5][0:55] } : rterm[5];
   assign rterm[3] = negshift[4] ? 
		     { rotate ? rterm[4][40:71] : fill[0:31], rterm[4][0:39] } : rterm[4];
   assign rterm[2] = negshift[3] ? 
		     { rotate ? rterm[3][8:71] : fill[0:63], rterm[3][0:7] } : rterm[3];
   assign rterm[1] = negshift[2] ? 
		     { rotate ? { rterm[2][16:71], rterm[2][0:15] } : fill[0:71] } : rterm[2];
   assign rterm[0] = negshift[1] ? 
		     { rotate ? { rterm[1][32:71], rterm[1][0:31] } : fill[0:71] } : rterm[1];
   
   // select the result, if the shift is negative, then use the right shifter
   assign outword = right_shift ? rterm[0] : lterm[0];
   

endmodule
