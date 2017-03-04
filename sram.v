//	-*- mode: Verilog; fill-column: 90 -*-
//
// Simulates the DE2 1Mx16 asynchronous SRAM
//
// 2013-02-13 dab	initial version

`timescale 1 ns / 1 ns

module de2_sram
  (
   input [19:0] addr,
   inout [15:0] data_bus,
   input 	CE_n,		// chip enable
   input 	OE_n,		// output enable
   input 	WE_n,		// write enable
   input 	UB_n, LB_n	// upper/lower byte enable
   );

   reg [7:0] 	upper [0:2**20-1];
   reg [7:0] 	lower [0:2**20-1];

   assign data_bus[15:8] = (~CE_n && ~OE_n && ~UB_n && WE_n) ? upper[addr] : z;
   assign data_bus[7:0] = (~CE_n && ~OE_n && ~LB_n && WE_n) ? lower[addr] : z;

   always @(CE_n, WE_n) begin
      if (~CE_n && ~WE_n) begin
	 if (~UB_n)
	   #6 upper[addr] <= data_bus[15:8];
	 if (~LB_n)
	   #6 lower[addr] <= data_bus[7:0];
      end
   end

endmodule // de2_sram
