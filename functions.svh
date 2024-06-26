// 	-*- mode: Verilog; fill-column: 90 -*-
//
// Utility functions


// Pull apart words

function [`HWORD] LEFT;
   input [`WORD]   w;
   LEFT = w[0:17];
endfunction

function [`HWORD] RIGHT;
   input [`WORD]   w;
   RIGHT = w[18:35];
endfunction

function [`WORD] SWAP;
   input [`WORD]   w;
   SWAP = { RIGHT(w), LEFT(w) };
endfunction

function NEGATIVE;
   input [`WORD]   w;
   NEGATIVE = w[0] == 1;
endfunction

function HALF_NEGATIVE;
   input [`HWORD]   w;
   HALF_NEGATIVE = w[0] == 1;
endfunction

// Returns the magnitude of a word.
function [`WORD] MAGNITUDE;
   input [`WORD] w;
   MAGNITUDE = NEGATIVE(w) ? -w : w;
endfunction

// Pull apart doublewords

function [`WORD] DLEFT;
   input [`DWORD]   d;
   DLEFT = d[0:`WORDSIZE-1];
endfunction // DLEFT

function [`WORD] DRIGHT;
   input [`DWORD]   d;
   DRIGHT = d[`WORDSIZE:`DWORDSIZE-1];
endfunction // DRIGHT

// Returns the magnitude of a doubleword.
function [`DWORD] DMAGNITUDE;
   input [`DWORD] w;
   DMAGNITUDE = w[0] == 1 ? -w : w;
endfunction


// Returns 1 of the address references ACs
function isAC;
   input [`ADDR] add;
   isAC = ((add & `ADDRSIZE'o777760) == 0);
endfunction


//
//  pull apart instructions - all these numeric constants annoy me!
//
function [0:8] instOP;
   input [`WORD]   op;
   instOP = op[0:8];
endfunction
function [0:3] instA;
   input [`WORD]   op;
   instA = op[9:12];
endfunction
function instI;
   input [`WORD]   op;
   instI = op[13];
endfunction
function [0:3] instX;
   input [`WORD]   op;
   instX = op[14:17];
endfunction
function [0:17] instY;
   input [`WORD]   op;
   instY = op[18:35];
endfunction
function [0:6] instIODEV;
   input [`WORD]   op;
   instIODEV = op[3:9];
endfunction
function [0:2] instIOOP;
   input [`WORD]   op;
   instIOOP = op[10:12];
endfunction



//
// Byte Pointer pieces
//
function [0:5] P;		// position
   input [`WORD] w;
   P = w[0:5];
endfunction
function [0:5] S;		// size
   input [`WORD] w;
   S = w[6:11];
endfunction
function [0:0] U;		// unused
   input [`WORD] w;
   U = w[12];
endfunction
function [0:17] Yinc;		// increment Y
   input [`WORD] w;
   Yinc = instY(w) + `HALFSIZE'd1;
endfunction

function [0:5] PlessS;		// position - size
   input [`WORD] w;
   PlessS = P(w) - S(w);
endfunction
function [0:5] Preset;		// reset position to start of a word
   input [`WORD] w;
   Preset = 6'd36 - S(w);
endfunction

function [`WORD] bp_mask;	// maps a size to a mask
   input [0:5] 	 size;
   case (size)
     'o00: bp_mask = `WORDSIZE'o000000000000;

     'o01: bp_mask = `WORDSIZE'o000000000001;
     'o02: bp_mask = `WORDSIZE'o000000000003;
     'o03: bp_mask = `WORDSIZE'o000000000007;

     'o04: bp_mask = `WORDSIZE'o000000000017;
     'o05: bp_mask = `WORDSIZE'o000000000037;
     'o06: bp_mask = `WORDSIZE'o000000000077;

     'o07: bp_mask = `WORDSIZE'o000000000177;
     'o10: bp_mask = `WORDSIZE'o000000000377;
     'o11: bp_mask = `WORDSIZE'o000000000777;

     'o12: bp_mask = `WORDSIZE'o000000001777;
     'o13: bp_mask = `WORDSIZE'o000000003777;
     'o14: bp_mask = `WORDSIZE'o000000007777;

     'o15: bp_mask = `WORDSIZE'o000000017777;
     'o16: bp_mask = `WORDSIZE'o000000037777;
     'o17: bp_mask = `WORDSIZE'o000000077777;

     'o20: bp_mask = `WORDSIZE'o000000177777;
     'o21: bp_mask = `WORDSIZE'o000000377777;
     'o22: bp_mask = `WORDSIZE'o000000777777;

     'o23: bp_mask = `WORDSIZE'o000001777777;
     'o24: bp_mask = `WORDSIZE'o000003777777;
     'o25: bp_mask = `WORDSIZE'o000007777777;

     'o26: bp_mask = `WORDSIZE'o000017777777;
     'o27: bp_mask = `WORDSIZE'o000037777777;
     'o30: bp_mask = `WORDSIZE'o000077777777;

     'o31: bp_mask = `WORDSIZE'o000177777777;
     'o32: bp_mask = `WORDSIZE'o000377777777;
     'o33: bp_mask = `WORDSIZE'o000777777777;

     'o34: bp_mask = `WORDSIZE'o001777777777;
     'o35: bp_mask = `WORDSIZE'o003777777777;
     'o36: bp_mask = `WORDSIZE'o007777777777;

     'o37: bp_mask = `WORDSIZE'o017777777777;
     'o40: bp_mask = `WORDSIZE'o037777777777;
     'o41: bp_mask = `WORDSIZE'o077777777777;

     'o42: bp_mask = `WORDSIZE'o177777777777;
     'o43: bp_mask = `WORDSIZE'o377777777777;
     default: bp_mask = `WORDSIZE'o777777777777;
   endcase // case (size)
endfunction // case
