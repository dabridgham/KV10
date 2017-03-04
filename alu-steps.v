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
    output 		     zero,
    output reg 		     busy = 0
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

   wire 		     n0, n1;
   wire [`WORD] 	     op2_invert;
   wire [0:`WORDSIZE-2]      neg_low;
   wire [0:1] 		     neg_high;
   wire [`WORD] 	     neg;
   assign op2_invert = ~op2;
   assign { n1, neg_low } = 1'b1 + op2_invert[1:`WORDSIZE-1];
   assign neg_high = op2_invert[0] + n1;
   assign { n0, neg } = { neg_high, neg_low };

   assign overflow = carry0 ^ carry1;
   assign zero = (result == 0) && (resultlow == 0);

   // for shift and rotate instructions, pull the 9-bit count out
   wire [0:`aluCOUNTwidth-1] op_count;
   assign op_count = { op2[`HALFSIZE], op2[`WORDSIZE-`aluCOUNTwidth+1:`WORDSIZE-1] };

   reg 			     done = 0;
   reg 			     first = 1;
   reg 			     shift_overflow, mask;
   reg [0:`aluCOUNTwidth-1]  count; // for shifts and rotates
   reg [`WORD] 		     shift_reg;
   reg [`WORD] 		     shift_reg_low;
   reg [`DWORD] 	     m1;
   reg [`DWORD] 	     m2;

   // mostly a mux to connect the outputs to the right signal lines but can also set busy
   // to kick off multi-cycle operations
   always @(*) begin
      resultlow <= 0;
      result <= 0;
      carry0 <= 0;
      carry1 <= 0;
      busy <= 0;
      
      case (command)
	// logical instructions - command is pulled straight out of the opcode, op1 = A and op2 = M
	`aluSETZ:	result <= 0;
	`aluAND:	result <= op1 & op2;
	`aluSETM:	result <= op2;
	`aluANDCA:	result <= ~op1 & op2;

	`aluANDCM:	result <= op1 & ~op2;
	`aluSETA:	result <= op1;
	`aluXOR:	result <= op1 ^ op2;
	`aluIOR:	result <= op1 | op2;

	`aluANDCB:	result <= ~op1 & ~op2;
	`aluEQV:	result <= ~(op1 ^ op2);
	`aluSETCA:	result <= ~op1;
	`aluORCA:	result <= ~op1 | op2;

	`aluSETCM:	result <= ~op2;
	`aluORCM:	result <= op1 | ~op2;
	`aluORCB:	result <= ~op1 | ~op2;
	`aluSETO:	result <= -1;
	
	// halfword moves --  op1 = destination value and op2 = M
	`aluHLL: result <= { LEFT(op2) , RIGHT(op1) };
	`aluHRL: result <= { RIGHT(op2), RIGHT(op1) };
	`aluHRR: result <= { LEFT(op1) , RIGHT(op2) };
	`aluHLR: result <= { LEFT(op1) , LEFT(op2)  };
	// sign-extend
	`aluHLLx: result <= { LEFT(op2) , HALF_NEGATIVE(LEFT(op2)) ? `HALFMINUSONE : `HALFZERO };
	`aluHRLx: result <= { RIGHT(op2), HALF_NEGATIVE(RIGHT(op2)) ? `HALFMINUSONE : `HALFZERO };
	`aluHRRx: result <= { HALF_NEGATIVE(RIGHT(op2)) ? `HALFMINUSONE : `HALFZERO , RIGHT(op2) };
	`aluHLRx: result <= { HALF_NEGATIVE(LEFT(op2)) ? `HALFMINUSONE : `HALFZERO  , LEFT(op2)  };


	`aluADD:		// op1 + op2
	  begin
	     result <= sum;
	     carry0 <= c0;
	     carry1 <= c1;
	  end
	`aluSUB:		// op1 - op2
	  begin
	     result <= dif;
	     carry0 <= b0;
	     carry1 <= b1;
	  end
	`aluNEGATE:		// -op2
	   begin
	      result <= neg;
	      carry0 <= n0;
	      carry1 <= n1;
	   end

	`aluMAGNITUDE:		// |op2|
	  if (NEGATIVE(op2)) begin
	     result <= neg;
	     carry0 <= n0;
	     carry1 <= n1;
	  end else begin
	     result <= op2;
	     carry0 <= 0;
	     carry1 <= 0;
	  end

	`aluCLR:		// 0,,0
	  begin
	     result <= 0;
	     resultlow <= 0;
	  end
	
	`aluSWAP:		// { RIGHT(op2), LEFT(op2) }
	  result <= { RIGHT(op2), LEFT(op2) };

	`aluIBP:		// Increment the Byte Pointer in op2
	  begin
	     if (P(op2) < S(op2))
	       result <= { Preset(op2), S(op2), U(op2), I(op2), X(op2), Yinc(op2) };
	     else
	       result <= { PlessS(op2), S(op2), U(op2), I(op2), X(op2), Y(op2) };
	     carry0 <= 0;
	     carry1 <= 0;
	  end
	`aluLDB:		// shifts and masks byte in op2 by byte-pointer in op1low
	  begin
	     result <= shift_reg & shift_reg_low;
	     carry0 <= 0;
	     carry1 <= 0;
	     if (!done)
	       busy <= 1;
	  end

	`aluDPB: // shifts byte in op1 and inserts it into op2 using byte-pointer in op1low
	   begin
	      result <= shift_reg;
	      carry0 <= 0;
	      carry1 <= 0;
	      if (!done)
		busy <= 1;
	   end

	// for all the shifts and rotates, count is in op2, bit0 for sign and bits 28-35 for count
	`aluLSH, `aluROT, `aluASH:
	  if (op_count == 0) begin
	     result <= op1;
	     carry0 <= 0;
	     carry1 <= 0;
	  end else begin
	     result <= shift_reg;
	     carry0 <= 0;
	     carry1 <= shift_overflow;
	     if (!done)
	       busy <= 1;
	  end
	`aluLSHC, `aluROTC, `aluASHC:
	  if (op_count == 0) begin
	     result <= op1;
	     resultlow <= op1low;
	     carry0 <= 0;
	     carry1 <= 0;
	  end else begin
	     result <= shift_reg;
	     resultlow <= shift_reg_low;
	     carry0 <= 0;
	     carry1 <= shift_overflow;
	     if (!done)
	       busy <= 1;
	  end

	// at the moment, either op1 or op2 has the value to check
	`aluJFFO:
	  begin
	     result <= count;
	     carry0 <= 0;
	     carry1 <= 1;
	     if (!done)
	       busy <= 1;
	  end

	`aluMUL:		// result,,resultlow <= op1 * op2
	  begin
	     // this is the conversion from a "normal" 72-bit 2s-complement number to the
	     // pdp10 format
	     result <= { shift_reg[0], shift_reg[2:`WORDSIZE-1], shift_reg_low[0] };
	     resultlow <= { shift_reg[0], shift_reg_low[1:`WORDSIZE-1] };
	     carry0 <= 0;
	     carry1 <= shift_overflow;
	     if (!done)
	       busy <= 1;
	  end

	`aluIDIV:		// result <= op1 / op2 , resultlow <= op1 mod op2
	  if (op2 == 0)		// check for divide by 0
	     carry1 <= 1;
	  else begin
	     result <= shift_reg;
	     resultlow <= shift_reg_low;
	     carry0 <= 0;
	     carry1 <= shift_overflow;
	     if (!done)
	       busy <= 1;
	  end

	`aluDIV:		// result <= op1,,op1low / op2 , resultlow <= op1 mod op2
	  // check for pending overflow
	  if ( (op1[0] ? -{ op1[0:`WORDSIZE-1], op1low[1:`WORDSIZE-1], 1'b0 } :
	                  { op1[0:`WORDSIZE-1], op1low[1:`WORDSIZE-1], 1'b0 } )
	       >= { (op2[0] ? -op2 : op2), `ZERO })
	    carry1 <= 1;
	  else begin
	     result <= shift_reg;
	     resultlow <= shift_reg_low;
	     carry0 <= 0;
	     carry1 <= shift_overflow;
	     if (!done)
	       busy <= 1;
	  end

      endcase // case (command)
   end // always @ (*)
   
   // Logical Shift - returns { shifted value, adjusted count, done flag }
   function [0:`WORDSIZE+`aluCOUNTwidth] LSH;
      input [`WORD] value;
      input [0:`aluCOUNTwidth-1] count;
      reg [0:`aluCOUNTwidth-1] 	 nc;

      if (count[0]) begin	// right shift
	 nc = count+1'd1;
	 LSH = { { 1'b0, value[0:`WORDSIZE-2] }, nc, nc == 0 };
      end else begin		// left shift
	 nc = count-1'd1;
	 LSH = { { value[1:`WORDSIZE-1], 1'b0 }, nc, nc == 0 };
      end
   endfunction

   // Arithmetic Shift - returns { shifted value, adjusted count, done flag }
   function [0:`WORDSIZE+`aluCOUNTwidth] ASH;
      input [`WORD] value;
      input [0:`aluCOUNTwidth-1] count;
      reg [0:`aluCOUNTwidth-1] 	 nc;

      if (count[0]) begin	// right shift
	 nc = count+1'd1;
	 ASH = { { value[0], value[0:`WORDSIZE-2] }, nc, nc == 0 };
      end else begin		// left shift
	 nc = count-1'd1;
	 ASH = { { value[0], value[2:`WORDSIZE-1], 1'b0 }, nc, nc == 0 };
      end
   endfunction

   // Rotate - returns { shifted value, adjusted count, done flag }
   function [0:`WORDSIZE+`aluCOUNTwidth] ROT;
      input [`WORD] value;
      input [0:`aluCOUNTwidth-1] count;
      reg [0:`aluCOUNTwidth-1] 	 nc;

      if (count[0]) begin	// right
	 nc = count+1'd1;
	 ROT = { { value[`WORDSIZE-1], value[0:`WORDSIZE-2] }, nc, nc == 0 };
      end else begin		// left
	 nc = count-1'd1;
	 ROT = { { value[1:`WORDSIZE-1], value[0] }, nc, nc == 0 };
      end
   endfunction

   // Rotate Combined - returns { shifted value high, shifted value low, adjusted count, done flag }
   function [0:`WORDSIZE*2+`aluCOUNTwidth] ROTC;
      input [`WORD] high;
      input [`WORD] low;
      input [0:`aluCOUNTwidth-1] count;
      reg [0:`aluCOUNTwidth-1] 	 nc;

      if (count[0]) begin	// right
	 nc = count+1'd1;
	 ROTC = { { low[`WORDSIZE-1], high[0:`WORDSIZE-2] }, { high[`WORDSIZE-1], low[0:`WORDSIZE-2] }, nc, nc == 0 };
      end else begin		// left
	 nc = count-1'd1;
	 ROTC = { { high[1:`WORDSIZE-1], low[0] }, { low[1:`WORDSIZE-1], high[0] }, nc, nc == 0 };
      end
   endfunction

   // Logical Shift Combined - returns { shifted value high, shifted value low, adjusted count, done flag }
   function [0:`WORDSIZE*2+`aluCOUNTwidth] LSHC;
      input [`WORD] high;
      input [`WORD] low;
      input [0:`aluCOUNTwidth-1] count;
      reg [0:`aluCOUNTwidth-1] 	 nc;

      if (count[0]) begin	// right
	 nc = count+1'd1;
	 LSHC = { { 1'b0, high[0:`WORDSIZE-2] }, { high[`WORDSIZE-1], low[0:`WORDSIZE-2] }, nc, nc == 0 };
      end else begin		// left
	 nc = count-1'd1;
	 LSHC = { { high[1:`WORDSIZE-1], low[0] }, { low[1:`WORDSIZE-1], 1'b0 }, nc, nc == 0 };
      end
   endfunction

   // Arithmetic Shift Combined - returns { shifted value high, shifted value low, adjusted count, done flag }
   function [0:`WORDSIZE*2+`aluCOUNTwidth] ASHC;
      input [`WORD] high;
      input [`WORD] low;
      input [0:`aluCOUNTwidth-1] count;
      reg [0:`aluCOUNTwidth-1] 	 nc;

      if (count[0]) begin	// right
	 nc = count+1'd1;
	 ASHC = { { high[0], high[0:`WORDSIZE-2] }, { high[0], high[`WORDSIZE-1], low[1:`WORDSIZE-2] }, nc, nc == 0 };
      end else begin		// left
	 nc = count-1'd1;
	 ASHC = { { high[0], high[2:`WORDSIZE-1], low[1] }, { high[0], low[2:`WORDSIZE-1], 1'b0 }, nc, nc == 0 };
      end
   endfunction

   // used by the divide algorithm
   wire [`DWORD] div_sum, div_dif, m2_shifted;
   assign m2_shifted = { m2[0], m2[0:`DWORDSIZE-2] };
   assign div_sum = m1 + m2_shifted;
   assign div_dif = m1 - m2_shifted;

   // this handles the operations that need multiple cycles
   always @(posedge clk) begin
      if (!busy || done) begin
	 done <= 0;
	 first <= 1;

	 case (command)
	   `aluMULnew:		// op1,,op1low + result,,resultlow
	     { result, resultlow } <= {op1, op1low } + { result, resultlow };
	   `aluHOLD:		// result,,resultlow
	     { result, resultlow } <= { result, resultlow };
	 endcase
      end else begin
	 first <= 0;

	 case (command)
	   default:
	     done <= 1;

	   `aluMUL:
	     // a fairly simple shift-and-add multipler
	     if (first) begin
		// set up register -- shift_reg gets the product, op1 and op2 are sign-extended into m1 and m2
		shift_reg <= 0;
		shift_reg_low <= 0;
		m1 <= { op1[0] ? `MINUSONE : `ZERO, op1 };
		m2 <= { op2[0] ? `MINUSONE : `ZERO, op2 };
		shift_overflow <= 0;
	     end else begin
		if (m2 == 0) begin // detect we're all done
		   // look for overflow (I'm not entirely sure this check won't have false positives!)
		   if ((shift_reg == `WORDSIZE'o200000000000) && (shift_reg_low == `ZERO)) begin
		      shift_reg <= `WORDSIZE'o400000000000;
		      shift_overflow <= 1;
		   end
		   done <= 1;
		end else begin
		   if (m2[`DWORDSIZE-1])
		     { shift_reg, shift_reg_low } <= { shift_reg, shift_reg_low } + m1;
		   m1 <= { m1[1:`DWORDSIZE-1], 1'b0 }; // m1 shift left
		   m2 <= { 1'b0, m2[0:`DWORDSIZE-2] }; // m2 shift right
		end
	     end

	   `aluIDIV, `aluDIV:
	     // non-restoring divide
	     if (first) begin
		// Initialization
		shift_overflow <= 0;
		shift_reg <= 0;	// quotient builds in here
		count <= `WORDSIZE;
		m2 <= { op2, `ZERO };		      // divisor in high word
		// the only difference between DIV and IDIV is the setup of the dividend,
		// put the magnitude of the dividend in m1, it will be the remainder when
		// finished
		if (command == `aluIDIV)
		  m1 <= { `ZERO, op1[0] ? -op1 : op1 };
		else
		   if (op1[0] == 0) // N positive
		     m1 <= { op1[0], op1 , op1low[1:`WORDSIZE-1] };
		   else		// N negative
		     m1 <= -{ op1[0], op1 , op1low[1:`WORDSIZE-1] };

	     end else begin
		// Main Divide Loop
		if (count != 0) begin
		   if (m1[0] == m2[0]) begin // remainder and divisor same signs means subtract
		      m1 <= div_dif;
		      shift_reg <= { shift_reg[1:`WORDSIZE-1], ~(m2[0] ^ div_dif[0]) };
		   end else begin // different signs means add
		      m1 <= div_sum;
		      shift_reg <= { shift_reg[1:`WORDSIZE-1], ~(m2[0] ^ div_sum[0]) };
		   end
		   m2 <= m2_shifted;
		   count <= count - `aluCOUNTwidth'd1;

		end else begin				    // count == 0, so finish up
		   // Post Correction and sign fixup

		   // fixup remainder
		   if (op1[0] != 0) begin      // N negative
		      if (m1[`WORDSIZE] ^ op1[0]) // R xor N
			shift_reg_low <= -DRIGHT(m1);
		      else			
			if (m2[0] != 0)
			  shift_reg_low <= DRIGHT(m1) - DRIGHT(m2); // R <= R - D
			else
			  shift_reg_low <= -(DRIGHT(m1) + DRIGHT(m2)); // R <= -(R + D)
		   end else begin	       // N positive
		      if (m1[`WORDSIZE] ^ op1[0]) // R xor N
			if (m2[0] != 0)
			  shift_reg_low <= DRIGHT(m1) - DRIGHT(m2); // R <= R - D
			else
			  shift_reg_low <= DRIGHT(m1) + DRIGHT(m2); // R <= R + D
		      else
			shift_reg_low <= DRIGHT(m1);
		   end

		   // fixup quotient
		   if (op1[0] != 0)	   // N negative
		     if (m2[0] != 0) // if D negative
		       shift_reg <= -(shift_reg + 1); // negate Q
		     else
		       shift_reg <= -shift_reg; // negate Q
		   else 
		     if (m2[0] != 0) // if D negative
		       shift_reg <= shift_reg + 1;

		   done <= 1;
		end
	     end

	   `aluASH:
	     if (first) begin
		shift_overflow <= op1[0] ^ op1[1];
		{ shift_reg, count, done } <= ASH(op1, op_count);
	     end else begin
		if (!op_count[0] && (shift_reg[0] ^ shift_reg[1]))
		  shift_overflow <= 1;
		{ shift_reg, count, done } <= ASH(shift_reg, count);
	     end
	   `aluLSH:
	     if (first)
	       { shift_reg, count, done } <= LSH(op1, op_count);
	     else 
	       { shift_reg, count, done } <= LSH(shift_reg, count);
	   `aluROT:
	     if (first)
	       { shift_reg, count, done } <= ROT(op1, op_count);
	     else 
	       { shift_reg, count, done } <= ROT(shift_reg, count);
	   
	   `aluROTC:
	     if (first)
	       { shift_reg, shift_reg_low, count, done } <= ROTC(op1, op1low, op_count);
	     else 
	       { shift_reg, shift_reg_low, count, done } <= ROTC(shift_reg, shift_reg_low, count);
	   
	   `aluLSHC:
	     if (first)
	       { shift_reg, shift_reg_low, count, done } <= LSHC(op1, op1low, op_count);
	     else 
	       { shift_reg, shift_reg_low, count, done } <= LSHC(shift_reg, shift_reg_low, count);

	   `aluASHC:
	     if (first) begin
		shift_overflow <= op1[0] ^ op1[1];
		{ shift_reg, shift_reg_low, count, done } <= ASHC(op1, op1low, op_count);
	     end else begin
		if (!op_count[0] && (shift_reg[0] ^ shift_reg[1]))
		  shift_overflow <= 1;
		{ shift_reg, shift_reg_low, count, done } <= ASHC(shift_reg, shift_reg_low, count);
	     end

	   `aluJFFO:
	      if (first) begin
		 shift_reg <= op2;
		 count <= 0;
	      end else begin
		 if (shift_reg[0] == 1)
		   done <= 1;
		 else begin
		    shift_reg <= { shift_reg[1:`WORDSIZE-1], 1'b1 };
		    count <= count + `aluCOUNTwidth'd1;
		 end
	      end // else: !if(first)
	   

	   `aluLDB:
	     if (first) begin
		shift_reg <= op2;	    // the byte is in here
		shift_reg_low <= `ZERO; // build the mask here
		count <= P(op1low);
		mask <= 0;
	     end else if (mask == 0) begin
		/* first shift the byte to the right */
		if (count != 0) begin
		   shift_reg <= { 1'b0, shift_reg[0:`WORDSIZE-2] };
		   count <= count - `aluCOUNTwidth'd1;
		end else begin
		   count <= S(op1low);
		   mask <= 1;
		end
	     end else begin
		/* now shift the mask to the left */
		if (count != 0) begin
		   shift_reg_low <= { shift_reg_low[1:`WORDSIZE-1], 1'b1 };
		   count <= count - `aluCOUNTwidth'd1;
		end else
		  done <= 1;
	     end

	   `aluDPB:
	     if (first) begin
		shift_reg <= op1;	// the byte we're depositing
		shift_reg_low <= `ZERO; // build the mask
		count <= S(op1low);
		mask <= 1;
	     end else if (mask == 1) begin
		// build the mask first
		if (count != 0) begin
		   shift_reg_low <= { shift_reg_low[1:`WORDSIZE-1], 1'b1 };
		   count <= count - `aluCOUNTwidth'd1;
		end else begin
		   count <= P(op1low);
		   mask <= 0;
		end
	     end else begin
		// now shift the mask and the byte into position
		if (count != 0) begin
		   shift_reg <= { shift_reg[1:`WORDSIZE-1], 1'b0 };
		   shift_reg_low <= { shift_reg_low[1:`WORDSIZE-1], 1'b0 };
		   count <= count - `aluCOUNTwidth'd1;
		end else begin
		   // all done, compute answer
		   shift_reg <= (shift_reg & shift_reg_low) | (op2 & ~shift_reg_low);
		   done <= 1;
		end
	     end // else: !if(mask == 1)

	 endcase
      end
   end

endmodule // ALU

