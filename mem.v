//	-*- mode: Verilog; fill-column: 90 -*-
//
// Hacked up memory for testing
//
// 2013-02-01 dab	initial version
// 2014-01-01 dab	work on the posedge and get wait_time to work right
// 2015-01-21 dab	modified to be async read instead of synchronous and full sized physical memory
//
// 2-15-02-07 dab	async is faster and that's awesome but the actual memory, either internal to the
//			FPGA or external, is synchronous so make this the same.

`timescale 1 ns / 1 ns

`include "constants.vh"

module mem
  (
   input 	      clk,
   input 	      reset, 
   input [`PADDR]     mem_addr,
   output reg [`WORD] mem_read_data,
   input [`WORD]      mem_write_data,
   input 	      mem_write, // only one of mem_write or mem_read
   input 	      mem_read,
   output reg 	      write_ack,
   output reg 	      read_ack,
   output reg 	      nxm
   );

   reg [`WORD] 	      ram[0:2**`PADDRSIZE-1];

   reg [30*8:1]       filename;

   reg 		      read_ip, write_ip, rw_done;
   reg [`PADDR]       saved_addr;
   reg [`WORD] 	      saved_write_data;

   reg [0:4] 	      wait_count;
   localparam wait_time = 0;

   initial begin
      if (! $value$plusargs("file=%s", filename)) begin
         $display("ERROR: please specify +file=<filename> to start.");
         $finish_and_return(10);
      end

      $readmemh(filename, ram);

      read_ip <= 0;
      write_ip <= 0;
      rw_done <= 0;

      wait_count <= 0;
   end

   always @(posedge clk) begin
      nxm <= 0;			// all memory exists
      write_ack <= 0;
      read_ack <= 0;

      if (wait_count != 0)
	wait_count <= wait_count - 1;
      else if (rw_done)
	rw_done <= 0;
      else begin
	 if (read_ip) begin
	    mem_read_data <= ram[saved_addr];
	    read_ack <= 1;
	    read_ip <= 0;
	 end else if (write_ip) begin
	    ram[saved_addr] <= saved_write_data;
	    write_ack <= 1;
	    write_ip <= 0;
	 end
	   
	 if (mem_read)
	   if (wait_time == 0) begin
	      mem_read_data <= ram[mem_addr];
	      read_ack <= 1;
	      rw_done <= 1;
	   end else begin
	      saved_addr <= mem_addr;
	      read_ip <= 1;
	      wait_count <= wait_time - 1;
	   end
	 else if (mem_write)
	   if (wait_time == 0) begin
	      ram[mem_addr] <= mem_write_data;
	      write_ack <= 1;
	      rw_done <= 1;
	   end else begin
	      saved_addr <= mem_addr;
	      saved_write_data <= mem_write_data;
	      write_ip <= 1;
	      wait_count <= wait_time - 1;
	   end
      end
   end
   
endmodule // mem

