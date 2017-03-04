//	-*- mode: Verilog; fill-column: 96 -*-
//
// Arithmetic Processing Unit for kv10 processor
//
// 2013-01-31 dab	initial version
// 2015-02-27 dab	rewrite to match better understanding of how to write state machines


`include "constants.vh"
`include "alu.vh"

// I kept typing this over and over so ...
// the AC for the current instruction
`define AC accumulators[ac]
`define AC_next accumulators[ac_next]

module apr
  (
   input 	      clk,
   input 	      reset,
   // interface to memory and I/O
   output reg [`ADDR] mem_addr,
   input [`WORD]      mem_read_data,
   output reg [`WORD] mem_write_data,
   output reg 	      mem_user, // selects user or exec memory
   output reg 	      mem_write = 0, // only one of mem_write, mem_read, io_write, or io_read
   output reg 	      mem_read = 0,
   output reg 	      io_write = 0,
   output reg 	      io_read = 0,
   input 	      mem_write_ack,
   input 	      mem_read_ack,
   input 	      mem_nxm,	// !!! don't do ;anything with this yet
   input 	      mem_page_fail,
   input [1:7] 	      mem_pi_req, // PI requests from I/O devices

   // these might grow to be part of a front-panel interface one day
   output reg [`ADDR] display_addr, 
   output reg 	      running
    );

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

`include "functions.vh"
`include "io.vh"

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
   
   //   
   // Main instruction decode.
   //

   always @(*) begin
      // defaults
      decode(AC_inst, `aluSETA, read_data, 0, none, none, none);
      conIO = 0;
      unassigned_code = 1;

      casex (OP(inst))		// synopsys full_case parallel_case

	LUUO01, LUUO02, LUUO03, LUUO04, LUUO05, LUUO06, LUUO07,
	LUUO10, LUUO11, LUUO12, LUUO13, LUUO14, LUUO15, LUUO16, LUUO17,
	LUUO20, LUUO21, LUUO22, LUUO23, LUUO24, LUUO25, LUUO26, LUUO27,
	LUUO30, LUUO31, LUUO32, LUUO33, LUUO34, LUUO35, LUUO36, LUUO37:
	  begin
	     decode(AC_inst, `aluSETA, read_data, 0, none, none, none);
	     unassigned_code = 1;
	  end
	  
	UUO00, 		  
	CALL, INITI, MUUO42, MUUO43, MUUO44, MUUO45, MUUO46, CALLI,
	OPEN, TTCALL, MUUO52, MUUO53, MUUO54, RENAME, IN, OUT,
	SETSTS, STATO, STATUS, GETSTS, INBUF, OUTBUF, INPUT, OUTPUT,
	CLOSE, RELEAS, MTAPE, UGETF, USETI, USETO, LOOKUP, ENTER:
	  begin
	     decode(AC_inst, `aluSETA, read_data, 0, none, none, none);
	     unassigned_code = 1;
	  end

	UJEN, UNK101, GFAD, GFSB, JSYS, ADJSP, GFMP, GFDV,
	DFAD, DFSB, DFMP, DFDV, DADD, DSUB, DMUL, DDIV,
	DMOVE, DMOVN, FIX, EXTEND, DMOVEM, DMOVNM, FIXR, FLTR,
	UFA, DFN, FSC,  // byte instructions come out of here
	FAD, FADL, FADM, FADB, FADR, FADRL, FADRM, FADRB,
	FSB, FSBL, FSBM, FSBB, FSBR, FSBRL, FSBRM, FSBRB,
	FMP, FMPL, FMPM, FMPB, FMPR, FMPRL, FMPRM, FMPRB,
	FDV, FDVL, FDVM, FDVB, FDVR, FDVRL, FDVRM, FDVRB:
	  begin
	     decode(AC_inst, `aluSETA, read_data, 0, none, none, none);
	     unassigned_code = 1;
	  end

	//
	// MOVE instructions
	//

	MOVE, MOVS, MOVN, MOVM:	    // AC <- C(E) (straight, swapped, negated, magnitude)
	  decode(AC_inst, move_alucmd(inst), read_data, 1, none, dispatch, mode_writeFlags(inst));
	MOVEI, MOVSI, MOVNI, MOVMI: // AC <- 0,,E (straight, swapped, negated, magnitude)
	  decode(AC_inst, move_alucmd(inst), E_word, 0, none, dispatch, mode_writeFlags(inst));
	// !!! really don't want ALUop2 to be AC_inst here but I'm not sure how to implement
	// negate or magnitude off ALUop1 !!!
	MOVEM, MOVSM, MOVNM, MOVMM: // C(E) <- AC (straight, swapped, negated, magnitude)
	  decode(AC_inst, move_alucmd(inst), AC_inst, 0, dispatch, none, mode_writeFlags(inst));
	MOVES, MOVSS, MOVNS, MOVMS: // C(E) and AC (if not 0) <- C(E)
	  decode(AC_inst, move_alucmd(inst), read_data, 1, dispatch, (ac != 0) ? write_finish : none, mode_writeFlags(inst));
	//
	// Integer Multiply and Divide
	//

	IMULI, IMUL, IMULM, IMULB, MULI, MUL, MULM, MULB:
	  begin
	     // this is a simple, shift and add multiplier.  to make negative numbers work right,
	     // we subtract the last partial product.
	     if (ALUcount == 0)
	       aluc_set(ALUstep, ALUstep[`DWORDSIZE-1] ? `aluSUB : `aluSETA, mem_src);
	     else
	       aluc_set(ALUstep, ALUstep[`DWORDSIZE-1] ? `aluADD : `aluSETA, mem_src);

	     decode_flags(mode_readE(inst), none, none, none);
	  end

	IDIVI, IDIV, IDIVM, IDIVB, DIVI, DIV, DIVM, DIVB:
	  begin
	     if (state[div_loop])
	       if (ALUcount == 0)
		 // when we're done the divide loop, if the remainder is negative fix it up.  we
		 // also only shift the quotient (low word of ALUstep) at this point.
		 if (ALUstep[0] == 1)
		   aluc_set({ DLEFT(ALUstep), ALUstep[`WORDSIZE+1:`DWORDSIZE-1], shift_bit}, 
			    NEGATIVE(ALUop2) ? `aluSUB : `aluADD, mem_src);
		 else
		   aluc_set({ DLEFT(ALUstep), ALUstep[`WORDSIZE+1:`DWORDSIZE-1], shift_bit}, `aluSETA, mem_src);
	       else
		 // the core of the divide loop shifts remainder,,quotient in ALUstep one bit left
		 // and then add or subtract the divisor in ALUop2.
		 aluc_set({ ALUstep[1:`DWORDSIZE-1], shift_bit},
			  NEGATIVE(ALUop2) ^ shift_bit ? `aluSUB : `aluADD, mem_src);
	     else
	       // These start the divide by setting up the initial values through the ALU
	       //
	       // IDIVx initializes op1 to the magnitude of A shifted left one position
	       //
	       // DIVx initializes op1 to the magnitude of the double word in A and A+1 shifted
	       // left one position (also gets rid of the duplicated sign bit in A+1)
	       case (OP(inst))	// synopsys full_case parallel_case
		 IDIVI:
		   aluc_set({`ZERO_SHORT, MAGNITUDE(AC_inst), 1'b0},
			    NEGATIVE(E_word) ? `aluADD : `aluSUB, E_word);
		 IDIV, IDIVM, IDIVB:
		   aluc_set({`ZERO_SHORT, MAGNITUDE(AC_inst), 1'b0}, 
			    NEGATIVE(read_data) ? `aluADD : `aluSUB, read_data);
		 DIVI:
		   aluc_set(DMAGNITUDE({AC_inst, `AC_next[1:`WORDSIZE-1], 1'b0}),
			    NEGATIVE(E_word) ? `aluADD : `aluSUB, E_word);
		 DIV, DIVM, DIVB:
		   aluc_set(DMAGNITUDE({AC_inst, `AC_next[1:`WORDSIZE-1], 1'b0}),
			    NEGATIVE(read_data) ? `aluADD : `aluSUB, read_data);
	       endcase // case (OP(inst))

	     decode_flags(mode_readE(inst), none, none, none);
	  end     

	//
	// Shifts and Rotates
	//

	ASH: decodec(ALUstep, `aluASH, E_word, 0, none, none, none);
	ROT: decodec(ALUstep, `aluROT, E_word, 0, none, none, none);
	LSH: decodec(ALUstep, `aluLSH, E_word, 0, none, none, none);
	JFFO: decodec(ALUstep, `aluLSHC, `ZERO, 0, none, none, none); // left shift
	ASHC: decodec(ALUstep, `aluASHC, E_word, 0, none, none, none);
	ROTC: decodec(ALUstep, `aluROTC, E_word, 0, none, none, none);
	LSHC: decodec(ALUstep, `aluLSHC, E_word, 0, none, none, none);
`ifdef CIRC
	CIRC: decodec(ALUstep, `aluCIRC, E_word, 0, none, none, none); // I need to write a diagnostic for CIRC !!!
`endif

	EXCH:			// Exchange, AC <-> C(E)
	  // this is kind of a hack, changing the input to the ALU to write read_data to the AC
	  // after the memory write finishes
	  decode(state[write_finish] ? read_data : AC_inst, `aluSETA, read_data, 1, dispatch, write_finish, none);

	BLT:			// Block Transfer (the ALU is incrementing the pointers)
	  decode(AC_inst, `aluAOB, `ZERO, 0, none, blt_read, none);
	AOBJP, AOBJN:		// Add One to Both halves of AC, Jump if Positive/Negative
	  decode(AC_inst, `aluAOB, `ZERO, 0, none, dispatch, none);
	JRST:			// Jump and Restory Flags
	  decode(AC_inst, `aluSETA, `ZERO, 0, none, none, none);
	JFCL:			// Jump on Flag and Clear
	  decode(AC_inst, `aluSETA, `ZERO, 0, none, none, none);
	XCT: // Execute instruction at E (I don't read E here as it would read in the wrong mode)
	  decode(AC_inst, `aluSETA, `ZERO, 0, none, none, none);
	
`ifdef NOTDEF
	MAP: ;
`endif

	PUSHJ:			// AC <- aob(AC) then C(AC) <- { Flags, PC_next}  Push down and Jump
	  decode(AC_inst, `aluAOB, `ZERO, 1, none, dispatch, none);
	PUSH:			// AC <- aob(AC) then C(AC) <- C(E)
	  decode(AC_inst, `aluAOB, `ZERO, 1, none, dispatch, none);
	POP:			// C(E) <- C(AC) then AC <- sob(AC)
	  decode(AC_inst, `aluSOB, `ZERO, 0, none, pop_finish, none);
	POPJ:			// Pop up and Jump
	  decode(AC_inst, `aluSOB, `ZERO, 0, none, popj_finish, none);

	JSR: 			// Jump to Subroutine
	  decode({ `FLAGS, PC_next }, `aluSETA, `ZERO, 0, dispatch, none, none);
	JSP:			// Jump and Save PC
	  decode({ `FLAGS, PC_next }, `aluSETA, `ZERO, 0, none, dispatch, none);
	JSA:			// Jump and Save AC
	  decode(AC_inst, `aluSETA, `ZERO, 0, dispatch, none, none);
	JRA:			// Jump and Restore AC
	  decode(`ZERO, `aluSETM, read_data, 0, none, jra_finish, none);

	ADD,			// AC <- AC + C(E)
	  ADDI,			// AC <- AC + 0,,E
	  ADDM,			// C(E) <- AC + C(E)
	  ADDB:			// AC and C(E) <- AC + C(E)
	    decode(AC_inst, `aluADD, mem_src, 
		   mode_readE(inst), mode_writeE(inst), mode_writeAC(inst), mode_writeFlags(inst));
	SUB,			// AC <- AC - C(E)
	  SUBI,			// AC <- AC - 0,,E
	  SUBM,			// C(E) <- AC - C(E)
	  SUBB:			// AC and C(E) <- AC - C(E)
	    decode(AC_inst, `aluSUB, mem_src, 
		   mode_readE(inst), mode_writeE(inst), mode_writeAC(inst), mode_writeFlags(inst));

	// Compare Accumulator to Immediate/Memory
	CAI,CAIL,CAIE,CAILE,CAIA,CAIGE,CAIN,CAIG:
	  decode(AC_inst, `aluSUB, E_word, 0, none, none, none);
	CAM,CAML,CAME,CAMLE,CAMA,CAMGE,CAMN,CAMG:
	  decode(AC_inst, `aluSUB, read_data, 1, none, none, none);

	JUMP, JUMPL, JUMPE, JUMPLE, JUMPA, JUMPGE, JUMPN, JUMPG:
	  decode(AC_inst, `aluSETA, read_data, 0, none, none, none);

	AOJ, AOJL, AOJE, AOJLE, AOJA, AOJGE, AOJN, AOJG:
	  decode(AC_inst, `aluADD, `ONE, 0, none, dispatch, dispatch);

	AOS,AOSL,AOSE,AOSLE,AOSA,AOSGE,AOSN,AOSG:
	  decode(`ONE, `aluADD, read_data, 1, dispatch, (ac != 0) ? write_finish : none, write_finish);

	// Adding -1 rather than Subtracting 1 makes the carry flags come out right
	SOJ, SOJL, SOJE, SOJLE, SOJA, SOJGE, SOJN, SOJG:
	  decode(AC_inst, `aluADD, `MINUSONE, 0, none, dispatch, dispatch);

	// Adding -1 rather than Subtracting 1 makes the carry flags come out right
	SOS,SOSL,SOSE,SOSLE,SOSA,SOSGE,SOSN,SOSG:
	  decode(`MINUSONE, `aluADD, read_data, 1, dispatch, (ac != 0) ? write_finish : none, write_finish);

	// Logical Operations
	SETZI, ANDI, ANDCAI, SETMI, ANDCMI, SETAI, XORI, ORI, // AC <- AC <op> 0,E
	  ANDCBI, EQVI, SETCAI, ORCAI, SETCMI, ORCMI, ORCBI, SETOI,
	  SETZ, AND, ANDCA, SETM, ANDCM, SETA, XOR, OR, // AC <- AC <op> C(E)
	  ANDCB, EQV, SETCA, ORCA, SETCM, ORCM, ORCB, SETO,
	  SETZM, ANDM, ANDCAM, SETMM, ANDCMM, SETAM, XORM, ORM, // C(E) <- AC <op> C(E)
	  ANDCBM, EQVM, SETCAM, ORCAM, SETCMM, ORCMM, ORCBM, SETOM,
	  SETZB, ANDB, ANDCAB, SETMB, ANDCMB, SETAB, XORB, ORB, // C(E) and AC <- AC <op> C(E)
	  ANDCBB, EQVB, SETCAB, ORCAB, SETCMB, ORCMB, ORCBB, SETOB:
	    decode(AC_inst, logical_alucmd(inst), mem_src, 
		   mode_readE(inst), mode_writeE(inst), mode_writeAC(inst), none);


	IBP:			// Increment Byte Pointer
	  decode(`ZERO, `aluIBP, read_data, 1, dispatch, none, none);
	LDB:					 // Load Byte
	  decodec(ALUstep, `aluLSH, `MINUSONE, 1, none, none, none); // left shift
	ILDB:			// Increment and Load Byte
	  if (state[ldb_loop])
	    decodec(ALUstep, `aluLSH, `MINUSONE, 1, none, none, none); // left shift
	  else
	    decode(`ZERO, `aluIBP, read_data, 1, none, none, none);
	DPB:			// Deposit Byte
	  decodec(ALUstep, `aluLSHC, `ZERO, 1, none, none, none); // right shift
	IDPB:			// Increment and Deposit Byte
	  if (state[dpb_loop])
	    decodec(ALUstep, `aluLSHC, `ZERO, 1, none, none, none); // right shift
	  else
	    decode(`ZERO, `aluIBP, read_data, 1, none, none, none);

	SKIP,SKIPL,SKIPE,SKIPLE,SKIPA,SKIPGE,SKIPN,SKIPG:
	  decode(AC_inst, `aluSETM, read_data, 1, none, none, none);

	// Half-word moves
`ifdef NOTDEF
	HLL,  HLLI,  HLLM,  HLLS,  HRL,  HRLI,  HRLM,  HRLS,
	  HLLZ, HLLZI, HLLZM, HLLZS, HRLZ, HRLZI, HRLZM, HRLZS,
	  HLLO, HLLOI, HLLOM, HLLOS, HRLO, HRLOI, HRLOM, HRLOS,
	  HLLE, HLLEI, HLLEM, HLLES, HRLE, HRLEI, HRLEM, HRLES,
	  HRR,  HRRI,  HRRM,  HRRS,  HLR,  HLRI,  HLRM,  HLRS,
	  HRRZ, HRRZI, HRRZM, HRRZS, HLRZ, HLRZI, HLRZM, HLRZS,
	  HRRO, HRROI, HRROM, HRROS, HLRO, HLROI, HLROM, HLROS,
	  HRRE, HRREI, HRREM, HRRES, HLRE, HLREI, HLREM, HLRES:
	    begin
	       case (halfword_extend(inst))
		 extend_none:
		   case (inst_mode(inst))
		     mode_basic, mode_immediate: ALUop1 = AC_inst;
		     mode_memory, mode_self:     ALUop1 = read_data;
		   endcase
		 extend_zero: ALUop1 = `ZERO;
		 extend_ones: ALUop1 = `MINUSONE;
		 extend_sign: ALUop1 = `ZERO;
	       endcase
	       ALUop2 = move_src;
	       case (inst_mode(inst))
		 mode_basic: decode_flags(1, none, dispatch, none);
		 mode_immediate: decode_flags(0, none, dispatch, none);
		 mode_memory: decode_flags(1, dispatch, none, none);
		 mode_self: decode_flags(1, dispatch, (ac != 0) ? write_finish : none, none);
	       endcase
	       ALUcommand = halfword_alucmd(inst);
	    end
`else
 `define SEX(op) NEGATIVE(op) ? `MINUSONE : `ZERO
 `define HSEX(op) HALF_NEGATIVE(op) ? `MINUSONE : `ZERO

	HLL: decode(AC_inst, `aluLL2, read_data, 1, none, dispatch, none);
	HLLI: decode(AC_inst, `aluLL2, E_word, 0, none, dispatch, none);
	HLLM: decode(AC_inst, `aluLL1, read_data, 1, dispatch, none, none);
	HLLS: decode(`ZERO, `aluIOR, read_data, 1, dispatch, (ac != 0) ? write_finish : none, none);
	HRL: decode(AC_inst, `aluRL2, read_data, 1, none, dispatch, none);
	HRLI: decode(AC_inst, `aluRL2, E_word, 0, none, dispatch, none);
	HRLM: decode(AC_inst, `aluRL1, read_data, 1, dispatch, none, none);
	HRLS: decode(`ZERO, `aluRDUP2, read_data, 1, dispatch, (ac != 0) ? write_finish : none, none);
		      
	HLLZ: decode(`ZERO, `aluLL2, read_data, 1, none, dispatch, none);
	HLLZI: decode(`ZERO, `aluLL2, E_word, 0, none, dispatch, none);
	HLLZM: decode(AC_inst, `aluLL1, `ZERO, 1, dispatch, none, none);
	HLLZS: decode(`ZERO, `aluLL2, read_data, 1, dispatch, (ac != 0) ? write_finish : none, none);
	HRLZ: decode(`ZERO, `aluRL2, read_data, 1, none, dispatch, none);
	HRLZI: decode(`ZERO, `aluRL2, E_word, 0, none, dispatch, none);
	HRLZM: decode(AC_inst, `aluRL1, `ZERO, 1, dispatch, none, none);
	HRLZS: decode(`ZERO, `aluRL2, read_data, 1, dispatch, (ac != 0) ? write_finish : none, none);
	
	HLLO: decode(`MINUSONE, `aluLL2, read_data, 1, none, dispatch, none);
	HLLOI: decode(`MINUSONE, `aluLL2, E_word, 0, none, dispatch, none);
	HLLOM: decode(AC_inst, `aluLL1, `MINUSONE, 1, dispatch, none, none);
	HLLOS: decode(`MINUSONE, `aluLL2, read_data, 1, dispatch, (ac != 0) ? write_finish : none, none);
	HRLO: decode(`MINUSONE, `aluRL2, read_data, 1, none, dispatch, none);
	HRLOI: decode(`MINUSONE, `aluRL2, E_word, 0, none, dispatch, none);
	HRLOM: decode(AC_inst, `aluRL1, `MINUSONE, 1, dispatch, none, none);
	HRLOS: decode(`MINUSONE, `aluRL2, read_data, 1, dispatch, (ac != 0) ? write_finish : none, none);
	
	HLLE: decode(`SEX(read_data), `aluLL2, read_data, 1, none, dispatch, none);
	HLLEI: decode(`SEX(E_word), `aluLL2, E_word, 0, none, dispatch, none);
	HLLEM: decode(AC_inst, `aluLL1, `SEX(AC_inst), 1, dispatch, none, none);
	HLLES: decode(`SEX(read_data), `aluLL2, read_data, 1, dispatch, (ac != 0) ? write_finish : none, none);
	HRLE: decode(`HSEX(RIGHT(ALUop2)), `aluRL2, read_data, 1, none, dispatch, none);
	HRLEI: decode(`HSEX(E), `aluRL2, E_word, 0, none, dispatch, none);
	HRLEM: decode(AC_inst, `aluRL1, `HSEX(RIGHT(AC_inst)), 1, dispatch, none, none);
	HRLES: decode(`HSEX(RIGHT(read_data)), `aluRL2, read_data, 1, dispatch, (ac != 0) ? write_finish : none, none);
	
	HRR: decode(AC_inst, `aluRR2, read_data, 1, none, dispatch, none);
	HRRI: decode(AC_inst, `aluRR2, E_word, 0, none, dispatch, none);
	HRRM: decode(AC_inst, `aluRR1, read_data, 1, dispatch, none, none);
	HRRS: decode(`ZERO, `aluIOR, read_data, 1, dispatch, (ac != 0) ? write_finish : none, none);
	HLR: decode(SWAP(AC_inst), `aluLR2, SWAP(read_data), 1, none, dispatch, none);
	HLRI: decode(SWAP(AC_inst), `aluLR2, SWAP(E_word), 0, none, dispatch, none);
	HLRM: decode(SWAP(AC_inst), `aluLR1, SWAP(read_data), 1, dispatch, none, none);
	HLRS: decode(SWAP(AC_inst), `aluRDUP2, SWAP(read_data), 1, dispatch, (ac != 0) ? write_finish : none, none);
		      
	HRRZ: decode(`ZERO, `aluRR2, read_data, 1, none, dispatch, none);
	HRRZI: decode(`ZERO, `aluRR2, E_word, 0, none, dispatch, none);
	HRRZM: decode(AC_inst, `aluRR1, `ZERO, 1, dispatch, none, none);
	HRRZS: decode(`ZERO, `aluRR2, read_data, 1, dispatch, (ac != 0) ? write_finish : none, none);
	HLRZ: decode(`ZERO, `aluLR2, SWAP(read_data), 1, none, dispatch, none);
	HLRZI: decode(`ZERO, `aluLR2, SWAP(E_word), 0, none, dispatch, none);
	HLRZM: decode(SWAP(AC_inst), `aluLR1, `ZERO, 1, dispatch, none, none);
	HLRZS: decode(`ZERO, `aluLR2, SWAP(read_data), 1, dispatch, (ac != 0) ? write_finish : none, none);
	
	HRRO: decode(`MINUSONE, `aluRR2, read_data, 1, none, dispatch, none);
	HRROI: decode(`MINUSONE, `aluRR2, E_word, 0, none, dispatch, none);
	HRROM: decode(AC_inst, `aluRR1, `MINUSONE, 1, dispatch, none, none);
	HRROS: decode(`MINUSONE, `aluRR2, read_data, 1, dispatch, (ac != 0) ? write_finish : none, none);
	HLRO: decode(`MINUSONE, `aluLR2, SWAP(read_data), 1, none, dispatch, none);
	HLROI: decode(`MINUSONE, `aluLR2, SWAP(E_word), 0, none, dispatch, none);
	HLROM: decode(SWAP(AC_inst), `aluLR1, `MINUSONE, 1, dispatch, none, none);
	HLROS: decode(`MINUSONE, `aluLR2, SWAP(read_data), 1, dispatch, (ac != 0) ? write_finish : none, none);
	
	HRRE: decode(`HSEX(RIGHT(read_data)), `aluRR2, read_data, 1, none, dispatch, none);
	HRREI: decode(`HSEX(E), `aluRR2, E_word, 0, none, dispatch, none);
	HRREM: decode(AC_inst, `aluRR1, `HSEX(RIGHT(AC_inst)), 1, dispatch, none, none);
	HRRES: decode(`HSEX(RIGHT(read_data)), `aluRR2, read_data, 1, dispatch, (ac != 0) ? write_finish : none, none);
	HLRE: decode(`SEX(read_data), `aluLR2, SWAP(read_data), 1, none, dispatch, none);
	HLREI: decode(`SEX(E_word), `aluLR2, SWAP(E_word), 0, none, dispatch, none);
	HLREM: decode(SWAP(AC_inst), `aluLR1, `SEX(AC_inst), 1, dispatch, none, none);
	HLRES: decode(`SEX(read_data), `aluLR2, SWAP(read_data), 1, dispatch, (ac != 0) ? write_finish : none, none);
`endif	  

	// Logical Testing and Modification (Bit Testing)
	TRN, TRNE, TRNA, TRNN, TRZ, TRZE, TRZA, TRZN, TRC, TRCE, TRCA, TRCN, TRO, TROE, TROA, TRON:
	  decode(AC_inst, test_op, E_word, 0, none, dispatch, none);
	TLN, TLNE, TLNA, TLNN, TLZ, TLZE, TLZA, TLZN, TLC, TLCE, TLCA, TLCN, TLO, TLOE, TLOA, TLON:
	  decode(AC_inst, test_op, SWAP(E_word), 0, none, dispatch, none);
	TDN, TDNE, TDNA, TDNN, TDZ, TDZE, TDZA, TDZN, TDC, TDCE, TDCA, TDCN, TDO, TDOE, TDOA, TDON:
	  decode(AC_inst, test_op, read_data, 1, none, dispatch, none);
	TSN, TSNE, TSNA, TSNN, TSZ, TSZE, TSZA, TSZN, TSC, TSCE, TSCA, TSCN, TSO, TSOE, TSOA, TSON:
	  decode(AC_inst, test_op, SWAP(read_data), 1, none, dispatch, none);

	IO_INSTRUCTION:
	  if (user_mode)
	    unassigned_code = 1; // needs to be a MUUO !!!
	  else
	    case (IOOP(inst))
	      // the APR and PI devices are caight here, everything else is sent out the I/O bus
	      CONO:		// Conditions Out
		decodeIO(AC_inst, `aluSETM, E_word, 0, none, 0, dispatch, 1);
	      CONI:		// Conditions In
		case (IODEV(inst))
		  APR:
		    decodeIO(apr_status, `aluSETA, read_data, 0, dispatch, 1, none, 1);
		  PI:
		    decodeIO(pi_status, `aluSETA, read_data, 0, dispatch, 1, none, 1);
		  default:
		    decodeIO(AC_inst, `aluSETM, read_data, 0, dispatch, 1, none, 1);
		endcase // casex (IODEV(inst))
	      CONSZ, CONSO:	// Conditions In and Skip if Zero/One
		case (IODEV(inst))
		  APR:
		    decodeIO(apr_status, `aluSETA, read_data, 0, none, 1, none, 1);
		  PI:
		    decodeIO(pi_status, `aluSETA, read_data, 0, none, 1, none, 1);
		  default:
		    decodeIO(AC_inst, `aluSETM, read_data, 0, none, 1, none, 1);
		endcase // casex (IODEV(inst))
	      DATAO:		// Data Out
		decodeIO(AC_inst, `aluSETM, read_data, 1, none, 0, dispatch, 0);
	      DATAI:		// Data In
		case (IODEV(inst))
		  APR:
		    decodeIO(switch_register, `aluSETA, read_data, 0, dispatch, 1, none, 0);
		  default:
		    decodeIO(AC_inst, `aluSETM, read_data, 0, dispatch, 1, none, 0);
		endcase
	      BLKI, BLKO:	// Block In/Out -- gotta get to these one day !!!
		unassigned_code = 1;
	    endcase
      endcase
   end // always @ begin

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
