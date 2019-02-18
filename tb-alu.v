//	-*- mode: Verilog; fill-column: 90 -*-
//
// testbench for the Arithmetic and Logic Unit for kv10 processor
//
// 2013-01-31 dab	initial version

`include "constants.vh"
`include "alu.vh"

module alu_tb#(parameter width=36)();
   reg reset = 0;
   
   reg [`aluCMDwidth-1:0] command;
   reg [width-1:0] 	  Alow; // doubleword operations are A,Alow
   reg [width-1:0] 	  A; // first operand
   reg [width-1:0] 	  M; // second operand

   wire [width-1:0] 	  result;
   wire [width-1:0] 	  resultlow;
   wire 		  overflow;
   wire 		  carry0;
   wire 		  carry1;
   wire 		  zero;


   initial begin
      $dumpfile("tb-alu.lxt");
      $dumpvars(0,alu_tb);

      #4 command = `aluADD;
      Alow = 0;
      A = 7;
      M = 13;

      #4 command = `aluSUB;
      A = 1;
      M = -2;

      #4 command = `aluADD;
      A = 1;
      M = -2;

      #4 command = `aluSUB;
      A = 3;
      M = 3;

      #4 command = `aluADD;
      A = 36'o377777_777777;
      M = 1;

      #4 command = `aluADD;
      A = 36'o777777_777777;
      M = 1;

      #4 command = `aluSUB;
      A = 36'o400000_000000;
      M = 1;

      #4 command = `aluLSH;
      A = 36'o000004_000000;
      M = 1;

      #10 command = `aluLSH;
      A = 36'o000004_000000;
      M = 2;

      #10 command = `aluLSH;
      A = 36'o000004_000000;
      M = -4;

      #10 command = `aluLSH;
      A = 36'o000004_000000;
      M = -10;

      #10 command = `aluROTC;
//      A = 36'o230703_603700;
//      Alow = 36'o770037_600377;
      #1 A = 0;
      #1 Alow = 36'o000007_000000;
      #1 M = 36'o374;
      #1 $display("ROTC: %o,%o %o -> %o,%o", A, Alow, M, result, resultlow);
      
      #1 $finish();

      #10 command = `aluROTC;
      A = 0;
      Alow = 36'o000007_000000;
      M = 1;
      #1 $display("ROTC: %o,%o %o -> %o,%o", A, Alow, M, result, resultlow);
      
      #10 command = `aluROTC;
      A = 0;
      Alow = 36'o000007_000000;
      M = 2;
      #1 $display("ROTC: %o,%o %o -> %o,%o", A, Alow, M, result, resultlow);
      
      #10 command = `aluROTC;
      A = 0;
      Alow = 36'o000007_000000;
      M = 4;
      #1 $display("ROTC: %o,%o %o -> %o,%o", A, Alow, M, result, resultlow);
      
      #10 command = `aluROTC;
      A = 0;
      Alow = 36'o000007_000000;
      M = 8;
      #1 $display("ROTC: %o,%o %o -> %o,%o", A, Alow, M, result, resultlow);
      
      #10 command = `aluROTC;
      A = 0;
      Alow = 36'o000007_000000;
      M = 16;
      #1 $display("ROTC: %o,%o %o -> %o,%o", A, Alow, M, result, resultlow);
      
      #10 command = `aluROTC;
      A = 0;
      Alow = 36'o000007_000000;
      M = 32;
      #1 $display("ROTC: %o,%o %o -> %o,%o", A, Alow, M, result, resultlow);
      
      #10 command = `aluROTC;
      A = 0;
      Alow = 36'o000007_000000;
      M = 'o374;
      #1 $display("ROTC: %o,%o %o -> %o,%o", A, Alow, M, result, resultlow);
      
      #10 command = `aluROTC;
      A = 0;
      Alow = 36'o000007_000000;
      M = 64;
      #1 $display("ROTC: %o,%o %o -> %o,%o", A, Alow, M, result, resultlow);
      
      #10 command = `aluROTC;
      A = 0;
      Alow = 36'o000007_000000;
      M = 128;
      #1 $display("ROTC: %o,%o %o -> %o,%o", A, Alow, M, result, resultlow);
      
      #1 $finish();
      

      #10 command = `aluROTC;
      A = 36'o000000_000000;
      Alow = 36'o000000_000001;
      M = 0;
      #1 $display("ROTC: %o,%o %o -> %o,%o", A, Alow, M, result, resultlow);
      
      #10 command = `aluROTC;
      A = 36'o000000_000000;
      Alow = 36'o000000_000001;
      M = 1;
      #1 $display("ROTC: %o,%o %o -> %o,%o", A, Alow, M, result, resultlow);
      
      #10 command = `aluROTC;
      A = 36'o000000_000000;
      Alow = 36'o000000_000001;
      M = 2;
      #1 $display("ROTC: %o,%o %o -> %o,%o", A, Alow, M, result, resultlow);
      
      #10 command = `aluROTC;
      A = 36'o000000_000000;
      Alow = 36'o000000_000001;
      M = 4;
      #1 $display("ROTC: %o,%o %o -> %o,%o", A, Alow, M, result, resultlow);
      
      #10 command = `aluROTC;
      A = 36'o000000_000000;
      Alow = 36'o000000_000001;
      M = 8;
      #1 $display("ROTC: %o,%o %o -> %o,%o", A, Alow, M, result, resultlow);

      #10 command = `aluROTC;
      A = 36'o000000_000000;
      Alow = 36'o000000_000001;
      M = 16;
      #1 $display("ROTC: %o,%o %o -> %o,%o", A, Alow, M, result, resultlow);

      #10 command = `aluROTC;
      A = 36'o000000_000000;
      Alow = 36'o000000_000001;
      M = 32;
      #1 $display("ROTC: %o,%o %o -> %o,%o", A, Alow, M, result, resultlow);

      #10 command = `aluROTC;
      A = 36'o000000_000000;
      Alow = 36'o000000_000001;
      M = 64;
      #1 $display("ROTC: %o,%o %o -> %o,%o", A, Alow, M, result, resultlow);

      #10 command = `aluROTC;
      A = 36'o000000_000000;
      Alow = 36'o000000_000001;
      M = 128;
      #1 $display("ROTC: %o,%o %o -> %o,%o", A, Alow, M, result, resultlow);

      #10 command = `aluROTC;
      A = 36'o000000_000000;
      Alow = 36'o000000_000001;
      M = 256;
      #1 $display("ROTC: %o,%o %o -> %o,%o", A, Alow, M, result, resultlow);
      
      #10 command = `aluROTC;
      A = 36'o777777_777777;
      Alow = 36'o777777_777776;
      M = 1;
      #1 $display("ROTC: %o,%o %o -> %o,%o", A, Alow, M, result, resultlow);
      
      #10 command = `aluROTC;
      A = 36'o777777_777777;
      Alow = 36'o777777_777776;
      M = 2;
      #1 $display("ROTC: %o,%o %o -> %o,%o", A, Alow, M, result, resultlow);
      
      #10 command = `aluROTC;
      A = 36'o777777_777777;
      Alow = 36'o777777_777776;
      M = 4;
      #1 $display("ROTC: %o,%o %o -> %o,%o", A, Alow, M, result, resultlow);
      
      #10 command = `aluROTC;
      A = 36'o777777_777777;
      Alow = 36'o777777_777776;
      M = 8;
      #1 $display("ROTC: %o,%o %o -> %o,%o", A, Alow, M, result, resultlow);

      #10 command = `aluROTC;
      A = 36'o777777_777777;
      Alow = 36'o777777_777776;
      M = 16;
      #1 $display("ROTC: %o,%o %o -> %o,%o", A, Alow, M, result, resultlow);

      #10 command = `aluROTC;
      A = 36'o777777_777777;
      Alow = 36'o777777_777776;
      M = 32;
      #1 $display("ROTC: %o,%o %o -> %o,%o", A, Alow, M, result, resultlow);

      #10 command = `aluROTC;
      A = 36'o777777_777777;
      Alow = 36'o777777_777776;
      M = 64;
      #1 $display("ROTC: %o,%o %o -> %o,%o", A, Alow, M, result, resultlow);

      #10 command = `aluROTC;
      A = 36'o777777_777777;
      Alow = 36'o777777_777776;
      M = 128;
      #1 $display("ROTC: %o,%o %o -> %o,%o", A, Alow, M, result, resultlow);

      #10 command = `aluROTC;
      A = 36'o777777_777777;
      Alow = 36'o777777_777776;
      M = 256;
      #1 $display("ROTC: %o,%o %o -> %o,%o", A, Alow, M, result, resultlow);

      // right shifts

      #10 command = `aluROTC;
      A = 36'o000000_000000;
      Alow = 36'o000000_000001;
      M = -2;
      #1 $display("ROTC: %o,%o %o -> %o,%o", A, Alow, M, result, resultlow);
      
      

      #40 $finish;

   end
   
   reg clk = 0;
   always #1 clk = !clk;

   alu alu(command, Alow, A, M, resultlow, result, carry0, carry1, overflow, zero);


endmodule // alu_tb
