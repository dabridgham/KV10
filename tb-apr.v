//	-*- mode: Verilog; fill-column: 90 -*-
//
// testbench for the kv10 processor
//
// 2013-02-01 dab	initial version
// 2015-01-19 dab	added pag

`timescale 100 us / 100 us

`include "constants.vh"
`include "alu.vh"

module apr_tb();
   reg reset = 0;
   reg [`ADDR] start_address = `ADDRSIZE'o1000; // need to read this out of the file!

   // APR <-> PAG connections
   wire [`ADDR] apr_addr;
   wire [`WORD] apr_read_data;
   wire [`WORD] apr_write_data;
   wire 	apr_user;
   wire 	apr_write, apr_read;
   wire 	apr_io_write, apr_io_read;
   wire 	apr_write_ack, apr_read_ack;
   wire 	apr_nxm, apr_page_fail;
   wire [1:7] 	apr_pi;
   
   // Just floating for now.  Eventually will connect to CACHE.
   wire [1:7] 	pag_pi;

   // PAG <-> Cache connections
   wire [`PADDR] pag_addr;
   wire [`WORD] pag_read_data;
   wire [`WORD] pag_write_data;
   wire 	pag_write, pag_read;
   wire 	pag_io_write, pag_io_read;
   wire 	pag_write_ack, pag_read_ack;
   wire 	pag_nxm;

   // Cache <-> MEM connections
   wire [`PADDR] mem_addr;
   wire [`WORD] mem_read_data;
   wire [`WORD] mem_write_data;
   wire 	mem_write, mem_read;
   wire 	mem_io_write, mem_io_read;
   wire 	mem_write_ack, mem_read_ack;
   wire 	mem_nxm;

   // Cache <-> IOM connections
   wire [`DEVICE] io_dev;
   wire [`WORD]   io_read_data;
   wire [`WORD]   io_write_data;
   wire 	  io_write;
   wire 	  io_read;
   wire 	  io_nxm;
   wire [1:7] 	  io_pi_in;

   wire [`ADDR]     display_addr;
   wire 	    running;

   initial begin
      $dumpfile("tb-apr.lxt");
      $dumpvars(0,apr_tb);

      #0 reset = 1;
      #32 reset = 0;
      

      # 800000 $finish_and_return(2);
   end
   
   reg 		   clk = 0;
   always #5 clk = !clk;

   assign apr_pi = 0;		// once the Cache and IOM are written, this assignment goes away
   
   apr apr(clk, reset,
	   apr_addr, apr_read_data, apr_write_data, apr_user, apr_write, apr_read, apr_io_write, apr_io_read,
	   apr_write_ack, apr_read_ack, apr_nxm, apr_page_fail, apr_pi,
	   display_addr, running);

`ifdef SIM
   pag pag(clk, reset, 
	   apr_addr, apr_read_data, apr_write_data, apr_user, apr_write, apr_read, apr_io_write, apr_io_read,
	   apr_write_ack, apr_read_ack, apr_nxm, apr_page_fail, apr_pi,
	   pag_addr, pag_read_data, pag_write_data, pag_write, pag_read, pag_io_write, pag_io_read,
	   pag_write_ack, pag_read_ack, pag_nxm, pag_pi);
`else
   assign pag_addr = { 4'b0, apr_addr };
   assign apr_read_data = pag_read_data;
   assign pag_write_data = apr_write_data;
   assign pag_write = apr_write;
   assign pag_read = apr_read;
   assign pag_io_write = apr_io_write;
   assign pag_io_read = apr_io_read;
   assign apr_write_ack = pag_write_ack;
   assign apr_read_ack = pag_read_ack;
   assign apr_nxm = pag_nxm;
   assign apr_pi = pag_pi;
`endif

`ifdef NOTDEF
   cache cache(clk, reset,
	       pag_addr, pag_read_data, pag_write_data, pag_write, pag_read, pag_io_write, pag_io_read,
	       pag_write_ack, pag_read_ack, pag_nxm, pag_pi,
	       mem_addr, mem_read_data, mem_write_data, mem_write, mem_read,
	       mem_write_ack, mem_read_ack, mem_nxm,
	       io_dev, io_read_data, io_write_data, io_write, io_read, io_nxm, io_pi_in);
`else
   assign mem_addr = pag_addr;
   assign pag_read_data = mem_read_data;
   assign mem_write_data = pag_write_data;
   assign mem_write = pag_write;
   assign mem_read = pag_read;
   assign pag_write_ack = mem_write_ack;
   assign pag_read_ack = mem_read_ack;
   assign pag_nxm = mem_nxm;
   assign pag_pi = 0;
`endif

   mem mem(clk, reset,
	   mem_addr, mem_read_data, mem_write_data, mem_write, mem_read,
	   mem_write_ack, mem_read_ack, mem_nxm);

endmodule // apr_tb
