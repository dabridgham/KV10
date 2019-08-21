//	-*- mode: Verilog; fill-column: 90 -*-
//
// Pager for the KV10 Processor.
//
// This design follows the description of PAG from Dave Conroy's PDP-10/X which follows
// the pager built by MIT to support ITS.


`timescale 1 ns / 1 ns

`include "constants.svh"

module pag
  (
   // signals from/to the APR
   input 	       clk,
   input 	       reset, 
   input [`ADDR]       mem_addr,
   input 	       mem_user, // selects user or exec memory
   output reg [`WORD]  mem_read_data,
   input [`WORD]       mem_write_data,
   input 	       mem_read,
   input 	       mem_write,
   output	       read_ack,
   output 	       write_ack,
   output reg	       page_fail,
   input [`DEVICE]     apr_io_dev,
   input 	       apr_io_cond,
   output reg [`WORD]  apr_io_read_data,
   input [`WORD]       apr_io_write_data,
   input 	       io_read,
   input 	       io_write,
   output reg 	       apr_io_read_ack,
   output reg 	       apr_io_write_ack,
   output reg 	       apr_nxd, 
   output [1:7]        pi_out, // PI requests to the APR

   // signals to/from the next stage in the chain (cache or memory)
   output reg [`PADDR] pmem_addr,
   input [`WORD]       pmem_read_data,
   output reg [`WORD]  pmem_write_data,
   output reg 	       pmem_read,
   output reg 	       pmem_write,
   output 	       pmem_io_read,
   output 	       pmem_io_write,
   input 	       pmem_read_ack,
   input 	       pmem_write_ack,
   input 	       pmem_nxd,
   input [1:7] 	       pi_in	// PI requests from the next stage
   );

`include "functions.svh"
`include "io.svh"

   // Pass these through.
   assign pmem_io_write = io_write;
   assign pmem_io_read = io_read;
   // At the moment, PAG doesn't generate interrupts.  There are comments in the PDP-10/X
   // documentation to the effect that this could change.
   assign pi_out = pi_in;


   reg 		      pag_enable = 0; // Enable Paging
   reg 		      pag_hm = 1,     // highest moby
		      pag_re = 1;     // ROM enable (not implemented !!!)
   reg [`WORD] 	      pag_last_error = 0;
   reg 		      ac_block_enable = 0;
   reg [14:31] 	      ac_block_base = 0; // for AC block relocation (calulate size from PMEMSIZE!!!)
   reg [`HWORD]       quantum_timer = 0; // need to hook this up to a clock !!!
					 // and it only incremenets at PI 0? !!!

   reg [14:29] 	      pt_elb = 0, // exec mode low segment base register
		      pt_ehb = 0, // exec mode high segment base register
 		      pt_ulb = 0, // user mode low segment base register
		      pt_uhb = 0; // user mode high segment base register
   reg 		      invalidate_exec, invalidate_user;
   reg [0:7] 	      invalidate_exec_count, invalidate_user_count;
   wire [0:7] 	      invalidate_exec_count_next = invalidate_exec_count + 1, 
		      invalidate_user_count_next = invalidate_user_count + 1;
   reg 		      load_pte;
   
   // the page table cache
   reg [`PPAGE_NMBR]   exec_ppn[0:255]; // physical page number
   reg [`PPAGE_NMBR]   user_ppn[0:255];
   reg [0:1] 	       exec_prot[0:255]; // protection
   reg [0:1] 	       user_prot[0:255];

   reg		       cache_miss;  // need to invoke the state machine

   localparam			// protection code values
     no_access = 2'o0,		// read is allowed for 1, 2, or 3
     write_access = 2'o3;


   //
   // The PAG I/O device
   //

   // Internal I/O Control Line Mux
   reg pag_io_read_ack, pag_io_write_ack;
   reg [`WORD] pag_io_read_data;
   reg pmem_io_read_ack = 0, pmem_io_write_ack = 0; // these need to move to the module interface !!!
   reg [`WORD] pmem_io_read_data; // needs to move to the module interface !!!
   always @(*) 
     if (pag_io_read_ack || pag_io_write_ack) begin
	apr_io_read_ack = pag_io_read_ack;
	apr_io_write_ack = pag_io_write_ack;
	apr_io_read_data = pag_io_read_data;
	apr_nxd = 0;
     end else begin
	apr_io_read_ack = pmem_io_read_ack;
	apr_io_write_ack = pmem_io_write_ack;
	apr_io_read_data = pmem_io_read_data;
	apr_nxd = pmem_nxd;
     end	
   
   // I/O Read
   always @(posedge clk)
     if (io_read) begin
	pag_io_read_ack = 1;
	case ({apr_io_dev, apr_io_cond})
	  IO_COND(PAG+0): pag_io_read_data <= { 28'b0, pag_hm, pag_enable, pag_re, 5'b0 };
	  IO_DATA(PAG+0): pag_io_read_data <= pag_last_error;
	  IO_DATA(PAG+1): pag_io_read_data <= `ZERO;
	  IO_DATA(PAG+2): pag_io_read_data <= { ac_block_enable, 13'b0, ac_block_base, 4'b0 };
	  IO_DATA(PAG+3): pag_io_read_data <= { `HALFZERO, quantum_timer };
	  IO_DATA(PAG+4): pag_io_read_data <= { 14'b0, pt_elb, 6'b0 };
	  IO_DATA(PAG+5): pag_io_read_data <= { 14'b0, pt_ehb, 6'b0 };
	  IO_DATA(PAG+6): pag_io_read_data <= { 14'b0, pt_ulb, 6'b0 };
	  IO_DATA(PAG+7): pag_io_read_data <= { 14'b0, pt_uhb, 6'b0 };
	  default: pag_io_read_ack = 0;
	endcase // case ({apr_io_dev, apr_io_cond})
     end

   // I/O Write
   wire [`ADDR]       invalidate_address = RIGHT(apr_io_write_data);
   always @(posedge clk) begin
      pag_io_write_ack = 0;

      // bulk invalidating the cache is handled here too
      if (invalidate_exec) begin
	 exec_prot[invalidate_exec_count] <= no_access;
	 invalidate_exec_count <= invalidate_exec_count_next;
	 if (invalidate_exec_count_next == 0)
	   invalidate_exec <= 0;
      end
      if (invalidate_user) begin
	 user_prot[invalidate_user_count] <= no_access;
	 invalidate_user_count <= invalidate_user_count_next;
	 if (invalidate_user_count_next == 0)
	   invalidate_user <= 0;
      end

      // write the PTE into the cache
      if (load_pte)
	if (saved_mem_user && !invalidate_user) begin
	   user_ppn[saved_mem_addr[`VPAGE_NMBR]] <= PT_PPN(saved_mem_addr, pmem_read_data);
	   user_prot[saved_mem_addr[`VPAGE_NMBR]] <= PT_PROT(saved_mem_addr, pmem_read_data);
	end else if (!invalidate_exec) begin
	   exec_ppn[saved_mem_addr[`VPAGE_NMBR]] <= PT_PPN(saved_mem_addr, pmem_read_data);
	   exec_prot[saved_mem_addr[`VPAGE_NMBR]] <= PT_PROT(saved_mem_addr, pmem_read_data);
	end


      // if we get a page fail, save the error information
      if (page_fail)
	pag_last_error <= { saved_mem_write, saved_mem_user, PT_PROT(saved_mem_addr, pmem_read_data),
			    14'b0, saved_mem_addr};


      if (reset) begin
	 pag_enable <= 0;
	 pag_hm <= 1;
	 pag_re <= 1;
	 pag_last_error <= 0;
	 ac_block_enable <= 0;
	 ac_block_base <= 0;
	 quantum_timer <= 0;
	 pt_elb <= 0;
	 pt_ehb <= 0;
	 pt_ulb <= 0;
	 pt_uhb <= 0;
	 invalidate_exec <= 1;
	 invalidate_user <= 1;
	 invalidate_exec_count <= 0;
	 invalidate_user_count <= 0;
      end else if (io_write)
	pag_io_write_ack = 1;
      
	case ({apr_io_dev, apr_io_cond})
	  IO_COND(PAG+0): { pag_hm, pag_enable, pag_re } <= apr_io_write_data[28:30];
	  IO_DATA(PAG+0): pag_last_error <= apr_io_write_data;
	  IO_DATA(PAG+1):
	    if (apr_io_write_data[INVALIDATE_SINGLE]) begin
	       if (apr_io_write_data[INVALIDATE_EXEC])
		 exec_prot[invalidate_address[`VPAGE_NMBR]] <= no_access;
	       if (apr_io_write_data[INVALIDATE_USER])
		 user_prot[invalidate_address[`VPAGE_NMBR]] <= no_access;
	    end else begin
	       if (apr_io_write_data[INVALIDATE_EXEC]) invalidate_exec <= 1;
	       if (apr_io_write_data[INVALIDATE_USER]) invalidate_user <= 1;

	    end
	  IO_DATA(PAG+2): { ac_block_enable, ac_block_base } <= { apr_io_write_data[0], apr_io_write_data[14:31] };
	  IO_DATA(PAG+3): quantum_timer <= RIGHT(apr_io_write_data);
	  IO_DATA(PAG+4): { pt_elb, invalidate_exec } <= { apr_io_write_data[14:29], 1'b1};
	  IO_DATA(PAG+5): { pt_ehb, invalidate_exec } <= { apr_io_write_data[14:29], 1'b1 };
	  IO_DATA(PAG+6): { pt_ulb, invalidate_user } <= { apr_io_write_data[14:29], 1'b1 };
	  IO_DATA(PAG+7): { pt_uhb, invalidate_user } <= { apr_io_write_data[14:29], 1'b1 };
	  default: pag_io_write_ack = 0;
	endcase // case ({apr_io_dev, apr_io_cond})
   end
   

   //
   // The Page Table and Address Translation
   //


// pieces of the in-memory page table (same in left and right half of a word)
`define PT_P 0:1		// protection code
`define PT_A 4			// age
`define PT_PPN 6:17		// physical page number

   // Map the Virtual Address to Physical.  The Virtual Addres can come directly from the
   // APR or it may have been saved by PAG because we took a cache miss.
   wire [`ADDR]        vaddr = mem_addr;
   wire 	       vuser = mem_user;
   wire [`PPAGE_NMBR]  entry_ppn = mem_user ? user_ppn[mem_addr[`VPAGE_NMBR]] : 
		                              exec_ppn[mem_addr[`VPAGE_NMBR]];
   reg [`PADDR]        mapped_addr;
   always @(*) begin
      if (!pag_enable)
	// Unrelocated.  The High Moby hack requires compiling in how large memory is.
	// That doesn't seem like a good idea.  It also messes up running the diagnostics
	// under the simulator. !!!
`ifdef SIM
	mapped_addr = { 4'o0, vaddr };
`else
	mapped_addr = { pag_hm ? 4'o17 : 4'o0, vaddr };
`endif
      else
	if (ac_block_enable && isAC(vaddr))
	  // redirect AC locations to the AC block.
	  // should write a diagnostic for this !!!
	  mapped_addr = { ac_block_base, mem_addr[32:35] };
	else
	  mapped_addr = { entry_ppn, mem_addr[`VPAGE_INDX] };
   end

   // generate the cache_miss signal off the incoming mem_addr
   wire [0:1] cache_prot = mem_user ? user_prot[mem_addr[`VPAGE_NMBR]] : exec_prot[mem_addr[`VPAGE_NMBR]];
   always @(*) begin
      // if we're using the AC block, we're ignoring the page-table cache
      if (!pag_enable || (ac_block_enable && isAC(mem_addr))) begin
	 cache_miss = 0;
      end else begin
	 // we miss in the cache if we're in the middle of invalidating the cache, the
	 // entry is not valid, or if there's a protection error
	 cache_miss = (mem_read || mem_write) &&
		      ((mem_user && invalidate_user) ||
		       (!mem_user && invalidate_exec) ||
		       (mem_read && (cache_prot == no_access)) ||
		       (mem_write && (cache_prot != write_access)));
      end
   end // always @ begin


   //
   // State Machine
   //


   localparam
     IDLE = 0,
     PTE_READ_WAIT = 1,
     PTE_READ = 2,
     PTE_WRITE_WAIT = 3,
     FINISH = 4,
     FINISH_WAIT = 5;
   
   integer   state_index, next_state_index;
   reg [0:5] state, next_state;

   task set_state;
      input integer s;
      begin
`ifdef SIM
	 next_state_index = s;
`endif
	 next_state[s] = 1'b1;
      end
   endtask
   
   // the state-machine sequencer
   always @(posedge clk) begin
      if (reset) begin
	 state <= 0;
	 state[IDLE] <= 1;
      end else begin
`ifdef SIM
	 state_index <= next_state_index;
`endif
	 state <= next_state;
      end
   end

   function [0:11] PT_PPN;
      input [`ADDR]   right;
      input [`WORD]   pte;
      if (right[`VPAGE_RIGHT])
	PT_PPN = pte[24:35];
      else
	PT_PPN = pte[6:17];
   endfunction
   function [0:1] PT_PROT;
      input [`ADDR]   right;
      input [`WORD]   pte;
      if (right[`VPAGE_RIGHT])
	PT_PROT = pte[18:19];
      else
	PT_PROT = pte[0:1];
   endfunction
   function PT_AGE;
      input [`ADDR]   right;
      input [`WORD]   pte;
      if (right[`VPAGE_RIGHT])
	PT_AGE = pte[22];
      else
	PT_AGE = pte[4];
   endfunction // if
   function [`WORD] PT_CLEAR_AGE;
      input [`ADDR]   right;
      input [`WORD]   pte;
      if (right[`VPAGE_RIGHT])
	PT_CLEAR_AGE = pte & ~ `WORDSIZE'o000000020000;
      else
	PT_CLEAR_AGE = pte & ~ `WORDSIZE'o020000000000;
   endfunction

   // If I move this inside the always block, I get circular logic !!!
   assign mem_read_data = pmem_read_data;

   // Send the signals through except when there's a cache miss or the state machine is in control
   wire 	      pag = cache_miss || !state[IDLE];
   reg [`PADDR]       pag_addr;
   reg [`WORD] 	      pag_write_data;
   reg 		      pag_read, pag_write, pag_read_ack, pag_write_ack;
   
   assign pmem_addr = pag ? pag_addr : mapped_addr;
   assign pmem_read = pag ? pag_read : mem_read;
   assign pmem_write = pag ? pag_write : mem_write;
   assign read_ack = pag ? pag_read_ack : pmem_read_ack;
   assign write_ack = pag ? pag_write_ack : pmem_write_ack;
   assign pmem_write_data = pag ? pag_write_data : mem_write_data;


   // if we have a cache miss, need to save all the information about the memory operation
   reg 	       save_mem_op;
   reg 	       saved_mem_user, saved_mem_write, saved_mem_read;
   reg [`ADDR] saved_mem_addr;
   reg [`WORD] saved_mem_write_data;
   reg [`PADDR] saved_pte_addr;
   always @(posedge clk)
     if (save_mem_op) begin
	saved_mem_addr = mem_addr;
	saved_mem_user = mem_user;
	saved_mem_read = mem_read;
	saved_mem_write = mem_write;
	saved_mem_write_data = mem_write_data;
	saved_pte_addr = pmem_addr;
     end

   // grab a copy of the PPN from the PTE when we read one
   reg 		save_pte;
   reg [`WORD] 	saved_pte;
   always @(posedge clk) if (save_pte) saved_pte <= pmem_read_data;

	
   // the state-machine logic
   always @(*) begin
      next_state = 0;

      pag_read = 0;
      pag_write = 0;
      pag_read_ack = 0;
      pag_write_ack = 0;
      pag_addr = 'x;
      pag_write_data = 'x;

      page_fail = 0;
      save_mem_op = 0;
      load_pte = 0;
      save_pte = 0;
      
      case (1'b1)
	state[IDLE]:
	  if (cache_miss) begin
	     // On a cache miss, start reading the Page Table Entry
	     if (mem_user)
	       pag_addr = { mem_addr[`VPAGE_HIGH] ? pt_uhb : pt_ulb, mem_addr[`VPAGE_PTINDEX] };
	     else
	       pag_addr = { mem_addr[`VPAGE_HIGH] ? pt_ehb : pt_elb, mem_addr[`VPAGE_PTINDEX] };
	     pag_read = 1;

	     save_mem_op = 1;	// save all the information
	     if (pmem_read_ack) set_state(PTE_READ);
	     else set_state(PTE_READ_WAIT);
	  end else begin
	     // When the answer is in the cache, just pass the control lines through and stay out of the way.
`ifdef NOTDEF
	     pmem_addr = mapped_addr;
	     pmem_write = mem_write;
	     pmem_read = mem_read;
	     write_ack = pmem_write_ack;
	     read_ack = pmem_read_ack;
	     pmem_write_data = mem_write_data;
`endif
	     set_state(IDLE);
	  end // else: !if(cache_miss)
	state[PTE_READ_WAIT]:
	  if (pmem_read_ack) set_state(PTE_READ);
	  else set_state(PTE_READ_WAIT);
	
	state[PTE_READ]: 
	  begin
	     // if we're not in the middle of invalidating the cache, write the PTE to the cache
	     if ((saved_mem_user && !invalidate_user) ||
		 (!saved_mem_user && !invalidate_exec))
	       load_pte = 1;

	     // save the PPN from the PTE for use later
	     save_pte = 1;
	     
	     // if the PTE we read has Age set, clear it and write it back to memory
	     if (PT_AGE(saved_mem_addr, pmem_read_data)) begin
		pag_addr = saved_pte_addr;
		pag_write_data = PT_CLEAR_AGE(saved_mem_addr, pmem_read_data);
		pag_write = 1;
		if (pmem_write_ack) set_state(FINISH);
		else set_state(PTE_WRITE_WAIT);
	     end else
	       set_state(FINISH);
	  end
	
	state[PTE_WRITE_WAIT]:
	  if (pmem_write_ack) set_state(FINISH);
	  else set_state(PTE_WRITE_WAIT);

	state[FINISH]:
	  // check protections and either issue a page fail or continue with the read or write
	  if ((PT_PROT(saved_mem_addr, saved_pte) == no_access) ||
	      ((PT_PROT(saved_mem_addr, saved_pte) != write_access) && saved_mem_write)) begin
`ifndef LINT
	     page_fail = 1;
`endif
	     // send the acks in case the PI isn't executed so that the read or write
	     // operation completes even if it didn't really succeed.
	     if (saved_mem_read) pag_read_ack = 1;
	     else if (saved_mem_write) pag_write_ack = 1;
	     set_state(IDLE);
	  end else begin
	     // now need to re-start the original memory operation
	     if (ac_block_enable && isAC(vaddr))
	       // redirect AC locations to the AC block.
	       // should write a diagnostic for this !!!
	       pag_addr = { ac_block_base, saved_mem_addr[32:35] };
	     else
	       pag_addr = { PT_PPN(saved_mem_addr, saved_pte), saved_mem_addr[`VPAGE_INDX] };
	     if (saved_mem_read) begin
//`ifndef LINT
		pag_read = 1;
//`endif
		if (pmem_read_ack) begin
		   pag_read_ack = 1;
		   set_state(IDLE);
		end else
		  set_state(FINISH_WAIT);
	     end else if (saved_mem_write) begin
		pag_write_data = saved_mem_write_data;
//`ifndef LINT
		pag_write = 1;
//`endif
		if (pmem_write_ack) begin
		   pag_write_ack = 1;
		   set_state(IDLE);
		end else
		  set_state(FINISH_WAIT);
	     end
	  end

	state[FINISH_WAIT]:
	  if (saved_mem_read && pmem_read_ack) begin
	     pag_read_ack = 1;
	     set_state(IDLE);
	  end else if (saved_mem_write && pmem_write_ack) begin
	     pag_write_ack = 1;
	     set_state(IDLE);
	  end else
	    set_state(FINISH_WAIT);
      endcase
   end
   

endmodule // pag


