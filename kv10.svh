// 	-*- mode: Verilog; fill-column: 90 -*-
//
// KV10 definitions

typedef bit [`ADDR] addr;
typedef bit [`WORD] word;
typedef bit [`DEVICE] device;
typedef bit sig;


`ifdef NOTDEF
// Memory Interface
interface membus (input wire clk);
   sig reset;
   addr address;
   word read_data;
   word write_data;
   sig read;
   sig write;
   sig read_ack;
   sig write_ack;
   sig page_fail;
		    
   modport out (input clk, read_data, read_ack, write_ack, page_fail, 
		output reset, address, write_data, read, write);
   modport in (output read_data, read_ack, write_ack, page_fail, 
		input clk, reset, address, write_data, read, write);

endinterface // mem
`endif //  `ifdef NOTDEF
