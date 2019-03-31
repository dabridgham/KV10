//	-*- mode: Verilog; fill-column: 90 -*-
//
// Hacked up memory for testing

`timescale 1 ns / 1 ns

`include "constants.vh"

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

   reg [30*8:1]       filename;

   reg 		      read_ip, write_ip, rw_done;
   reg [`PADDR]       saved_addr;
   reg [`WORD] 	      saved_write_data;

   reg [0:4] 	      wait_count;
   localparam wait_time = 0;

   initial begin
`ifndef LINT
      if (! $value$plusargs("file=%s", filename)) begin
         $display("ERROR: please specify +file=<filename> to start.");
         $finish_and_return(10);
      end
`endif
      
      $readmemh(filename, ram);

      read_ip = 0;
      write_ip = 0;
      rw_done = 0;

      wait_count = 0;
   end

   // hack for pushing the ack asynchronously so it's there a cycle earlier than the data.
   // only works if wait_time is 0.
   always @(*) read_ack = mem_read;
   always @(*) write_ack = mem_write;

   always @(posedge clk) begin
//      write_ack <= 0;
//      read_ack <= 0;

      if (wait_count != 0)
	wait_count <= wait_count - 1;
      else if (rw_done) begin
	 $display("done");
	 rw_done <= 0;
      end else begin
	 if (read_ip) begin
//`define DEBUG_MEM
`ifdef DEBUG_MEM
	    $display("   <-- [%06o]", mem_addr);
`endif
	    mem_read_data <= ram[saved_addr];
//	    read_ack <= 1;
	    read_ip <= 0;
	 end else if (write_ip) begin
`ifdef DEBUG_MEM
	    $display("   [%06o] <-- %06o,%06o", saved_addr, saved_write_data[0:17], saved_write_data[18:35]);
`endif
	    ram[saved_addr] <= saved_write_data;
//	    write_ack <= 1;
	    write_ip <= 0;
	 end
	   
	 if (mem_read) begin
`ifdef DEBUG_MEM
	    $write("Reading ");
`endif
	    if (wait_time == 0) begin
`ifdef DEBUG_MEM
	       $display("   <-- [%06o]", mem_addr);
`endif
	       mem_read_data <= ram[mem_addr];
//	      read_ack <= 1;
	       rw_done <= 0;
	    end else begin
	       saved_addr <= mem_addr;
	       read_ip <= 1;
	       wait_count <= wait_time - 1;
	    end
	 end else if (mem_write) begin // if (mem_read)
`ifdef DEBUG_MEM
	    $write("Writing ");
`endif
	    if (wait_time == 0) begin
`ifdef DEBUG_MEM
	       $display("   [%06o] <-- %06o,%06o", mem_addr, mem_write_data[0:17], mem_write_data[18:35]);
`endif
	       ram[mem_addr] <= mem_write_data;
//	      write_ack <= 1;
	       rw_done <= 0;
	    end else begin
	       saved_addr <= mem_addr;
	       saved_write_data <= mem_write_data;
	       write_ip <= 1;
	       wait_count <= wait_time - 1;
	    end // else: !if(wait_time == 0)
	 end
      end
   end
   
endmodule // mem

