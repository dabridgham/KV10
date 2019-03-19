//	-*- mode: Verilog; fill-column: 90 -*-
//
// Memory interface between processor and 16-bit wide async SRAM
//
// 2013-10-13 dab	initial version

`include "constants.vh"

module mem_sram
  (
   // interface to processor
   input 	      clk,
   input [`ADDR]      mem_addr,
   output reg [`WORD] mem_read_data,
   input [`WORD]      mem_write_data,
   input 	      mem_write, // only one of mem_write or mem_read
   input 	      mem_read,
   output reg 	      mem_ack,
   input 	      mem_user,	// selects user or exec memory

   // interface to sram
   output [19:0]      sram_addr,
   inout [15:0]       sram_data_bus,
   output reg 	      CE_n,	 // chip enable
   output reg	      OE_n,	 // output enable
   output reg	      WE_n,	 // write enable
   output reg	      UB_n, LB_n // upper/lower byte enable
   );

   reg [0:1] 	      byte_index;

   function [0:8] write_bits;
      input [0:1]     byte_index;
      case (byte_index)
	'b00: write_bits = mem_write_data[0:8];
	'b01: write_bits = mem_write_data[9:17];
	'b10: write_bits = mem_write_data[18:26];
	'b11: write_bits = mem_write_data[27:35];
      endcase // case (byte_index)
   endfunction // case

   assign sram_addr = { mem_addr, byte_index };
   assign sram_data_bus = WE_n ? 'z : { 7'b0, write_bits(byte_index) };
   

   initial begin
      CE_n <= 1;
      OE_n <= 1;
      WE_n <= 1;
      UB_n <= 1;
      LB_n <= 1;
      mem_ack <= 0;
      byte_index <= 'b11;
   end      

   always @(negedge clk) begin
      if (mem_write) begin
      end else if (mem_read) begin
	 CE_n <= 0;
	 OE_n <= 0;
	 UB_n <= 0;
	 LB_n <= 0;
	 case (byte_index)
	   2'b00:
	     begin
		mem_read_data[0:8] <= sram_data_bus[8:0];
		byte_index <= 2'b01;
	     end
	   2'b01:
	     begin
		mem_read_data[9:17] <= sram_data_bus[8:0];
		byte_index <= 2'b10;
	     end
	   2'b10:
	     begin
		mem_read_data[18:26] <= sram_data_bus[8:0];
		byte_index <= 2'b11;
	     end
	   2'b11:
	     begin
		if (CE_n == 0) begin
		   mem_read_data[27:35] <= sram_data_bus[8:0];
		   mem_ack <= 1;
		   CE_n <= 0;
		   OE_n <= 0;
		   UB_n <= 0;
		   LB_n <= 0;
		   byte_index <= 2'b11; // don't increment when we're done
		end else begin
		   byte_index <= 2'b00; // first time through a read cycle hits this
		end
	     end
	 endcase // case (byte_index)
      end else begin
	 CE_n <= 1;
	 OE_n <= 1;
	 WE_n <= 1;
	 UB_n <= 1;
	 LB_n <= 1;
	 mem_ack <= 0;
      end
   end

endmodule // mem
