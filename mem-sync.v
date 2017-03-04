//	-*- mode: Verilog; fill-column: 90 -*-
//
// Hacked up memory for testing
//
// 2013-02-01 dab	initial version
// 2014-01-01 dab	work on the posedge and get wait_time to work right

`include "constants.vh"

module mem
  (
   input 	      clk,
   input [`ADDR]      mem_addr,
   output reg [`WORD] mem_read_data,
   input [`WORD]      mem_write_data,
   input 	      mem_write, // only one of mem_write or mem_read
   input 	      mem_read,
   output reg 	      mem_ack,
   input 	      mem_user // selects user or exec memory
   );

   reg [`WORD] 	      ram[0:2**`ADDRSIZE-1];

   reg [30*8:1]       filename;

   integer 	      wait_count;
   localparam wait_time = 0;
   reg 		      waiting_read, waiting_write;

   initial begin
      if (! $value$plusargs("file=%s", filename)) begin
         $display("ERROR: please specify +file=<filename> to start.");
         $finish_and_return(10);
      end

      $readmemh(filename, ram);

      wait_count <= wait_time;
      waiting_read <= 0;
      waiting_write <= 0;
   end

   always @(posedge clk) begin
      if (wait_count > 0) begin
	 wait_count <= wait_count - 1;
      end else begin
	 mem_ack <= 0;
	 if (waiting_read) begin
	    mem_read_data <= ram[mem_addr]; // this expects mem_addr to be held!  that works for now
	    mem_ack <= 1;
	    waiting_read <= 0;
	 end else if (waiting_write) begin
	    mem_ack <= 1;
	    waiting_write <= 0;
	 end else if (mem_read) begin
	    if (wait_time == 0) begin
	       mem_read_data <= ram[mem_addr];
	       mem_ack <= 1;
	    end else begin
	       wait_count <= wait_time - 1;
	       waiting_read <= 1;
	    end
	 end else if (mem_write) begin
	    ram[mem_addr] <= mem_write_data;
	    if (wait_time == 0)
	      mem_ack <= 1;
	    else begin
	       wait_count <= wait_time - 1;
	       waiting_write <= 1;
	    end
	 end
      end // else: !if(wait_count > 0)



   end
endmodule // mem
