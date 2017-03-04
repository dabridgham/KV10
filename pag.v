//	-*- mode: Verilog; fill-column: 90 -*-
//
// Pager for the kv10 processor
//
// This design follows the description of PAG from Dave Conroy's PDP-10/X which follows
// the pager built by MIT to support ITS.
//
// 2015-01-18 dab	initial version


`include "constants.vh"

module pag
  (
   // signals from/to the processor
   input 	       clk,
   input 	       reset, 
   input [`ADDR]       mem_addr,
   output reg [`WORD]  mem_read_data,
   input [`WORD]       mem_write_data,
   input 	       mem_user, // selects user or exec memory
   input 	       mem_write, // only one of mem_write, mem_read, io_write, or io_read
   input 	       mem_read,
   input 	       io_write,
   input 	       io_read,
   output reg 	       write_ack,
   output reg 	       read_ack,
   output reg 	       nxm, // non-existent memory
   output reg 	       page_fail,
   output reg [1:7]    pi_out, // PI requests to the APR

   // signals to/from the next stage in the chain (cache or memory)
   output reg [`PADDR] pmem_addr,
   input [`WORD]       pmem_read_data,
   output reg [`WORD]  pmem_write_data,
   output reg 	       pmem_write,
   output reg 	       pmem_read,
   output reg 	       pmem_io_write,
   output reg 	       pmem_io_read,
   input 	       pmem_write_ack,
   input 	       pmem_read_ack,
   input 	       pmem_nxm,
   input [1:7] 	       pi_in	// PI requests from the next stage
   );

`include "functions.vh"
`include "io.vh"

   // the page table cache: exec/user
   reg [`PPAGE_NMBR]   exec_ppn[0:255]; // physical page number
   reg [`PPAGE_NMBR]   user_ppn[0:255];
   reg [0:1] 	      exec_prot[0:255];	// protection
   reg [0:1] 	      user_prot[0:255];
   reg 		      exec_age[0:255]; // age bit
   reg 		      user_age[0:255];
   reg 		      exec_valid[0:255]; // entry is valid
   reg 		      user_valid[0:255];

   reg 		      pag_enable;
   reg 		      pag_hm = 0, // highest moby (not implemented)
		      pag_re = 0; // ROM enable (not implemented)
   reg [`WORD] 	      pag_last_error;
   reg 		      ac_block_enable;
   reg [0:17] 	      ac_block_base; // for AC block relocation (calulate size from PMEMSIZE!!!)
   reg [`HWORD]       quantum_timer; // need to hook this up to a clock !!!

   reg [0:15] 	      pt_elb,	// exec mode low segment base register
		      pt_ehb,	// exec mode high segment base register
 		      pt_ulb,	// user mode low segment base register
		      pt_uhb;	// user mode high segment base register

   reg 		      invalidate_exec, invalidate_user;
   reg [0:7] 	      invalidate_counter;
   reg 		      cache_valid, cache_miss;
   reg [0:1] 	      cache_prot;
   reg 		      read_nxm, write_nxm; // !!! lose these
   reg 		      saved_mem_user, saved_mem_write, saved_mem_read;
   reg [`ADDR] 	      saved_mem_addr;
   reg [`WORD] 	      saved_mem_write_data;
   reg [`PADDR]       saved_pte_addr;
   reg [`WORD] 	      saved_pte;
   
// pieces of the in-memory page table (same in left and right half of a word)
`define PT_P 0:1		// protection code
`define PT_A 4			// age
`define PT_PPN 6:17		// physical page number

   localparam			// protection code values
     no_access = 2'o0,		// read is allowed for 1, 2, or 3
     write_access = 2'o3;
   
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
   
   // state machine
   reg [0:3] 	      state, next_state;
   localparam
     idle = 0,
     read_pte = 1,
     write_pte = 2,
     finish_write_pte = 3;
   
   // generate the cache_miss signal off the incoming mem_addr
   always @(*) begin
      // if we're using the AC block, we're ignoring the page-table cache
      if (ac_block_enable && ((mem_addr & 'o777770) == 0)) begin
	 cache_valid = 1;	// valid and prot are set just so they don't latch
	 cache_prot = write_access;
	 cache_miss = 0;
      end else begin
	 if (mem_user) begin
	    cache_valid = user_valid[mem_addr[`VPAGE_NMBR]];
	    cache_prot = user_prot[mem_addr[`VPAGE_NMBR]];
	 end else begin
	    cache_valid = exec_valid[mem_addr[`VPAGE_NMBR]];
	    cache_prot = exec_prot[mem_addr[`VPAGE_NMBR]];
	 end
	 // we miss in the cache if we're in the middle of invalidating the cache, the
	 // entry is not valid, or if there's a protection error
	 cache_miss = (mem_read || mem_write) &&
		      ((mem_user && invalidate_user)
		       || (!mem_user && invalidate_exec)
		       || (!cache_valid)
		       || (mem_read && (cache_prot == no_access))
		       || (mem_write && (cache_prot != write_access)));
      end
   end // always @ begin

   // generate the physical address to send to memory
   reg [`PADDR] mapped_addr;
   always @(*) begin
      if (!pag_enable)
	// unrelocated (low moby)
	mapped_addr = { 4'o0, mem_addr };
      else
	if (ac_block_enable && ((mem_addr & `ADDRSIZE'o777770) == 0))
	  // redirect AC locations to the AC block.
	  // should write a diagnostic for this !!!
	  mapped_addr = { ac_block_base, mem_addr[32:35] };
	else
	  mapped_addr = { mem_user ? user_ppn[mem_addr[`VPAGE_NMBR]] : exec_ppn[mem_addr[`VPAGE_NMBR]],
			  mem_addr[`VPAGE_INDX] };
   end

   // mux for mem_read_data.  It either comes from physical memory (most of the time) or
   // from local I/O registers
   reg [`WORD] io_read_data;
   reg 	       select_read_io, pag_read_ack;
   always @(*) begin
      if (select_read_io) begin
	 mem_read_data = io_read_data;
	 read_ack = 1;
      end else begin
	 mem_read_data = pmem_read_data;
	 read_ack = pag_read_ack;
      end
   end

   // look up the physical page number and generate the cache_miss signal.  Also handle
   // reads of I/O ports.
   always @(*) begin
      next_state = 0;

//      $display("0 (%b): %b %b %b %b", state, pmem_write_ack, pmem_read_ack, mem_write, mem_read);

      write_ack = pmem_write_ack;
      pag_read_ack = pmem_read_ack;
//      mem_read_data = pmem_read_data;
      pmem_write_data = mem_write_data;
      pmem_addr = mapped_addr;
      page_fail = 0;
      nxm = 0;
      
      pmem_write = 0;
      pmem_read = 0;
      pmem_io_write = 0;
      pmem_io_read = 0;

      pi_out = pi_in;		// if PAG can generate PI, we'll need to plug in here

      // now we run the state machine
      if (reset) begin
	 next_state[idle] = 1;
      end else
	case (1'b1)		// synopsys full_case parallel_case
	  state[idle]:
	    if (!pag_enable) begin
	       // pass the signals on through
	       pmem_write = mem_write;
	       pmem_read = mem_read;
	       pmem_io_write = io_write;
	       pmem_io_read = io_read;
	       nxm = pmem_nxm;
	       next_state[idle] = 1;
	       
	    end else if (mem_read || mem_write) begin
	       // if we have a cache miss, read the page-table entry otherwise continue
	       // with the mapped memory operation
	       if (cache_miss) begin
		  if (mem_user)
		    pmem_addr = { mem_addr[`VPAGE_HIGH] ? pt_uhb : pt_ulb, mem_addr[`VPAGE_PTINDEX] };
		  else
		    pmem_addr = { mem_addr[`VPAGE_HIGH] ? pt_ehb : pt_elb, mem_addr[`VPAGE_PTINDEX] };
//		  $display("   miss %8o: ", pmem_addr);
		  pmem_write = 0;
		  pmem_read = 1;
		  pmem_io_write = 0;
		  pmem_io_read = 0;
		  next_state[read_pte] = 1;
	       end else begin
//		  $display("   hit %8o:", pmem_addr);
		  pmem_write = mem_write;
		  pmem_read = mem_read;
		  nxm = pmem_nxm;
		  next_state[idle] = 1;
	       end
	    end else begin // if (mem_read || mem_write)
//      $display("1: %b %b %b %b", pmem_write_ack, pmem_read_ack, mem_write, mem_read);
	       next_state[idle] = 1;
	    end // else: !if(mem_read || mem_write)
	  
	  state[read_pte]:
	    // wait for the PTE read to finish
	    if (!pmem_read_ack)
	      next_state[read_pte] = 1; // wait for ack
	    else
	      // check the protection bits on the PTE and either page fail or set up to
	      // read or write memory with the mapped address and wait for the ack
	      if ((saved_mem_read && (PT_PROT(saved_mem_addr, pmem_read_data) == no_access)) ||
		  (saved_mem_write && (PT_PROT(saved_mem_addr, pmem_read_data) != write_access))) begin
		 // page fail
//		 $display("  PAGE FAIL");
		 
		 if (saved_mem_read)
		   pag_read_ack = 1;
		 else if (saved_mem_write)
		   write_ack = 1;
		 page_fail = 1;
		 next_state[idle] = 1;
	      end else begin
		 // now continue the write or read of memory
		 pmem_addr = { PT_PPN(saved_mem_addr, pmem_read_data), saved_mem_addr[`VPAGE_INDX] };
		 pmem_write_data = saved_mem_write_data;
		 pmem_write = saved_mem_write;
		 pmem_read = saved_mem_read;
		 write_ack = 0;
		 pag_read_ack = 0;
		 
		 // if the age bit is set, we need to clear it and write the PTE back to memory
		 if (PT_AGE(saved_mem_addr, pmem_read_data))
		   next_state[write_pte] = 1;
		 else
		   next_state[idle] = 1;
	      end

	  state[write_pte]:
	    // let the previous read or write finish
	    if ((saved_mem_write && !pmem_write_ack) ||
		(saved_mem_read && !pmem_read_ack))
	      next_state[write_pte] = 1;
	    else begin
	       // clear the age bit and write the PTE back to memory
	       pmem_addr = saved_pte_addr;
	       pmem_write_data = PT_CLEAR_AGE(saved_mem_addr, saved_pte);
	       pmem_write = 1;
	       pmem_read = 0;
	       next_state[finish_write_pte] = 1;
	    end

	  state[finish_write_pte]:
	    if (!pmem_write_ack)
	      next_state[finish_write_pte] = 1;
	    else begin
	       write_ack = 0;	// don't want pmem_write_ack to pass through
	       next_state[idle] = 1;
	    end
	  
	endcase // case (1'b1)
   end // always @ (*)
   

   // state machine for the pager.  handles writes to I/O ports.
   always @(posedge clk) begin
      // default the control signals
      write_nxm <= 0;

      state <= next_state;	// advance the state on each clock tick
      
      // invalidating happens in parallel with the rest of the state machine though it
      // does interfere with normal operation somewhat since you can't use the cache
      // during invalidation
      if (invalidate_exec | invalidate_user) begin
	 // could be invalidating either user or exec or both at once
	 if (invalidate_exec) exec_valid[invalidate_counter] <= 0;
	 if (invalidate_user) user_valid[invalidate_counter] <= 0;

	 if (invalidate_counter == 8'd255) begin
	    invalidate_counter <= 8'd0;
	    invalidate_exec <= 0;
	    invalidate_user <= 0;
	 end else begin
	    invalidate_counter <= invalidate_counter + 8'd1;
	    invalidate_exec <= invalidate_exec;
	    invalidate_user <= invalidate_user;
	 end
      end else // if (invalidate_exec | invalidate_user)
	invalidate_counter <= 8'd0;

      if (reset) begin
	 pag_enable <= 0;
	 invalidate_exec <= 1;
	 invalidate_user <= 1;
	 invalidate_counter <= 8'd0;

	 ac_block_enable <= 0;
	 ac_block_base <= 18'b0;
	 quantum_timer <= `HALFSIZE'b0;
	     
	 pt_elb <= 16'b0;
	 pt_ehb <= 16'b0;
	 pt_ulb <= 16'b0;
	 pt_uhb <= 16'b0;
      end else
	case (1'b1)		// synopsys full_case parallel_case
`ifdef SIM
	  default:
	    begin
	       // there is really no recovery from this !!! so I don't know if there's
	       // much point to catching it.
	       $display("!!! Unknown PAG state %b", state);
	       state <= 0;
	       state[idle] <= 1;
	    end
`endif

	  state[idle]:
	    begin
	       // if there's a cache miss, the async code will read the page table entry.
	       // save that here so we'll have it later
	       if (cache_miss) begin
		  saved_mem_user <= mem_user;
		  saved_mem_write <= mem_write;
		  saved_mem_read <= mem_read;
		  saved_mem_addr <= mem_addr;
		  saved_mem_write_data <= mem_write_data;
	       end

	       // handle I/O reads
	       select_read_io <= 0;
	       if (io_read) begin
		  select_read_io <= 1;
		  if (IO_CON(mem_addr))	// CONI
		    case (IO_DEV(mem_addr))
		      PAG+0: io_read_data = { 28'b0, pag_hm, pag_enable, pag_re, 5'b0 };
		      default: read_nxm = 1;
		    endcase
		  else			// DATAI
		    case (IO_DEV(mem_addr))
		      PAG+0: io_read_data = pag_last_error;
		      PAG+2: io_read_data = { ac_block_enable, 13'b0, ac_block_base, 4'b0 };
		      PAG+3: io_read_data = { `HALFZERO, quantum_timer };
		      PAG+4: io_read_data = { 14'b0, pt_elb, 5'b0 };
		      PAG+5: io_read_data = { 14'b0, pt_ehb, 5'b0 };
		      PAG+6: io_read_data = { 14'b0, pt_ulb, 5'b0 };
		      PAG+7: io_read_data = { 14'b0, pt_uhb, 5'b0 };
		      default: read_nxm = 1;
		    endcase

	       // and I/O writes
	       end else if (io_write) begin
		  if (IO_CON(mem_addr))	// CONO
		    case (IO_DEV(mem_addr))
		      PAG+0:
			begin
`ifdef SIM
			   $display("   !! Paging Enable <= %o", mem_write_data[29]);
`endif		 
			   pag_enable <= mem_write_data[29];
			end
		      default: write_nxm <= 1;
		    endcase
		  else			// DATAO
		    case (IO_DEV(mem_addr))
		      PAG+0:
			pag_last_error <= mem_write_data;
		      PAG+1: 
			begin
			   if (mem_write_data[2]) begin // IS - invalidate single entry
			      if (mem_write_data[0])    // EIE - invalidate exec space
				exec_valid[mem_write_data[18:25]] <= 0;
			      if (mem_write_data[1])    // UIE - invalidate user space
				user_valid[mem_write_data[18:25]] <= 0;
			   end else begin		   // !IS - invalidate entire cache
			      if (mem_write_data[0])    // EIE - invalidate exec space
				invalidate_exec <= 1;
			      if (mem_write_data[1])    // UIE - invalidate user space
				invalidate_user <= 1;
			   end // else: !if(mem_write_data[2])
			end
		      PAG+2:
			{ ac_block_enable, ac_block_base }
			  <= { mem_write_data[0],	     // AE
			       mem_write_data[14:31]}; // AB
		      PAG+3:
			quantum_timer <= RIGHT(mem_write_data);
		      PAG+4:
			begin 
			   pt_elb <= mem_write_data[14:29];
			   invalidate_exec <= 1;
			end
		      PAG+5:
			begin
			   pt_ehb <= mem_write_data[14:29];
			   invalidate_exec <= 1;
			end
		      PAG+6:
			begin
			   pt_ulb <= mem_write_data[14:29];
			   invalidate_user <= 1;
			end
		      PAG+7:
			begin
			   pt_uhb <= mem_write_data[14:29];
			   invalidate_user <= 1;
			end
		      default: write_nxm <= 1;
		    endcase
	       end
	    end // case: state[idle]
	  
	  state[read_pte]:
	    begin
	       // we've read the PTE from memory so write it to the cache.  only write the
	       // cache if we're not in the middle of invalidating it
	       if (saved_mem_user && !invalidate_user) begin
		  user_ppn[saved_mem_addr[`VPAGE_NMBR]] <= PT_PPN(saved_mem_addr, pmem_read_data);
		  user_prot[saved_mem_addr[`VPAGE_NMBR]] <= PT_PROT(saved_mem_addr, pmem_read_data);
		  user_valid[saved_mem_addr[`VPAGE_NMBR]] <= 1;
	       end else if (!invalidate_exec) begin
		  exec_ppn[saved_mem_addr[`VPAGE_NMBR]] <= PT_PPN(saved_mem_addr, pmem_read_data);
		  exec_prot[saved_mem_addr[`VPAGE_NMBR]] <= PT_PROT(saved_mem_addr, pmem_read_data);
		  exec_valid[saved_mem_addr[`VPAGE_NMBR]] <= 1;
	       end

	       // save these in case we write the PTE back to memory
	       saved_pte_addr <= pmem_addr;
	       saved_pte <= pmem_read_data;

	       // on page fail, remember why the failure occurred and set the status bits
	       if (page_fail)
		 pag_last_error <= { !saved_mem_read, saved_mem_user, PT_PROT(saved_mem_addr, pmem_read_data),
				     14'b0, saved_mem_addr };
	    end

	  state[finish_write_pte], state[write_pte]:
	    ;

	endcase // case (1'b1)
   end
   
endmodule // pag


