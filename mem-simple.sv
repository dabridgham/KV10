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

`ifdef IACK
   // push the acks immediately so they're there a cycle earlier than the data.
   always @(*) read_ack = mem_read;
   always @(*) write_ack = mem_write;
`endif

   always @(posedge clk) begin
`ifndef IACK
      read_ack <= 0;
      write_ack <= 0;
`endif

      if (mem_read) begin
	 mem_read_data <= ram[mem_addr];
`ifndef IACK
	 read_ack <= 1;
`endif
      end

      if (mem_write) begin
	 ram[mem_addr] <= mem_write_data;
`ifndef IACK
	 write_ack <= 1;
`endif
      end
   end

endmodule // mem

