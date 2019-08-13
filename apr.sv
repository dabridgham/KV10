//	-*- mode: Verilog; fill-column: 96 -*-
//
// Arithmetic Processing Unit for kv10 processor
//

`timescale 1 ns / 1 ns

`include "constants.svh"
`include "alu.svh"

typedef bit [`ADDR] addr;	// gotta figure out how to move these to a header file !!!
typedef bit [`WORD] word;
typedef bit [`HWORD] hword;
typedef bit [`DEVICE] device;


module apr
  (
   input 	    clk,
   input 	    reset,
   // interface to memory
   output [`ADDR]   mem_addr,
   output reg 	    mem_user, // selects user or exec memory
   input [`WORD]    mem_read_data,
   output [`WORD]   mem_write_data,
   output reg 	    mem_mem_read,
   output reg 	    mem_mem_write,
   input 	    mem_write_ack,
   input 	    mem_read_ack,
   input 	    mem_page_fail,
   // interface to I/O bus
   output [`DEVICE] io_dev, // the I/O Device
   output 	    io_cond, // I/O Device Conditions
   input [`WORD]    ext_io_read_data,
   output [`WORD]   io_write_data,
   output reg 	    io_read,
   output reg 	    io_write,
   input 	    ext_io_read_ack,
   input 	    ext_io_write_ack,
   input 	    ext_io_nxd,
   input [1:7] 	    io_pi_req, // PI requests from I/O devices

   // these might grow to be part of a front-panel interface one day
   output [`ADDR]   display_addr, 
   output 	    running
    );

`include "functions.svh"
`include "io.svh"
`include "opcodes.svh"
`include "decode.svh"
   

   //
   // Interrupt Logic and PI Device
   //

   reg 		      pi_ge;	// Global Enable
   reg [1:7] 	      pi_le;	// Level Enable
   reg [1:7] 	      pi_sr;	// Software request
   reg [1:7] 	      pi_ip;	// PI In-Progress
   reg [1:7] 	      pi_trap;	// trap interrupts from the APR
   reg [1:7] 	      pi_error;	// error interrupts from the APR
   wire [1:7] 	      pi_hr = pi_trap | pi_error | io_pi_req; // hardware request
   wire [1:7] 	      pi_rq = pi_sr | (pi_le & pi_hr); // interrupt request - software requests
 						       // happen even if the level enable is off
   addr 	      pi_vector; // Vector Address for the current interrupt level
   reg 		      interrupt_instruction; // set while executing an interrupt instruction
   reg 		      start_interrupt;
   reg 		      dismiss_interrupt, clr_ii, clr_user;
   wire 	      udisint;		 // dismiss interrupt from the uengine
   wire		      interrupt_request; // signals when there's an interrupt request higher
					 // than the current level in-progress
   word pi_status;
   assign pi_status = { 11'b0, pi_sr, 3'b0, pi_ip, pi_ge, pi_le }; // PI status word for CONI
   
   
   task RESET_PI;
      pi_ge <= 0;
      pi_le <= 0;
      pi_sr <= 0;
      pi_ip <= 0;
      interrupt_instruction <= 0;
   endtask

   // Figure out if we need to begin interrupt processing
   reg [1:7] pi_mask;		// mask of interrupts in-progress
   always @(*)
     case (1'b1)
       pi_ip[1]: pi_mask = 7'o177;
       pi_ip[2]: pi_mask = 7'o077;
       pi_ip[3]: pi_mask = 7'o037;
       pi_ip[4]: pi_mask = 7'o017;
       pi_ip[5]: pi_mask = 7'o007;
       pi_ip[6]: pi_mask = 7'o003;
       pi_ip[7]: pi_mask = 7'o001;
       default:  pi_mask = 7'o000;
     endcase // case (1'b1)
   assign interrupt_request = pi_ge && ((pi_rq & ~pi_mask) != 0);

   // Set the PI Vector according to the current level of interrupt being requested
   task set_pi_vector;
      input integer level;
      pi_vector = addr'('o40 + (2*level) + integer'(pi_ip[level]));
   endtask

   always @(*)
     if (start_interrupt)
       case (1'b1)
	 pi_rq[1]: set_pi_vector(1);
	 pi_rq[2]: set_pi_vector(2);
	 pi_rq[3]: set_pi_vector(3);
	 pi_rq[4]: set_pi_vector(4);
	 pi_rq[5]: set_pi_vector(5);
	 pi_rq[6]: set_pi_vector(6);
	 pi_rq[7]: set_pi_vector(7);
       endcase
     else
       // If we're not executing an interrupt instruction, default back to here for use
       // executing UUOs.  If I want to separate out Unassigned Instructions, this is where that
       // would go.  !!!
       pi_vector = `UUO_VEC;

   always @(posedge clk)
     if (start_interrupt) begin
	// To begin interrupt processing, execute the interrupt instruction and mark this PI
	// level as In-Progress
	interrupt_instruction <= 1;
	case (1'b1)
	  pi_rq[1]: pi_ip[1] <= 1;
	  pi_rq[2]: pi_ip[2] <= 1;
	  pi_rq[3]: pi_ip[3] <= 1;
	  pi_rq[4]: pi_ip[4] <= 1;
	  pi_rq[5]: pi_ip[5] <= 1;
	  pi_rq[6]: pi_ip[6] <= 1;
	  pi_rq[7]: pi_ip[7] <= 1;
	endcase	  
     end else if (clr_ii) begin
	interrupt_instruction <= 0;
     end else if (dismiss_interrupt || udisint) begin
	case (1'b1)
	  pi_ip[1]: pi_ip[1] <= 0;
	  pi_ip[2]: pi_ip[2] <= 0;
	  pi_ip[3]: pi_ip[3] <= 0;
	  pi_ip[4]: pi_ip[4] <= 0;
	  pi_ip[5]: pi_ip[5] <= 0;
	  pi_ip[6]: pi_ip[6] <= 0;
	  pi_ip[7]: pi_ip[7] <= 0;
	endcase	  
     end

   reg MUUO, clr_MUUO;
   wire set_MUUO;

   always @(posedge clk)
     if (reset || clr_MUUO)
       MUUO <= 0;
     else if (set_MUUO)
       MUUO <= 1;

   // Modify various signals while we're executing an interrupt instruction
   always @(*) begin
      PC_load = uPC_load;
      clr_ii = 0;
      clr_user = 0;
      dismiss_interrupt = 0;
      clr_MUUO = 0;

      if (interrupt_instruction) begin
	 // only select interrupt instructions may load the PC
	 PC_load = 0;

	 // when instructions try to load the PC, figure out what to do ...
	 if (uPC_load) begin
	    clr_ii = 1;
	    case (1'b1)
	      // Instructions that are used to jump to an interrupt service routine
	      int_jump:
		begin
		   PC_load = 1;
		   clr_user = 1;	// switch to kernel mode for the ISR
		end

	      // Instructions that may skip.  If they skip, dismiss the interrupt and return to
	      // previous processing, If they don't skip, execute the second interrupt instruction
	      // in the vector.
	      int_skip:
		if (Asel == 8)	// next
		  // go on to exectute the second instruction
		  clr_ii = 0; // still an interrupt instruction
		else		// skip
		  dismiss_interrupt = 1;

	      // All other instructions just dismiss the interrupt.
	      default:
		dismiss_interrupt = 1;
	    endcase // case (1'b1)
	 end
      end else if (MUUO) begin // if (interrupt_instruction)
	 // MUUO instructions let the PC get laoded as usual.  The only difference is that
	 // select JUMP instructions will clear the user flag

	 if (uPC_load) begin
	    clr_MUUO = 1;
	    if (int_jump)
	      clr_user = 1;
	 end
      end
   end

   //
   // APR Device
   //
   
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
       apr_fu1 = 0;	     // the user mode trap-1 flag
   wire apr_eir,	     // indicates that an error interrupt is pending
	apr_tir;	     // indicates that a trap interrupt is pending
   reg [0:2] apr_eia = 0;    // the PI assignment for the error interrupt. 0 means not connected
   reg [0:2] apr_tia = 0;    // the PI assignment for the trap interrupt. 0 means not connected
   wire [`WORD] apr_status = // APR status word for CONI
		{ apr_ehe, apr_ese, apr_ee2, apr_ee1, apr_eu2, apr_eu1, apr_eia,
		  apr_the, apr_tse, apr_te2, apr_te1, apr_tu2, apr_tu1,	apr_tia,	
		  7'b0, apr_fhe, apr_fse, apr_fe2, apr_fe1, apr_fu2, apr_fu1, apr_eir, apr_tir, 3'b0 };

   task reset_apr;
      begin
	 apr_ehe <= 0;	 apr_ese <= 0;
	 apr_ee2 <= 0;	 apr_ee1 <= 0;
	 apr_eu2 <= 0;	 apr_eu1 <= 0;
	 apr_the <= 0;	 apr_tse <= 0;
	 apr_te2 <= 0;	 apr_te1 <= 0;
	 apr_tu2 <= 0;	 apr_tu1 <= 0;
	 apr_fhe <= 0;	 apr_fse <= 0;
	 apr_fe2 <= 0;	 apr_fe1 <= 0;
	 apr_fu2 <= 0;	 apr_fu1 <= 0;
	 apr_eia <= 0;	 apr_tia <= 0;
      end
   endtask

   // set error interrupt
   assign apr_eir = (apr_ehe && (apr_fhe /*|| mem_nxm*/)) ||   // notice NXM or page fail immediately.
		    (apr_ese && (apr_fse || mem_page_fail)) || // the error flag will be set on the next clock.
		    (apr_ee2 && apr_fe2) ||
		    (apr_ee1 && apr_fe1) ||
		    (apr_eu2 && apr_fu2) ||
		    (apr_eu1 && apr_fu1);
   always @(*) begin
      pi_error = 0;
      if (apr_eia != 0)
	pi_error[apr_eia] = apr_eir;
   end

   // set trap interrupt
   assign apr_tir = (apr_the && (apr_fhe /*|| mem_nxm*/)) ||   // notice NXM or page fail immediately.
		    (apr_tse && (apr_fse || mem_page_fail)) || // the error flag will be set on the next clock
		    (apr_te2 && apr_fe2) ||
		    (apr_te1 && apr_fe1) ||
		    (apr_tu2 && apr_fu2) ||
		    (apr_tu1 && apr_fu1);
   always @(*) begin
      pi_trap = 0;
      if (apr_tia != 0)
	pi_trap[apr_tia] = apr_tir;
   end   

   task set_overflow_tsk;
      begin
	 overflow <= 1;
	 if (user)
	   apr_fu1 <= 1;
	 else
	   apr_fe1 <= 1;
      end
   endtask

   task set_pushdown_overflow;
      begin
	 if (user)
	   apr_fu2 <= 1;
	 else
	   apr_fe2 <= 1;
      end
   endtask


   //
   // The APR and PI devices
   //

   reg 		      io_read_ack, io_write_ack, io_nxd;
   reg [`WORD] 	      io_read_data, int_io_read_data;


   // Internal I/O Control Line Mux
   always @(*) begin
      io_read_data = int_io_read_data;

      case ({io_dev, io_cond})
	IO_DATA(APR), // Switch Register (can be output on a KI-like console) (not yet implemented !!!)
	IO_DATA(PI):  // Memory Indicator (output only) (not yet implemented !!!)
	  begin
	     io_nxd = 1;
	     io_read_ack = 0;
	     io_write_ack = 0;
	  end
	IO_COND(APR), IO_COND(PI):
	  begin
	     io_nxd = 0;
	     io_read_ack = 1;
	     io_write_ack = 1;
	  end
	default:
	  begin
	     io_nxd = ext_io_nxd;
	     io_read_ack = ext_io_read_ack;
	     io_write_ack = ext_io_write_ack;
`ifndef LINT
	     io_read_data = ext_io_read_data;
`endif
	  end
      endcase // case ({io_dev, io_cond})
   end
   
   // Internal I/O Device Read
   always @(posedge clk)
     if (io_read)
       case ({io_dev, io_cond})
	 IO_DATA(APR): int_io_read_data <= 0;
	 IO_COND(APR): int_io_read_data <= apr_status;
	 IO_DATA(PI): int_io_read_data <= 0;
	 IO_COND(PI): int_io_read_data <= pi_status;
       endcase

   // Internal I/O Device Write
   always @(posedge clk) begin
      // Set the hard and soft error flags here, in the same always block as the I/O operations
      // on the register.  Once I get to compiling this for the FPGA, see if that's actually
      // necessary. !!!
      if (mem_page_fail) apr_fse <= 1;
`ifdef NOTDEF
      if (mem_nxm) apr_fhe <= 1;
`endif

      if (reset) begin
	 RESET_PI();
      end else if (io_write) begin
	 case ({io_dev, io_cond})
	   IO_DATA(APR):
	     ;
	   
	   IO_COND(APR):
	     begin
		if (io_write_data[`APR_SSE]) apr_fse <= 1; // set/clear soft error
		else if (io_write_data[`APR_CSE]) apr_fse <= 0;
		
		if (io_write_data[`APR_RIO]) ; // Does nothing now.  Probably should just poke BIO !!!

		if (io_write_data[`APR_SF]) begin // set/clear flags
		   if (io_write_data[`APR_MHE]) apr_fhe <= 1;
		   if (io_write_data[`APR_MSE]) apr_fse <= 1;
		   if (io_write_data[`APR_ME2]) apr_fe2 <= 1;
		   if (io_write_data[`APR_ME1]) apr_fe1 <= 1;
		   if (io_write_data[`APR_MU2]) apr_fu2 <= 1;
		   if (io_write_data[`APR_MU1]) apr_fu1 <= 1;
		end else if (io_write_data[`APR_CF]) begin
		   if (io_write_data[`APR_MHE]) apr_fhe <= 0;
		   if (io_write_data[`APR_MSE]) apr_fse <= 0;
		   if (io_write_data[`APR_ME2]) apr_fe2 <= 0;
		   if (io_write_data[`APR_ME1]) apr_fe1 <= 0;
		   if (io_write_data[`APR_MU2]) apr_fu2 <= 0;
		   if (io_write_data[`APR_MU1]) apr_fu1 <= 0;
		end

		if (io_write_data[`APR_LE]) begin // load error interrupt enables and PI assignment
		   apr_ehe <= io_write_data[`APR_MHE];
		   apr_ese <= io_write_data[`APR_MSE];
		   apr_ee2 <= io_write_data[`APR_ME2];
		   apr_ee1 <= io_write_data[`APR_ME1];
		   apr_eu2 <= io_write_data[`APR_MU2];
		   apr_eu1 <= io_write_data[`APR_MU1];
		   apr_eia <= io_write_data[`APR_IA];
		end

		if (io_write_data[`APR_LT]) begin // load trap interrupt enables and PI assignment
		   apr_the <= io_write_data[`APR_MHE];
		   apr_tse <= io_write_data[`APR_MSE];
		   apr_te2 <= io_write_data[`APR_ME2];
		   apr_te1 <= io_write_data[`APR_ME1];
		   apr_tu2 <= io_write_data[`APR_MU2];
		   apr_tu1 <= io_write_data[`APR_MU1];
		   apr_tia <= io_write_data[`APR_IA];
		end
	     end

	   IO_DATA(PI):
	     ;

	   IO_COND(PI):
	     if (io_write_data[PI_RPI]) begin
		RESET_PI();
	     end else begin
		// Matching the KX10, we prioritize setting over clearing.
		if (io_write_data[PI_SSR])
		  pi_sr <= pi_sr | io_write_data[`PI_Mask];
		else if (io_write_data[PI_CSR])
		  pi_sr <= pi_sr & ~io_write_data[`PI_Mask];

		if (io_write_data[PI_SLE])
		  pi_le <= pi_le | io_write_data[`PI_Mask];
		else if (io_write_data[PI_CLE])
		  pi_le <= pi_le & ~io_write_data[`PI_Mask];

		if (io_write_data[PI_SGE])
		  pi_ge <= 1;
		else if (io_write_data[PI_CGE])
		  pi_ge <= 0;
	     end
	 endcase
      end
   end

   //
   // Data Paths
   //

   // Fast Accumulators
   // Select either A or A+1 for double word operations
   wire 	      ACnext; // driven from the micro-instruction
   wire [0:3] 	      ACsel = ACnext ? A + 1 : A;
   wire [`WORD]       write_data, AC, AC_mem;
   wire 	      mem_write, mem_read; // driven from the uinst
      
   reg 		      AC_write;
   fast_ac fast_ac(clk, ACsel, AC, write_data, AC_write,
		   mem_addr[32:35], AC_mem, write_data, mem_read, mem_write && isAC(mem_addr));
   

   //
   // Processor Status Word
   //
   reg 		      overflow, carry0, carry1, floating_overflow;
   reg 		      saved_overflow, saved_carry0, saved_carry1;
   reg 		      first_part_done, user, userIO, floating_underflow, no_divide;
   reg 		      set_flags, save_flags, clear_flags, set_overflow, set_pd_overflow;
   reg 		      clear_first_part_done, set_first_part_done, set_no_divide;
   reg 		      PSW_load;
   wire 	      set_user;
   wire [`HWORD]      PSW = { overflow, carry0, carry1, floating_overflow,
			      first_part_done, user, userIO, 4'b0,
			      floating_underflow, no_divide, 5'b0 };
   always @(posedge clk) begin
      if (reset) begin
	 overflow <= 0;
	 carry0 <= 0;
	 carry1 <= 0;
	 floating_overflow <= 0;
	 first_part_done <= 0;
	 user <= 0;
	 userIO <= 0;
	 floating_underflow <= 0;
	 no_divide <= 0;
      end

      // this is a set of latches on the ALU flags to save them for later
      if (save_flags) begin
	 saved_overflow <= ALUoverflow;
	 saved_carry0 <= ALUcarry0;
	 saved_carry1 <= ALUcarry1;
      end

      if (set_flags) begin
	 if ((saved_overflow) || (save_flags && ALUoverflow)) set_overflow_tsk();
	 if ((saved_carry0) || (save_flags && ALUcarry0)) carry0 <= 1;
	 if ((saved_carry1) || (save_flags && ALUcarry1)) carry1 <= 1;
      end

      if (set_overflow) set_overflow_tsk();

      if (clear_flags) begin
	 if (inst[9]) overflow <= 0;
	 if (inst[10]) carry0 <= 0;
	 if (inst[11]) carry1 <= 0;
	 if (inst[12]) floating_overflow <= 0;
      end

      if (set_pd_overflow && ALUoverflow) set_pushdown_overflow();
      
      if (clear_first_part_done) first_part_done <= 0;
      if (set_first_part_done) first_part_done <= 1;
      if (set_no_divide) no_divide <= 1;
      
      // set_user comes from the uengine while clr_user comes from the interrupt processing
      if (set_user) user <= 1;
      else if (clr_user) user <= 0;

      if (PSW_load) begin	// load PSW from the left half of write_data
	 overflow <= write_data[0];
	 carry0 <= write_data[1];
	 carry1 <= write_data[2];
	 floating_overflow <= write_data[3];
	 first_part_done <= write_data[4];
	 user <= user ? 1 : write_data[5];
	 userIO <= user ? 0 : write_data[6];
	 floating_underflow <= write_data[11];
	 no_divide <= write_data[12];
      end
   end


   // An assortment of other registers in the micro-machine
   reg [`WORD] 	      Breg;	// scratchpad for double-word operations
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
   reg 		      Breg_load, Areg_load, Mreg_load,
		      OpA_load, IX_load, Y_load, BP_load,
   		      PC_load;
   wire 	      uPC_load;
   always @(posedge clk) begin
      if (Breg_load) Breg <= ALUresultlow;
      
      if (Areg_load) 
	Areg <= write_data;
      else if (mul_start)
	Areg <= 0;		// a hack to save a state
      
      if (Mreg_load) Mreg <= write_data;
      if (PC_load)
	PC <= RIGHT(Amux);
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
     case (Asel)
       // indexes here must match those in kv10.def
       0: Amux = `ZERO;
       1: Amux = `ONE;
       2: Amux = `MINUSONE;
       3: Amux = `WORDSIZE'o254000_001000; // jrst 1000
       4: Amux = {`WORDSIZE{Malu[0]}}; // sign-extend Malu
       5: Amux = { `HALFZERO, pi_vector };
       6: Amux = Areg;
       7: Amux = { PSW, PC };
       // This is just ugly.  JSR, JSP, PSA, and PUSHJ normally save the next PC.  However, when
       // used as an interrupt instruction, they want to save the current PC.  Seems like there
       // ought to be a more elegant way to get the right answer here.
       8: Amux = { PSW, interrupt_instruction ? PC : PC_next };
       9: Amux = { PSW, PC_skip };
       10: Amux = AC;
       11: Amux = { RIGHT(AC), LEFT(AC) };
       12: Amux = bp_mask(BP_S);
       13: Amux = Mreg;
       14: Amux = { `HALFZERO, E };
       15: Amux = { `XFILL, X };
     endcase

   // M-leg mux to the ALU
   wire [0:3] 	      Msel;	// set correct size !!!
   reg [`WORD] 	      Mmux;
   wire [`HWORD]      extP = { 12'b0, BP_P }; // byte position
   wire [`HWORD]      extPneg = -extP;	      // for shifting bytes to the right
   always @(*)
     // numbers here must match those in kv10.def
     case (Msel)
       0: Mmux = Mreg;
       1: Mmux = AC;
       2: Mmux = { `HALFZERO, 12'b0, BP_P };
       3: Mmux = { `HALFZERO, extPneg };
       4: Mmux = { `HALFZERO, E };
       5: Mmux = read_data;
       6: Mmux = io_read_data;
       7: Mmux = { OpA, 5'b0, Y }; // the instruction except for I and X
       default: Mmux = AC;
     endcase // case (Msel)

   // some extra state to help with implementing multiply and divide
   wire 	      mul_shift_set = NEGATIVE(Mmux) & Breg[35];
   reg 		      mul_shift_bit;
   wire 	      mul_shift_ctl = mul_shift_bit | mul_shift_set;
   reg 		      mul_start;
   always @(posedge clk)
     if (reset || mul_start) begin
	mul_shift_bit <= 0;
     end else begin
	if (mul_shift_set)
	  mul_shift_bit <= 1;
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
   alu alu(ALUcommand, Breg, Amux, Malu, mul_shift_ctl, NEGATIVE(AC), ALUresultlow, ALUresult, 
	   ALUcarry0, ALUcarry1, ALUoverflow, ALUzero);
   // rename the output of the ALU
   assign write_data = ALUresult;
   // Send the output of the ALU to the write data lines for the memory and I/O
   assign mem_write_data = write_data;
   assign io_write_data = write_data;
   // Pull the memory address off the A input to the ALU
   assign mem_addr = RIGHT(Amux);

   //
   // Mux for Memory and ACs
   //

   // Control Signals Mux's
   reg [`WORD] 	      read_data;
   assign mem_mem_read = isAC(mem_addr) ? 0 : mem_read;
   assign mem_mem_write = isAC(mem_addr) ? 0 : mem_write;

   // The read_data mux selection is latched and read_data can show up a clock later
   reg 		      is_ac;
   always @(posedge clk)
     if (mem_read || mem_write)
       is_ac = isAC(mem_addr);
   assign read_data = is_ac ? AC_mem : mem_read_data;

`ifdef NOTDEF
   // The acks need to come through immediately but we also need to latch the mux in case they
   // show up later
   wire 	      ack_sel = (mem_read || mem_write) ? isAC(mem_addr) : is_ac;
   wire 	      read_ack = ack_sel ? mem_read : mem_read_ack;
   wire 	      write_ack = ack_sel ? mem_write : mem_write_ack;
`else
   reg 		      read_ac_ack, write_ac_ack;
   always @(posedge clk) read_ac_ack = isAC(mem_addr) && mem_read;
   always @(posedge clk) write_ac_ack = isAC(mem_addr) && mem_write;

   wire 	      read_ack = is_ac ? read_ac_ack : mem_read_ack;
   wire 	      write_ack = is_ac ? write_ac_ack : mem_write_ack;
`endif


   // Compute a skip or jump condition looking at the ALU output.  This signal only makes
   // sense when the ALU is performing a subtraction.
   reg [0:2] 	      condition_code;	// driven by the instruction decode ROM
   reg 		      jump_condition;
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
   reg 		      jump_condition_0;
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
   

   // Most of the time, mem_user is just the user flag from the processor.  Exceptions are when
   // executing interrupt instructions or the instruction for an MOOU.  Then XCTR gets
   // complicated.
   wire memIF;		    // Instruction Fetch
   wire [0:1] memDE;	    // driven by the micro-engine to indicate the class of memory access
   localparam 
     memE1 = 0,			// EA calculation, Index and Indirect
     memD1 = 1,			// Memory Operands and BLT Destination
     memE2 = 2,			// EA calculation for Byte Pointers
     memD2 = 3;			// Byte data and BLT Source
   reg 	      XCTR;		// set while XCTR is executing an instruction
   wire       dXCT;		// driven by the instruction decode
   reg [0:3]  mem_access;	// latched from A when we find out it's an XCTR instruction
   reg 	      XCTRI;		// latched from A[0]

   always @(posedge clk)
     if (reset) begin
	XCTR <= 0;
	XCTRI <= 0;
     end else if (dXCT && save_flags && !user) begin // when we read the instruction for XCTR to execute
	XCTR <= 1;
	XCTRI <= A[0];
	case (A[1:3])
	  0: mem_access <= 4'b0000;
	  1: mem_access <= 4'b0100;
	  2: mem_access <= 4'b0001;
	  3: mem_access <= 4'b0101;
	  4: mem_access <= 4'b1000;
	  5: mem_access <= 4'b0111;
	  6: mem_access <= 4'b0000;
	  7: mem_access <= 4'b0000;
	endcase
     end else if (XCTR && memIF) begin // this will hit when we execute the first instruction after the XCTR
	XCTR <= 0;
	XCTRI <= 0;
     end
   
   always @(*)
     if (interrupt_instruction || MUUO)
       mem_user = 0;
     else if (XCTR)
       mem_user = mem_access[memDE]; // this only works during XCTR when we know we're in exec mode
     else 
       mem_user = user;


   //
   // Micro-Controller
   //

   // the micro-instruction and its breakout
   wire [63:0] uinst;		// set the width once I'm done !!!
   wire        umem_read;	// the micro-engine intercepts the mem_read signal
   
   // All these micro-instruction bit assignments need to match up with the values in kv10.def
   assign udisint = uinst[61];
   assign mul_start = uinst[60];
   assign set_no_divide = uinst[59];
   assign set_first_part_done = uinst[58];
   assign clear_first_part_done = uinst[57];
   assign set_overflow = uinst[56];
   assign clear_flags = uinst[55];
   assign set_flags = uinst[54];
   assign set_pd_overflow = uinst[53];
   assign set_user = uinst[52];
   assign PSW_load = uinst[51];
   assign ACnext = uinst[50];
   assign set_MUUO = uinst[49];
   assign BP_load = uinst[48];
   assign Y_load = uinst[47];
   assign IX_load = uinst[46];
   assign OpA_load = uinst[45];
   assign Mswap = uinst[44];

   assign uPC_load = uinst[42];
   assign Mreg_load = uinst[41];
   assign Areg_load = uinst[40];
   assign Breg_load = uinst[39];
   assign AC_write = uinst[38];
   
   assign io_write = uinst[37];
   assign io_read = uinst[36];
   assign mem_write = uinst[35];
   assign umem_read = uinst[34];
   assign memIF = uinst[33];
   assign memDE = uinst[32:31];
   assign save_flags = uinst[30];
   assign ALUcommand = uinst[29:24];
   assign Asel = uinst[23:20];
   assign Msel = uinst[19:16];
   wire [4:0]  ubranch_code = uinst[15:11];
   wire [10:0] unext = uinst[10:0]; // the next instruction location

   reg [10:0]  ucurr, uprev;	// current and previous micro-addresses, kept for debugging
   reg [10:0]  uaddr;
   reg [10:0]  ubranch;		// gets ORd with unext to get the next micro-address

   uROM uROM(clk, uaddr, uinst);

   // the core of the microsequencer is trvial except for a little special bit for handling
   // interrupts and page faults
   // async part
   always @(*) begin
      if (reset)
	uaddr = 0;
      else if (interrupt_request && (umem_read || read_ack))
	// If an interrupt is being requested when a memory read starts, inhibit mem_read so the
	// read doesn't even start and branch immediately to the interrupt handler.  Similarly, if
	// an interrupt is being requested when a read_ack comes in, also branch to the interrupt
	// handler.
	uaddr = 'o777;
      else if (mem_page_fail)
	// If we get a page fault, immediately abort the instruction.  The next step is to try
	// executing the same instruction.  If the PI system is set up to accept Page Fault
	// interrupts, we'll go to the interrupt handler and take care of this.  If not, then
	// the instruction will likely generate a page fault again which will be a double error
	// and the processor will halt.  This double error check is not yet implemented. !!!
	uaddr = 'o775;
      else 
	uaddr = unext | ubranch;
   end

   // sync part
   always @(posedge clk) begin
      ucurr <= uaddr;
      if (reset)
	uprev <= 11'ox;
      else
	uprev <= ucurr;
   end

   always @(posedge clk) begin
      start_interrupt <= 0;

      if (interrupt_request && (umem_read || read_ack)) begin
	 start_interrupt <= 1;
      end

`ifdef SIM
      // what do I do if we hit a halt when not in the simulator?  !!!
      if (unext == 0) begin
	 $display(" HALT!!!");
	 $display("uEngine halt @%o from %o", uaddr, uprev);
	 $finish_and_return(1);
      end
`endif
   end // always @ (posedge clk)

   // inhibit mem_read if we're requesting an interrupt
   assign mem_read = umem_read & ~interrupt_request;

   // branching is where much of the magic happens in the micro-engine
   always @(*) begin
      ubranch = 0;		// default all the bits to 0
      
      // these numbers need to match up with the numbers in kv10.def
      case (ubranch_code)
	// no branch
	0: ubranch = 0;

	// Memory Read - loop, waiting for read_ack.  Interrupts are handled directly by a hack
	// in the micro-engine.
	1: ubranch[0] = read_ack;

	// mem write - loop, waiting for write_ack
	2: ubranch[0] = write_ack;

	// IX - a 3-way branch on index and indirect calculating the Effective Address.
	3: case (1'b1)
	     Index: ubranch[1:0] = 0;
	     Indirect: ubranch[1:0] = 1;
	     default: ubranch[1:0] = 2;
	   endcase

	// Indirect - If the Effective Address calculation included an Index register, we need
	// to then check if there's also an Indirect.
	4: ubranch[0] = Indirect;

	// Dispatch - This comes from the instruction decode.  By default it's just the
	// instruction opcode but it also handles the Effective Address calculation (well, it
	// will someday), instructions that need to read the value at E first, and then a few
	// special cases to optimze certain instructions.  Also, I/O instructions are handled
	// specially.
	5: if (ReadE)
	  ubranch[8:0] = 9'o740;
	else
	  ubranch[8:0] = dispatch;

	// Conditional skip or jump
	6: ubranch[0] = jump_condition;

	// Conditional skip or jump with a comparison to 0
	7: ubranch[0] = jump_condition_0;

	// Write Self check - if AC != 0
	8: ubranch[0] = (A != 0);

	// Test - Bitwise compare on the /inputs/ to the ALU.  For the TEST instructions.
	9: ubranch[0] = ((Amux & Malu) != 0);

	// JFCL - if any of the flags are about to be cleared
	10: ubranch[0] = (({overflow, carry0, carry1, floating_overflow} & inst[9:12]) != 0);

	// MUL - break out the different Multiply or Divide instructions
	// 0: IMUL/IDIV	1: IMULI/IDIVI	2: IMULM/IDIVM	3: IMULB/IDIVB
	// 4: MUL/DIV	5: MULI/DIVI	6: MULM/DIVM	7: MULB/DIVB
	11: ubranch[2:0] = inst[6:8];

	// OVR - check ALUoverflow, used in DIV and JFFO
	12: ubranch[0] = ALUoverflow;

	// Byte - Branch on which of four byte instructions
	// 0: ILDB	1: LBD		2: IDPB		3: DPB
	13: ubranch[1:0] = inst[7:8];

	// First Part Done
	14: ubranch[0] = first_part_done;

	// BLT terminates when the word we just wrote went into location E
	15: ubranch[0] = (RIGHT(AC) == E);

	// IO Read - three way branch
	16: case (1'b1)
	      io_nxd: ubranch[1:0] = 2;
	      io_read_ack: ubranch[1:0] = 1;
	      default: ubranch[1:0] = 0;
	    endcase // case (1'b1)

	// IO Write - three way branch
	17: case (1'b1)
	      io_nxd: ubranch[1:0] = 2;
	      io_write_ack: ubranch[1:0] = 1;
	      default: ubranch[1:0] = 0;
	    endcase // case (1'b1)

	default: ubranch = 0;
      endcase // case (ubranch_code)
   end

`ifdef SIM
   //
   // The disassembler
   //

 `include "disasm.svh"

   // I need to pull out the cycle and instruction count so they work when I'm not in the
   // simulator too. !!!
   reg [`WORD] 	 cycles;
   reg [`WORD] 	 instruction_count;
   reg [`ADDR] 	 read_addr;

   always @(posedge clk) begin
      cycles <= cycles+1;

      // the read address may go away before OpA_load is set, so remember it
      if (mem_read) read_addr <= mem_addr;

      if (reset) begin
	 instruction_count <= 0;
	 cycles <= 0;
	 carry0 <= 0;
	 carry1 <= 0;
	 overflow <= 0;
	 floating_overflow <= 0;
      end

      if (OpA_load) begin
	 instruction_count <= instruction_count + 1;
	 
	 // this is a horrible hack but it's really handy for running a bunch of
	 // tests and DaveC's tests all loop back to 001000 !!!
	 if ((PC == `ADDRSIZE'o1000) && (instruction_count != 0))
	   $finish_and_return(0);

	 // disassembler
	 $display("%6o: %6o,%6o %s", read_addr, write_data[0:17], write_data[18:35], disasm(write_data));
      end // if (OpA_load)

 `ifdef NOTDEF
      // it might be nice to figure out how to make this work again !!!
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

   // print out state and stats when we're done
   final begin
      $display("Cycles: %0d  Instructions: %0d   Cycles/inst: %f",
	       cycles, instruction_count, $itor(cycles)/$itor(instruction_count));
      $display("carry0: %b  carry1: %b  overflow: %b  floating overflow: %b",
	       carry0, carry1, overflow, floating_overflow);
      $display("User: %b  UserIO: %b", user, userIO);
   end

 `ifdef NOTDEF
   // this happens so rarely.  need to investigate if I can collapse the two checks into one !!!
   always @(posedge clk)
     if (jump_condition != jump_condition_0)
       $display("!!! Jump conditions different !!!");
 `endif

`endif
   


   //
   // Instruction Decode ROM
   //

   wire dReadE;			// from the decode ROM
   wire [0:8] dispatch;		// main instruction branch in the micro-code
   wire       int_jump;		// interrupt instruction is special as a jump
   wire       int_skip;		// interrupt instruction is special as a skip
   decode decode(.inst(inst),
		 .user(user),
		 .userIO(userIO),
		 .dispatch(dispatch),
 		 .ReadE(dReadE),
		 .condition_code(condition_code),
 		 .io_dev(io_dev),
		 .io_cond(io_cond),
		 .int_jump(int_jump),
		 .int_skip(int_skip),
		 .xct(dXCT));

   reg 	      have_dispatched = 0;	// set once we've dispatched so we don't read E again
   wire       ReadE = dReadE & ~have_dispatched; // the instruction reads the value from E
   always @(posedge clk) begin
      // After we read E, clear the flag so we can dispatch again and not read E again
      if (ubranch_code == 5)	// brDISPATCH
	have_dispatched <= 1;
      // grab ReadE from the decode ROM but into a register that we can clear once we read E
      else if (OpA_load)
	have_dispatched <= 0;
   end


endmodule // APR


// Fast Accumulators
module fast_ac
  (input       clk,
   input [0:3] 	      ACsel,
   output [`WORD]     AC,
   input [`WORD]      ac_write_data,
   input 	      AC_write,
   input [0:3] 	      mem_addr,
   output reg [`WORD] AC_mem,
   input [`WORD]      mem_write_data,
   input 	      mem_read,
   input 	      mem_write);
   
   reg [`WORD] 	      accumulators [0:'o17];

   // dual-port, synchronous write
   always @(posedge clk)
     if (AC_write)
       accumulators[ACsel] <= ac_write_data;
   always @(posedge clk)
     if (mem_write)       // XCTR needs to be able to turn this off sometimes !!!
       accumulators[mem_addr] <= mem_write_data;

   // asynchronous read for the AC
   assign AC = accumulators[ACsel];
   // when we read from the accumulators as if they're memory, do a synchronous read
   always @(posedge clk)
     if (mem_read)
       AC_mem <= accumulators[mem_addr];

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

   final begin
      $display("0: %o,%o  4: %o,%o  10: %o,%o  14: %o,%o",
	       accumulators[0][0:17], accumulators[0][18:35],
	       accumulators[4][0:17], accumulators[4][18:35],
	       accumulators[8][0:17], accumulators[8][18:35],
	       accumulators[12][0:17], accumulators[12][18:35]);
      $display("1: %o,%o  5: %o,%o  11: %o,%o  15: %o,%o",
	       accumulators[1][0:17], accumulators[1][18:35],
	       accumulators[5][0:17], accumulators[5][18:35],
	       accumulators[9][0:17], accumulators[9][18:35],
	       accumulators[13][0:17], accumulators[13][18:35]);
      $display("2: %o,%o  6: %o,%o  12: %o,%o  16: %o,%o",
	       accumulators[2][0:17], accumulators[2][18:35],
	       accumulators[6][0:17], accumulators[6][18:35],
	       accumulators[10][0:17], accumulators[10][18:35],
	       accumulators[14][0:17], accumulators[14][18:35]);
      $display("3: %o,%o  7: %o,%o  13: %o,%o  17: %o,%o",
	       accumulators[3][0:17], accumulators[3][18:35],
	       accumulators[7][0:17], accumulators[7][18:35],
	       accumulators[11][0:17], accumulators[11][18:35],
	       accumulators[15][0:17], accumulators[15][18:35]);
   end // final begin
`endif

endmodule // fast_ac


// ROM for the Microcode
module uROM
  (input clk,
   input [10:0]  uaddr,
   output reg [63:0] uinst
   );
   
   reg [63:0] 	 uROM [0:2047];	// microcode ROM

   initial $readmemh("kv10.hex", uROM);

   always @(posedge clk)
     uinst <= uROM[uaddr];

endmodule // urom
