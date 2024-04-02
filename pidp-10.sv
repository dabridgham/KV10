//	-*- mode: Verilog; fill-column: 96 -*-
//
// PiDP-10 Console interface
//

module pidp10
  (
   input	      reset,
   input	      clk, // runs about 100 kHz (frequency is purely a guess, at this point and
			   // isn't critical anyway)
   // LED outputs
   input [18:35]      pc,
   input [0:35]	      inst,
   input [0:35]	      data,
   input [1:7]	      pip, // PI In Progress
   input [1:7]	      pir, // PI Request
   input [1:7]	      pia, // PI Active
   input [1:7]	      iob, // IOB PI Request
   input	      memory_data,
   input	      program_data,
   input	      run,
   input	      program_stop,
   input	      pi_on,
   input	      user_mode,
   input	      power,
   input	      memory_stop,
   // switch inputs
   output reg [0:35]  data_switches,
   output reg [18:35] addr_switches,
   output reg	      single_inst,
   output reg	      single_cycle,
   output reg	      par_stop,
   output reg	      nxm_stop,
   output reg	      rept,
   output reg	      inst_fetch,
   output reg	      data_fetch,
   output reg	      write,
   output reg	      addr_stop,
   output reg	      addr_break,
   output reg	      read_in,
   output reg	      start,
   output reg	      cont,
   output reg	      stop,
   output reg	      reset_switch,
   output reg	      xct,
   output reg	      examine_this,
   output reg	      examine_next,
   output reg	      deposit_this,
   output reg	      deposit_next,
   // LED/switch matrix
   output reg [3:0]   row_addr, // row is indexed
   inout [17:0]	      col	// columns are individual wires
   );

   // increment row address
   always @(posedge clk)
     if (reset || (row_addr == 12)) // only 13 rows used
       row_addr <= 0;
     else
       row_addr <= row_addr + 1;
   
   reg [17:0]	     leds;		     // register to hold the LED signals
   assign col = row_addr[3] ? 18'bZ : ~leds; // Bit 3 of row_addr controls if we're writing LEDs
					     // or reading switches. Complement the LEDs since
					     // it's sinking current to illuminate the LED.
   
   // multiplex the LED values
   always @(posedge clk)
     case (row_addr)
       0: leds <= data[18:35];
       1: leds <= data[0:17];
       2: leds <= inst[18:35];
       3: leds <= inst[0:17];
       4: leds <= pc;
       5: leds <= { power, memory_stop, user_mode, stop, iob, pia };
       6: leds <= { memory_data, program_data, pi_on, run, pip, pir };
       default:
	 leds <= 0;
     endcase // case (row_addr)
   
   // multiplex the switches
   //
   // switch rows start at row_addr 8, called row0 on the schematic
   //
   // rows 3 and 4 (row_addrs 11 and 12) also connect to the maintenance panel or the
   // joystick/button panels. I don't have that schematic yet so those will be added later.
   always @(posedge clk)
      case (row_addr)
	8: data_switches[18:35] <= col;
	9: data_switches[0:17] <= col;
	10: addr_switches[18:35] <= col;
	11: { deposit_this, deposit_next, read_in, start, cont, 
	      stop, reset_switch, xct, examine_this, examine_next } <= col[9:0]; // these are
									  // all the momentary
									  // switches, they need
									  // debouncing
	12: { single_inst, single_cycle, par_stop, nxm_stop, rept,
	      inst_fetch, data_fetch, write, addr_stop, addr_break } <= col[9:0];
	default: ;
      endcase // case (row_addr)

endmodule // pidp10
