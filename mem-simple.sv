//	-*- mode: Verilog; fill-column: 90 -*-
//
// Hacked up memory, really simplified, for testing inside Xilinx Vivado

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

//   reg [`WORD] 	      ram[0:2**`PADDRSIZE-1];
   reg [`WORD] 	      ram[0:2**15-1]; // fit into the Block RAM in the FPGA

   initial begin
      $readmemh("dgcaa.mif", ram);
   end

   always @(posedge clk) begin
      read_ack <= 0;
      write_ack <= 0;

      if (mem_read) begin
	 mem_read_data <= ram[mem_addr];
	 read_ack <= 1;
      end

      if (mem_write) begin
	 ram[mem_addr] <= mem_write_data;
	 write_ack <= 1;
      end
   end

endmodule // mem

