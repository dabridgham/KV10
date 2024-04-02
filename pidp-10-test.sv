//	-*- mode: Verilog; fill-column: 96 -*-
//
// PiDP-10 Console Test
//
// Not a testbench but a blinkenlights test

module pidp10_test
  (
   input 	 clk50_in,	// 50 MHz clock input, M21

   // a couple LEDs to play with
   output 	 led0,		// G21
   output 	 led1,		// G20

   // The PiDP-10 interface
   output reg [3:0]   row_addr, // row is indexed
   inout [17:0]	      col	// columns are individual wires
   );

   // blink some LEDs so we can see it's doing something
   // divide clock down to human visible speeds
   reg [35:0] 	count = 0;    
   always @(posedge clk50_in)
     count = count + 1;
        
   assign led0 = count[22];
   assign led1 = count[23];

   wire		clk100k = count[9]; // about 50 kHz
   wire		clk2h = count[24];  // about 2 Hz
   
   
   // Hook up to the PiDP-10 Console
   reg		reset = 0;
   reg [18:35]	pc;
   reg [0:35]	inst, data;
   reg [1:7]	pip, pir, pia, iob;
   reg		memory_data, program_data, run, program_stop, pi_on, user_mode, power, memory_stop;
   wire [0:35]	data_switches;
   wire [18:35]	addr_switches;
   wire		single_inst, single_cycle, par_stop, nxm_stop, rept, inst_fetch, data_fetch, write,
		addr_stop, addr_break;
   wire		read_in, start, cont, stop, reset_switch, xct, examine_this, examine_next,
		deposit_this, deposit_next;
   pidp10 pidp10(reset, clk100k, pc, inst, data, pip, pir, pia, iob, memory_data, program_data,
		 run, program_stop, pi_on, user_mode, power, memory_stop,

		 data_switches, addr_switches, single_inst, single_cycle, par_stop, nxm_stop,
		 rept, inst_fetch, data_fetch, write, addr_stop, addr_break,

		 read_in, start, cont, stop, reset_switch, xct, examine_this, examine_next,
		 deposit_this, deposit_next,

		 row_addr, col);
   
   // put on a lights display
   always @(posedge clk2h) begin
      if (reset_switch) begin
	 inst <= 0;
	 data <= 7;
      end else begin
	 data <= {inst[0], data[0:34]}; // inst and data make a circular rotation
	 inst <= {inst[1:35], data[35]};
	 pc <= {pc[19:35], data[35]}; // pc gets the low bit of data
	 iob <= {iob[2:7], pc[18]};    // the various PI LEDs get the overflow from pc
	 pip <= {pip[2:7], iob[1]};
	 pir <= {pip[1], pir[1:6]};
	 pia <= {pia[2:7], pir[7]};
	 { power, pi_on, run, program_stop, user_mode, memory_stop }
	   <= { pi_on, run, program_stop, user_mode, memory_stop, pia[1] };
	 if ((data[35] == 1) && (inst[35] == 0))
	   memory_data <= ~memory_data;
	 program_data <= ~memory_data;
      end
   end

endmodule // pidp10_test
