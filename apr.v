//	-*- mode: Verilog; fill-column: 96 -*-
//
// Arithmetic Processing Unit for kv10 processor
//

`timescale 1 ns / 1 ns

`include "constants.vh"
`include "alu.vh"

module apr
  (
   input 	      clk,
   input 	      reset,
   // interface to memory and I/O
   output reg [`ADDR] mem_addr,
   input [`WORD]      mem_read_data,
   output [`WORD]     mem_write_data,
   output reg 	      mem_user, // selects user or exec memory
   output reg 	      mem_mem_write, // only one of mem_write, mem_read, io_write, or io_read
   output reg 	      mem_mem_read,
   output reg 	      io_write,
   output reg 	      io_read,
   input 	      mem_write_ack,
   input 	      mem_read_ack,
   input 	      mem_nxm, // !!! don't do anything with this yet
   input 	      mem_page_fail,
   input [1:7] 	      mem_pi_req, // PI requests from I/O devices

   // these might grow to be part of a front-panel interface one day
   output reg [`ADDR] display_addr, 
   output reg 	      running
    );

`include "functions.vh"
`include "io.vh"
`include "opcodes.vh"
`include "decode.vh"
   
   //
   // Data Paths
   //

   // Fast Accumulators
   reg [`WORD] 	      accumulators [0:'o17];
   reg 		      AC_write,
		      AC_mem_write;
`ifdef SIM
   initial begin
      accumulators[0] = 'o070707_707070;
      accumulators[1] = 'o070707_707070;
      accumulators[2] = 'o070707_707070;
      accumulators[3] = 'o070707_707070;
      accumulators[4] = 'o070707_707070;
      accumulators[5] = 'o070707_707070;
      accumulators[6] = 'o070707_707070;
      accumulators[7] = 'o070707_707070;
      accumulators[8] = 'o070707_707070;
      accumulators[9] = 'o070707_707070;
      accumulators[10] = 'o070707_707070;
      accumulators[11] = 'o070707_707070;
      accumulators[12] = 'o070707_707070;
      accumulators[13] = 'o070707_707070;
      accumulators[14] = 'o070707_707070;
      accumulators[15] = 'o070707_707070;
   end
`endif   

   // dual-port, synchronous write
   always @(posedge clk) begin
      if (AC_write)
	accumulators[ACsel] <= write_data;
      if (AC_mem_write)
	accumulators[mem_addr[32:35]] <= write_data;
   end
   // dual-port, asynchronous read
   wire [`WORD]       AC = accumulators[ACsel];
   wire [`WORD]       AC_mem = accumulators[mem_addr[32:35]];

   // An assortment of other registers in the micro-machine
   reg [`WORD] 	      Alow;	// scratchpad for double-word operations
   reg [`WORD] 	      Areg;	// scratchpad for the A leg of the ALU
   reg [`WORD] 	      Mreg;	// scratchpad for the M leg of the ALU
   reg [`ADDR] 	      PC;	// Program Counter
   reg [0:12] 	      OpA;	// Op and A fields of the instruction
   reg [13:17] 	      IX;	// I and X fields of the instruction
   reg [18:35] 	      Y;	// Y field of the instruction
   wire [`WORD]       inst = { OpA, IX, Y }; // put the whole instruction together
   wire 	      Indirect = instI(inst);
   wire [0:3] 	      X = instX(inst);
   wire 	      Index = (X != 0);
   wire [`ADDR]       E = Y;	       // Y is also used for E
   wire [0:3] 	      A = instA(inst); // Pull out the A field
   reg [0:5] 	      BP_P;	       // Position field of byte pointer
   reg [0:5] 	      BP_S;	       // Size field of byte pointer
   // write these registers under control of the micro-machine
   reg 		      Alow_load, Areg_load, Mreg_load,
		      OpA_load, IX_load, Y_load, BP_load,
		      PC_load;
   always @(posedge clk) begin
      if (Alow_load) Alow <= ALUresultlow;
      
      if (Areg_load) 
	Areg <= write_data;
      else if (mul_start)
	Areg <= 0;		// a hack to save a state
      
      if (Mreg_load) Mreg <= write_data;
      if (PC_load)
	PC <= RIGHT(write_data);
      if (OpA_load) OpA <= { instOP(write_data), instA(write_data) };
      if (IX_load)
	IX <= { instI(write_data), instX(write_data) };
      if (Y_load) Y <= instY(write_data);
      if (BP_load) { BP_P, BP_S } = { P(write_data), S(write_data) };
   end

   // A-leg mux to the ALU
   wire [0:3] 	      Asel;	// set correct size !!!
   reg [`WORD] 	      Amux;
   wire [`ADDR]       PC_next = PC + 1;
   wire [`ADDR]       PC_skip = PC + 2;
   always @(*)
     // numbers here must match those in kv10.def
     case (Asel)
       0: Amux = `ONE;
       1: Amux = `MINUSONE;
       2: Amux = Areg;
       3: Amux = Mreg;
       4: Amux = { PSW, PC };
       5: Amux = AC;
       6: Amux = { `HALFSIZE'd0, E };
       7: Amux = bp_mask(BP_S);
       8: Amux = `WORDSIZE'o254000_001000; // jrst 1000
//       9: Amux = PIvector;
       10: Amux = `ZERO;
`ifndef LINT
       // this makes a loop that never happens in practice but verilator has no way to know that
       // so remove it for lint runs.  Need to fix this some better way !!!
       11: Amux = {`WORDSIZE{Malu[0]}}; // sign-extend Malu
`endif
       12: Amux = { PSW, PC_next };
       13: Amux = { PSW, PC_skip };
       14: Amux = { RIGHT(AC), LEFT(AC) };
       default: Amux = AC;
     endcase // case (Asel)

   // M-leg mux to the ALU
   wire [0:3] 	      Msel;	// set correct size !!!
   reg [`WORD] 	      Mmux;
   wire [`HWORD]      extP = { 12'b0, BP_P }; // byte position
   wire [`HWORD]      extPneg = -extP;	      // for shifting bytes to the right
   always @(*)
     // numbers here must match those in kv10.def
     case (Msel)
       0: Mmux = AC;
       1: Mmux = { `HALFZERO, E };
       2: Mmux = Mreg;
       3: Mmux = { `HALFZERO, 12'b0, BP_P };
       4: Mmux = { `HALFZERO, extPneg };
       5: Mmux = read_data;
       default: Mmux = AC;
     endcase // case (Msel)

   // Select either A or A+1 for double word operations or X for index calculations
   wire 	      ACnext, ACindex; // driven from the micro-instruction
   wire [0:3] 	      ACsel = ACindex ? X : (ACnext ? A + 1 : A);
      
   // some extra state to help with implementing multiply and divide
   wire 	      mul_shift_set = NEGATIVE(Mmux) & Alow[35];
   reg 		      mul_shift_bit;
   wire 	      mul_shift_ctl = mul_shift_bit | mul_shift_set;
   reg [0:5] 	      mul_count;
   reg 		      mul_done; // when the count overflows to 0
   reg 		      mul_start, mul_step, div_start;
   reg 		      div_first; // set on our first trip through
   wire 	      div_overflow = div_first & ALUoverflow; // for catching divide overflow
   always @(posedge clk)
     if (reset || mul_start || div_start) begin
	mul_shift_bit <= 0;
	mul_count <= div_start ? -36 : -35;
	mul_done <= 0;
	div_first <= 1;
//     end else if (mul_step) begin
     end else begin
	if (mul_shift_set)
	  mul_shift_bit <= 1;
	{mul_done, mul_count } <= mul_count + 1;
	div_first <= 0;
     end

   // Wire in the ALU
   reg [`aluCMD]      ALUcommand;
   wire [`WORD]       ALUresultlow;
   wire [`WORD]       ALUresult;
   wire 	      ALUcarry0;
   wire 	      ALUcarry1;
   wire 	      ALUoverflow;
   wire 	      ALUzero;
   wire 	      Mswap;
   wire [`WORD]       Malu = Mswap ? { RIGHT(Mmux), LEFT(Mmux) } : Mmux;
   alu alu(ALUcommand, Alow, Amux, Malu, mul_shift_ctl, NEGATIVE(AC), ALUresultlow, ALUresult, 
     ALUcarry0, ALUcarry1, ALUoverflow, ALUzero);
   // rename the output of the ALU
   wire [`WORD]       write_data = ALUresult;
   // Send the output of the ALU to the write data lines for the memory
   assign mem_write_data = write_data;
   // Pull the memory address off the A input to the ALU
   assign mem_addr = RIGHT(Amux);

   // Mux for Memory and ACs
   wire 	      mem_read, mem_write;
   reg [`WORD] 	      read_data;
   reg 		      read_ack, write_ack;
   reg 		      read, write;
   always @(*)
     if (isAC(mem_addr)) begin
	read_data = AC_mem;
	read_ack = mem_read;
	AC_mem_write = mem_write;
	mem_mem_read = 0;
	mem_mem_write = 0;
	write_ack = mem_write;
     end else begin
	read_data = mem_read_data;
	read_ack = mem_read_ack & mem_read;
	AC_mem_write = 0;
	mem_mem_write = mem_write;
	mem_mem_read = mem_read;
	write_ack = mem_write_ack & mem_write;
     end

   // Compute a skip or jump condition looking at the ALU output.  This signal only makes
   // sense when the ALU is performing a subtraction.
   reg [0:2] condition_code;	// driven by the instruction decode ROM
   reg 	     jump_condition;
   always @(*)
     case (condition_code) // synopsys full_case parallel_case
       skip_never: jump_condition = 0;
       skipl: jump_condition = !ALUzero & (ALUoverflow ^ NEGATIVE(ALUresult));
       skipe: jump_condition = ALUzero;
       skiple: jump_condition = ALUzero | (ALUoverflow ^ NEGATIVE(ALUresult));
       skipa: jump_condition = 1;
       skipge: jump_condition = ALUzero | !(ALUoverflow ^ NEGATIVE(ALUresult));
       skipn: jump_condition = !ALUzero;
       skipg: jump_condition = !ALUzero & !(ALUoverflow ^ NEGATIVE(ALUresult));
     endcase
   // Compute a skip or jump condition by comparing the ALU output to 0
   reg 	     jump_condition_0;
   always @(*)
     case (condition_code) // synopsys full_case parallel_case
       skip_never: jump_condition_0 = 0;
       skipl: jump_condition_0 = NEGATIVE(ALUresult);
       skipe: jump_condition_0 =  ALUzero;
       skiple: jump_condition_0 = ALUzero | NEGATIVE(ALUresult);
       skipa: jump_condition_0 = 1;
       skipge: jump_condition_0 = ALUzero | !NEGATIVE(ALUresult);
       skipn: jump_condition_0 = !ALUzero;
       skipg: jump_condition_0 = !ALUzero &!NEGATIVE(ALUresult);
     endcase
   
   //
   // Processor Status Word
   //
   reg overflow, carry0, carry1, floating_overflow;
   reg saved_overflow, saved_carry0, saved_carry1;
   reg first_part_done, user, userIO, floating_underflow, no_divide;
   reg set_flags, save_flags, clear_flags, set_overflow;
   reg clear_first_part_done, set_first_part_done, set_no_divide;
   reg PSW_load;
   wire [`HWORD] PSW = { overflow, carry0, carry1, floating_overflow,
			 first_part_done, user, userIO, 4'b0,
			 floating_underflow, no_divide, 5'b0 };
   always @(posedge clk) begin
      // this is a set of latches on the ALU flags to save them for later
      if (save_flags) begin
	 saved_overflow <= ALUoverflow;
	 saved_carry0 <= ALUcarry0;
	 saved_carry1 <= ALUcarry1;
      end

      if (set_flags) begin
	 if ((saved_overflow) || (save_flags && ALUoverflow)) overflow <= 1;
	 if ((saved_carry0) || (save_flags && ALUcarry0)) carry0 <= 1;
	 if ((saved_carry1) || (save_flags && ALUcarry1)) carry1 <= 1;
      end

      if (set_overflow) overflow <= 1;

      if (clear_flags) begin
	 if (inst[9]) overflow <= 0;
	 if (inst[10]) carry0 <= 0;
	 if (inst[11]) carry1 <= 0;
	 if (inst[12]) floating_overflow <= 0;
      end
      
      if (clear_first_part_done) first_part_done <= 0;
      if (set_first_part_done) first_part_done <= 1;
      if (set_no_divide) no_divide <= 1;
      
      if (PSW_load) begin	// load PSW from the left half of Mreg
	 overflow <= Mreg[0];
	 carry0 <= Mreg[1];
	 carry1 <= Mreg[2];
	 floating_overflow <= Mreg[3];
	 first_part_done <= Mreg[4];
	 user <= Mreg[5];
	 userIO <= Mreg[6];
	 floating_underflow <= Mreg[11];
	 no_divide <= Mreg[12];
      end
   end

   // need to save the ALUoverflow flag for JFFO
   reg JFFO_overflow, overflow_load;
   always @(posedge clk)
     if (overflow_load)
       JFFO_overflow <= ALUoverflow;
   

   //
   // Micro-Controller
   //

   // the micro-instruction and its breakout
   reg [63:0] uROM [0:2047];	// microcode ROM
   reg [63:0] uinst;		// set the width once I'm done !!!

   wire       uhalt = uinst[63]; // halt the micro-engine
   assign div_start = uinst[62];
//   assign mul_step = uinst[61];
   assign mul_start = uinst[60];
   assign set_no_divide = uinst[59];
   assign set_first_part_done = uinst[58];
   assign clear_first_part_done = uinst[57];
   assign set_overflow = uinst[56];
   assign clear_flags = uinst[55];
   assign overflow_load = uinst[54]; // is this needed? !!!
   assign set_flags = uinst[53];

   assign PSW_load = uinst[51];
   assign ACnext = uinst[50];
   assign ACindex = uinst[49];
   assign BP_load = uinst[48];
   assign Y_load = uinst[47];
   assign IX_load = uinst[46];
   assign OpA_load = uinst[45];
//   assign PC_skip = uinst[44];
//   assign PC_next = uinst[43];
   assign PC_load = uinst[42];
   assign Mreg_load = uinst[41];
   assign Areg_load = uinst[40];
   assign Alow_load = uinst[39];
   assign AC_write = uinst[38];
   
   assign io_write = uinst[37];
   assign io_read = uinst[36];
   assign mem_write = uinst[35];
   assign mem_read = uinst[34];

//   assign Cswap = uinst[33];
   assign Mswap = uinst[32];
//   assign Aswap = uinst[31];
   assign save_flags = uinst[30];

   assign ALUcommand = uinst[29:24];
   assign Asel = uinst[23:20];
   assign Msel = uinst[19:16];
   wire [4:0] ubranch_code = uinst[15:11];
   wire [10:0] unext = uinst[10:0]; // the next instruction location

   reg [10:0] uaddr, uprev;	// current and previous micro-addresses, kept for debugging
   reg [10:0] ubranch;		// gets ORd with unext to get the next micro-address

   initial $readmemh("kv10.hex", uROM);

   // the core of the microsequencer is trvial
   always @(posedge clk) begin
      if (reset) begin
	 uprev <= 'x;
	 uaddr <= 0;
	 uinst <= uROM[0];
      end
`ifdef SIM
      // what do I do if we hit a uhalt when not in the simulator?  !!!
      else if (uhalt) 
	begin
	   $display(" HALT!!!");
	   $display("uEngine halt @%o from %o", uaddr, uprev);
	   $display("Cycles: %0d  Instructions: %0d   Cycles/inst: %f",
		    cycles, instruction_count, $itor(cycles)/$itor(instruction_count));
	   $display("carry0: %b  carry1: %b  overflow: %b  floating overflow: %b",
		    carry0, carry1, overflow, floating_overflow);
	   print_ac();
	   $finish_and_return(1);
	end
`endif
      else begin
	 uprev <= uaddr;
	 uaddr <= unext | ubranch;
	 uinst <= uROM[unext | ubranch];
//`define UDISASM 1
`ifdef UDISASM
	 $display("%o", uaddr);
`endif
      end
   end // always @ (posedge clk)

   // branching is where much of the magic happens in the micro-engine
   always @(*) begin
      ubranch = 0;		// default all the bits to 0
      
      // these numbers need to match up with the numbers in kv10.def
      case (ubranch_code)
	// no branch
	0: ubranch = 0;

	// mem read - a 4-way branch for reading from memory
	1: case (1'b1)
//	     interrupt:		ubranch[1:0] = 3;	// implement interrupts !!!
	     mem_page_fail:	ubranch[1:0] = 2;
	     read_ack:		ubranch[1:0] = 1;
	     default:		ubranch[1:0] = 0;
	   endcase // case (1'b1)

	// mem write - a 3-way branch for writing to memory.  interrupts are only recognized
	// when reading from memory.
	2: case (1'b1)
	     mem_page_fail:	ubranch[1:0] = 2;
	     write_ack:		ubranch[1:0] = 1;
	     default:		ubranch[1:0] = 0;
	   endcase

	// IX - a 3-way branch on index and indirect calculating the Effective Address.  this
	// comes from write_data because the check happens before inst gets written
	3: case (1'b1)
	     instX(write_data) != 0: ubranch[1:0] = 0;
	     instI(write_data): ubranch[1:0] = 1;
	     default: ubranch[1:0] = 2;
	   endcase

	// Indirect - If the Effective Address calculation included an Index register, we need
	// to then check if there's also an Indirect.  This happens after inst is written so
	// take the Indirect bit from there.
	4: ubranch[0] = Indirect;

	// Dispatch - This comes from the instruction decode.  By default it's just the
	// instruction opcode but it also handles the Effective Address calculation,
	// instructions that need to read the value at E first, and then a few special cases to
	// optimze certain instructions.  Also, I/O instructions are handled specially.
	5: if (ReadE)
	  ubranch[8:0] = 9'o720;
	else
	  ubranch[8:0] = dispatch;

	// condition skip or jump comparisons
	6: ubranch[0] = Comp0 ? jump_condition_0 : jump_condition;

	// Write Self check - if AC != 0
	7: ubranch[0] = (A != 0);

	// Test - Bitwise compare on the /inputs/ to the ALU.  For the TEST instructions.
	8: ubranch[0] = ((Amux & Malu) != 0);

	// JFCL - if any of the flags are about to be cleared
	9: ubranch[0] = (({overflow, carry0, carry1, floating_overflow} & inst[9:12]) != 0);

	// MUL - break out the different Multiply or Divide instructions
	// 0: IMUL/IDIV	1: IMULI/IDIVI	2: IMULM/IDIVM	3: IMULB/IDIVB
	// 5: MUL/DIV	6: MULI/DIVI	7: MULM/DIVM	7: MULB/DIVB
	10: ubranch[2:0] = inst[6:8];

	// OVR - check ALUoverflow, used in DIV and JFFO
	11: ubranch[0] = ALUoverflow;

	// Byte - Branch on which of four byte instructions
	// 0: ILDB	1: LBD		2: IDPB		3: DPB
	12: ubranch[1:0] = inst[7:8];

	// First Part Done
	13: ubranch[0] = first_part_done;

	// BLT terminates when the word we just wrote went into location E
	14: ubranch[0] = (RIGHT(AC) == E);

	default: ubranch = 0;
      endcase // case (ubranch_code)
   end

`ifdef SIM
`include "disasm.vh"

   reg [`WORD] 	 cycles;
   reg [`WORD] 	 instruction_count;
   reg [`ADDR] 	 inst_addr;

   always @(posedge clk) begin
      cycles <= cycles+1;

      // When the Op is loaded, remember the instruction address for the disassembler
      if (OpA_load) begin
	 inst_addr <= mem_addr;
	 instruction_count <= instruction_count + 1;
      end
      
      if (reset) begin
	 instruction_count <= 0;
	 cycles <= 0;
	 carry0 <= 0;
	 carry1 <= 0;
	 overflow <= 0;
	 floating_overflow <= 0;
      end

      if (OpA_load) begin
	 // this is a horrible hack but it's really handy for running a bunch of
	 // tests and DaveC's tests all loop back to 001000 !!!
	 if ((PC == `ADDRSIZE'o1000) && (instruction_count != 0)) begin
	    $display("Cycles: %0d  Instructions: %0d   Cycles/inst: %f",
		     cycles, instruction_count, $itor(cycles)/$itor(instruction_count));
	    $finish_and_return(0);
	 end

	 // disassembler
	 $display("%6o: %6o,%6o %s", mem_addr, write_data[0:17], write_data[18:35], disasm(write_data));
      end // if (OpA_load)

`ifdef NOTDEF
      if (ubranch_code == 4) begin	// dispatch
	 if (instX(inst) || instI(inst))
	   $write(" @%6o", E);
	 if (ReadE)
	   $write(" [%6o,%6o]", Mreg[0:17], Mreg[18:35]);
	 if (WriteAC || (WriteSelf && (A != 0)) || WriteE)
	   $write(" %6o,%6o -->", write_data[0:17], write_data[18:35]);
	 if (WriteAC || (WriteSelf && (A != 0)))
	   $write(" AC%o", A);
	 if (WriteE)
	   $write(" [%6o]", E);
	 $display("");		// newline
      end // if (ubranch_code == 4)
`endif //  `ifdef NOTDEF
   end

`endif
   


   //
   // Instruction Decode ROM
   //

   reg ReadE;			// the instruction reads the value from E
   wire dReadE;			// from the decode ROM
   wire Comp0;			// use jump_condition_0 instead of jump_condition
   wire [0:8] dispatch;		// main instruction branch in the micro-code
   wire [`ADDR] io_dev;		// the I/O device
   wire [`WORD] dinst = OpA_load ? write_data : inst;
   decode decode(.inst(dinst),
		 .user(user),
		 .userIO(userIO),
		 .dispatch(dispatch),
 		 .ReadE(dReadE),
		 .condition_code(condition_code),
 		 .Comp0(Comp0),
 		 .io_dev(io_dev));
   always @(posedge clk) begin
      // After we read E, clear the flag so we can dispatch again and not read E again
      if (ubranch_code == 5)	// dispatch
	ReadE <= 0;
      // grab ReadE from the decode ROM but into a register that we can clear once we read E
      else if (OpA_load)
	ReadE <= dReadE;
   end


`ifdef NOTDEF

   //
   // State Machine
   //
   
`ifdef SIM
`include "disasm.vh"
`endif
   
`define STATE_COUNT 48		// eventually I'll know how large these have to be!!!
`define STATE_SIZE 6
   reg [0:`STATE_COUNT-1] state;
   reg [0:`STATE_COUNT-1] next_state;
`ifdef SIM
   reg [0:`STATE_SIZE-1] state_index; // these are just for debugging
   reg [0:`STATE_SIZE-1] next_state_index;
`endif
   
   task set_state;
      input [0:`STATE_SIZE-1] s;
      begin
`ifdef SIM
	 next_state_index = s;
`endif
	 next_state[s] = 1'b1;
      end
   endtask

   // Keeps track of a count of instructions and clock cycles
   reg [`WORD] instruction_count = 0;
   reg 	       inc_inst_count;
   reg [`WORD] cycles = 0;
`ifdef SIM
   reg [`ADDR] inst_addr;
`endif

   // a hack to skip Indexing once we've already done it
   reg 	       X_hidden = 0;
   reg 	       X_hide;
   always @(posedge clk)
     if (reset || IX_load)
       X_hidden <= 0;
     else if (X_hide)
       X_hidden <= 1;

   // states in the processor state machine
   localparam 
     st_init = 0,
     st_instruction_fetch = 1,
     st_instruction_dispatch = 2,
     st_read_e = 3,
     st_index = 4,
     st_exch = 5,
     st_jsr = 6,
     st_jsp = 7,
     st_jsa = 8,
     st_inc_e = 9,
     st_jump = 10,
     st_push = 11,
     st_push2 = 12,
     st_pop = 13,
     st_pop2 = 14,
     st_pushj = 15,
     st_popj = 16,
     st_jffo = 17,
     st_write_double = 18,
     st_write_low = 19,
     st_mul = 20,
     st_div1 = 21,
     st_div2 = 22,
     st_div3 = 23,
     st_divhigh = 24,
     st_divlow = 25,

     st_bp_read = 26,
     st_bp_index = 27,
     st_bp_exec = 28,
     st_ldb = 29,
     st_dpb = 30,
     st_dpb_finish = 31,
     st_blt_write = 32,
     st_blt_inc = 33,
     
     st_ioread = 45,
     
     st_unassigned = 46,
     st_halted = 47;

   reg mem_read, mem_write;

   // synchronous part of state machine
   always @(posedge clk) begin
      state <= next_state;

`ifdef SIM
      cycles <= cycles+1;

      // When the Op is loaded, remember the instruction address for the disassembler
      if (OpA_load)
	inst_addr <= mem_addr;
`endif
      if (reset) begin
	 instruction_count <= 0;
	 cycles <= 0;
	 carry0 <= 0;
	 carry1 <= 0;
	 overflow <= 0;
	 floating_overflow <= 0;
      end else if (inc_inst_count) begin
	 instruction_count <= instruction_count + 1;
`ifdef SIM
	 // this is a horrible hack but it's really handy for running a bunch of
	 // tests and DaveC's tests all loop back to 001000 !!!
	 if ((PC == `ADDRSIZE'o1000) && (instruction_count != 0)) begin
	    $display("Cycles: %0d  Instructions: %0d   Cycles/inst: %f",
		     cycles, instruction_count, $itor(cycles)/$itor(instruction_count));
	    $finish_and_return(0);
	 end

	 // disassembler
	 $write("%6o: %6o,%6o %s", inst_addr, inst[0:17], inst[18:35], disasm(inst));
	 if (instX(inst) || instI(inst))
	   $write(" @%6o", E);
	 if (ReadE)
	   $write(" [%6o,%6o]", Mreg[0:17], Mreg[18:35]);
	 if (WriteAC || (WriteSelf && (A != 0)) || WriteE)
	   $write(" %6o,%6o -->", write_data[0:17], write_data[18:35]);
	 if (WriteAC || (WriteSelf && (A != 0)))
	   $write(" AC%o", A);
	 if (WriteE)
	   $write(" [%6o]", E);
	 $display("");		// newline
`endif
      end


`ifdef SIM
      state_index <= next_state_index;
      
      case (1'b1)
	state[st_unassigned]:
	  $display("Unassigned!!!");
	state[st_halted]:
	  begin
	     $display(" HALT!!!");
	     $display("Cycles: %0d  Instructions: %0d   Cycles/inst: %f",
		      cycles, instruction_count, $itor(cycles)/$itor(instruction_count));
	     $display("carry0: %b  carry1: %b  overflow: %b  floating overflow: %b",
		      carry0, carry1, overflow, floating_overflow);
	     print_ac();
	     $finish_and_return(1);
	  end
      endcase
`endif
   end

   // async part of the state machine
   always @(*) begin
      next_state = 0;
      inc_inst_count = 0;
      mem_read = 0;
      mem_write = 0;
      io_read = 0;
      io_write = 0;

      AC_write = 0;
      Alow_load = 0;
      Areg_load = 0;
      Mreg_load = 0;
      PC_load = 0;
      PC_next = 0;
      PC_skip = 0;
      OpA_load = 0;
      IX_load = 0;
      X_hide = 0;
      Y_load = 0;
      BP_load = 0;
      ACnext = 0;

      PSW_load = 0;
      eset = 0;
      Flags_load = 0;
      overflow_load = 0;
      clear_overflow = 0;
      set_overflow = 0;
      clear_carry0 = 0;
      clear_carry1 = 0;
      clear_floating_overflow = 0;
      clear_first_part_done = 0;
      set_first_part_done = 0;
      set_no_divide = 0;
      Mswap_ue = 0;
      ALUcommand = 'oX;
      Asel = 'oX;
      Msel = 'oX;
      Csel = 'oX;

      mul_start = 0;
      mul_step = 0;
      div_start = 0;

      if (reset)
	set_state(st_init);
      else
	case (1'b1)
	  state[st_init]:
	    begin
	       // Perhaps a more interesting way to implement this is to stuff a 'JRST 1000'
	       // into the instruction register !!!
	       Csel = Csel_start_addr;
	       PC_load = 1;
	       PSW_reset = 1;
	       set_state(st_instruction_fetch);
	    end

	  state[st_instruction_fetch]:
	     begin
		ADDRsel = ADDRsel_PC;
		Csel = Csel_read_data;
		mem_read = 1;
		if (read_ack) begin
		   OpA_load = 1;
		   IX_load = 1;
		   Y_load = 1;
		   set_state(st_instruction_dispatch);
		end else
		  set_state(st_instruction_fetch);
	     end // case: state[instruction_fetch]

	  state[st_instruction_dispatch], state[st_read_e]:
	    begin
	       if (Index && !X_hidden) begin
		  // don't have to wait for read_ack since we know it's an accumulator
		  ADDRsel = ADDRsel_X;
		  Csel = Csel_read_data;
		  Mreg_load = 1;
		  set_state(st_index);
	       end else if (Indirect) begin
		  ADDRsel = ADDRsel_E;
		  Csel = Csel_read_data;
		  mem_read = 1;
		  if (read_ack) begin
		     IX_load = 1;
		     Y_load = 1;
		     Mreg_load = 1; // load Mreg too so JRST 02 works
		  end
		  set_state(st_instruction_dispatch);
	       end else
		 // a bit of magic here, if we're in state instruction_dispatch then we may go
		 // on to read E, but if we're in state read_e then we've already read E so
		 // don't read it again.
		 if (ReadE && state[st_instruction_dispatch]) begin
		    ADDRsel = ADDRsel_E;
		    Csel = Csel_read_data;
		    mem_read = 1;
		    if (read_ack) begin
		       Mreg_load = 1;
		       set_state(st_read_e);
		    end else
		      set_state(st_instruction_dispatch);
		 end else begin
		    inc_inst_count = 1;
		    case (dispatch)
		      // Most simple instructions come here.  Set up the muxes and the ALU
		      // according to the instruction decode and write the ALU's output to AC or
		      // memory
		      dCommon:
			begin
			   case (1'b1)
			     ReadOne: Asel = Asel_one;
			     ReadMinusOne: Asel = Asel_minusone;
			     ReadMonA: Asel = Asel_Mreg;
			     default: Asel = Asel_AC;
			   endcase
			   case (1'b1)
			     // ReadAC overrides ReadE
			     ReadAC: Msel = Msel_AC;
			     ReadE: Msel = Msel_Mreg;
			     default: Msel = Msel_E;
			   endcase
			   ALUcommand = ALUinst;
			   Csel = Csel_ALUresult;
			   if (WriteE) begin
			      ADDRsel = ADDRsel_E;
			      mem_write = 1;
			   end
			   
			   if (WriteE && !write_ack) begin
			      // a little more magic, whether we started in state
			      // instruction_dispatch or read_e, looping to wait for write_ack
			      // using read_e means we won't try to read E again.
			      set_state(st_read_e);
			      // suppress this except for the last time through
			      inc_inst_count = 0;
			   end else begin
			      // after the write to memory has completed successfully, if
			      // we're also writing to AC or setting the flags do it now.
			      Flags_load = SetFlags;
			      if (WriteAC || (WriteSelf && (A != 0)))
				AC_write = 1;

			      // some of the jump and skip instructions end up here.  since
			      // skip_condition is set to skip_never by default, any regular
			      // instructions that end up here don't jump or skip.
			      if (Comp0 ? jump_condition_0 : jump_condition)
				if (jump)
				  // Since the ALU is set up for the instruction, can't feed E
				  // through to PC for the jump in this state.
				  set_state(st_jump);
				else begin
				   PC_skip = 1;
				   set_state(st_instruction_fetch);
				end
			      else begin
				 PC_next = 1;
				 set_state(st_instruction_fetch);
			      end
			   end
			end // case: Common

		      // The Logical Test instructions
		      dTEST:
			begin
			   Asel = Asel_AC;
			   Msel = ReadE ? Msel_Mreg : Msel_E;
			   ALUcommand = ALUinst;
			   Csel = Csel_ALUresult;			   
			   AC_write = WriteAC;
			   case (condition_code)
			     skip_never:
			       PC_next = 1;
			     skipe:
			       if ((Aalu & Malu) == 0)
				 PC_skip = 1;
			       else
				 PC_next = 1;
			     skipa:
			       PC_skip = 1;
			     skipn:
			       if ((Aalu & Malu) != 0)
				 PC_skip = 1;
			       else
				 PC_next = 1;
			   endcase // case (condition_code)
			   set_state(st_instruction_fetch);
			end

		      dEXCH:
			begin
			   Asel = Asel_AC;
			   Msel = Msel_Mreg;
			   ALUcommand = ALUinst;
			   Csel = Csel_ALUresult;
			   ADDRsel = ADDRsel_E;
			   mem_write = 1;
			   if (write_ack)
			     set_state(st_exch);
			   else begin
			      inc_inst_count = 0;
			      set_state(st_read_e);
			   end
			end

		      dJRST:
			// A whole lot missing here still !!!
			begin
			   if (inst[10]) begin // halt
			      PC_next = 1;
			      set_state(st_halted);
			   end else begin
			      if (inst[11]) // restore flags
				PSW_load = 1;

			      Msel = Msel_E;
			      ALUcommand = `aluSETM;
			      Csel = Csel_ALUresult;
			      PC_load = 1;
			      set_state(st_instruction_fetch);
			   end // else: !if(inst[10])
			end
		      
		      dJFCL:
			begin
			   clear_overflow = overflow & inst[9];
			   clear_carry0 = carry0 & inst[10];
			   clear_carry1 = carry1 & inst[11];
			   clear_floating_overflow = floating_overflow & inst[12];
			   if (({overflow, carry0, carry1, floating_overflow} & inst[9:12]) != 0) begin
			      Msel = Msel_E;
			      ALUcommand = `aluSETM;
			      Csel = Csel_ALUresult;
			      PC_load = 1;
			   end else
			     PC_next = 1;
			   set_state(st_instruction_fetch);
			end // case: Jfcl

		      dJSR:
			begin
			   // if executed as an interrupt insturction or MUUO, leaves user mode !!!
			   PC_next = 1; // need to increment PC before storing it.
			   set_state(st_jsr);
			end

		      dJSP:
			begin
			   // if executed as an interrupt instruction or MUUO, leaves user mode !!!
			   PC_next = 1; // need to increment PC before storing it
			   set_state(st_jsp);
			end

		      dJSA:
			// if executed as an interrupt instruction or MUUO, leaves user mode !!!
			begin
			   // C(E) <- AC
			   Asel = Asel_AC;
			   ALUcommand = `aluSETA;
			   Csel = Csel_ALUresult;
			   ADDRsel = ADDRsel_E;
			   mem_write = 1;
			   if (write_ack) begin
			      PC_next = 1; // increment PC before storing it
			      set_state(st_jsa);
			   end else begin
			      inc_inst_count = 0;
			      set_state(st_instruction_dispatch);
			   end
			end // case: Jsa

		      dJRA:
			 begin
			    // AC <- C(LEFT(AC))
			    Msel = Msel_AC;
			    Mswap_ue = 1;
			    Csel = Csel_read_data;
			    ADDRsel = ADDRsel_M;
			    mem_read = 1;
			    if (read_ack) begin
			       AC_write = 1;
			       set_state(st_jump);
			    end else begin
			       inc_inst_count = 0;
			       set_state(st_instruction_dispatch);
			    end
			 end

		      dXCT:
			begin
			   ADDRsel = ADDRsel_E;
			   Csel = Csel_read_data;
			   mem_read = 1;
			   if (read_ack) begin
			      OpA_load = 1;
			      IX_load = 1;
			      Y_load = 1;
			   end else
			     inc_inst_count = 0;
			   set_state(st_instruction_dispatch);
			end

		      dPUSH:
			 begin
			    ADDRsel = ADDRsel_E;
			    Csel = Csel_read_data;
			    mem_read = 1;
			    if (read_ack) begin
			       Mreg_load = 1;
			       set_state(st_push);
			    end else begin
			       inc_inst_count = 0;
			       set_state(st_instruction_dispatch);
			    end
			 end

		      dPOP, dPOPJ:
			begin
			   // Mreg <- C(AC)
			   Msel = Msel_AC;
			   ADDRsel = ADDRsel_M;
			   Csel = Csel_read_data;
			   mem_read = 1;
			   if (read_ack) begin
			      Mreg_load = 1;
			      set_state(dispatch == dPOP ? st_pop : st_pop2);
			   end else begin
			      inc_inst_count = 0;
			      set_state(st_instruction_dispatch);
			   end
			end // case: Pop

		      dPUSHJ:
			begin
			   // need to implement the pushdown_overflow flag !!!
			   Asel = Asel_AC;
			   ALUcommand = `aluAOB;
			   Csel = Csel_ALUresult;
			   AC_write = 1;
			   PC_next = 1;
			   Mreg_load = 1; // Also put AC in Mreg so RIGHT(AC) can be the address
			   set_state(st_pushj);
			end
		      
		      dSHIFTC:
			begin
			   // Alow <- A+1
			   Asel = Asel_AC;
			   ACnext = 1;
			   ALUcommand = `aluSETAlow; // SETAlow routes A to Clow
			   Alow_load = 1;
			   set_state(st_write_double);
			end

		      dJFFO:
			begin
			   // Areg <- JFFO(AC)
			   Asel = Asel_AC;
			   ALUcommand = `aluJFFO;
			   Csel = Csel_ALUresult;
			   Areg_load = 1;
			   overflow_load = 1; // save overflow for later
			   set_state(st_jffo);
			end

		      dBLT:
			begin
			   // Mreg <- C(left(AC))
			   Msel = Msel_AC;
			   Mswap_ue = 1; // direct left half of AC to ADDRmux
			   ADDRsel = ADDRsel_M;
			   Csel = Csel_read_data;
			   mem_read = 1;
			   if (read_ack) begin
			      Mreg_load = 1;
			      set_state(st_blt_write);
			   end else begin
			      // as it is now, the instruction counter increments for each
			      // iteration of BLT. !!!
			      inc_inst_count = 0;
			      set_state(st_instruction_dispatch);
			   end
			end

		      dMUL, dIMUL:
			begin	// Alow <- AC  Areg <- 0
			   Asel = Asel_AC;
			   ALUcommand = `aluSETAlow;
			   Csel = Csel_ALUresult;
			   Alow_load = 1;
			   mul_start = 1; // side-effect clears Areg
			   set_state(st_mul);
			end

		      dDIV:
			begin
			   // Alow <- A+1  (Same as ShiftC !!!)
			   Asel = Asel_AC;
			   ACnext = 1;
			   ALUcommand = `aluSETAlow; // SETAlow routes A to Clow
			   Alow_load = 1;
			   div_start = 1;
			   set_state(st_div1);
			end

		      dIDIV:
			begin
			   // A,Alow <- |AC| << 1
			   Asel = Asel_AC;
			   ALUcommand = `aluDIV_MAG36;
			   Csel = Csel_ALUresult;
			   Alow_load = 1;
			   Areg_load = 1;
			   div_start = 1;
			   set_state(st_div2);
			end

		      dLDB, dDPB, dILDB, dIDPB:
			if (((dispatch == dILDB) || (dispatch == dIDPB))
			    && !first_part_done) begin
			   // if the first part is not done, then we need to write the
			   // incremented byte pointer back to memory
			   Msel = Msel_Mreg;
			   ALUcommand = `aluIBP;
			   Csel = Csel_ALUresult;
			   ADDRsel = ADDRsel_E;
			   mem_write = 1;
			   if (write_ack) begin
			      // Move the incremented byte pointer into BP_P, BP_S, I, X,
			      // and Y and go to the BP read state
			      BP_load = 1;
			      IX_load = 1;
			      Y_load = 1;
			      set_first_part_done = 1; // mark first part is now done
			      set_state(st_bp_read);
			   end else begin
			      inc_inst_count = 0;
			      set_state(st_read_e);
			   end
			end else begin
			   // Mreg has the byte pointer, move it to BP_P, BP_S, I, X, and Y
			   Msel = Msel_Mreg;
			   ALUcommand = `aluSETM;
			   Csel = Csel_ALUresult;
			   BP_load = 1;
			   IX_load = 1;
			   Y_load = 1;
			   set_state(st_bp_read);
			end // else: !if(((dispatch == Ildb) || (dispatch == Idpb))...

		      dIOwrite:	// I/O Device <- 0,E or C(E)
			begin
			   Msel = ReadE ? Msel_Mreg : Msel_E;
			   ALUcommand = `aluSETM;
			   Csel = Csel_ALUresult;
			   io_write = 1;
			   PC_next = 1;
			   set_state(st_instruction_fetch);
			end

		      dIOread:	// C(E) <- I/O Device
			begin
			   Csel = Csel_io_data;
			   io_read = 1;

			   if (WriteE) begin
			      ADDRsel = ADDRsel_E;
			      mem_write = 1;

			      if (write_ack) begin
				 // If WriteE, it's either DATAI or CONI so just go to the next
				 // instruction
				 PC_next = 1;
				 set_state(st_instruction_fetch);
			      end else begin
				 set_state(st_read_e);
				 inc_inst_count = 0;
			      end
			   end else begin
			      // If not WriteE, it's either CONSO or CONSZ so save the value
			      // to Mreg and go to the next state to compute the skip
			      Mreg_load = 1;
			      set_state(st_ioread);
			   end
			end


		      // Unassigned codes - eventually will generate the proper trap but just
		      // halts for now !!!
		      dUnassigned, dMUUO:
			set_state(st_unassigned);
			
		    endcase // case (dispatch)
		 end
	    end // case: state[e_calc]

	  // Index register is in Mreg so add Y and loop
	  state[st_index]:
	    begin
	       Asel = Asel_E;
	       Msel = Msel_Mreg;
	       ALUcommand = `aluADD;
	       Csel = Csel_ALUresult;
	       X_hide = 1;	// hide X so instruction_dispatch doesn't see it
	       Y_load = 1;
	       set_state(st_instruction_dispatch);
	    end // case: state[index]

	  // The Byte Pointer is in I, X, and Y so read the location
	  state[st_bp_read]:
	    begin
	       if (Index && !X_hidden) begin
		  // don't have to wait for read_ack since we know it's an accumulator
		  ADDRsel = ADDRsel_X;
		  Csel = Csel_read_data;
		  Mreg_load = 1;
		  set_state(st_bp_index);
	       end else if (Indirect) begin
		  ADDRsel = ADDRsel_E;
		  Csel = Csel_read_data;
		  mem_read = 1;
		  if (read_ack) begin
		     IX_load = 1;
		     Y_load = 1;
		  end
		  set_state(st_bp_read);
	       end else begin
		  // Address of the word containing the byte is now in E, so read that word into
		  // Mreg.  Need to read the word whether we're doing an LDB or DPB.
		  ADDRsel = ADDRsel_E;
		  Csel = Csel_read_data;
		  mem_read = 1;
		  if (read_ack) begin
		     Mreg_load = 1;
		     set_state(st_bp_exec);
		  end else
		    set_state(st_bp_read);
	       end // else: !if(Indirect)
	    end

	  // Index register is in Mreg so add Y and loop.  Just like st_index except loops back
	  // to st_bp_read.
	  state[st_bp_index]:
	    begin
	       Asel = Asel_E;
	       Msel = Msel_Mreg;
	       ALUcommand = `aluADD;
	       Csel = Csel_ALUresult;
	       X_hide = 1;	// hide X so st_bp_read doesn't see it
	       Y_load = 1;
	       set_state(st_bp_read);
	    end // case: state[index]

	  // Execute the Byte Pointer instruction, word containing the byte is in Mreg
	  state[st_bp_exec]:
	    if ((dispatch == dLDB) || (dispatch == dILDB)) begin // LDB or ILDB
	       // AC <- Mreg >> P
	       // This steps on AC but we can't be interrupted before finishing up the
	       // operation in the next state
	       Asel = Asel_Mreg;
	       Msel = Msel_BP_Pneg;
	       ALUcommand = `aluLSH;
	       Csel = Csel_ALUresult;
	       AC_write = 1;
	       set_state(st_ldb);
	    end else begin	// DPB or IDPB
	       // Alow <- BPmask << P
	       Asel = Asel_BPmask;
	       Msel = Msel_BP_P;
	       ALUcommand = `aluLSH;
	       Alow_load = 1;
	       set_state(st_dpb);
	    end

	  // Finish up LDB
	  state[st_ldb]:
	    begin
	       // AC <- AC & BPmask
	       Asel = Asel_BPmask;
	       Msel = Msel_AC;
	       ALUcommand = `aluAND;
	       Csel = Csel_ALUresult;
	       AC_write = 1;
	       if (dispatch == dILDB)
		 clear_first_part_done = 1;
	       PC_next = 1;
	       set_state(st_instruction_fetch);
	    end

	  state[st_dpb]:
	    begin
	       // Areg <- AC << P
	       Asel = Asel_AC;
	       Msel = Msel_BP_P;
	       ALUcommand = `aluLSH;
	       Csel = Csel_ALUresult;
	       Areg_load = 1;
	       set_state(st_dpb_finish);
	    end

	  // Finish up DPB
	  state[st_dpb_finish]:
	    begin
	       // C(E) <- Areg | Mreg masked by ALow
	       Asel = Asel_Areg;
	       Msel = Msel_Mreg;
	       ALUcommand = `aluDPB;
	       Csel = Csel_ALUresult;
	       ADDRsel = ADDRsel_E;
	       mem_write = 1;
	       if (write_ack) begin
		  if (dispatch == dIDPB)
		    clear_first_part_done = 1;
		  PC_next = 1;
		  set_state(st_instruction_fetch);
	       end else
		 set_state(st_dpb_finish);
	    end

	  // Write out the word for BLT
	  state[st_blt_write]:
	    begin
	       // C(AC) <- Mreg
	       Asel = Asel_Mreg;
	       Msel = Msel_AC;
	       ALUcommand = `aluSETA;
	       Csel = Csel_ALUresult;
	       ADDRsel = ADDRsel_M;
	       mem_write = 1;
	       if (write_ack)
		 set_state(st_blt_inc);
	       else
		 set_state(st_blt_write);
	    end

	  // Increment both halves of AC for BLT
	  state[st_blt_inc]:
	    begin
	       Asel = Asel_AC;
	       ALUcommand = `aluAOB;
	       Csel = Csel_ALUresult;
	       AC_write = 1;
	       // BLT terminates when the word we just wrote went into location E
	       if (RIGHT(AC) == E) begin
		  PC_next = 1;
		  set_state(st_instruction_fetch);
	       end else
		 // re-executing the instruction jumps back to the read step
		 set_state(st_instruction_dispatch);
	    end

	  state[st_exch]:
	    begin
	       Asel = Asel_AC;
	       Msel = Msel_Mreg;
	       ALUcommand = `aluSETM;
	       Csel = Csel_ALUresult;
	       AC_write = 1;
	       PC_next = 1;
	       set_state(st_instruction_fetch);
	    end

	  state[st_jsr]:
	    begin
	       // C(E) <- PSW,PC
	       Asel = Asel_PC;	// PC is already incremented
	       ALUcommand = `aluSETA;
	       Csel = Csel_ALUresult;
	       ADDRsel = ADDRsel_E;
	       mem_write = 1;
	       clear_first_part_done = 1;
	       if (write_ack)
		 set_state(st_inc_e);
	       else
		 set_state(st_jsr);
	    end // case: state[st_jsr]

	  state[st_jsp]:
	    begin
	       // AC <- PSW,PC
	       Asel = Asel_PC;	// PC is now incremented
	       ALUcommand = `aluSETA;
	       Csel = Csel_ALUresult;
	       AC_write = 1;
	       clear_first_part_done = 1;
	       set_state(st_jump);
	    end

	  state[st_jsa]:
	    begin
	       // AC <- E,PC
	       Asel = Asel_PC;	// PC is already incremented
	       Msel = Msel_E;
	       Mswap_ue = 1;
	       ALUcommand = `aluHMN;
	       Csel = Csel_ALUresult;
	       AC_write = 1;
	       set_state(st_inc_e);
	    end

	  // Increment E and jump to E+1
	  state[st_inc_e]:
	    begin
	       Asel = Asel_one;
	       Msel = Msel_E;
	       ALUcommand = `aluADD;
	       Csel = Csel_ALUresult;
	       Y_load = 1;
	       set_state(st_jump);
	    end

	  // finish up with a jump from instructions that need an extra cycle
	  state[st_jump]:
	    begin
	       Msel = Msel_E;
	       ALUcommand = `aluSETM;
	       Csel = Csel_ALUresult;
	       PC_load = 1;
	       set_state(st_instruction_fetch);
	    end

	  state[st_push]:
	    begin
	       // AC <- AOB(AC)   need to implement the pushdown_overflow flag !!!
	       Asel = Asel_AC;
	       ALUcommand = `aluAOB;
	       Csel = Csel_ALUresult;
	       AC_write = 1;
	       set_state(st_push2);
	    end

	  state[st_push2]:
	    begin
	       // C(RIGHT(AC)) <- C(E) (which is in Mreg)
	       Asel = Asel_Mreg;
	       ALUcommand = `aluSETA;
	       Csel = Csel_ALUresult;
	       // SETA just uses the A input to the ALU so we'll put AC on the M input and use
	       // that to generate the write address
	       Msel = Msel_AC;
	       ADDRsel = ADDRsel_M;
	       mem_write = 1;
	       if (write_ack) begin
		  PC_next = 1;
		  set_state(st_instruction_fetch);
	       end else
		 set_state(st_push2);
	    end // case: state[st_push2]

	  state[st_pop]:
	    begin
	       // C(E) <- Mreg
	       Msel = Msel_Mreg;
	       ALUcommand = `aluSETM;
	       Csel = Csel_ALUresult;
	       ADDRsel = ADDRsel_E;
	       mem_write = 1;
	       if (write_ack)
		 set_state(st_pop2);
	       else
		 set_state(st_pop);
	    end // case: state[st_pop]

	  state[st_pop2]:
	    begin
	       // AC <- SOB(AC)   need to implement the pushdown_overflow flag !!!!
	       Asel = Asel_AC;
	       ALUcommand = `aluSOB;
	       Csel = Csel_ALUresult;
	       AC_write = 1;
	       if (dispatch == dPOP) begin
		  PC_next = 1;
		  set_state(st_instruction_fetch);
	       end else // POPJ
		 set_state(st_popj);
	    end

	  state[st_popj]:
	    begin
	       // PC <- Mreg (which holds C(AC) before AC was decremented)
	       Msel = Msel_Mreg;
	       ALUcommand = `aluSETM;
	       Csel = Csel_ALUresult;
	       PC_load = 1;
	       set_state(st_instruction_fetch);
	    end

	  state[st_pushj]:
	    begin
	       // C(E) <- PSW,PC
	       Asel = Asel_PC;	// PC is alredy incremented
	       ALUcommand = `aluSETA;
	       Csel = Csel_ALUresult;

	       // The ALU is only passing A through so Mreg was loaded with AC so it can be used
	       // for the address here
	       Msel = Msel_Mreg;
	       ADDRsel = ADDRsel_M;
	       mem_write = 1;
	       clear_first_part_done = 1;
	       if (write_ack)
		 set_state(st_jump);
	       else
		 set_state(st_pushj);
	    end

	  state[st_jffo]:
	    begin
	       // AC+1 <- Areg
	       Asel = Asel_Areg;
	       ALUcommand = `aluSETA;
	       Csel = Csel_ALUresult;
	       ACnext = 1;
	       AC_write = 1;
	       // Jump if overflow
	       if (JFFO_overflow)
		 set_state(st_jump);
	       else begin
		  PC_next = 1;
		  set_state(st_instruction_fetch);
	       end
	    end

	  state[st_write_double]:
	    begin
	       // beginning of double-word instructions (just the double-word shifts and rotates for now)
	       // A <- ALUresult
	       // Alow <- ALUresultlow (to hold for now, write to AC+1 on the next state
	       Asel = Asel_AC;
	       Msel = Msel_E;
	       ALUcommand = ALUinst;
	       Csel = Csel_ALUresult;
	       AC_write = 1;
	       Alow_load = 1;
	       if (SetFlags)
		 Flags_load = 1;
	       set_state(st_write_low);
	    end // case: state[st_write_double]

	  state[st_write_low]:
	    begin
	       // A+1 <- Alow
	       Msel = Msel_E;
	       ALUcommand = `aluSETAlow; // SETAlow routes Alow to C (ALUresult)
	       Csel = Csel_ALUresult;
	       ACnext = 1;
	       AC_write = 1;
	       PC_next = 1;
	       set_state(st_instruction_fetch);
	    end

	  state[st_mul]:
	    if (mul_done) begin
	       Asel = Asel_Areg;
	       Msel = ReadE ? Msel_Mreg : Msel_E;
	       ALUcommand = (dispatch == dIMUL) ? `aluIMUL_SUB : `aluMUL_SUB;
	       Csel = Csel_ALUresult;
	       if (WriteE) begin
		  ADDRsel = ADDRsel_E;
		  mem_write = 1;
	       end

	       if (WriteE && !write_ack)
		 set_state(st_mul);
	       else begin
		  if (SetFlags)
		    Flags_load = 1;

		  if (WriteAC) begin
		     AC_write = 1;
		     if (dispatch == dMUL) begin
			// like st_write_double, write AC now and save Alow for the next state
			Alow_load = 1;
			set_state(st_write_low);
		     end else begin
			PC_next = 1;
			set_state(st_instruction_fetch);
		     end
		  end else begin
		     PC_next = 1;
		     set_state(st_instruction_fetch);
		  end
	       end // else: !if(WriteE && !write_ack)
	    end else begin
	       // the core of the multiply loop
	       Asel = Asel_Areg;
	       Msel = ReadE ? Msel_Mreg : Msel_E;
	       ALUcommand = `aluMUL_ADD;
	       Csel = Csel_ALUresult;
	       Areg_load = 1;
	       Alow_load = 1;
	       mul_step = 1;
	       set_state(st_mul);
	    end

	  state[st_div1]:
	    begin		// Areg,Alow <- |A,Alow|
	       Asel = Asel_AC;
	       ALUcommand = `aluDIV_MAG72;
	       Csel = Csel_ALUresult;
	       Areg_load = 1;
	       Alow_load = 1;
	       set_state(st_div2);
	    end

	  state[st_div2]:
	    begin		// core of the divide loop, subtract and shift
	       Asel = Asel_Areg;
	       Msel = ReadE ? Msel_Mreg : Msel_E;
	       ALUcommand = `aluDIV_OP;
	       Csel = Csel_ALUresult;
	       Areg_load = 1;
	       Alow_load = 1;
	       mul_step = 1;
	       if (div_overflow) begin
		  set_overflow = 1;
		  set_no_divide = 1;
		  PC_next = 1;
		  set_state(st_instruction_fetch);
	       end if (mul_done) begin
		  ALUcommand = `aluDIV_FIXR; // Unrotate R (in Areg)
		  set_state(st_div3);
	       end else
		 set_state(st_div2);
	    end

	  state[st_div3]:
	    begin
	       Asel = Asel_Areg;
	       Msel = ReadE ? Msel_Mreg : Msel_E;
	       ALUcommand = `aluDIV_FIXUP;
	       Csel = Csel_ALUresult;
	       Areg_load = 1;
	       Alow_load = 1;
	       set_state(st_divhigh);
	    end

	  state[st_divhigh]:	// write quotient
	    begin
	       ALUcommand = `aluSETAlow;
	       Csel = Csel_ALUresult;
	       
	       if (WriteE) begin
		  ADDRsel = ADDRsel_E;
		  mem_write = 1;
	       end

	       if (WriteE && !write_ack)
		 set_state(st_divhigh);
	       else begin
		  if (WriteAC) begin // if we're not writing to AC then we could go directly to
				     // st_instruction_fetch here
		     AC_write = 1;
		  end
		  set_state(st_divlow);
	       end
	    end // case: state[st_divhigh]

	  state[st_divlow]:	// write remainder
	    begin
	       if (WriteAC) begin
		  Asel = Asel_Areg;
		  ALUcommand = `aluSETA;
		  Csel = Csel_ALUresult;
		  ACnext = 1;
		  AC_write = 1;
	       end
	       PC_next = 1;
	       set_state(st_instruction_fetch);
	    end

	  state[st_ioread]:
	    begin
	       Msel = Msel_Mreg;
	       ALUcommand = ALUinst;
	       if (jump_condition_0)
		 PC_skip = 1;
	       else
		 PC_next = 1;
	       set_state(st_instruction_fetch);
	    end

	  state[st_unassigned]:
	    set_state(st_halted);
	  state[st_halted]:
	    set_state(st_halted);

	endcase // case (1'b1)
   end
`endif      



`ifdef NOTDEF
   // *********************************************************************************
   // *********************************************************************************
   // *********************************************************************************
   // *********************************************************************************
   // *********************************************************************************
   // *********************************************************************************


   reg [`WORD] switch_register;

   //
   // The state variables in the APR state machine
   //

`define STATE_COUNT 64
`define STATE_SIZE 6
   reg [0:`STATE_COUNT-1] state; // eventually I'll know how large this has to be!!!
   reg [0:`STATE_COUNT-1] next_state;
`ifdef SIM
   reg [0:`STATE_SIZE-1] state_index; // these are just for debugging
   reg [0:`STATE_SIZE-1] next_state_index;
`endif
   
   task set_state;
      input [0:`STATE_SIZE-1] s;
      begin
`ifdef SIM
	 next_state_index = s;
`endif
	 next_state[s] = 1'b1;
      end
   endtask

   // states in the processor state machine
   localparam 
     none = 0,			// used internally as a flag
     init = 0,
     
     instruction_fetch = 1,
     indirect = 2,
     index = 3,
     dispatch = 4,
     write_finish = 5,

     pushj_finish = 10,
     popj_finish = 11,
     pop_finish = 12,
     jra_finish = 13,

     shift_loop = 15,
     jffo_loop = 16,
   
     mul_loop = 20,
     div_loop = 21,
     div_write = 22,

     read_bp_indirect = 25,
     read_bp_index = 26,

     write_bp_finish = 30,
     ldb_start = 31,
     ldb_loop = 32,
     dpb_start = 33,
     dpb_loop = 34,

     blt_write = 40,
     blt_read = 41,
   
     interrupt = 45,

     UUO = 60,
     UUO_finish = 61,
     halting = 62,
     halted = 63;

   //
   // reading and writing memory and ACs comes through here.  select_ac is driven from the
   // clocked logic of the state machine so everything stays in sync.
   //
   reg read_ack, write_ack;
   reg ac_write_ack, ac_read_ack, select_ac;
   reg [`WORD] read_data;
   reg [`WORD] ac_read_data, io_read_data;

   // read multiplexer from memory or AC
   always @(*)
     if (select_ac) begin
	read_ack = ac_read_ack;
	read_data = ac_read_data;
     end else begin
	read_ack = mem_read_ack;
	if (mem_read_ack)
	  read_data = mem_read_data;
	else
	  read_data = read_data; // latch read_data
     end

   // write multiplexer, just the ack signal
   always @(*)
     if (select_ac)
       write_ack = ac_write_ack;
     else
       write_ack = mem_write_ack;
   
   //
   // control the mem_user signal
   //
   
   // memory reference classes
   reg [0:4] 	      mem_ref_class; // the current memory reference class (one-hot)
   reg [0:4] 	      xctr_mode;     // holds how the XCTR instruction wants its memory accesses
				     // for each reference class
   localparam 
     MEM_IF = 0,	      // instruction fetch
     MEM_E1 = 1,	      // index register and memory references that are part of the EA
			      // calculation of instructions
     MEM_D1 = 2,	      // memory references from most instructions
     MEM_E2 = 3,	      // index register and memory references that are part of the EA
			      // calculation of byte pointers (also EXTEND if we implemented it)
     MEM_D2 = 4;	      // memory references that are byte data and the source operand in
			      // BLT (would also be destination EA calculations and operands in
			      // EXTEND if we implemented EXTEND)
     
   always @(*) begin
      if (user_mode)
	mem_user = !MUUO_flag;
      else 
	case (1'b1)	// synopsys full_case parallel_case
	  mem_ref_class[MEM_IF]: mem_user = xctr_mode[MEM_IF];
	  mem_ref_class[MEM_E1]: mem_user = xctr_mode[MEM_E1];
	  mem_ref_class[MEM_D1]: mem_user = xctr_mode[MEM_D1];
	  mem_ref_class[MEM_E2]: mem_user = xctr_mode[MEM_E2];
	  mem_ref_class[MEM_D2]: mem_user = xctr_mode[MEM_D2];
	endcase // case (mem_ref_class)
   end

   // start a read from memory or AC, data shows up on read_data, read_ack out of the read mux
   task read_start;
      input [`ADDR] addr;
      input [0:4]   ref_class;
      begin
	 mem_addr = addr;
	 mem_ref_class = 0;
	 mem_ref_class[ref_class] = 1;
	 if (isAC(addr))
	   ac_mem_read = 1;
	 else
	   mem_read = 1;
      end
   endtask // read
   task read;
      input [`ADDR] addr;
      input [0:4]   ref_class;
      input [0:`STATE_SIZE-1] s;
      begin
	 read_start(addr, ref_class);
	 set_state(s);
      end
   endtask

   // start a write to memory or accumulators
   task write_start;
      input [`ADDR] addr;
      input [`WORD] data;
      input [0:4]   ref_class;
      begin
	 mem_addr = addr;
	 mem_write_data = data;
	 mem_ref_class = 0;
	 mem_ref_class[ref_class] = 1;
	 if (isAC(addr))
	   ac_mem_write = 1;
	 else
	   mem_write = 1;
      end
   endtask // write
   task write;
      input [`ADDR] addr;
      input [`WORD] data;
      input [0:4]   ref_class;
      input [0:`STATE_SIZE-1] s;
      begin
	 write_start(addr, data, ref_class);
	 set_state(s);
      end
   endtask

   // read from an I/O device
   task read_io;
      input [`DEVICE] dev;
      input 	      con;
      input [0:`STATE_SIZE-1] s;
      begin
	 mem_addr <= IO_ENCODE(dev, con);
	 io_read <= 1;
	 set_state(s);
      end
   endtask
   
   // write to an I/O device
   task write_io;
      input [`DEVICE] dev;
      input 	      con;
      input [`WORD]   data;
      input [0:`STATE_SIZE-1] s;
      begin
	 mem_addr <= IO_ENCODE(dev, con);
	 mem_write_data <= data;
	 io_write <= 1;
	 set_state(s);
      end
   endtask
	 

   //
   // ALU Interface
   //
   
   // some internal registers used for multiply and divide (I should put these through the ALU
   // if possible)
   reg [`WORD] op2;
   reg [`DWORD] ALUstep;	// for shifts, rotates, multiplies, and divides
   reg [0:`CSIZE-1] ALUcount;
   wire [0:`CSIZE-1] ALUcount_inc = ALUcount + `CSIZE'b1;
   wire [0:`CSIZE-1] ALUcount_dec = ALUcount - `CSIZE'b1;
   reg 		     shift_bit;	// the sign bit when shifting the multiply product and the
				// quotient bit when dividing
   
   // pull out the size of a shift or rotate from E
   wire [0:`CSIZE-1] shift_count = { E[18], E[`WORDSIZE-8:`WORDSIZE-1] };

   // at the end of a multiply, we need one more right shift but then we need to undo the shift
   // for the left word while duplicating the sign bit in the right word.  p_left and p_right do
   // that.
   wire [`WORD]      p_left;
   wire [`WORD]      p_right;
   assign p_left = ALUresult;
   assign p_right = { ALUresult[0], ALUresultlow[0:`WORDSIZE-2] };

   reg [`aluCMDwidth-1:0] ALUcommand;
   reg [`WORD] 		  ALUop1low; // doubleword operations are op1,op1low
   reg [`WORD] 		  ALUop1;    // first operand
   reg [`WORD] 		  ALUop2;    // second operand
   wire [`WORD] 	  ALUresultlow;
   wire [`WORD] 	  ALUresult;
   wire 		  ALUcarry0;
   wire 		  ALUcarry1;
   wire 		  ALUoverflow;
   wire 		  ALUzero;
   alu alu(clk, reset, ALUcommand, ALUop1low, ALUop1, ALUop2,
	   ALUresultlow, ALUresult, ALUcarry0, ALUcarry1, ALUoverflow, ALUzero);

   //
   // PI System
   //

   reg 	      pi_ge;			  // global enable
   reg [1:7]  pi_le;			  // level enable
   reg [1:7]  pi_ip;			  // in progress
   reg [1:7]  pi_sr;			  // software request
   wire [1:7] pi_hr = pi_trap | pi_error | pi_io; // hardware request
   reg [1:7]  pi_trap = 0;		  // trap interrupts from the APR
   reg [1:7]  pi_error = 0;		  // error interrupts from the APR
   reg [1:7]  pi_io = 0;		  // interrupt requests from I/O devices

   // these are clocked
   reg 	      interrupt_instruction;	  // set while executing an interrupt instruction
   reg 	      uuo_instruction;	// set while executing an interrupt instruction for UUO handling
   // these are unclocked
   reg 	      set_interrupt_instruction;
   reg 	      set_uuo_instruction;
   reg 	      clear_interrupt;

   // put the bits together for a status word to be read by CONI
   wire [`WORD] pi_status = { 11'b0, pi_sr, 3'b0, pi_ip, pi_ge, pi_le };

`ifdef OLD_PI
   // !!! how about getting rid of all this converting the interrupt level to a 4-bit number
   reg [0:3] 	pi_level_ip;			      // level in progress, 8 = none
   reg [0:3] 	pi_level_rq;			      // level requesting interrupt, 8 = none
   wire 	pi_now = (pi_level_rq < pi_level_ip); // true if it's time to take an interrupt

   always @(*) begin
      case (1'b1)
	pi_ip[1]: pi_level_ip <= 1;
	pi_ip[2]: pi_level_ip <= 2;
	pi_ip[3]: pi_level_ip <= 3;
	pi_ip[4]: pi_level_ip <= 4;
	pi_ip[5]: pi_level_ip <= 5;
	pi_ip[6]: pi_level_ip <= 6;
	pi_ip[7]: pi_level_ip <= 7;
	default:  pi_level_ip <= 8;
      endcase
   end	

   always @(*) begin
      if (!pi_ge)
	pi_level_rq <= 4'd8;
      else
	// Software requests happen even if the level enable is off.
	// ordering definitely matters here to get priority
	case (1'b1)
	  pi_sr[1] | (pi_le[1] & pi_hr[1]): pi_level_rq <= 4'd1;
	  pi_sr[2] | (pi_le[2] & pi_hr[2]): pi_level_rq <= 4'd2;
	  pi_sr[3] | (pi_le[3] & pi_hr[3]): pi_level_rq <= 4'd3;
	  pi_sr[4] | (pi_le[4] & pi_hr[4]): pi_level_rq <= 4'd4;
	  pi_sr[5] | (pi_le[5] & pi_hr[5]): pi_level_rq <= 4'd5;
	  pi_sr[6] | (pi_le[6] & pi_hr[6]): pi_level_rq <= 4'd6;
	  pi_sr[7] | (pi_le[7] & pi_hr[7]): pi_level_rq <= 4'd7;
	  default: pi_level_rq <= 4'd8;
	endcase	  
   end

   // set PI in-progress flag
   task pi_set_ip;
      pi_ip[pi_level_rq] <= 1;
   endtask

   // clear PI in-progress flag
   task pi_clear_ip;
      pi_ip[pi_level_ip] <= 0;
   endtask

`else
   // this ought to help get rid of the pi_level_* variables.  still need a task to clear the
   // current level in-progress.
   reg 		pi_now;
   reg [`ADDR] 	pi_vector;
   wire [1:7] 	pi_ir = pi_sr | (pi_le & pi_hr); // interrupt request - software requests happen
						 // even if the level enable is off
   task set_pi_vector;
      input integer level;
      pi_vector = `ADDRSIZE'o40+2*level;
   endtask

   always @(*) begin
      case (1'b1)
	pi_ir[1]: set_pi_vector(1);
	pi_ir[2]: set_pi_vector(2);
	pi_ir[3]: set_pi_vector(3);
	pi_ir[4]: set_pi_vector(4);
	pi_ir[5]: set_pi_vector(5);
	pi_ir[6]: set_pi_vector(6);
	pi_ir[7]: set_pi_vector(7);
	default: set_pi_vector(0);
      endcase	
   end

   always @(*) begin
      if (!pi_ge)
	pi_now = 0;
      else
	case (1'b1)
	  // The ordering is definitely important here.
	  pi_ip[1]: pi_now = 0;
	  pi_ir[1]: pi_now = 1;
	  pi_ip[2]: pi_now = 0;
	  pi_ir[2]: pi_now = 1;
	  pi_ip[3]: pi_now = 0;
	  pi_ir[3]: pi_now = 1;
	  pi_ip[4]: pi_now = 0;
	  pi_ir[4]: pi_now = 1;
	  pi_ip[5]: pi_now = 0;
	  pi_ir[5]: pi_now = 1;
	  pi_ip[6]: pi_now = 0;
	  pi_ir[6]: pi_now = 1;
	  pi_ip[7]: pi_now = 0;
	  pi_ir[7]: pi_now = 1;
	  default: pi_now = 0;
	endcase	
   end

   // set PI in-progress flag
   task pi_set_ip;
      case (1'b1)
	pi_ir[1]: pi_ip[1] <= 1;
	pi_ir[2]: pi_ip[2] <= 1;
	pi_ir[3]: pi_ip[3] <= 1;
	pi_ir[4]: pi_ip[4] <= 1;
	pi_ir[5]: pi_ip[5] <= 1;
	pi_ir[6]: pi_ip[6] <= 1;
	pi_ir[7]: pi_ip[7] <= 1;
      endcase
   endtask	

   // clear PI in-progress flag
   task pi_clear_ip;
      case (1'b1)
	pi_ip[1]: pi_ip[1] <= 0;
	pi_ip[2]: pi_ip[2] <= 0;
	pi_ip[3]: pi_ip[3] <= 0;
	pi_ip[4]: pi_ip[4] <= 0;
	pi_ip[5]: pi_ip[5] <= 0;
	pi_ip[6]: pi_ip[6] <= 0;
	pi_ip[7]: pi_ip[7] <= 0;
      endcase
   endtask	

`endif

   // APR device
   reg apr_ehe = 0,	     // error interrupt enable for the hard error flag
       apr_ese = 0,	     // error interrupt enable for the soft error flag
       apr_ee2 = 0,	     // error interrupt enable for the executive mode trap-2 flag
       apr_ee1 = 0,	     // error interrupt enable for the executive mode trap-1 flag
       apr_eu2 = 0,	     // error interrupt enable for the user mode trap-2 flag
       apr_eu1 = 0,	     // error interrupt enable for the user mode trap-1 flag
       apr_the = 0,	     // trap interrupt enable for the hard error flag
       apr_tse = 0,	     // trap interrupt enable for the soft error flag
       apr_te2 = 0,	     // trap interrupt enable for the executive mode trap-2 flag
       apr_te1 = 0,	     // trap interrupt enable for the executive mode trap-1 flag
       apr_tu2 = 0,	     // trap interrupt enable for the user mode trap-2 flag
       apr_tu1 = 0,	     // trap interrupt enable for the user mode trap-1 flag
       apr_fhe = 0,	     // the hard error flag
       apr_fse = 0,	     // the soft error flag
       apr_fe2 = 0,	     // the executive mode trap-2 flag
       apr_fe1 = 0,	     // the executive mode trap-1 flag
       apr_fu2 = 0,	     // the user mode trap-2 flag
       apr_fu1 = 0,	     // the user mode trap-1 flag
       apr_eir = 0,	     // indicates that an error interrupt is pending, even if the error
			     // interrupt is not connected to the PI system
       apr_tir = 0;	     // indicates that a trap interrupt is pending, even if the error
			     // interrupt is not connected to the PI system
   reg [0:2] apr_eia = 0;    // the PI assignment for the error interrupt. 0 means not connected
   reg [0:2] apr_tia = 0;    // the PI assignment for the trap interrupt. 0 means not connected
   wire [`WORD] apr_status = // APR status word for CONI
		{ apr_ehe, apr_ese, apr_ee2, apr_ee1, apr_eu2, apr_eu1, apr_eia,
		  apr_the, apr_tse, apr_te2, apr_te1, apr_tu2, apr_tu1,	apr_tia,	
		  7'b0, apr_fhe, apr_fse, apr_fe2, apr_fe1, apr_fu2, apr_fu1, apr_eir, apr_tir, 3'b0 };

   task reset_apr;
      begin
	 apr_ehe <= 0;
	 apr_ese <= 0;
	 apr_ee2 <= 0;
	 apr_ee1 <= 0;
	 apr_eu2 <= 0;
	 apr_eu1 <= 0;
	 apr_the <= 0;
	 apr_tse <= 0;
	 apr_te2 <= 0;
	 apr_te1 <= 0;
	 apr_tu2 <= 0;
	 apr_tu1 <= 0;
	 apr_fhe <= 0;
	 apr_fse <= 0;
	 apr_fe2 <= 0;
	 apr_fe1 <= 0;
	 apr_fu2 <= 0;
	 apr_fu1 <= 0;
//	 apr_eir <= 0;   // these are cleared as a side-effect of clearing other things
//	 apr_tir <= 0;
	 apr_eia <= 0;
	 apr_tia <= 0;
      end
   endtask
	 

   // set error interrupt
   always @(*) begin
      pi_error = 0;
      if ((apr_ehe && (apr_fhe || mem_nxm)) ||	     // notice NXM or page fail immediately.
	  (apr_ese && (apr_fse || mem_page_fail)) || // the error flag will be set on the next
						     // clock.
	  (apr_ee2 && apr_fe2) ||
	  (apr_ee1 && apr_fe1) ||
	  (apr_eu2 && apr_fu2) ||
	  (apr_eu1 && apr_fu1)) 
	begin
	   apr_eir = 1;
	   if (apr_eia != 0)
	     pi_error[apr_eia] = 1;
	end else
	  apr_eir = 0;
   end

   // set trap interrupt
   always @(*) begin
      pi_trap = 0;
      if ((apr_the && (apr_fhe || mem_nxm)) ||	     // notice NXM or page fail immediately.
	  (apr_tse && (apr_fse || mem_page_fail)) || // the error flag will be set on the next
						     // clock
	  (apr_te2 && apr_fe2) ||
	  (apr_te1 && apr_fe1) ||
	  (apr_tu2 && apr_fu2) ||
	  (apr_tu1 && apr_fu1)) 
	begin
	   apr_tir = 1;
	   if (apr_tia != 0)
	     pi_trap[apr_tia] = 1;
	end else
	  apr_tir = 0;
   end
   
   task reset_pi;
      begin
	 pi_ge <= 0;
	 pi_le <= 0;
	 pi_ip <= 0;
	 pi_sr <= 0;

	 // reset the APR_* flags too? !!!
      end
   endtask

   task set_overflow;
      begin
	 overflow <= 1;
	 if (user_mode)
	   apr_fu1 <= 1;
	 else
	   apr_fe1 <= 1;
      end
   endtask

   task set_pushdown_overflow;
      begin
	 if (user_mode)
	   apr_fu2 <= 1;
	 else
	   apr_fe2 <= 1;
      end
   endtask

   

   //
   // All the various flags and state words and registers of the processor
   //
   reg [`WORD]  accumulators[0:15];	// Fast Accumulators
   reg [`ADDR] 	PC;		// Program Counter
   reg [`WORD] 	inst;		// instruction read from memory
   reg [`ADDR]  E;		// Effective Address
   reg [`WORD]  E_last_read;	// keep the last value read in calculating E
   reg [`WORD]  byte_pointer;	// saves the byte pointer when doing E calculations
   reg 		latch_byte_pointer;
`ifdef SIM
   reg 		latch_inst;
`endif
   reg 		MUUO_flag, UC_flag; // distinguish LUUO, MUUO, and unassigned codes. setting
				// MUUO makes memory accesses go to exec memory space so
				// unassigned code need to set MUUO as well.
   reg 		set_MUUO_flag, set_UC_flag; // unclocked
   reg 		skip_on_fault;	// disables the page_fail detection

`ifdef SIM
   reg [`ADDR] 	inst_addr;	// used by the disassembler
`endif
 		 
   // Processor flags
   reg 		carry0;
   reg 		carry1;
   reg 		overflow;
   reg 		floating_overflow;
   reg 		user_mode;	// user/exec mode
   reg 		first_part_done, floating_underflow, no_divide;

   // hacks for signals I need to ignore on the lhs of an assignment
   reg [1:5] 	ignore5;
   reg 		ignore;
   

   // these are computed here so they're in one place and so they're the right size. when
   // executing an interrupt instruction, don't jump ahead too much.  need to make sure this is
   // always right. !!!
   wire [`ADDR]  PC_next = interrupt_instruction ? PC : PC + `ADDRSIZE'o1;
   wire [`ADDR]  PC_skip = PC + `ADDRSIZE'o2;

   wire [0:3] 	 ac = A(inst);
   wire [0:3] 	 ac_next = ac + 1'b1;

   wire [`WORD]  AC_inst = `AC;
   wire [`WORD]  E_word = { `HALFZERO, E };
   
   // for EA calculation, add in the index register if needed but this is after Y has been put
   // in E and C(X) read in on read_data so ...
   wire [`ADDR]  E_indexed = E + RIGHT(read_data);
   

`ifdef SIM
`include "disasm.vh"
`endif


   // For SKIP, CAI, CAM instructions
   function [0:2] skip_condition;
      input [`WORD]   op;
      skip_condition = op[6:8];
   endfunction
   localparam
     skip_never = 3'o0,
     skipl = 3'o1,
     skipe = 3'o2,
     skiple = 3'o3,
     skipa = 3'o4,
     skipge = 3'o5,
     skipn = 3'o6,
     skipg = 3'o7;

   // Compute a skip or jump condition by comparing the ALU output to 0
   reg 			  jump_condition_0;
   always @(*)
     case (skip_condition(inst)) // synopsys full_case parallel_case
       skip_never: jump_condition_0 = 0;
       skipl: jump_condition_0 = NEGATIVE(ALUresult);
       skipe: jump_condition_0 =  ALUzero;
       skiple: jump_condition_0 = ALUzero | NEGATIVE(ALUresult);
       skipa: jump_condition_0 = 1;
       skipge: jump_condition_0 = ALUzero | !NEGATIVE(ALUresult);
       skipn: jump_condition_0 = !ALUzero;
       skipg: jump_condition_0 = !ALUzero &!NEGATIVE(ALUresult);
     endcase // case (skip_condition(inst))

   // Compute a skip or jump condition looking at the ALU output.  This signal only makes
   // sense when the ALU is performing a subtraction.
   reg 			  jump_condition;
   always @(*)
     case (skip_condition(inst)) // synopsys full_case parallel_case
       skip_never: jump_condition = 0;
       skipl: jump_condition = !ALUzero & (ALUoverflow ^ NEGATIVE(ALUresult));
       skipe: jump_condition = ALUzero;
       skiple: jump_condition = ALUzero | (ALUoverflow ^ NEGATIVE(ALUresult));
       skipa: jump_condition = 1;
       skipge: jump_condition = ALUzero | !(ALUoverflow ^ NEGATIVE(ALUresult));
       skipn: jump_condition = !ALUzero;
       skipg: jump_condition = !ALUzero & !(ALUoverflow ^ NEGATIVE(ALUresult));
     endcase
   
   // each instruction sequence ends with one of these: next, jump, skip, or execute
   task next;
      begin
	 clear_interrupt = 1; // normal instruction processing clears the various interrupt flags
	 
	 set_PC = 1;
	 next_PC = PC_next;
	 read_start(PC_next, MEM_IF);
	 execute();
      end
   endtask // next
   task jump;
      input [`ADDR] jump_dest;
      begin
	 clear_interrupt = 1; // normal instruction processing clears the various interrupt flags

	 set_PC = 1;
	 next_PC = jump_dest;
	 read_start(jump_dest, MEM_IF);
	 execute();
      end
   endtask // jump
   task skip;
      begin
	 clear_interrupt = 1; // normal instruction processing clears the various interrupt flags

	 set_PC = 1;
	 next_PC = PC_skip;
	 read_start(PC_skip, MEM_IF);
	 execute();
      end
   endtask // skip
   task execute;
      begin
	 // next_PC is already set and read has started
`ifdef SIM
	 latch_inst = 1;
`endif
	 set_state(instruction_fetch);
      end
   endtask // execute

   
   //
   // functions for instruction decoding and driving the ALU
   //

   reg readE, writeE, readIO, writeIO, conIO, writeAC, setFlags, unassigned_code;

   // returns the ALUcommand for the MOV[ESNM] instruction
   function [0:`aluCMDwidth-1] move_alucmd;
      input [`WORD]   inst;
      case (inst[5:6])
	0: move_alucmd = `aluSETM;
	1: move_alucmd = `aluSWAP;
	2: move_alucmd = `aluNEGATE;
	3: move_alucmd = `aluMAGNITUDE;
	endcase
   endfunction

   // returns the ALUcommand for the logical instructions
   function [0:`aluCMDwidth-1] logical_alucmd;
      input [`WORD]   inst;
      logical_alucmd = `aluSETZ | inst[3:6];
   endfunction

`ifdef NOTDEF
   // returns the ALUcommand for the halfword move instructions
   function [0:`aluCMDwidth-1] halfword_alucmd;
      input [`WORD]   inst;
      halfword_alucmd = `aluHLL | { halfword_extend(inst) == extend_sign, inst[3], inst[6] };
   endfunction
`endif

   // returns the extend mode for the halfword move instructions
   // 0 - none
   // 1 - zeros
   // 2 - ones
   // 3 - sign extend
   localparam 
     extend_none = 0,
     extend_zero = 1,
     extend_ones = 2,
     extend_sign = 3;
   function [0:1] halfword_extend;
      input [`WORD]   inst;
      halfword_extend = inst[4:5];
   endfunction

   // returns the memory mode of serveral different instructions
   // 0 - basic		AC <- C(E)
   // 1 - immediate	AC <- 0,E
   // 2 - memory	C(E) <- AC
   // 3 - self		C(E) and AC <- C(E)  (AC if A is non-zero)
   // 3 - both		C(E) and AC <- C(E)
   localparam
     mode_basic = 0,
     mode_immediate = 1,
     mode_memory = 2,
     mode_self = 3,		// it's self or both depending on the instruction
     mode_both = 3;
   function [0:1] inst_mode;
      input [`WORD]   inst;
      inst_mode = inst[7:8];
   endfunction
   
   function mode_readE;
      input [`WORD]   inst;
      case (inst_mode(inst))
	mode_basic, mode_memory, mode_both: mode_readE = 1;
	mode_immediate: mode_readE = 0;
      endcase
   endfunction
   
   function integer mode_writeE;
      input [`WORD]   inst;
      case (inst_mode(inst))
	mode_basic, mode_immediate: mode_writeE = none;
	mode_memory, mode_both: mode_writeE = dispatch;
      endcase
   endfunction
   
   function integer mode_writeAC;
      input [`WORD]   inst;
      case (inst_mode(inst))
	mode_basic, mode_immediate: mode_writeAC = dispatch;
	mode_both: mode_writeAC = write_finish;
	mode_memory: mode_writeAC = none;
      endcase
   endfunction // case
   
   function integer mode_writeFlags;
      input [`WORD]   inst;
      case (inst_mode(inst))
	mode_basic, mode_immediate: mode_writeFlags = dispatch;
	mode_memory, mode_both: mode_writeFlags = write_finish;
      endcase
   endfunction


   task aluc_set;
      input [`DWORD] 	       op1;
      input [0:`aluCMDwidth-1] cmd;
      input [`WORD] 	       op2;
      begin
	 ALUop1 = DLEFT(op1);
	 ALUop1low = DRIGHT(op1);
	 ALUcommand = cmd;
	 ALUop2 = op2;
      end
   endtask

   task alu_set;
      input [`WORD] 	       op1;
      input [0:`aluCMDwidth-1] cmd;
      input [`WORD] 	       op2;
      aluc_set({op1, `AC_next}, cmd, op2);
   endtask

   task decode_flags;
      input  	       readEctl;    // 1 if needs to read E into read_data
      input integer    writeEst;    // the state to write E
      input integer    writeACst;   // the state to write AC
      input integer    setFlagsst;  // the state to set flags
      begin
	 readE = readEctl;
	 writeE = writeEst ? state[writeEst] : 1'b0;
	 writeAC = writeACst ? state[writeACst] : 1'b0;
	 setFlags = setFlagsst ? state[setFlagsst] : 1'b0;
	 readIO = 0;
	 writeIO = 0;
	 unassigned_code = 0;
      end
   endtask      

   task decodec;
      input [`DWORD] 	       op1;
      input [0:`aluCMDwidth-1] cmd;
      input [`WORD] 	       op2;
      input 		       readEctl;    // 1 if needs to read E into read_data
      input integer 	       writeEst;    // the state to write E
      input integer 	       writeACst;   // the state to write AC
      input integer 	       setFlagsst;  // the state set flags
      begin
	 aluc_set(op1, cmd, op2);
	 decode_flags(readEctl, writeEst, writeACst, setFlagsst);
      end
   endtask

   task decode;
      input [`WORD] 	       op1;
      input [0:`aluCMDwidth-1] cmd;
      input [`WORD] 	       op2;
      input 		       readEctl;    // 1 if needs to read E into read_data
      input integer 	       writeEst;    // the state to write E
      input integer 	       writeACst;   // the state to write AC
      input integer 	       setFlagsst;  // the state to set flags
      begin
	 decodec({ op1, `AC_next }, cmd, op2, readEctl, writeEst, writeACst, setFlagsst);
      end
   endtask

   task decodeIO;
      input [`WORD] 	       op1;
      input [0:`aluCMDwidth-1] cmd;
      input [`WORD] 	       op2;
      input 		       readEctl;    // 1 if needs to read E into read_data
      input integer 	       writeEst;    // the state to write E
      input 		       readIOctl;   // 1 if needs to do an IO read
      input integer 	       writeIOst;   // the state to write IO
      input 		       con;	    // 1 if conditions, else data
      begin
	 decodec({ op1, `AC_next }, cmd, op2, readEctl, writeEst, none, none);
	 readIO = readIOctl;
	 writeIO = writeIOst ? state[writeIOst] : 1'b0;
	 conIO = con;
      end
   endtask
   

   // sets the ALU operation for the TEST instructions (why doesn't this work as a function?)
   reg [0:`aluCMDwidth-1] test_op;
   always @(*) begin
      case (inst[3:4])		// name the bits symbolically !!!
	0: test_op = `aluSETA;
	1: test_op = `aluANDCM;
	2: test_op = `aluXOR;
	3: test_op = `aluIOR;
      endcase // case (inst[3:4])
   end // always @ begin

   // set the memory source operand for typical moded instructions
   reg [`WORD] mem_src;
   always @(*) begin
      case (inst_mode(inst))
	mode_basic: mem_src = read_data;
	mode_immediate: mem_src = E_word;
	mode_memory: mem_src = read_data;
	mode_both: mem_src = read_data;
      endcase
   end

`ifdef NOTDEF
   // the source for move (full-word and half-word) instructions
   reg [`WORD] move_src;
   always @(*) begin
      case (inst_mode(inst))
	mode_basic: move_src = read_data;
	mode_immediate: move_src = E_word;
	mode_memory: move_src = AC_inst;
	mode_both: move_src = read_data;
      endcase
   end
`endif //  `ifdef NOTDEF
   

`include "opcodes.vh"
   
   // Combinational logic for the APR state machine - read the instruction at PC, calculate E,
   // execute the instruction.  No pipelining at all here, maybe someday.

   reg [`ADDR] next_PC;		// the combinational logic calculates the next PC
   reg 	       set_PC;		// a flag to tell the clocked logic to set PC from next_PC
   reg 	       ac_mem_write;	// tells the clocked logic to set the AC addressed in mem_addr
   reg 	       ac_mem_read;	// just used as part of a read in-progress flag

   always @(*) begin
      running = 1;
      mem_read = 0;		// reset mem_read unless explicitly set otherwise
      mem_write = 0;
      io_read = 0;
      io_write = 0;

      inst = inst;		// latch this
      mem_addr = mem_addr;	// this shouldn't be latched but it fails if it's not !!!
//      mem_addr = `ADDRSIZE'oX;

      mem_write_data = `WORDSIZE'oX;  // ALUresult;
      mem_ref_class = 0;

      ac_mem_write = 0;
      ac_mem_read = 0;

      clear_interrupt = 0;
      set_interrupt_instruction = 0;
      set_uuo_instruction = 0;
      set_MUUO_flag = 0;
      set_UC_flag = 0;

`ifdef SIM
      latch_inst = 0;
`endif
      set_PC = 0;
      next_PC = `ADDRSIZE'oXXXXXX;
      
      next_state = 0;
      
      if (reset) begin
	 running = 0;
 	 set_state(init);
      end
      
      // If a memory operation is in progress, do nothing until it completes
      else if (mem_in_progress && !(read_ack || write_ack))
	;

      // XCTRI (XCT in exec mode with bit [09] on) sets the skip_on_fault flag.  In this case,
      // if we see page_fail or NXM, then we abort the instruction and skip instead of taking an
      // interrupt.
`ifdef NOTDEF
      // this isn't working.  simply looking at mem_page_fail causes Icarus to go into a tight loop !!!
      else if (skip_on_fault && (mem_page_fail || mem_nxm)) begin
	// mem_write, mem_read, io_write, and io_read are cleared which ought to clear the fault
	// condition
	$display("Skipping on Fault...exit");
	skip();			// need to write a diagnostic to verify this !!!
      end
`endif

      // This is the interrupt check.  We appear to bail out immediately to the interrupt
      // handling state but there are three cases.  Errors (hard and soft, i.e. NXM and Page
      // Faults) abort the current instruction.  Traps (U1, U2, E1, and E2 from arithmetic
      // overflow and push-down overflow) also bail out immediately but since they're only set
      // at the very end of the instruction, the PC is advanced and the next instruction is the
      // one on-deck (as it were) for executing when the interrupt is dismissed.  Interrupt
      // requests from I/O devices are only clocked into the PI system during memory reads or in
      // selected points in long-running instructions (look for pi_io <= mem_pi_req) and so
      // those are the only points where a hardware interrupt will interrupt an instruction.
      else if (pi_now & !state[interrupt])
	// checking for state[interrupt] is kind of a crock but otherwise we stay in the
	// interrupt state an extra cycle until it sets pi_ip which clear pi_now but by then
	// we've lost the right pi_vector.
	set_state(interrupt);

      else if (writeE)
	write(E, ALUresult, MEM_D1, write_finish);

      else if (writeIO)
	case (IODEV(inst))
	  APR, PI:		// local devices
	    next();
	  default:		// send it out the I/O bus
	    write_io(IODEV(inst), conIO, ALUresult, write_finish);
	endcase

      // The main state machine for the APR
      else begin
	 case (1'b1)		// synopsys full_case parallel_case
	   state[init]:
	     begin
		jump(`ADDRSIZE'o001000); // need a better way to pick the start address !!!
		// in fact, the better way here may be to insert a JRST into the
		// instruction register and jump to instruction dispatch. it doesn't help
		// with picking the destination of the JRST though.
	     end

	   // come here after the instruction fetch or after reading an indirect word for
	   // calculating the Effective Address.
	   state[instruction_fetch], state[indirect]:
	     begin
		if (state[instruction_fetch])
		  inst = read_data; // this latches

		if (X(read_data) != 0)				// index
		  read({ `XFILL, X(read_data) }, MEM_E1, index);
		else if (I(read_data))				// indirect
		  read(Y(read_data), MEM_E1, indirect);
		else		// immediate
		  if (readIO)
		    read_io(IODEV(inst), conIO, dispatch);
		  else if (readE)
		    read(Y(read_data), MEM_D1, dispatch);
		  else
		    set_state(dispatch);
	     end
	   
	   // need to add the previous Y (now in E) and C(X) in read_data
	   state[index]:
	     begin
		if (I(E_last_read))
		  read(E_indexed, MEM_E1, indirect);
		else
		  if (readIO)
		    read_io(IODEV(inst), conIO, dispatch);
		  else if (readE)
		    read(Y(E_indexed), MEM_D1, dispatch);
		  else
		    set_state(dispatch);
	     end

	   // the starting point for executing instructions.  inst and E are set by now.
	   state[dispatch]:
	     begin
		if (unassigned_code)
		  set_state(UUO); // !!! this will be fixed at some point
		else
		casex (OP(inst))
		  LDB, DPB:		// Load/Deposit Byte
		    // do I,X,Y calculation or read the data word
		    if (X(read_data) != 0) begin // index
		       read({ `XFILL, X(read_data)}, MEM_E2, read_bp_index);
		    end else if (I(read_data)) begin // indirect
		       read(Y(read_data), MEM_E2, read_bp_indirect); // loop for indirect
		    end else begin
		       case (OP(inst)) // synopsys full_case parallel_case
			 LDB, ILDB:
			   read(Y(read_data), MEM_D2, ldb_start); // get the data word
			 DPB, IDPB:
			   read(Y(read_data), MEM_D2, dpb_start); // get the data word
		       endcase // case (OP(inst))
		    end

		  ILDB, IDPB:	// Increment Pointer and Load/Deposit Byte
		    if (first_part_done)
		      // do I,X,Y calculation or read the data word
		      if (X(read_data) != 0) begin // index
			 read({ `XFILL, X(read_data)}, MEM_E2, read_bp_index);
		      end else if (I(read_data)) begin // indirect
			 read(Y(read_data), MEM_E2, read_bp_indirect); // loop for indirect
		      end else begin
			 case (OP(inst)) // synopsys full_case parallel_case
			   LDB, ILDB:
			     read(Y(read_data), MEM_D2, ldb_start); // get the data word
			   DPB, IDPB:
			     read(Y(read_data), MEM_D2, dpb_start); // get the data word
			 endcase // case (OP(inst))
		      end

		    else
		      write(E, ALUresult, MEM_D1, write_bp_finish);

		  IMULI, IMUL, IMULM, IMULB, MULI, MUL, MULM, MULB:
		    set_state(mul_loop);

		  IDIVI, IDIV, IDIVM, IDIVB, DIVI, DIV, DIVM, DIVB:
		    // The ALU is already set up with the first trip through so we can detect
		    // overflow right here.
		    if (!NEGATIVE(ALUresult))
		      next();
		    else
		      set_state(div_loop);

		  // Compare Accumulator to Immediate/Memory
		  CAI,CAIL,CAIE,CAILE,CAIA,CAIGE,CAIN,CAIG:
		    if (jump_condition)
		      skip();
		    else
		      next();
		  
		  CAM,CAML,CAME,CAMLE,CAMA,CAMGE,CAMN,CAMG:
		    if (jump_condition)
		      skip();
		    else
		      next();

		  SKIP,SKIPL,SKIPE,SKIPLE,SKIPA,SKIPGE,SKIPN,SKIPG:
		    if (jump_condition_0)
		      skip();
		    else
		      next();

		  AOJ, AOJL, AOJE, AOJLE, AOJA, AOJGE, AOJN, AOJG,
		    SOJ, SOJL, SOJE, SOJLE, SOJA, SOJGE, SOJN, SOJG:
		      if (jump_condition_0)
			jump(E);
		      else
			next();

		  ASH, ROT, LSH: set_state(shift_loop);
		  ASHC, ROTC, LSHC: set_state(shift_loop);
`ifdef CIRC
		  CIRC: set_state(shift_loop);
`endif

		  JFFO:		// Jump if Find First One
		    if (AC_inst == 0)
		      next();
		    else
		      set_state(jffo_loop);

		  /* EXCH BLT AOBJP AOBJN JRST JFCL XCT MAP */
		  
		  BLT:		// Block Transfer
		    read(LEFT(AC_inst), MEM_D2, blt_write);

		  AOBJP:	// Add One to Both halves of AC, Jump if Positive
		    if (NEGATIVE(ALUresult))
		      next();
		    else
		      jump(E);

		  AOBJN:	// Add One to Both halves of AC, Jump if Negative
		    if (NEGATIVE(ALUresult))
		      jump(E);
		    else
		      next();

		  JRST:		// Jump and Restore
		    begin
		       if (!inst[9] && !inst[10])
			 jump(E); // if not trapping or halting

		       if (inst[9]) // dismiss the current interrupt
			 if (user_mode)
			   set_state(UUO);
			 else 
			   jump(E);

		       if (inst[10]) // halt
			  if (user_mode)
			    set_state(UUO);
			  else
			    set_state(halting);
		    end

		  JFCL:		// Jump on Flag and Clear
		    if ((inst[9] && overflow) ||
			(inst[10] && carry0) ||
			(inst[11] && carry1) ||
			(inst[12] && floating_overflow))
		      jump(E);
		    else
		      next();

		  XCT:		// Execute instruction at E
		    begin
		       // !!! do I need to clear interrupt_instruction and friends here?
		       // Should only matter if XCT is an interrupt instruction and I don't
		       // know what that should do anyway.
		       read_start(E, MEM_IF);
		       execute();
		    end
		  
		  PUSHJ:	// Push down and Jump
		    write(RIGHT(ALUresult), { `FLAGS, PC_next }, MEM_D1, pushj_finish);

		  PUSH:		// AC <- aob(AC) then C(AC) <- C(E)
		    // haven't written the incremented AC back to AC yet, so use ALUresult
		    write(RIGHT(ALUresult), read_data, MEM_D1, write_finish);

		  POP:		// C(E) <- C(AC) then AC <- sob(AC)
		    read(RIGHT(AC_inst), MEM_D1, pop_finish);

		  POPJ:		// Pop up and Jump
		    read(RIGHT(AC_inst), MEM_D1, popj_finish);

		  JSP:		// Jump and Save PC
		    jump(E);

		  JRA:		// Jump and restore AC
		    // be nice to start this read earlier but this'll work !!!
		    read(LEFT(AC_inst), MEM_D1, jra_finish);

		  JUMP, JUMPL, JUMPE, JUMPLE, JUMPA, JUMPGE, JUMPN, JUMPG:
		    if (jump_condition_0)
		      jump(E);
		    else
		      next();

		  // Logical Testing and Modification (Bit Testing)
		  TRN, TRNE, TRNA, TRNN, TRZ, TRZE, TRZA, TRZN, TRC, TRCE, TRCA, TRCN, TRO, TROE, TROA, TRON,
		  TLN, TLNE, TLNA, TLNN, TLZ, TLZE, TLZA, TLZN, TLC, TLCE, TLCA, TLCN, TLO, TLOE, TLOA, TLON,
		  TDN, TDNE, TDNA, TDNN, TDZ, TDZE, TDZA, TDZN, TDC, TDCE, TDCA, TDCN, TDO, TDOE, TDOA, TDON,
		  TSN, TSNE, TSNA, TSNN, TSZ, TSZE, TSZA, TSZN, TSC, TSCE, TSCA, TSCN, TSO, TSOE, TSOA, TSON:
		    case (inst[6:7]) // skip, or not
		      0:	     // never skip
			next();
		      1:	// skip if masked bits are 0
			if ((ALUop1 & ALUop2) == 0)
			  skip();
			else
			  next();
		      2:	// always skip
			skip();
		      3:	// skip if masked bits are not all 0
			if ((ALUop1 & ALUop2) != 0)
			  skip();
			else
			  next();
		    endcase

		  //
		  // I/O Instructions
		  //

		  IO_INSTRUCTION:
		    case (IOOP(inst))
		      default:
			next();

		      CONSZ:
			if (RIGHT(ALUresult) & E)
			  next();
			else
			  skip();

		      CONSO:
			if (RIGHT(ALUresult) & E)
			  skip();
			else
			  next();
		    endcase
		  
		  default:
		    next();
		  
		endcase // case (OP(inst))
	     end
	   
	   state[blt_write]:		// BLT write word
	     if (RIGHT(AC_inst) == E)
	       write(RIGHT(AC_inst), read_data, MEM_D1, write_finish);
	     else
	       write(RIGHT(AC_inst), read_data, MEM_D1, blt_read);

	   state[blt_read]:		// BLT read word
	     read(LEFT(ALUresult), MEM_D2, blt_write);

	   state[write_bp_finish]:
	     begin
		// do I,X,Y calculation or read the data word
		if (X(ALUresult) != 0) begin // index
		   read({ `XFILL, X(ALUresult)}, MEM_E2, read_bp_index);
		end else if (I(ALUresult)) begin // indirect
		   read(Y(ALUresult), MEM_E2, read_bp_indirect); // loop for indirect
		end else begin
		   case (OP(inst)) // synopsys full_case parallel_case
		     LDB, ILDB:
		       read(Y(ALUresult), MEM_D2, ldb_start); // get the data word
		     DPB, IDPB:
		       read(Y(ALUresult), MEM_D2, dpb_start); // get the data word
		   endcase // case (OP(inst))
		end
	     end		   

	   state[read_bp_indirect]: // indirect in reading byte pointer
	     begin
		// do I,X,Y calculation to read the data word
		if (X(read_data) != 0) begin // index
		   read({ `XFILL, X(read_data)}, MEM_E2, read_bp_index);
		end else if (I(read_data)) begin // indirect
		   read(Y(read_data), MEM_E2, read_bp_indirect); // loop for indirect
		end else begin
		   case (OP(inst)) // synopsys full_case parallel_case
		     LDB, ILDB:
		       read(Y(read_data), MEM_D2, ldb_start); // get the data word
		     DPB, IDPB:
		       read(Y(read_data), MEM_D2, dpb_start); // get the data word
		   endcase // case (OP(inst))
		end
	     end

	   // need to add the previous Y (now in E) and C(X) in read_data
	   state[read_bp_index]:
	     begin
		if (I(E_last_read))
		  read(E_indexed, MEM_E1, read_bp_indirect);
		else
		  case (OP(inst)) // synopsys full_case parallel_case
		    LDB, ILDB:
		      read(E_indexed, MEM_D2, ldb_start);
		    DPB, IDPB:
		      read(E_indexed, MEM_D2, dpb_start);
		  endcase // case (OP(inst))
	     end

	   state[ldb_start]:		// wait for the data to show up, then mask and set up for the shift
	     begin
		set_state(ldb_loop);
	     end

	   state[ldb_loop]: // very much like lsh_loop but clear first_part_done, also it only shifts right
	     if (ALUcount == 0)
	       next();
	     else
	       set_state(ldb_loop);

	   state[dpb_start]:
	     begin
		set_state(dpb_loop);
	     end

	   state[dpb_loop]:
	     if (ALUcount == 0) begin // we're done, mask and write
		write(RIGHT(E_last_read),
		      (DLEFT(ALUstep) & DRIGHT(ALUstep)) | (op2 & ~DRIGHT(ALUstep)), 
		      MEM_D2, write_finish);
	     end else begin
		set_state(dpb_loop);
	     end

	   state[div_loop]:
	     if (ALUcount == 0)
	       set_state(div_write);
	     else
	       set_state(div_loop);

	   state[div_write]:
	     case (inst_mode(inst))
	       mode_basic, mode_immediate:
		 next();
	       mode_memory, mode_both:
		 // memory writes are started here.  AC writes are done in the clocked logic,
		 // either in div_write or write_finish
		 write(E, DRIGHT(ALUstep), MEM_D1, write_finish);
	     endcase

	   state[mul_loop]:
	     if (ALUcount == 0) // we're done, write answer
	       // memory writes are started here, AC writes are handled in the clocked logic in
	       // either mul_loop or write_finish
	       case (OP(inst))	// synopsys full_case parallel_case
		 IMULI, IMUL, IMULM, IMULB:
		   case (inst_mode(inst))
		     mode_basic, mode_immediate:
		       next();
		     mode_memory, mode_both:
		       write(E, p_right, MEM_D1, write_finish);
		   endcase

		 MULI, MUL, MULM, MULB:
		   case (inst_mode(inst))
		     mode_basic, mode_immediate:
		       next();
		     mode_memory, mode_both:
		       write(E, p_left, MEM_D1, write_finish);
		   endcase // case (inst_mode(inst))
	       endcase // case OP(inst)
	     else begin
		set_state(mul_loop);		    // loop
	     end

	   state[shift_loop]:
	     if (ALUcount == 0)
	       next();
	     else
	       set_state(shift_loop);

	   state[jffo_loop]:
	     if (ALUstep[0] == 1)
	       jump(E);
	     else 
	       set_state(jffo_loop);

	   state[pop_finish]:
	     write(E, read_data, MEM_D1, write_finish);

	   state[pushj_finish]:	// wait for write_ack, then jump to E
	     jump(E);

	   state[popj_finish]:
	     jump(RIGHT(read_data));

	   state[jra_finish]:
	     jump(E);

	   state[write_finish]:	// wait for the write to finish
	     // various jumps and skips end up here because they've written to memory
	     case (OP(inst))	// synopsys parallel_case
	       JSR, JSA:
		 jump(E+1);

	       AOS,AOSL,AOSE,AOSLE,AOSA,AOSGE,AOSN,AOSG,
		 SOS,SOSL,SOSE,SOSLE,SOSA,SOSGE,SOSN,SOSG:
		   if (jump_condition_0)
		     skip();
		   else
		     next();

	       default:
		 next();
	     endcase

	   state[interrupt]:
	     begin
`ifdef OLD_PI
		read_start(`ADDRSIZE'o40+2*pi_level_rq, MEM_IF);
`else
		read_start(pi_vector, MEM_IF);
`endif
		execute();
	     end

	   state[UUO]:
	     if (interrupt_instruction || uuo_instruction) begin
`ifdef SIM
		$display(" Double Error!!!");
`endif
		set_state(halting);
	     end else begin
		case (OP(inst))	// synopsys full_case parallel_case
		  LUUO01, LUUO02, LUUO03, LUUO04, LUUO05, LUUO06, LUUO07,
		  LUUO10, LUUO11, LUUO12, LUUO13, LUUO14, LUUO15, LUUO16, LUUO17,
		  LUUO20, LUUO21, LUUO22, LUUO23, LUUO24, LUUO25, LUUO26, LUUO27,
		  LUUO30, LUUO31, LUUO32, LUUO33, LUUO34, LUUO35, LUUO36, LUUO37:
		    ;	// set neither MUUO or UC
		  
		  UUO00,
		    CALL, INITI, MUUO42, MUUO43, MUUO44, MUUO45, MUUO46, CALLI,
		    OPEN, TTCALL, MUUO52, MUUO53, MUUO54, RENAME, IN, OUT,
		    SETSTS, STATO, STATUS, GETSTS, INBUF, OUTBUF, INPUT, OUTPUT,
		    CLOSE, RELEAS, MTAPE, UGETF, USETI, USETO, LOOKUP, ENTER:
		      begin
			 set_MUUO_flag = 1;
		      end

		  default:	// unassigned codes
		      begin
			 set_MUUO_flag = 1;
			 set_UC_flag = 1;
		      end
		endcase

		write(UC_flag ? `UAC_VEC : `UUO_VEC, { OP(inst), A(inst), 5'b0, E }, MEM_IF, UUO_finish);
	     end // else: !if(interrupt_instruction)

	   state[UUO_finish]:
	     // we've written the instruction and E to 40 or 60, now execute the interrupt instruction
	     begin
		read_start(UC_flag ? `UAC_VEC+1 : `UUO_VEC+1, MEM_IF);
		set_uuo_instruction = 1;
		execute();
	     end

	   // this state is all about being able to print out information before exiting
	   // the simulator.  with a front-panel, it may be used to update the displayed
	   // information there.
	   state[halting]:
	     begin
		running = 0;
		set_state(halted);
	     end
	   state[halted]:
	     begin
		running = 0;
		set_state(halted);
	     end

`ifdef SIM
	   // there'd better never be an unhandled state!
	   default:
	     begin
		$display("Unknown processor state: %d", state);
		set_state(halting);
	     end
`endif
	 endcase // case (state)
      end
   end


   //
   // Clocked portion of the APR state machine
   //

   reg mem_in_progress = 0;
   reg [`WORD] instruction_count = 0;
`ifdef SIM
   real        cycles;
`endif

   always @(posedge clk) begin
`ifdef SIM
      cycles <= cycles + 1;
`endif

      // when we get the ack, turn off in_progress
      if (reset | (mem_in_progress && (read_ack || write_ack)))
	mem_in_progress <= 0;
      // however, if we have another read or write being started not, turn it on
      if (mem_read || mem_write)
	mem_in_progress <= 1;

      // translate page fails into soft errors
      if (mem_page_fail)
	apr_fse <= 1;

      // translate NXM into hard errors
      if (mem_nxm)
	apr_fhe <= 1;

      // normal instruction processing sets clear_interrupt which clears all these flags
      if (clear_interrupt) begin
	 interrupt_instruction <= 0;
	 uuo_instruction <= 0;
	 MUUO_flag <= 0;
	 UC_flag <= 0;
	 xctr_mode <= 0;
	 skip_on_fault <= 0;
      end

      // if the control is set to set these flags
      if (set_interrupt_instruction)
	interrupt_instruction <= 1;
      if (set_uuo_instruction)
	uuo_instruction <= 1;
      if (set_MUUO_flag)
	MUUO_flag <= 1;
      if (set_UC_flag)
	UC_flag <= 1;
      
      // Only check for device interrupts on a read
      if (read_ack)
	pi_io <= mem_pi_req;	// this clocks I/O devices' PI requests into the PI system


      // if we're doing a memory read or write, then just hang fire until we get the answer
      if (mem_in_progress && !(read_ack || write_ack))
	;

      else begin
	 // in the normal case, sequence to the next state
	 state <= next_state;
`ifdef SIM
	 state_index <= next_state_index;
`endif

	 //
	 // This makes the Accumulators look like synchronous memory when it's being accessed
	 // as memory.  It's down here so that the logic that waits for read and write acks
	 // also makes the accumulator access wait.
	 //

	 // switch the read/write multiplexors on the clock
	 select_ac <= isAC(mem_addr);

	 // handle writing and reading accumulators in lieu of memory here
	 if (ac_mem_write) begin
	    accumulators[mem_addr[32:35]] <= mem_write_data;
	    ac_write_ack <= 1;
	 end else
	   ac_write_ack <= 0;

	 if (ac_mem_read) begin
	    ac_read_data <= accumulators[mem_addr[32:35]];
	    ac_read_ack <= 1;
	 end else
	   ac_read_ack <= 0;


	 // this is all about preventing XCT or executing interrupt instructions from
	 // modifying the PC
	 if (set_PC)
	   PC <= next_PC;

`ifdef SIM
	 // this is a crock but it seems to manage to get the right answer and it's only used
	 // by the disassembler during simulation testing anyway
	 if (latch_inst)
	   inst_addr <= mem_addr;
`endif

	 // write the ALU output to AC and flags if needed
	 if (writeAC)
	   `AC <= ALUresult;

	 if (setFlags)
	   begin
	      if (ALUcarry0) carry0 <= 1;
	      if (ALUcarry1) carry1 <= 1;
	      if (ALUoverflow) set_overflow();
	   end

	 case (1'b1)		// synopsys full_case parallel_case
	   state[init]:
	     begin
`ifdef SIM
		cycles <= 0;
`endif
		instruction_count <= 0;

		user_mode <= 0;
		carry0 <= 0;
		carry1 <= 0;
		overflow <= 0;
		floating_overflow <= 0;
		first_part_done <= 0;
		floating_underflow <= 0;
		no_divide <= 0;

		reset_pi();
		reset_apr();
		
		// these initial values are arbitrary! !!!
		accumulators[0] <= `WORDSIZE'o254000000002;
		accumulators[1] <= `WORDSIZE'o254000000003;
		accumulators[2] <= `WORDSIZE'o254000000001;
		accumulators[3] <= `WORDSIZE'o254200000000;
		accumulators[4] <= 123;
		accumulators[5] <= 123;
		accumulators[6] <= 123;
		accumulators[7] <= 123;
		accumulators[8] <= 123;
		accumulators[9] <= 123;
		accumulators[10] <= 123;
		accumulators[11] <= 123;
		accumulators[12] <= 123;
		accumulators[13] <= 123;
		accumulators[14] <= 123;
		accumulators[15] <= 123;
	     end

	   state[instruction_fetch], state[indirect]:
	     begin
		E_last_read <= read_data; // keep the last value read in calculating E
		E <= Y(read_data);
	     end

	   state[index]:
	     begin
		E_last_read <= read_data;
		if (!I(E_last_read)) 
		  E <= E_indexed;
	     end

	   state[write_bp_finish]:
	     begin
		E_last_read <= ALUresult;
		E <= Y(ALUresult);
		first_part_done <= 1;
	     end

	   state[read_bp_indirect]:
	     begin
		E_last_read <= read_data;
		E <= Y(read_data);
	     end

	   state[read_bp_index]:
	     begin
		E_last_read <= read_data;
		if (!I(E_last_read)) 
		  E <= E_indexed;
	     end

	   state[ldb_start]:
	     begin
		ALUcount <= P(byte_pointer);
		ALUstep <= { read_data, `ZERO };
	     end

	   state[ldb_loop]:
	     if (ALUcount == 0) begin
		first_part_done <= 0;
		`AC <= DLEFT(ALUstep) & bp_mask(S(byte_pointer));
	     end else begin
		ALUstep <= { ALUresult, ALUresultlow };
		ALUcount <= ALUcount_dec;
	     end

	   state[dpb_start]:
	     begin
		ALUcount <= P(byte_pointer);
		ALUstep <= { AC_inst, bp_mask(S(byte_pointer)) };
		op2 <= read_data;
	     end

	   state[dpb_loop]:
	     if (ALUcount == 0)
	       first_part_done <= 0;
	     else begin
		ALUstep <= { ALUresult, ALUresultlow };
		ALUcount <= ALUcount_dec;
	     end

	   state[dispatch]:
	     begin
`ifdef SIM
		// this is a horrible hack but it's really handy for running a bunch of
		// tests and DaveC's tests all loop back to 001000 !!!
		if ((PC == `ADDRSIZE'o1000) && (instruction_count != 0)) begin
		   $display("Cycles: %f  Instructions: %0d   Cycles/inst: %f",
			    cycles, instruction_count, cycles/instruction_count);
		   $finish_and_return(0);
		end

		// disassembler
		if (X(inst) || I(inst))
		  $display("%6o: %6o,%6o %s --> %6o", inst_addr, LEFT(inst), RIGHT(inst), disasm(inst), E);
		else
		  $display("%6o: %6o,%6o %s", inst_addr, LEFT(inst), RIGHT(inst), disasm(inst));
`endif

		//  this is being used to display a count of times through the diagnostic on the
		//  LEDs on my dev board!
		if (PC == `ADDRSIZE'o1000)
		  display_addr <= instruction_count[0:17];
		instruction_count <= instruction_count + 1;

		casex (OP(inst))
		  IMUL, IMULI, IMULM, IMULB, MUL, MULI, MULM, MULB:
		    begin
		       ALUcount <= `WORDSIZE-1;
		       ALUstep <= { `ZERO, AC_inst }; // accumulate the product here
		       shift_bit <= read_data[0] & AC_inst[`WORDSIZE-1];
		    end

		  IDIV, IDIVI, IDIVM, IDIVB, DIV, DIVI, DIVM, DIVB:
		    // The ALU is already set up with the first trip through so we can detect
		    // overflow right here.
		    if (!NEGATIVE(ALUresult)) begin
		       no_divide <= 1;
		       set_overflow();
		    end else begin
		       ALUcount <= `WORDSIZE-1;
		       shift_bit <= 0;
		       ALUstep <= { ALUresult, ALUresultlow };
		    end

		  // this isn't writing ALUresult because I'm using the ALU to compute the skip condition
		  SKIP,SKIPL,SKIPE,SKIPLE,SKIPA,SKIPGE,SKIPN,SKIPG:
		    if (ac != 0)
		      `AC <= read_data;
		  
		  LDB, DPB:
		    begin
		       byte_pointer <= read_data;
		       E_last_read <= read_data;
		       E <= Y(read_data);
		    end

		  ILDB, IDPB:
		    begin
		       // this could also be handled by the ALU controls !!!
		       if (first_part_done)
			 byte_pointer <= read_data;
		       else
			 byte_pointer <= ALUresult;
		       E_last_read <= read_data;
		       E <= Y(read_data);
		    end

		  ASH, ROT, LSH, ASHC, ROTC, LSHC, CIRC:
		    begin
		       ALUcount <= shift_count;
		       ALUstep <= { AC_inst, `AC_next };
		    end

		  JFFO:	// Jump if Find First One
		    if (AC_inst == 0) begin
		       `AC_next <= 0;
		    end else begin
		       ALUcount <= 0;
		       ALUstep <= { AC_inst, `MINUSONE };
		    end

		  JSP:
		    first_part_done <= 0;

		  JRST:	// Jump and Restore
		    begin
		       if (inst[9]) // dismiss current interrupt
			 if (user_mode)
			   MUUO_flag <= 1;
			 else
			   pi_clear_ip();

		       if (inst[10]) // halt
			 if (user_mode)
			   MUUO_flag <= 1;

		       if (inst[11])	// restore flags
			 // the user_mode flag is left out of the USER_FLAGS definition so it
			 // can't be cleared by user_mode code
			 if (user_mode)
			   { `USER_FLAGS } <= E_last_read[0:12];
			 else
			   { `EXEC_FLAGS } <= E_last_read[0:12];

		       if (inst[12]) // enter user mode
			 user_mode <= 1;
		    end

		  JFCL:	// Jump on Flag and Clear
		    begin
		       if (inst[9] && overflow)
			 overflow <= 0;
		       if (inst[10] && carry0)
			 carry0 <= 0;
		       if (inst[11] && carry1)
			 carry1 <= 0;
		       if (inst[12] && floating_overflow)
			 floating_overflow <= 0;
		    end

		  XCT:		// Execute instruction at E
		    begin
		       // These are the KX10 modifications for exec mode XCT
		       if (!user_mode)
			 case (inst[10:12])
			   1: xctr_mode[MEM_D1] <= 1;
			   2: xctr_mode[MEM_D2] <= 1;
			   3: begin
			      xctr_mode[MEM_D1] <= 1;
			      xctr_mode[MEM_D2] <= 1;
			   end
			   4: xctr_mode[MEM_E1] <= 1;
			   5: begin
			      xctr_mode[MEM_D1] <= 1;
			      xctr_mode[MEM_E2] <= 1;
			      xctr_mode[MEM_D2] <= 1;
			   end
			 endcase

		       // execute() clears skip_on_fault but this will override, for one instruction, 
		       if (!user_mode && inst[9])
			 skip_on_fault <= 1;
		    end
		  
		  IO_INSTRUCTION:
		    if (user_mode) begin
		       MUUO_flag <= 1;
		    end else
		      // Handle the APR and PI devices here.  Everything else goes out the I/O bus.
		      case (IOOP(inst))
			BLKI, BLKO:
			  begin
`ifdef SIM
			     $display("     !!! BKLI/BKLO not yet implemented!");
`endif
			     UC_flag <= 1;
			  end

			DATAO:
			  case (IODEV(inst))
			    APR:
			      switch_register <= read_data;
			  endcase

			CONO:
			  case (IODEV(inst))
			    APR:
			      begin
				 if (E[`APR_SSE]) apr_fse <= 1; // set/clear soft error
				 else if (E[`APR_CSE]) apr_fse <= 0;
				 
				 if (E[`APR_RIO]) ; // Does nothing now.  Probably should just poke BIO !!!

				 if (E[`APR_SF]) begin // set/clear flags
				    if (E[`APR_MHE]) apr_fhe <= 1;
				    if (E[`APR_MSE]) apr_fse <= 1;
				    if (E[`APR_ME2]) apr_fe2 <= 1;
				    if (E[`APR_ME1]) apr_fe1 <= 1;
				    if (E[`APR_MU2]) apr_fu2 <= 1;
				    if (E[`APR_MU1]) apr_fu1 <= 1;
				 end else if (E[`APR_CF]) begin
				    if (E[`APR_MHE]) apr_fhe <= 0;
				    if (E[`APR_MSE]) apr_fse <= 0;
				    if (E[`APR_ME2]) apr_fe2 <= 0;
				    if (E[`APR_ME1]) apr_fe1 <= 0;
				    if (E[`APR_MU2]) apr_fu2 <= 0;
				    if (E[`APR_MU1]) apr_fu1 <= 0;
				 end

				 if (E[`APR_LE]) begin // load error interrupt enables and PI assignment
				    apr_ehe <= E[`APR_MHE];
				    apr_ese <= E[`APR_MSE];
				    apr_ee2 <= E[`APR_ME2];
				    apr_ee1 <= E[`APR_ME1];
				    apr_eu2 <= E[`APR_MU2];
				    apr_eu1 <= E[`APR_MU1];
				    apr_eia <= E[`APR_IA];
				 end

				 if (E[`APR_LT]) begin // load trap interrupt enables and PI assignment
				    apr_the <= E[`APR_MHE];
				    apr_tse <= E[`APR_MSE];
				    apr_te2 <= E[`APR_ME2];
				    apr_te1 <= E[`APR_ME1];
				    apr_tu2 <= E[`APR_MU2];
				    apr_tu1 <= E[`APR_MU1];
				    apr_tia <= E[`APR_IA];
				 end
			      end // case: APR

			    PI:
			      if (E[`PI_RPI])
				reset_pi();
			      else begin
				 if (E[`PI_SSR]) pi_sr <= pi_sr | E[`PI_Mask]; // set/clear software request
				 else if (E[`PI_CSR]) pi_sr <= pi_sr & ~E[`PI_Mask];
				 
				 if (E[`PI_SLE]) pi_le <= pi_le | E[`PI_Mask]; // set/clear level enable
				 else if (E[`PI_CLE]) pi_le <= pi_le & ~E[`PI_Mask];

				 if (E[`PI_SGE]) pi_ge <= 1'b1; // set/clear global enable
				 else if (E[`PI_CGE]) pi_ge <= 1'b0;
			      end
			  endcase // case (IODEV(inst))

		      endcase // case (IOOP(inst))
		endcase

	     end

	   state[mul_loop]:
	     if (ALUcount == 0) // we're done, write answer
	       // overflow checks for all the MUL variants but only write the ACs for basic
	       // and immediate modes.  otherwise the memory write is started by the aysnc
	       // circuit and an AC write, if any, is handled in write_finish
	       case (OP(inst))	// synopsys full_case parallel_case
		 IMULI, IMUL, IMULM, IMULB:
		   begin
		      // overflow if we've set anything in the left word. unlike division,
		      // multiplication still writes the answer in the event of an overflow.
		      if (!((ALUresult == `ZERO) || (ALUresult == `MINUSONE)))
			set_overflow();

		      case (inst_mode(inst))
			mode_basic, mode_immediate:
			  `AC <= p_right;
		      endcase
		   end

		 MULI, MUL, MULM, MULB:
		   begin
		      // Because of the duplicated sign-bit, we have only 70-bits of magnitude
		      // and the maximum negative times the maximum negative will result in
		      // the maximum negative which is an overflow.
		      if ((p_left == `MAXNEG) && (p_right == `MAXNEG))
			set_overflow();

		      case (inst_mode(inst))
			mode_basic, mode_immediate:
			  begin
			     `AC <= p_left;
			     `AC_next <= p_right;
			  end
		      endcase // case (inst_mode(inst))
		   end // case: MULI, MUL, MULM, MULB
	       endcase // case OP(inst)
	   
	     else begin
		// the core of the multiply loop accumulates the quotient in ALUstep.  the ALU
		// has done the ADD or SUB, here we shift to the right.
		ALUstep <= { shift_bit, ALUresult, ALUresultlow[0:`WORDSIZE-2] };
		ALUcount <= ALUcount_dec;
		if (ALUop2[0] & ALUresultlow[`WORDSIZE-2])
		  shift_bit <= 1;
	     end
	   
	   state[div_loop]:
	     if (ALUcount == 0) begin
		// When we're done the divide loop, we fix up the remainder if it's negative
		// (that's what's coming out of the ALU right now) and then we negate the
		// remainder and/or quotient if needed.
		ALUstep <= { NEGATIVE(AC_inst) ? -ALUresult : ALUresult,
			     NEGATIVE(AC_inst) ^ NEGATIVE(ALUop2) ? -ALUresultlow : ALUresultlow };
	     end else begin
		ALUstep <= { ALUresult, ALUresultlow };
		shift_bit <= ~ALUresult[0];
		ALUcount <= ALUcount_dec;
	     end

	   state[div_write]:
	     // writes for division are scattered through three places.  memory writes start
	     // in the combinatorial block, AC writes in the clocked block, and AC writes
	     // after a memory write are done by the write_finish state.
	     case(OP(inst))
	       IDIV, IDIVI, DIV, DIVI:
		 begin
		    `AC <= DRIGHT(ALUstep);
		    `AC_next <= DLEFT(ALUstep);
		 end
	     endcase

	   state[pushj_finish]:
	     begin
		first_part_done <= 0;
		if (LEFT(ALUresult) == `HALFZERO)
		  set_pushdown_overflow();
		if (interrupt_instruction || uuo_instruction)
		  user_mode <= 0;
	     end
	   
	   state[popj_finish]:
	     if (LEFT(ALUresult) == `HALFMINUSONE)
	       set_pushdown_overflow();
	   
	   state[shift_loop]:
	     if (ALUcount == 0) begin
		case (OP(inst))	// synopsys full_case parallel_case
		  ASH, ROT, LSH:
		    `AC <= DLEFT(ALUstep);
		  ASHC, ROTC, LSHC, CIRC:
		    { `AC, `AC_next } <= ALUstep;
		endcase
	     end else begin
		// !!! if I set overflow before the instruction is done, might it cause a trap
		// too soon?
		if (ALUoverflow)
		  set_overflow();
		ALUstep <= { ALUresult, ALUresultlow };
		ALUcount <= (ALUcount[0] == 0) ? ALUcount_dec : ALUcount_inc;
	     end

	   state[jffo_loop]:
	     if (ALUstep[0] == 1) begin
		`AC_next <= ALUcount;
	     end else begin
		ALUcount <= ALUcount_inc;
		ALUstep <= { ALUresult, ALUresultlow };
	     end

	   state[write_finish]:	// wait for the write to finish, read next instruction
	     begin
		case (OP(inst))	// synopsys full_case parallel_case
		  IMULB:
		    `AC <= p_right;
		  MULB:
		    begin
		       `AC <= p_left;
		       `AC_next <= p_right;
		    end

		  IDIVB, DIVB:
		    begin
		       `AC <= DRIGHT(ALUstep);
		       `AC_next <= DLEFT(ALUstep);
		    end

		  // Self instructions write AC here

		  // Moves to self
		  MOVES, MOVSS, MOVNS, MOVMS,
		    // Half-word moves to self
		    HLLS, HRLS, HLLZS, HRLZS, HLLOS, HRLOS, HLLES, HRLES,
		    HRRS, HLRS, HRRZS, HLRZS, HRROS, HLROS, HRRES, HLRES:
		      if (ac != 0)
			`AC <= ALUresult;

		  PUSH:
		    if (LEFT(AC_inst) == `HALFZERO)
		      set_pushdown_overflow();

		  POP:
		    if (LEFT(AC_inst) == `HALFMINUSONE)
		      set_pushdown_overflow();

		  JSR:
		    begin
		       first_part_done <= 0;
		       if (interrupt_instruction || uuo_instruction)
			 user_mode <= 0;
		    end

		  JSA:
		    begin
		       if (interrupt_instruction || uuo_instruction)
			 user_mode <= 0;
		       `AC <= { E, PC_next }; // maybe send this through the ALU? !!!
		    end

		endcase // case OP(inst)
	     end

	   state[interrupt]:
	     begin
		interrupt_instruction <= 1;
		pi_set_ip();
		MUUO_flag <= 1;	// setting this makes further memory accesses also go to exec space
	     end

`ifdef SIM

	   state[UUO]:
	     if (set_UC_flag)
	       $display(" Unassigned Code !!!");
	     else if (set_MUUO_flag)
	       $display(" MUUO!!!");
	     else
	       $display(" LUUO!!!");

	   state[halting]:
	     begin
		$display(" HALT!!!");
		$display("Cycles: %f  Instructions: %d   Cycles/inst: %f",
			 cycles, instruction_count, cycles/instruction_count);
		$display("carry0: %b  carry1: %b  overflow: %b  floating overflow: %b",
			 carry0, carry1, overflow, floating_overflow);
		print_ac();
	     end
	   state[halted]:
	     begin
		$finish_and_return(1);
	     end
`endif

	 endcase // case (1'b1)
      end // else: !if(mem_in_progress && !(read_ack || write_ack))
   end
`endif //  `ifdef NOTDEF

endmodule // APR

`ifdef NOTDEF
// taken from a message from jacobjones on alteraforum.com
// parameterized mux with continuous output
module mux
  #(parameter
    WIDTH           = 8,
    CHANNELS        = 4,
    SEL_WIDTH       = 3) // arg! this should be $clog2(CHANNELS) but Quartus does not accept that in a port declaration;
   (
//    input [$clog2(CHANNELS)-1:0] sel,
    input [SEL_WIDTH-1:0] 	 sel,
    input [(CHANNELS*WIDTH)-1:0] in_bus,

    output [WIDTH-1:0] 		 out
    );

   genvar 			   ig;
    
   wire [WIDTH-1:0] 		   input_array [0:CHANNELS-1];

   assign  out = input_array[sel];

   generate
      for(ig=0; ig<CHANNELS; ig=ig+1) begin: array_assignments
         assign  input_array[ig] = in_bus[(ig*WIDTH)+:WIDTH];
      end
   endgenerate
endmodule // mux
`endif
