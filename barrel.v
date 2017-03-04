// Not working code, just jotting down ideas for how to write a barrel shifter

module barrel_shift_36
  (
   input [0:35]  inword,
   input [0:8] 	 shift, // if negative, shift right
   input 	 arith, // shift is arithmetic
   input 	 rotate, // rotate instead of shift
   output [0:35] outword
   );

   //
   // left shifter
   //

   wire [0:35] 	 lterm [0:8];	// intermediate stages in the left shifter
   assign lterm[8] = inword;	// set up input
   assign lterm[7] = shift[8] ? { lterm[8][1:35], rotate ? lterm[8][0:0] : 1'b0 } : lterm[8];
   assign lterm[6] = shift[7] ? { lterm[7][2:35], rotate ? lterm[7][0:1] : 2'b0 } : lterm[7];
   assign lterm[5] = shift[6] ? { lterm[6][4:35], rotate ? lterm[6][0:3] : 4'b0 } : lterm[6];
   assign lterm[4] = shift[5] ? { lterm[5][8:35], rotate ? lterm[5][0:7] : 8'b0 } : lterm[5];
   assign lterm[3] = shift[4] ? { lterm[4][16:35], rotate ? lterm[4][0:15] : 16'b0 } : lterm[4];
   assign lterm[2] = shift[3] ? { lterm[3][32:35], rotate ? lterm[3][0:31] : 32'b0 } : lterm[3];
   assign lterm[1] = shift[2] ? { rotate ? { lterm[2][28:35], lterm[2][0:27] } : 36'b0 } : lterm[2];
   assign lterm[0] = shift[1] ? { rotate ? { lterm[1][20:35], lterm[1][0:19] } : 36'b0 } : lterm[1];

   //
   // right shifter
   //

   // in order to support the largest negative number, we need one more stage in the right
   // shifter than in the left
   wire [0:9] 	 negshift = -shift; // one bit wider to handle the max negative number
   wire [0:35] 	 rterm [0:9];	    // intermediate stages in the right shifter
   wire 	 sign = inword[0];  // sign of input word
   assign rterm[9] = inword;	    // set up input
   assign rterm[8] = negshift[9] ?
		     { rotate ? rterm[9][35:35] : arith ? {1{sign}} : 1'b0, rterm[9][0:34] } :
		     rterm[9];
   assign rterm[7] = negshift[8] ?
		     { rotate ? rterm[8][34:35] : arith ? {2{sign}} : 2'b0, rterm[8][0:33] } :
		     rterm[8];
   assign rterm[6] = negshift[7] ?
		     { rotate ? rterm[7][32:35] : arith ? {4{sign}} : 4'b0, rterm[7][0:31] } :
		     rterm[7];
   assign rterm[5] = negshift[6] ?
		     { rotate ? rterm[6][28:35] : arith ? {8{sign}} : 8'b0, rterm[6][0:27] } :
		     rterm[6];
   assign rterm[4] = negshift[5] ? 
		     { rotate ? rterm[5][20:35] : arith ? {16{sign}} : 16'b0, rterm[5][0:19] } : 
		     rterm[5];
   assign rterm[3] = negshift[4] ? 
		     { rotate ? rterm[4][4:35] : arith ? {32{sign}} : 32'b0, rterm[4][0:3] } : 
		     rterm[4];
   assign rterm[2] = negshift[3] ? 
		     { rotate ? { rterm[3][8:35], rterm[3][0:7] } : arith ? {36{sign}} : 36'b0 } : 
		     rterm[3];
   assign rterm[1] = negshift[2] ? 
		     { rotate ? { rterm[2][16:35], rterm[2][0:15] } : arith ? {36{sign}} : 36'b0 } : 
		     rterm[2];
   assign rterm[0] = negshift[1] ? 
		     { rotate ? { rterm[1][32:35], rterm[1][0:31] } : arith ? {36{sign}} : 36'b0 } : 
		     rterm[1];
   
   // select the result, if the shift is negative, then use the right shifter
   assign outword = shift[0] ? rterm[0] : lterm[0];
   

endmodule // barrel_shift
