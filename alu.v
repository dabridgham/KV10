//	-*- mode: Verilog; fill-column: 90 -*-
//
// Arithmetic and Logic Unit for kv10 processor
//
// 2013-01-31 dab	initial version


`include "constants.vh"
`include "alu.vh"

module alu
   (
    input 		     clk,
    input 		     reset,
    input [0:`aluCMDwidth-1] command,
    input [`WORD] 	     op1low, // doubleword operations are op1,,op1low
    input [`WORD] 	     op1,     // first operand
    input [`WORD] 	     op2,     // second operand

    output reg [`WORD] 	     resultlow = 0,
    output reg [`WORD] 	     result = 0,
    output reg 		     carry0,
    output reg 		     carry1,
    output 		     overflow,
    output 		     zero
    );
   
`include "functions.vh"

   // the adder - The pdp10 has two carry bits, the carry out of bit1
   // into bit0 and the carry out of bit0
   wire 		     c0, c1;
   wire [0:`WORDSIZE-2]      sum_low;
   wire [0:1] 		     sum_high;
   wire [`WORD] 	     sum;
   assign { c1, sum_low } = op1[1:`WORDSIZE-1] + op2[1:`WORDSIZE-1];
   assign sum_high = op1[0] + op2[0] + c1;
   assign { c0, sum } = { sum_high, sum_low };
   
   // subtraction
   wire 		     b0, b1;
   wire [0:`WORDSIZE-2]      dif_low;
   wire [0:1] 		     dif_high;
   wire [`WORD] 	     dif;
   assign { b1, dif_low } = op1[1:`WORDSIZE-1] - op2[1:`WORDSIZE-1];
   assign dif_high = op1[0] - op2[0] - b1;
   assign { b0, dif } = { dif_high, dif_low };

   // invert op1 and op2 as these are used in several places
   wire [`WORD] 	     nop1 = ~op1;
   wire [`WORD] 	     nop2 = ~op2;

   // negate op2
   wire 		     n0, n1;
   wire [0:`WORDSIZE-2]      neg_low;
   wire [0:1] 		     neg_high;
   wire [`WORD] 	     neg;
   assign { n1, neg_low } = 1'b1 + nop2[1:`WORDSIZE-1];
   assign neg_high = nop2[0] + n1;
   assign { n0, neg } = { neg_high, neg_low };

   assign overflow = carry0 ^ carry1; // overflow if the carrys are different
   assign zero = (result == 0);

   // mostly a mux to connect the outputs to the right signal lines
   always @(*) begin
      resultlow = op1low;
      result = op1;
      carry0 = 0;
      carry1 = 0;
      
      case (command)		// synopsys full_case parallel_case
	// logical instructions - command is pulled straight out of the opcode, op1 = A and op2 = M
	`aluSETZ:	result = 0;
	`aluAND:	result = op1 & op2;
	`aluSETM:	result = op2;
	`aluANDCA:	result = nop1 & op2;

	`aluANDCM:	result = op1 & nop2;
	`aluSETA:	result = op1;
	`aluXOR:	result = op1 ^ op2;
	`aluIOR:	result = op1 | op2;

	`aluANDCB:	result = nop1 & nop2;
	`aluEQV:	result = ~(op1 ^ op2);
	`aluSETCA:	result = nop1;
	`aluORCA:	result = nop1 | op2;

	`aluSETCM:	result = nop2;
	`aluORCM:	result = op1 | nop2;
	`aluORCB:	result = nop1 | nop2;
	`aluSETO:	result = `MINUSONE;
	
`ifdef NOTDEF
	// halfword moves --  op1 = destination value and op2 = M
	`aluHLL: result = { LEFT(op2) , RIGHT(op1) };
	`aluHRL: result = { RIGHT(op2), RIGHT(op1) };
	`aluHRR: result = { LEFT(op1) , RIGHT(op2) };
	`aluHLR: result = { LEFT(op1) , LEFT(op2)  };
	// sign-extend
	`aluHLLx: result = { LEFT(op2) , HALF_NEGATIVE(LEFT(op2)) ? `HALFMINUSONE : `HALFZERO };
	`aluHRLx: result = { RIGHT(op2), HALF_NEGATIVE(RIGHT(op2)) ? `HALFMINUSONE : `HALFZERO };
	`aluHRRx: result = { HALF_NEGATIVE(RIGHT(op2)) ? `HALFMINUSONE : `HALFZERO , RIGHT(op2) };
	`aluHLRx: result = { HALF_NEGATIVE(LEFT(op2)) ? `HALFMINUSONE : `HALFZERO  , LEFT(op2)  };
`else
	// used with halfword moves
	`aluLL1: result = { LEFT(op1), RIGHT(op2) };
	`aluLL2: result = { LEFT(op2), RIGHT(op1) };
	`aluRL1: result = { RIGHT(op1), RIGHT(op2) };
	`aluRL2: result = { RIGHT(op2), RIGHT(op1) };
	`aluRDUP2: result = { RIGHT(op2), RIGHT(op2) };
`endif

	`aluADD:		// op1 + op2
	  { carry0, carry1, result } = { c0, c1, sum };

	`aluSUB:		// op1 - op2
	  { carry0, carry1, result } = { b0, b1, dif };

	`aluNEGATE:		// -op2
	  { carry0, carry1, result } = { n0, n1, neg };

	`aluMAGNITUDE:		// |op2|
	  if (NEGATIVE(op2))
	    { carry0, carry1, result } = { n0, n1, neg };
	  else
	     result = op2;

	`aluSWAP:		// swap the half-words of op2
	  result = { RIGHT(op2), LEFT(op2) };

	`aluLSH:		// logical shift op1 in the direction specified by op2
	  if (op2[`HALFSIZE] == 1'b1)
	    result = { 1'b0, op1[0:`WORDSIZE-2] }; // logical shift right
	  else
	    result = { op1[1:`WORDSIZE-1], 1'b0 }; // logical shift left

	`aluROT:		// rotate op1 in the direction specified by op2
	  if (op2[`HALFSIZE] == 1'b1)
	    result = { op1[`WORDSIZE-1], op1[0:`WORDSIZE-2] }; // rotate right
	  else
	    result = { op1[1:`WORDSIZE-1], op1[0] }; // rotate left

	`aluASH:		// arithmetic shift op1 in the direction specified by op2, may set overflow
	  if (op2[`HALFSIZE] == 1'b1)
	    result = { op1[0], op1[0], op1[1:`WORDSIZE-2] }; // arithmetic shift right
	  else begin
	     result = { op1[0], op1[2:`WORDSIZE-1], 1'b0 }; // arithmetic shift left
	     if (op1[0] != op1[1]) // if these bits are different, we're shifting out a
	       carry0 = 1;	   // significant bit
	  end

	`aluLSHC:		// logical shift op1,,op1low in the direction specified by op2
	  if (op2[`HALFSIZE] == 1'b1) begin
	     result = { 1'b0, op1[0:`WORDSIZE-2] }; // logical shift right
	     resultlow = { op1[`WORDSIZE-1], op1low[0:`WORDSIZE-2] };
	  end else begin
	     result = { op1[1:`WORDSIZE-1], op1low[0] }; // logical shift left
	     resultlow = { op1low[1:`WORDSIZE-1], 1'b0 };
	  end

	`aluROTC:		// rotate op1,,op1low in the direction specified by op2
	  if (op2[`HALFSIZE] == 1'b1) begin
	     result = { op1low[`WORDSIZE-1], op1[0:`WORDSIZE-2] }; // rotate right
	     resultlow = { op1[`WORDSIZE-1], op1low[0:`WORDSIZE-2] };
	  end else begin
	     result = { op1[1:`WORDSIZE-1], op1low[0] }; // rotate left
	     resultlow = { op1low[1:`WORDSIZE-1], op1[0] };
	  end

	`aluASHC: // arithmetic shift op1,,op1low in the direction specified by op2, may set overflow
	  if (op2[`HALFSIZE] == 1'b1) begin
	     result = { op1[0], op1[0:`WORDSIZE-2] }; // arithmetic shift right
	     resultlow = { op1[0], op1[`WORDSIZE-1], op1low[1:`WORDSIZE-2] };
	  end else begin
	     result = { op1[0], op1[2:`WORDSIZE-1], op1low[1] }; // arithmetic shift left
	     resultlow = { op1[0], op1low[2:`WORDSIZE-1], 1'b0 };
	     if (op1[0] != op1[1]) // if these bits are different, we're shifting out a
	       carry0 = 1;	   // significant bit
	  end

	`aluCIRC:		// circulate op1,,op1low in the direction specified by op2
	  // this is entirely untested.  I need to write a diagnostic. !!!
	  if (op2[`HALFSIZE] == 1'b1) begin
	     result = { op1low[0], op1[0:`WORDSIZE-2] }; // circulate op1 right
	     resultlow = { op1low[1:`WORDSIZE-1], op1[`WORDSIZE-1] };
	  end else begin
	     result = { op1[1:`WORDSIZE-1], op1low[`WORDSIZE-1] }; // circulate op1 left
	     resultlow = { op1[0], op1low[0:`WORDSIZE-2]};
	  end

	`aluIBP:		// Increment the Byte Pointer in op2
	  if (P(op2) < S(op2))
	    result = { Preset(op2), S(op2), U(op2), I(op2), X(op2), Yinc(op2) };
	  else
	    result = { PlessS(op2), S(op2), U(op2), I(op2), X(op2), Y(op2) };

	`aluAOB:		// add 1 to both halves of op1
	  result = AOB(op1);

	`aluSOB:		// subtract 1 from both halves of op1
	  result = SOB(op1);

      endcase // case (command)
   end // always @ (*)

endmodule // ALU

