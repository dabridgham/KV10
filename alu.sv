//	-*- mode: Verilog; fill-column: 90 -*-
//
// Arithmetic and Logic Unit for kv10 processor


// verilator lint_off LITENDIAN
// this program calls Big Endian bit fields Little Endian, for some reason, and flags them as errors.

`timescale 1 ns / 1 ns

`include "constants.svh"
`include "alu.svh"

module alu
   (
    input [0:`aluCMDwidth-1] command,
    input [`WORD] 	     Alow, // doubleword operations are A,,Alow
    input [`WORD] 	     A, // first operand
    input [`WORD] 	     M, // second operand
    input 		     f, // shift input for multiplication
    input 		     div_neg, // dividend was negative 

    output reg [`WORD] 	     resultlow,
    output reg [`WORD] 	     result,
    output reg 		     carry0,
    output reg 		     carry1,
    output reg 		     overflow,
    output 		     zero
    );
   
`include "functions.svh"

   // the adder - The pdp10 has two carry bits, the carry out of bit1
   // into bit0 and the carry out of bit0
   wire 		     c0, c1;
   wire [0:`WORDSIZE-2]      sum_low;
   wire [0:1] 		     sum_high;
   wire [`WORD] 	     sum;
   assign { c1, sum_low } = A[1:`WORDSIZE-1] + M[1:`WORDSIZE-1];
   assign sum_high = A[0] + M[0] + c1;
   assign { c0, sum } = { sum_high, sum_low };
   
   // subtraction - similarly, two borrow bits
   wire 		     b0, b1;
   wire [0:`WORDSIZE-2]      dif_low;
   wire [0:1] 		     dif_high;
   wire [`WORD] 	     dif;
   assign { b1, dif_low } = A[1:`WORDSIZE-1] - M[1:`WORDSIZE-1];
   assign dif_high = A[0] - M[0] - b1;
   assign { b0, dif } = { dif_high, dif_low };

   // invert A and M as these are used in several places
   wire [`WORD] 	     notA = ~A;
   wire [`WORD] 	     notM = ~M;

   // negate M
   wire 		     n0, n1;
   wire [0:`WORDSIZE-2]      neg_low;
   wire [0:1] 		     neg_high;
   wire [`WORD] 	     neg;
   assign { n1, neg_low } = 1'b1 + notM[1:`WORDSIZE-1];
   assign neg_high = notM[0] + n1;
   assign { n0, neg } = { neg_high, neg_low };

   // negate A
   wire [`WORD] 	     Aneg = -A;

   // negate A,Alow
   wire [`DWORD] 	     ACneg = -{ A[0], A, Alow[1:35] };

   assign zero = (result == 0);

   // connect to the barrel shifters
   reg 			     shift_arith, shift_rotate;
   wire [0:8] 		     shift_amount = { M[18], M[28:35] };
   wire 		     shift36_overflow;
   wire [`WORD] 	     shift36_out;
   barrel_shift_36 shift36
     (.inword(A), .shift(shift_amount),
      .arith(shift_arith), .rotate(shift_rotate),
      .outword(shift36_out), .overflow(shift36_overflow));

   reg [`DWORD] 	     shift72_in;
   wire 		     shift72_overflow;
   wire [`DWORD] 	     shift72_out;
   barrel_shift_72 shift72
     (.inword(shift72_in), .shift(shift_amount), 
      .arith(shift_arith), .rotate(shift_rotate),
      .outword(shift72_out), .overflow(shift72_overflow));

   // In the final fixup step in division, I need to do a final add or subtract if the
   // remainder came out negative
   reg [`WORD] 		     posR;
   always @(*)
     if (NEGATIVE(A))
       posR = NEGATIVE(M) ? dif : sum;
     else
       posR = A;

	
   // Add one to both halves.  This is written KI10 style; that is, the
   // right half does not overflow into the left.
   wire 		     aovr;
   wire [`HWORD] 	     al, ar;
   wire [`WORD] 	     aob;
   assign { aovr, al } = LEFT(M) + `HALFONE;
   assign ar = RIGHT(M) + `HALFONE;
   assign aob = { al, ar };

   // Subtract one from both halves.  This is written KI10 style; that is, the
   // right half does not overflow into the left.
   wire 		     sovr;
   wire [`HWORD] 	     sl, sr;
   wire [`WORD] 	     sob;
   assign { sovr, sl } = LEFT(M) - `HALFONE;
   assign sr = RIGHT(M) - `HALFONE;
   assign sob = { sl, sr };




   // mostly a mux to connect the outputs to the right signal lines
   always @(*) begin
      resultlow = Alow;
      result = A;
      carry0 = 0;
      carry1 = 0;
      overflow = 0;
      shift_arith = 0;
      shift_rotate = 0;
      shift72_in = { A, Alow };
      
      // verilator lint_off CASEINCOMPLETE
      case (command)		// synopsys full_case parallel_case
      // verilator lint_on CASEINCOMPLETE

	// logical instructions
	`aluSETZ:	result = `ZERO;
	`aluAND:	result = A & M;
	`aluSETM:	result = M;
	`aluANDCA:	result = notA & M;

	`aluANDCM:	result = A & notM;
	`aluSETA:	result = A;
	`aluXOR:	result = A ^ M;
	`aluIOR:	result = A | M;

	`aluANDCB:	result = notA & notM;
	`aluEQV:	result = ~(A ^ M);
	`aluSETCA:	result = notA;
	`aluORCA:	result = notA | M;

	`aluSETCM:	result = notM;
	`aluORCM:	result = A | notM;
	`aluORCB:	result = notA | notM;
	`aluSETO:	result = `MINUSONE;
	
	// Halfword moves
	`aluHLL: result = { LEFT(M), RIGHT(A) };
	`aluHLR: result = { LEFT(A), LEFT(M) };

	`aluSETAlow: { result, resultlow } = { Alow, A }; // Swap A and Alow

	`aluADD:		// A + M
	  { overflow, carry0, carry1, result } = { c0^c1, c0, c1, sum };

	`aluSUB:		// A - M
	  { overflow, carry0, carry1, result } = { b0^b1, b0, b1, dif };

	`aluMAGNITUDE:		// |M|
	  if (NEGATIVE(M))
	    { overflow, carry0, carry1, result } = { n0^n1, n0, n1, neg };
	  else
	    result = M;

	`aluNEGATE:		// -M
	  { overflow, carry0, carry1, result } = { n0^n1, n0, n1, neg };


	`aluLSH:		// logical shift A in the direction specified by M
	  begin
	     shift_rotate = 0;
	     shift_arith = 0;
	     result = shift36_out;
	     resultlow = shift36_out; // duplicate result for DPB
	  end

	`aluROT:		// rotate A in the direction specified by M
	  begin
	     shift_rotate = 1;
	     shift_arith = 0;
	     result = shift36_out;
	  end

	`aluASH:		// arithmetic shift A in the direction specified by M, may set overflow
	  begin
	     shift_rotate = 0;
	     shift_arith = 1;
	     result = shift36_out;
	     overflow = shift36_overflow;
	  end

	`aluLSHC:		// logical shift A,,Alow in the direction specified by M
	  begin
	     shift_rotate = 0;
	     shift_arith = 0;
	     result = DLEFT(shift72_out);
	     resultlow = DRIGHT(shift72_out);
	  end

	`aluROTC:		// rotate A,,Alow in the direction specified by M
	  begin
	     shift_rotate = 1;
	     shift_arith = 0;
	     result = DLEFT(shift72_out);
	     resultlow = DRIGHT(shift72_out);
	  end

	`aluASHC: // arithmetic shift A,,Alow in the direction specified by M, may set overflow
	  begin
	     shift_rotate = 0;
	     shift_arith = 1;
	     shift72_in = { A, Alow[1:35], 1'b0 }; // ignore sign bit in Alow
	     if (shift_amount == 0) begin
		// hack so we don't disturb Alow[0] if there's no shift
		result = A;
		resultlow = Alow;
		overflow = 0;
	     end else begin
		// split 71-bit signed value into two 36-bit words
		result = shift72_out[0:35];
		resultlow = { shift72_out[0], shift72_out[36:70] };
		overflow = shift72_overflow;
	     end
	  end

	`aluCIRC:		// circulate A,,Alow in the direction specified by M
	  //  the barrel shifter doesn't do CIRC and would probably need an entirely
	  //  different unit to do it.  this is entirely untested.  I need to write a
	  //  diagnostic. !!!
	  if (M[`HALFSIZE] == 1'b1) begin
	     result = { Alow[0], A[0:`WORDSIZE-2] }; // circulate A right
	     resultlow = { Alow[1:`WORDSIZE-1], A[`WORDSIZE-1] };
	  end else begin
	     result = { A[1:`WORDSIZE-1], Alow[`WORDSIZE-1] }; // circulate A left
	     resultlow = { A[0], Alow[0:`WORDSIZE-2]};
	  end

	`aluJFFO:		// Count the number of leading 0s on M
				// Sets overflow if M is not 0
	  begin
	     overflow = 1;
	     case(1'b1)
		M[0]: result = 0;
		M[1]: result = 1;
		M[2]: result = 2;
		M[3]: result = 3;
		M[4]: result = 4;
		M[5]: result = 5;
		M[6]: result = 6;
		M[7]: result = 7;
		M[8]: result = 8;
		M[9]: result = 9;
		M[10]: result = 10;
		M[11]: result = 11;
		M[12]: result = 12;
		M[13]: result = 13;
		M[14]: result = 14;
		M[15]: result = 15;
		M[16]: result = 16;
		M[17]: result = 17;
		M[18]: result = 18;
		M[19]: result = 19;
		M[20]: result = 20;
		M[21]: result = 21;
		M[22]: result = 22;
		M[23]: result = 23;
		M[24]: result = 24;
		M[25]: result = 25;
		M[26]: result = 26;
		M[27]: result = 27;
		M[28]: result = 28;
		M[29]: result = 29;
		M[30]: result = 30;
		M[31]: result = 31;
		M[32]: result = 32;
		M[33]: result = 33;
		M[34]: result = 34;
		M[35]: result = 35;
		default:
		  begin
		     result = 0;
		     overflow = 0;
		  end
	     endcase // case (1'b1)
	  end // case: `aluJFFO
	
	`aluIBP:		// Increment the Byte Pointer in M
	  if (P(M) < S(M))
	    result = { Preset(M), S(M), U(M), instI(M), instX(M), Yinc(M) };
	  else
	    result = { PlessS(M), S(M), U(M), instI(M), instX(M), instY(M) };

	`aluAOB:		// add 1 to both halves of M
	  { overflow, result }  = { aovr, aob };

	`aluSOB:		// subtract 1 from both halves of M
	  { overflow, result } = { sovr, sob };


	// rather specialized operations to implement multiplication
	`aluMUL_ADD:
	  if (Alow[35])
	    { result, resultlow } = { f, sum, Alow[0:34] }; // (A+M),Alow >> 1
	  else
	    { result, resultlow } = { f, A, Alow[0:34] }; // A,Alow >> 1
	
	`aluMUL_SUB:
	  begin
	     // besides doing the subtraction (optionally), this converts the double-word
	     // result into two 70-bit words plus the duplicated sign bits and catches the
	     // overflow case
	     if (Alow[35])
	       { result, resultlow } = { dif, dif[0], Alow[0:34] };
	     else
	       { result, resultlow } = { A, A[0], Alow[0:34] };

	     overflow = ((result == 36'o400000_000000) && (resultlow == 36'o400000_000000));
	  end

	`aluIMUL_SUB:
	  // Much like MUL_SUB but puts the low word on result instead and has a different
	  // overflow check
	  begin
	     // besides doing the subtraction (optionally), this converts the double-word
	     // result into two 70-bit words plus the duplicated sign bits
	     if (Alow[35])
	       { resultlow, result } = { dif, dif[0], Alow[0:34] };
	     else
	       { resultlow, result } = { A, A[0], Alow[0:34] };

	     // remember, resultlow is really the high word 
	     overflow = !((resultlow == 36'o000000_000000) || (resultlow == 36'o777777_777777));
	  end

	// and the specialized operations for division
	`aluDIV_MAG72:
	  // if A,Alow is negative, negate it.  get rid of the extra sign bit and left justify
	  if (NEGATIVE(A))
	    { result, resultlow } = { ACneg[1:`DWORDSIZE-1], 1'b0};
	  else
	    { result, resultlow } = { A, Alow[1:`WORDSIZE-1], 1'b0 };
	
	`aluDIV_MAG36:
	  // Put the magnitude of A in resultlow but left shifted one position
	  if (NEGATIVE(A))
	    { result, resultlow } = { 35'b0, Aneg, 1'b0 };
	  else
	    { result, resultlow } = { 35'b0, A, 1'b0 };

	`aluDIV_OP:
	  // Add or Subtract M from A depending on their relative signs, then ROTC 1 the
	  // result but invert the sign bit as it rotates around.  overflow is also set to
	  // that inverted sign bit
	  if (A[0] == M[0])
	    { overflow, result, resultlow } = { ~dif[0], dif[1:`WORDSIZE-1], Alow, ~dif[0] };
	  else
	    { overflow, result, resultlow } = { ~sum[0], sum[1:`WORDSIZE-1], Alow, ~sum[0] };

	`aluDIV_FIXR:
	  // Need to undo the ROTC but just in A (which is holding the remainder)
	  { result, resultlow } = { ~Alow[`WORDSIZE-1], A[0:`WORDSIZE-2], Alow };

	`aluDIV_FIXUP:
	  // First, adjust R to be positive
	  // Then, negate R and Q as needed to make everything come out right
	  // Finally, swap Q and R in the result to make the microcode easier
	  if (div_neg)
	    if (NEGATIVE(M))
	      { result, resultlow } = { Alow, -posR };
	    else
	      { result, resultlow } = { -Alow, -posR };
	  else
	    if (NEGATIVE(M))
	      { result, resultlow } = { -Alow, posR };
	    else
	      { result, resultlow } = { Alow, posR };

	`aluDPB:		// mask is on Alow, new byte on A, and memory contents on M
	  result = (Alow & A) | (~Alow & M);

	`aluBPMASK:		// the Byte Pointer mask from M (from size field)
	  result = bp_mask(S(M));

	`aluBPSHIFT:		// the Byte Pointer shift from M (pointer field)
	  result = P(M);

      endcase // case (command)
   end // always @ (*)

endmodule // ALU

