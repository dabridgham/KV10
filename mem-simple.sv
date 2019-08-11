//	-*- mode: Verilog; fill-column: 90 -*-
//
// Hacked up memory, really simplified, for testing inside Xilinx

`timescale 1 ns / 1 ns

`include "constants.svh"

module mem
  (
   input 	      clk,
   input 	      reset, 
   input [`PADDR]     mem_addr,
   output reg [`WORD] mem_read_data,
   input [`WORD]      mem_write_data,
   input 	      mem_read,
   input 	      mem_write,
   output reg 	      read_ack,
   output reg  	      write_ack
   );

   reg [`WORD] 	      ram[0:2**`PADDRSIZE-1];

   initial begin
      $readmemh("dgcaa.mif", ram);
   end

   // hack for pushing the ack asynchronously so it's there a cycle earlier than the data.
   // only works if wait_time is 0.
   always @(*) read_ack = mem_read;
   always @(*) write_ack = mem_write;

   always @(posedge clk) begin
      if (mem_read)
	mem_read_data <= ram[mem_addr];

      if (mem_write)
	ram[mem_addr] <= mem_write_data;
   end

endmodule // mem

