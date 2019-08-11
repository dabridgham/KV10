//	-*- mode: Verilog; fill-column: 90 -*-
//
// testbench for the kv10 processor

`timescale 1 ns / 1 ns

`include "constants.svh"
`include "alu.svh"

module apr_tb();

   // APR <-> PAG connections
   wire [`ADDR] apr_addr;
   wire [`WORD] apr_read_data;
   wire [`WORD] apr_write_data;
   wire 	apr_user;
   wire 	apr_read, apr_write;
   wire 	apr_io_write, apr_io_read;
   wire 	apr_read_ack, apr_write_ack;
   wire 	apr_page_fail;
   wire [`DEVICE] apr_io_dev;	// the I/O Device
   wire 	  apr_io_cond;	// I/O Device Conditions
   wire [`WORD]   apr_io_read_data;
   wire [`WORD]   apr_io_write_data;
   wire 	  apr_io_read_ack;
   wire 	  apr_io_write_ack;
   wire 	  apr_nxd;
   wire [1:7] 	  apr_pi;
   
   // PAG <-> Cache connections
   wire [`PADDR]  pag_addr;
   wire [`WORD]   pag_read_data;
   wire [`WORD]   pag_write_data;
   wire 	  pag_read, pag_write;
   wire 	  pag_io_read, pag_io_write;
   wire 	  pag_read_ack, pag_write_ack;
   wire [`DEVICE] pag_io_dev;	// the I/O Device
   wire 	  pag_io_cond;	// I/O Device Conditions
   wire [`WORD]   pag_io_read_data;
   wire [`WORD]   pag_io_write_data;
   wire 	  pag_io_read_ack;
   wire 	  pag_io_write_ack;
   wire 	  pag_nxd;
   wire [1:7] 	  pag_pi;

   // Cache <-> MEM connections
   wire [`PADDR]  mem_addr;
   wire [`WORD]   mem_read_data;
   wire [`WORD]   mem_write_data;
   wire 	  mem_read, mem_write;
   wire 	  mem_io_read, mem_io_write;
   wire 	  mem_read_ack, mem_write_ack;

   // Cache <-> IOM connections
   wire [`DEVICE] io_dev;
   wire [`WORD]   io_read_data;
   wire [`WORD]   io_write_data;
   wire 	  io_read;
   wire 	  io_write;
   wire [1:7] 	  io_pi_in;

   wire [`ADDR]   display_addr;
   wire 	  running;

   reg 		  reset = 0;
   reg 		  clk = 1;
`ifndef LINT
   initial begin
      $dumpfile("tb-apr.lxt");
      $dumpvars(0,apr_tb);

      #0 reset = 1;
      #300 reset = 0;

      #10000000 $display("Out of time");
      $finish_and_return(2);
   end
   
   always #50 clk = !clk;
`endif

   apr apr(clk, reset,
	   apr_addr, apr_user, apr_read_data, apr_write_data, apr_read, apr_write, 
	   apr_write_ack, apr_read_ack, apr_page_fail, 
	   apr_io_dev, apr_io_cond, apr_io_read_data, apr_io_write_data,
	   apr_io_read, apr_io_write, apr_io_read_ack, apr_io_write_ack, apr_nxd, apr_pi,
	   display_addr, running);

`define PAG 1
`ifdef PAG
   pag pag(clk, reset, 
	   apr_addr, apr_user, apr_read_data, apr_write_data, apr_read, apr_write, 
	   apr_read_ack, apr_write_ack, apr_page_fail,
	   apr_io_dev, apr_io_cond, apr_io_read_data, apr_io_write_data, apr_io_read, apr_io_write,
	   apr_io_read_ack, apr_io_write_ack, apr_nxd, apr_pi,
	   pag_addr, pag_read_data, pag_write_data, pag_read, pag_write, pag_io_read, pag_io_write,
	   pag_read_ack, pag_write_ack, pag_nxd, pag_pi
);
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
   assign pag_io_dev = apr_io_dev;
   assign pag_io_cond = apr_io_cond;
   assign apr_io_read_data = pag_io_read_data;
   assign pag_io_write_data = apr_io_write_data;
   assign apr_io_read_ack = pag_io_read_ack;
   assign apr_io_write_ack = pag_io_write_ack;
   assign apr_nxd = pag_nxd;
   assign apr_pi = pag_pi;
`endif

//`define CACHE
`ifdef CACHE
   cache cache(clk, reset,
	       pag_addr, pag_read_data, pag_write_data, pag_write, pag_read, pag_io_write, pag_io_read,
	       pag_write_ack, pag_read_ack, pag_pi,
	       mem_addr, mem_read_data, mem_write_data, mem_write, mem_read,
	       mem_write_ack, mem_read_ack, 
	       io_dev, io_read_data, io_write_data, io_write, io_read, io_pi_in,
	       pag_io_dev, pag_io_cond, pag_io_read_data, pag_io_read_ack, pag_io_write_ack, pag_nxd);
`else
   assign mem_addr = pag_addr;
   assign pag_read_data = mem_read_data;
   assign mem_write_data = pag_write_data;
   assign mem_write = pag_write;
   assign mem_read = pag_read;
   assign pag_write_ack = mem_write_ack;
   assign pag_read_ack = mem_read_ack;
   assign pag_io_read_data = 0;
   assign pag_io_read_ack = 0;
   assign pag_io_write_ack = 0;
   assign pag_nxd = 1;
   assign pag_pi = 0;
`endif

   mem mem(clk, reset, mem_addr, mem_read_data, mem_write_data, 
	   mem_read, mem_write, mem_read_ack, mem_write_ack);

endmodule // apr_tb
