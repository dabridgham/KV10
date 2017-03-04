// 	-*- mode: Verilog; fill-column: 90 -*-
//
// KV10 definitions
//
// 2013-02-01 dab	initial version

`define WORDSIZE 36
`define HALFSIZE 18
`define ADDRSIZE 18
`define DWORDSIZE 72
`define DEVSIZE 7
`define CSIZE 9			// size of the counter for shifts and rotates
`define WORDSIZESHORT 35	// needed for a place where `WORDSIZE-1 doesn't work
`define XFILL 14'b0   // this fills out the address when read the INDEX register as memory

`define PADDRSIZE 22	   // this can't easily change due to the design of the page table
`define PPAGE_NMBR 14:25   // the page number in a physical address
`define PPAGE_INDX 26:35   // the index within a page
`define VPAGE_NMBR 18:25   // the page number in a virtual address
`define VPAGE_INDX 26:35   // the index within a page
`define VPAGE_HIGH 18	   // selects high or low page table
`define VPAGE_PTINDEX 19:24	// index into page table
`define VPAGE_RIGHT 25		// left or right half of the word in the page table

`define WORD 0:`WORDSIZE-1
`define HWORD 0:`HALFSIZE-1
`define ADDR 18:`WORDSIZE-1
`define PADDR 14:`WORDSIZE-1
`define DWORD 0:`DWORDSIZE-1
`define DEVICE 0:`DEVSIZE-1

`define ZERO `WORDSIZE'o0
`define ZERO_SHORT `WORDSIZESHORT'o0
`define ONE `WORDSIZE'o1
`define MINUSONE `WORDSIZE'o777777_777777
`define MAXNEG `WORDSIZE'o400000_000000
`define HALFZERO `HALFSIZE'o0
`define HALFONE `HALFSIZE'o1
`define HALFMINUSONE `HALFSIZE'o777777

// Separate user/exec definitions for where I use this on the left-hand side of an assignment
`define FLAGS overflow, carry0, carry1, floating_overflow, first_part_done, user_mode, 5'b0, floating_underflow, no_divide, 5'b0
`define USER_FLAGS overflow, carry0, carry1, floating_overflow, first_part_done, ignore, ignore5, floating_underflow, no_divide
`define EXEC_FLAGS overflow, carry0, carry1, floating_overflow, first_part_done, user_mode, ignore5, floating_underflow, no_divide
 
//
// These are compile-time controls for various features of the core processor
//

//`define CIRC 1			// implement the CIRC instruction
//`define UAC 1			// unassigned code use locations 60/61, otherwise 40/41
`define CACHE_STATS 1		// includes stats counters in the cache, also an I/O device to read them
//`define OLD_PI 1

// UUOs vector through 40/41 while Unassigned Codes can use either 60/61 (as the KA10) or 40/41 (as the KX10)
`define UUO_VEC `ADDRSIZE'o40
`ifdef UAC
 `define UAC_VEC `ADDRSIZE'o60
`else
 `define UAC_VEC `ADDRSIZE'o40
`endif
