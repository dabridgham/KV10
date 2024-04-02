//	-*- mode: Verilog; fill-column: 90 -*-
//
// Cache for the KV10 - It's a simple two-way, associate, write-through cache.  The cache
// also handles reassembling 36-bit words out of whatever width the memory is.  As well,
// the cache is where the I/O signals are split out to go to IOM.
//
// 2015-01-25 dab	initial version

`include "constants.svh"

module cache
  (
   input 		clk,
   input 		reset, 

   // signals from PAG
   input [`PADDR] 	pag_addr,
   output reg [`WORD] 	pag_read_data,
   input [`WORD] 	pag_write_data,
   input 		pag_write, // only one of mem_write, mem_read, io_write, or io_read
   input 		pag_read,
   input 		pag_io_write,
   input 		pag_io_read,
   output reg 		pag_write_ack,
   output reg 		pag_read_ack,
   output reg 		pag_nxm,
   output reg [1:7] 	pag_pi_out,

   // signals out to MEM
   output reg [`PADDR] 	mem_addr,
   input [`WORD] 	mem_read_data,
   output reg [`WORD] 	mem_write_data,
   output reg 		mem_write, // only one of mem_write, mem_read, io_write, or io_read
   output reg 		mem_read,
   input 		mem_write_ack,
   input 		mem_read_ack,
   input 		mem_nxm,

   // signals out to IOM
   output reg [`DEVICE] io_dev,
   input [`WORD] 	io_read_data,
   output reg [`WORD] 	io_write_data,
   output reg 		io_write,
   output reg 		io_read,
   input 		io_nxm,
   input [1:7] 		io_pi_in
   );

`include "functions.svh"
`include "io.svh"
   
   parameter 
     cacheaddr = 9,		// log2 of number of lines in cache
     lineaddr = 2,		// log2 of linelength
     enable = 0;

   // computed parameters
   //
   //            kaddr1      caddr1
   //     paddr0     | caddr0    | laddr0   paddr1
   //        |       | |         | |        |
   //       +---------+-----------+----------+
   // paddr |  check  | cacheaddr | lineaddr |
   //       +---------+-----------+----------+
   //       14      24 25       33 34      35  (numbers from cacheaddr=9 and lineaddr=2)
   //
   localparam
     cachelines = 2**cacheaddr,	// cache size is cachelines*linelength*2 words
     linelength = 2**lineaddr,
     linebits = `WORDSIZE*linelength,
     paddr1 = `WORDSIZE-1,
     paddr0 = `WORDSIZE-`PADDRSIZE,
     caddr0 = `WORDSIZE-cacheaddr-lineaddr,
     caddr1 = paddr1-lineaddr,
     laddr0 = `WORDSIZE-lineaddr,
     kaddr1 = paddr1-cacheaddr-lineaddr;

   // these comprise the two-way, set associative cache memory itself
   reg [0:linebits-1] 	cache0[0:cachelines-1], // cache data
			cache1[0:cachelines-1];
   reg [paddr0:kaddr1] 	check0[0:cachelines-1], // check address bits
			check1[0:cachelines-1];
   reg 			valid0[0:cachelines-1], // the cache entry is valid
 			valid1[0:cachelines-1],
 			last[0:cachelines-1]; // which set was last used for each line
   
   reg [paddr0:kaddr1] 	check;
   reg [caddr0:caddr1] 	line;
   reg [laddr0:paddr1] 	index;

   // read or write words in a cache line
   function [`WORD] line_read;
      input [0:linebits-1] line;
      input [laddr0:paddr1] index;
      line_read = line[index*`WORDSIZE +:`WORDSIZE];
   endfunction

   // state machine
   reg [0:10] 		    state, next_state; // how many states do I need!!!
   reg [0:cacheaddr-1] 	    counter;	       // line count
   reg [0:lineaddr-1] 	    ictr;	       // index within a line
   reg [0:linebits-1] 	    line_tmp, line_tmp0, line_tmp1;

   localparam
     init = 0,
     flushing = 1,
     disabled = 2,
     idle = 3,
     read_line = 4;

`ifdef CACHE_STATS
   reg [`WORD] 		    read_hit, read_miss, write_hit, write_miss;
`endif

   always @(*) begin
      // defaults
      pag_read_ack = 0;
      pag_write_ack = 0;
      pag_nxm = 0;

      mem_addr = pag_addr;
      mem_write_data = pag_write_data;
      mem_read = 0;
      mem_write = 0;

      // pull these fields out of the incoming address
      check = pag_addr[paddr0:kaddr1];
      line = pag_addr[caddr0:caddr1];
      index = pag_addr[laddr0:paddr1];
	 
      line_tmp0 = cache0[line];
      line_tmp1 = cache1[line];

`ifdef NOTDEF			// still need to do I/O !!!
      io_dev = pag_io_dev;
`endif
      pag_pi_out = io_pi_in;

      next_state = 0;

      if (reset)
	next_state[init] = 1;
      else
	case (1'b1)		// synopsys full_case parallel_case
	  // can this be default!!!
	  state[init] | state[flushing] | state[disabled]:
	    begin
	       // just connect signals straight through to MEM
	       // does not assemble memory-width chunks into 36-bit sized chunks !!!
	       mem_addr = pag_addr;
	       pag_read_data = mem_read_data;
	       mem_write_data = pag_write_data;
	       mem_write = pag_write;
	       mem_read = pag_read;
	       pag_write_ack = mem_write_ack;
	       pag_read_ack = mem_read_ack;
	       pag_nxm = mem_nxm | io_nxm;

	       case (1'b1)	// synopsys full_case parallel_case
		 state[init]: next_state[flushing] = 1;
		 state[flushing]:
		   if (counter == 0)
		     if (enable)
		       next_state[idle] = 1;
		     else
		       next_state[disabled] = 1;
		   else
		     next_state[flushing] = 1;
		 state[disabled]: next_state[disabled] = 1;
	       endcase // case (1'b1)
	    end // case: state[init] | state[flushing] | state[disabled]

	  state[idle]:
	    begin
	       if (pag_read)
		 if (valid0[line] && (check0[line] == check)) begin
		    pag_read_data = line_read(cache0[line], index);
		    pag_read_ack = 1;
		    next_state[idle] = 1;
		 end else if (valid1[line] && (check1[line] == check)) begin
		    pag_read_data = line_read(cache1[line], index);
		    pag_read_ack = 1;
		    next_state[idle] = 1;
		 end else begin
		    pag_read_ack = 0;
		    next_state[read_line] = 1;
		 end
	       else if (pag_write)
		 if ((valid0[line] && (check0[line] == check)) ||
		     (valid1[line] && (check1[line] == check))) begin
		    mem_addr = pag_addr;
		    mem_write_data = pag_write_data;
		    mem_write = pag_write;
		    mem_read = 0;
		    pag_write_ack = mem_write_ack;
		    next_state[idle] = 1;
		 end else begin
		    pag_write_ack = 0;
		    // read the line into the cache which will throw back to idle which
		    // will then do the write
		    next_state[read_line] = 1;
		 end
	       else
		 next_state[idle] = 1;
	    end // case: state[idle]

	  state[read_line]:
	    begin
	       mem_addr = { check, line, ictr };
	       mem_read = 1;
	       if (mem_read_ack && (ictr == linelength-1))
		 next_state[idle] = 1;
	       else
		 next_state[read_line] = 1;
	    end

	endcase // case (1'b1)
   end // always @ (*)
   
   always @(posedge clk)
     begin
	state <= next_state;

	case (1'b1)		// synopsys full_case parallel_case
	  state[init]:
	    begin
	       counter <= -1;
`ifdef CACHE_STATS
 	       read_hit <= 0;
	       read_miss <= 0;
	       write_hit <= 0;
	       write_miss <= 0;	       
`endif
	    end

	  state[flushing]:
	    begin
	       valid0[counter] <= 0;
	       valid1[counter] <= 0;
	       counter <= counter - 1;
	    end

	  state[disabled]:
	    ;			// do nothing

	  state[idle]:
	    begin
	       ictr <= 0;

	       if (pag_read) begin
		  if (valid0[line] && (check0[line] == check)) begin
		     last[line] <= 0;
`ifdef CACHE_STATS
		     read_hit <= read_hit+1;
`endif
		  end else if (valid1[line] && (check1[line] == check)) begin
		     last[line] <= 1;
`ifdef CACHE_STATS
		     read_hit <= read_hit+1;
`endif
		  end
`ifdef CACHE_STATS
		  else
		    read_miss <= read_miss+1;
`endif

	       end else if (pag_write) begin
		  if (valid0[line] && (check0[line] == check)) begin
		     cache0[line][index*`WORDSIZE +: `WORDSIZE] <= pag_write_data;
		     last[line] <= 0;
`ifdef CACHE_STATS
		     write_hit <= write_hit+1;
`endif
		  end else if (valid1[line] && (check1[line] == check)) begin
		     cache1[line][index*`WORDSIZE +: `WORDSIZE] <= pag_write_data;
		     last[line] <= 1;
`ifdef CACHE_STATS
		     write_hit <= write_hit+1;
`endif
		  end
`ifdef CACHE_STATS
		  else begin
		     // decrement write_hit because once we read in the line the write
		     // will succeed and the miss will also get counted as a hit
		     write_hit <= write_hit-1;
		     write_miss <= write_miss+1;
		  end
`endif
	       end
	    end

	  state[read_line]:
	    if (mem_read_ack) begin
	       if (last[line] == 1)
		 cache0[line][ictr*`WORDSIZE +: `WORDSIZE] <= mem_read_data;
	       else
		 cache1[line][ictr*`WORDSIZE +: `WORDSIZE] <= mem_read_data;
	       ictr <= ictr + 1;
	       if (ictr == linelength-1) begin
		  if (last[line] == 1) begin
		     check0[line] <= check;
		     valid0[line] <= 1;
		     last[line] <= 0;
		  end else begin
		     check1[line] <= check;
		     valid1[line] <= 1;
		     last[line] <= 1;
		  end
	       end
	    end

	endcase // case (1'b1)
     end
   
endmodule // cache
