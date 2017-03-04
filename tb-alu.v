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
   reg [width-1:0] 	  op1high; // doubleword operations are op1high,op1
   reg [width-1:0] 	  op1; // first operand
   reg [width-1:0] 	  op2; // second operand

   wire [width-1:0] 	  resulthigh;
   wire [width-1:0] 	  resultlow;
   wire 		  overflow;
   wire 		  carry0;
   wire 		  carry1;
   wire 		  zero;
   wire 		  busy;


   initial begin
      $dumpfile("tb-alu.lxt");
      $dumpvars(0,alu_tb);

      #1 reset = 1;
      #10 reset = 0;

      #4 command = `aluADD;
      op1high = 0;
      op1 = 7;
      op2 = 13;

      #4 command = `aluSUB;
      op1 = 1;
      op2 = -2;

      #4 command = `aluADD;
      op1 = 1;
      op2 = -2;

      #4 command = `aluSUB;
      op1 = 3;
      op2 = 3;

      #4 command = `aluADD;
      op1 = 36'o377777_777777;
      op2 = 1;

      #4 command = `aluADD;
      op1 = 36'o777777_777777;
      op2 = 1;

      #4 command = `aluSUB;
      op1 = 36'o400000_000000;
      op2 = 1;

      #4 command = `aluLSH;
      op1 = 36'o000004_000000;
      op2 = 1;
      #1 while (busy) #1 command = `aluLSH;
      command = `aluOFF;

      #10 command = `aluLSH;
      op1 = 36'o000004_000000;
      op2 = 2;
      #1 while (busy) #1 command = `aluLSH;
      command = `aluOFF;

      #10 command = `aluLSH;
      op1 = 36'o000004_000000;
      op2 = -4;
      #1 while (busy) #1 command = `aluLSH;
      command = `aluOFF;

      #10 command = `aluLSH;
      op1 = 36'o000004_000000;
      op2 = -10;
      #1 while (busy) #1 command = `aluLSH;
      command = `aluOFF;

      #40 $finish;

   end
   
   reg clk = 0;
   always #1 clk = !clk;

   alu alu(clk, reset, command, op1high, op1, op2, resulthigh, resultlow, overflow, carry0, carry1, zero, busy);


endmodule // alu_tb
