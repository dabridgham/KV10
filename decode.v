//	-*- mode: Verilog; fill-column: 96 -*-
//
// Instruction Decode ROM
//

`include "constants.vh"

`timescale 1 ns / 1 ns

module decode
  (
   input [`WORD] 	inst, // instruction
   input 		user, // user/exec mode
   input 		userIO, // userIO is enabled
   output reg [8:0] 	dispatch, // main instruction branch in the state machine
   output reg 		ReadE, // the instruction reads the value from E
   output reg [0:2] 	condition_code, // jump or skip condition
   output reg 		Comp0, // use jump_condition_0 instead of jump_condition
   output [`ADDR] 	io_dev	// the I/O device
   );

`include "opcodes.vh"
`include "decode.vh"
`include "functions.vh"

   localparam 
     no = 1'b0,
     yes = 1'b1;

   // build up an address for I/O devices from the device field in the
   // instruction and whether it's a data or conditions operation
   reg 			io_conditions;
   assign io_dev = { 9'b0, instIODEV(inst), 1'b0, io_conditions };

   always @(*) begin
      // defaults
      dispatch = instOP(inst);
      ReadE = no;
      condition_code = skip_never;
      Comp0 = no;
      io_conditions = no;

      // verilator lint_off CASEX
      // Turn off this verilator flag and fix this !!!
      casex (instOP(inst))	// synopsys full_case parallel_case

	LUUO01, LUUO02, LUUO03, LUUO04, LUUO05, LUUO06, LUUO07,
	LUUO10, LUUO11, LUUO12, LUUO13, LUUO14, LUUO15, LUUO16, LUUO17,
	LUUO20, LUUO21, LUUO22, LUUO23, LUUO24, LUUO25, LUUO26, LUUO27,
	LUUO30, LUUO31, LUUO32, LUUO33, LUUO34, LUUO35, LUUO36, LUUO37:
	  ;
	  
	UUO00, 		  
	CALL, INITI, MUUO42, MUUO43, MUUO44, MUUO45, MUUO46, CALLI,
	OPEN, TTCALL, MUUO52, MUUO53, MUUO54, RENAME, IN, OUT,
	SETSTS, STATO, STATUS, GETSTS, INBUF, OUTBUF, INPUT, OUTPUT,
	CLOSE, RELEAS, MTAPE, UGETF, USETI, USETO, LOOKUP, ENTER:
	  ;

	UJEN, UNK101, GFAD, GFSB, JSYS, ADJSP, GFMP, GFDV,
	DFAD, DFSB, DFMP, DFDV, DADD, DSUB, DMUL, DDIV,
	DMOVE, DMOVN, FIX, EXTEND, DMOVEM, DMOVNM, FIXR, FLTR,
	UFA, DFN, FSC,  // byte instructions come out of here
	FAD, FADL, FADM, FADB, FADR, FADRL, FADRM, FADRB,
	FSB, FSBL, FSBM, FSBB, FSBR, FSBRL, FSBRM, FSBRB,
	FMP, FMPL, FMPM, FMPB, FMPR, FMPRL, FMPRM, FMPRB,
	FDV, FDVL, FDVM, FDVB, FDVR, FDVRL, FDVRM, FDVRB:
	  ;

	//
	// Full Word MOVE instructions
	//

	MOVE:  ReadE = yes;	// AC <- C(E)
	MOVEI: ReadE = no;	// AC <- 0,E
	MOVEM: ReadE = no;	// C(E) <- AC
	MOVES: ReadE = yes;	// C(E) and AC (if not 0) <= C(E)

	MOVS:  ReadE = yes;	// AC <- swap(C(E))
	MOVSI: ReadE = no;	// AC <- E,0
	MOVSM: ReadE = no;	// C(E) <- swap(AC)
	MOVSS: ReadE = yes;	// C(E) and AC (if not 0) <= swap(C(E))

	MOVN:  ReadE = yes;	// AC <- -C(E)
	MOVNI: ReadE = no;	// AC <- -0,E
	MOVNM: ReadE = no;	// C(E) <- -AC
	MOVNS: ReadE = yes;	// C(E) and AC (if not 0) <= -C(E)

	MOVM:  ReadE = yes;	// AC <- |C(E)|
	MOVMI: ReadE = no;	// AC <- |0,E|
	MOVMM: ReadE = no;	// C(E) <- |AC|
	MOVMS: ReadE = yes;	// C(E) and AC (if not 0) <= |C(E)|

	//
	// Integer Multiply and Divide
	//

	IMUL:  ReadE = yes;
	IMULI: ReadE = no;
	IMULM: ReadE = yes;
	IMULB: ReadE = yes;

	MUL:  ReadE = yes;
	MULI: ReadE = no;
	MULM: ReadE = yes;
	MULB: ReadE = yes;
	
	IDIV:  ReadE = yes;
	IDIVI: ReadE = no;
	IDIVM: ReadE = yes;
	IDIVB: ReadE = yes;
	
	DIV:  ReadE = yes;
	DIVI: ReadE = no;
	DIVM: ReadE = yes;
	DIVB: ReadE = yes;
	
	//
	// Shifts and Rotates
	//

	ASH: ;
	ROT: ;
	LSH: ;
	JFFO: ;
	ASHC: ;
	ROTC: ;
	LSHC: ;
	CIRC: ;

	EXCH: ReadE = yes;	// Exchange, AC <-> C(E)
	BLT: ;			// Block Transfer
	
	AOBJP:			// Add One to Both halves of AC, Jump if Positive
	  { condition_code, Comp0 } = { skipge, yes };
	AOBJN:			// Add One to Both halves of AC, Jump if Negative
	  { condition_code, Comp0 } = { skipl, yes };

	JRST:			// Jump and Restory Flags
	  // Special optimization for JRST
	  case (1'b1)
	    inst[10]: dispatch = 9'o730; // JRST 4 (HALT)
	    inst[11]: dispatch = 9'o731; // JRST 10 (JRSTF)
	    default: ;			 // JRST
	  endcase

	JFCL: ;			// Jump on Flag and Clear

	// Does E get read in the wrong mode? !!!
	XCT: ReadE = yes;	// Execute instruction at E
	
	MAP: ;

	PUSHJ: ;		// Push down and Jump: AC <- aob(AC) then C(AC) <- PSW,PC
	PUSH: ReadE = yes;	// AC <- aob(AC) then C(AC) <- C(E)
	POP: ;			// C(E) <- C(AC) then AC <- sob(AC)
	POPJ: ;			// Pop up and Jump: 

	JSR: ;			// Jump to Subroutine: C(E) <- PSW,PC  PC <- E+1
	JSP: ;			// Jump and Save PC: AC <- PSW,PC  PC <- E
	JSA: ;			// Jump and Save AC: C(E) <- AC  AC <- E,PC  PC <- E+1
	JRA: ;			// Jump and Restore AC: AC <- C(left(AC))  PC <- E

	ADD:  ReadE = yes;	// AC <- AC + C(E)
	ADDI: ReadE = no;	// AC <- AC + 0,,E
	ADDM: ReadE = yes;	// C(E) <- AC + C(E)
	ADDB: ReadE = yes;	// AC and C(E) <- AC + C(E)

	SUB:  ReadE = yes;	// AC <- AC - C(E)
	SUBI: ReadE = no;	// AC <- AC - 0,,E
	SUBM: ReadE = yes;	// C(E) <- AC - C(E)
	SUBB: ReadE = yes;	// AC and C(E) <- AC - C(E)

	// Compare Accumulator to Immediate
	CAI: { ReadE, condition_code } = { no, skip_never };
	CAIL: { ReadE, condition_code } = { no, skipl };
	CAIE: { ReadE, condition_code } = { no, skipe };
	CAILE: { ReadE, condition_code } = { no, skiple };
	CAIA: { ReadE, condition_code } = { no, skipa };
	CAIGE: { ReadE, condition_code } = { no, skipge };
	CAIN: { ReadE, condition_code } = { no, skipn };
	CAIG: { ReadE, condition_code } = { no, skipg };
	// Compare Accumulator to Memory
	CAM: { ReadE, condition_code } = { yes, skip_never };
	CAML: { ReadE, condition_code } = { yes, skipl };
	CAME: { ReadE, condition_code } = { yes, skipe };
	CAMLE: { ReadE, condition_code } = { yes, skiple };
	CAMA: { ReadE, condition_code } = { yes, skipa };
	CAMGE: { ReadE, condition_code } = { yes, skipge };
	CAMN: { ReadE, condition_code } = { yes, skipn };
	CAMG: { ReadE, condition_code } = { yes, skipg };

	// Compare AC with 0
	JUMP: { condition_code, Comp0 } = { skip_never, yes };
	JUMPL: { condition_code, Comp0 } = { skipl, yes };
	JUMPE: { condition_code, Comp0 } = { skipe, yes };
	JUMPLE: { condition_code, Comp0 } = { skiple, yes };
	JUMPA: { condition_code, Comp0 } = { skipa, yes };
	JUMPGE: { condition_code, Comp0 } = { skipge, yes };
	JUMPN: { condition_code, Comp0 } = { skipn, yes };
	JUMPG: { condition_code, Comp0 } = { skipg, yes };

	// Add one to AC and jump
	AOJ: { condition_code, Comp0 } = { skip_never, yes };
	AOJL: { condition_code, Comp0 } = { skipl, yes };
	AOJE: { condition_code, Comp0 } = { skipe, yes };
	AOJLE: { condition_code, Comp0 } = { skiple, yes };
	AOJA: { condition_code, Comp0 } = { skipa, yes };
	AOJGE: { condition_code, Comp0 } = { skipge, yes };
	AOJN: { condition_code, Comp0 } = { skipn, yes };
	AOJG: { condition_code, Comp0 } = { skipg, yes };

	// Add one to Memory and skip
	AOS: { ReadE, condition_code, Comp0 } = { yes, skip_never, yes };
	AOSL: { ReadE, condition_code, Comp0 } = { yes, skipl, yes };
	AOSE: { ReadE, condition_code, Comp0 } = { yes, skipe, yes };
	AOSLE: { ReadE, condition_code, Comp0 } = { yes, skiple, yes };
	AOSA: { ReadE, condition_code, Comp0 } = { yes, skipa, yes };
	AOSGE: { ReadE, condition_code, Comp0 } = { yes, skipge, yes };
	AOSN: { ReadE, condition_code, Comp0 } = { yes, skipn, yes };
	AOSG: { ReadE, condition_code, Comp0 } = { yes, skipg, yes };

	// Subtract One from AC and jump
	SOJ: { condition_code, Comp0 } = { skip_never, yes };
	SOJL: { condition_code, Comp0 } = { skipl, yes };
	SOJE: { condition_code, Comp0 } = { skipe, yes };
	SOJLE: { condition_code, Comp0 } = { skiple, yes };
	SOJA: { condition_code, Comp0 } = { skipa, yes };
	SOJGE: { condition_code, Comp0 } = { skipge, yes };
	SOJN: { condition_code, Comp0 } = { skipn, yes };
	SOJG: { condition_code, Comp0 } = { skipg, yes };

	// Subtract One from Memory and skip
	SOS: { ReadE, condition_code, Comp0 } = { yes, skip_never, yes };
	SOSL: { ReadE, condition_code, Comp0 } = { yes, skipl, yes };
	SOSE: { ReadE, condition_code, Comp0 } = { yes, skipe, yes };
	SOSLE: { ReadE, condition_code, Comp0 } = { yes, skiple, yes };
	SOSA: { ReadE, condition_code, Comp0 } = { yes, skipa, yes };
	SOSGE: { ReadE, condition_code, Comp0 } = { yes, skipge, yes };
	SOSN: { ReadE, condition_code, Comp0 } = { yes, skipn, yes };
	SOSG: { ReadE, condition_code, Comp0 } = { yes, skipg, yes };
	
	// Logical Operations
	// AC <- AC <op> 0,E
	SETZI: ;
	ANDI: ;
	ANDCAI: ;
	SETMI: ;
	ANDCMI: ;
	SETAI: ;
	XORI: ;
	ORI: ;
	ANDCBI: ;
	EQVI: ;
	SETCAI: ;
	ORCAI: ;
	SETCMI: ;
	ORCMI: ;
	ORCBI: ;
	SETOI: ;
   
	// AC <- AC <op> C(E)
	// SETZ, for instance, doesn't really need to Read E.  Optimize !!!
	SETZ: ReadE = yes;
	AND: ReadE = yes;
	ANDCA: ReadE = yes;
	SETM: ReadE = yes;
	ANDCM: ReadE = yes;
	SETA: ReadE = yes;
	XOR: ReadE = yes;
	OR: ReadE = yes;
	ANDCB: ReadE = yes;
	EQV: ReadE = yes;
	SETCA: ReadE = yes;
	ORCA: ReadE = yes;
	SETCM: ReadE = yes;
	ORCM: ReadE = yes;
	ORCB: ReadE = yes;
	SETO: ReadE = yes;
   
	// C(E) <- AC <op> C(E)
	SETZM: ReadE = yes;
	ANDM: ReadE = yes;
	ANDCAM: ReadE = yes;
	SETMM: ReadE = yes;
	ANDCMM: ReadE = yes;
	SETAM: ReadE = yes;
	XORM: ReadE = yes;
	ORM: ReadE = yes;
	ANDCBM: ReadE = yes;
	EQVM: ReadE = yes;
	SETCAM: ReadE = yes;
	ORCAM: ReadE = yes;
	SETCMM: ReadE = yes;
	ORCMM: ReadE = yes;
	ORCBM: ReadE = yes;
	SETOM: ReadE = yes;
   
	// C(E) and AC <- AC <op> C(E)
	SETZB: ReadE = yes;
	ANDB: ReadE = yes;
	ANDCAB: ReadE = yes;
	SETMB: ReadE = yes;
	ANDCMB: ReadE = yes;
	SETAB: ReadE = yes;
	XORB: ReadE = yes;
	ORB: ReadE = yes;
	ANDCBB: ReadE = yes;
	EQVB: ReadE = yes;
	SETCAB: ReadE = yes;
	ORCAB: ReadE = yes;
	SETCMB: ReadE = yes;
	ORCMB: ReadE = yes;
	ORCBB: ReadE = yes;
	SETOB: ReadE = yes;

	IBP: ReadE = yes;	// Increment Byte Pointer
	LDB: ReadE = yes;	// Load Byte
	ILDB: ReadE = yes;	// Increment and Load Byte
	DPB: ReadE = yes;	// Deposit Byte
	IDPB: ReadE = yes;	// Increment and Deposit Byte

	// Compare Memory with 0 and skip
	SKIP: { ReadE, condition_code, Comp0 } = { yes, skip_never, yes };
	SKIPL: { ReadE, condition_code, Comp0 } = { yes, skipl, yes };
	SKIPE: { ReadE, condition_code, Comp0 } = { yes, skipe, yes };
	SKIPLE: { ReadE, condition_code, Comp0 } = { yes, skiple, yes };
	SKIPA: { ReadE, condition_code, Comp0 } = { yes, skipa, yes };
	SKIPGE: { ReadE, condition_code, Comp0 } = { yes, skipge, yes };
	SKIPN: { ReadE, condition_code, Comp0 } = { yes, skipn, yes };
	SKIPG: { ReadE, condition_code, Comp0 } = { yes, skipg, yes };
	
	// Half-word moves - Halfword[LR][LR][- Zeros Ones Extend][- Immediate Memory Self]
	//   Mode     Suffix    Source     Destination
	//  Basic                (E)           AC
	//  Immediate   I        0,E           AC
	//  Memory      M         AC           (E)
	//  Self        S        (E)           (E) and AC if AC nonzero
`define HMOVE(alu, aswap, mswap, cswap, readac, readm, reade, writeac, writes, writee) { ALUinst, Aswap, Mswap, Cswap, ReadAC, ReadMonA, ReadE, WriteAC, WriteSelf, WriteE } = { alu, aswap, mswap, cswap, readac, readm, reade, writeac, writes, writee }

	HLL: ReadE = yes;
	HLLI: ReadE = no;
	HLLM: ReadE = yes;
	HLLS: ReadE = yes;
	HRL: ReadE = yes;
	HRLI: ReadE = no;
	HRLM: ReadE = yes;
	HRLS: ReadE = yes;
		      
	HLLZ: ReadE = yes;
	HLLZI: ReadE = no;
	HLLZM: ReadE = yes;
	HLLZS: ReadE = yes;
	HRLZ: ReadE = yes;
	HRLZI: ReadE = no;
	HRLZM: ReadE = yes;
	HRLZS: ReadE = yes;
	
	HLLO: ReadE = yes;
	HLLOI: ReadE = no;
	HLLOM: ReadE = yes;
	HLLOS: ReadE = yes;
	HRLO: ReadE = yes;
	HRLOI: ReadE = no;
	HRLOM: ReadE = yes;
	HRLOS: ReadE = yes;
	
	HLLE: ReadE = yes;
	HLLEI: ReadE = no;
	HLLEM: ReadE = yes;
	HLLES: ReadE = yes;
	HRLE: ReadE = yes;
	HRLEI: ReadE = no;
	HRLEM: ReadE = yes;
	HRLES: ReadE = yes;

	HRR: ReadE = yes;
	HRRI: ReadE = no;
	HRRM: ReadE = yes;
	HRRS: ReadE = yes;
	HLR: ReadE = yes;
	HLRI: ReadE = no;
	HLRM: ReadE = yes;
	HLRS: ReadE = yes;
		      
	HRRZ: ReadE = yes;
	HRRZI: ReadE = no;
	HRRZM: ReadE = yes;
	HRRZS: ReadE = yes;
	HLRZ: ReadE = yes;
	HLRZI: ReadE = no;
	HLRZM: ReadE = yes;
	HLRZS: ReadE = yes;
	
	HRRO: ReadE = yes;
	HRROI: ReadE = no;
	HRROM: ReadE = yes;
	HRROS: ReadE = yes;
	HLRO: ReadE = yes;
	HLROI: ReadE = no;
	HLROM: ReadE = yes;
	HLROS: ReadE = yes;
	
	HRRE: ReadE = yes;
	HRREI: ReadE = no;
	HRREM: ReadE = yes;
	HRRES: ReadE = yes;
	HLRE: ReadE = yes;
	HLREI: ReadE = no;
	HLREM: ReadE = yes;
	HLRES: ReadE = yes;

	// Logical Testing and Modification (Bit Testing)
	// R - mask right half of AC with 0,E
	// L - mask left half of AC with E,0
	// D - mask AC with C(E)
	// S - mask AC with swap(C(E))
	//
	// N - no modification to AC
	// Z - zeros in masked bit positions
	// C - complement masked bit positions
	// O - ones in masked bit positions
	//
	//   - never skip
	// E - skip if all masked bits equal 0
	// A - always skip
	// N - skip if any masked bit is 1

	TRN: ReadE = no;
	TLN: ReadE = no;
	TRNE: ReadE = no;
	TLNE: ReadE = no;
	TRNA: ReadE = no;
	TLNA: ReadE = no;
	TRNN: ReadE = no;
	TLNN: ReadE = no;

	TDN: ReadE = yes;
	TSN: ReadE = yes;
	TDNE: ReadE = yes;
	TSNE: ReadE = yes;
	TDNA: ReadE = yes;
	TSNA: ReadE = yes;
	TDNN: ReadE = yes;
	TSNN: ReadE = yes;

	TRZ: ReadE = no;
	TLZ: ReadE = no;
	TRZE: ReadE = no;
	TLZE: ReadE = no;
	TRZA: ReadE = no;
	TLZA: ReadE = no;
	TRZN: ReadE = no;
	TLZN: ReadE = no;

	TDZ: ReadE = yes;
	TSZ: ReadE = yes;
	TDZE: ReadE = yes;
	TSZE: ReadE = yes;
	TDZA: ReadE = yes;
	TSZA: ReadE = yes;
	TDZN: ReadE = yes;
	TSZN: ReadE = yes;

	TRC: ReadE = no;
	TLC: ReadE = no;
	TRCE: ReadE = no;
	TLCE: ReadE = no;
	TRCA: ReadE = no;
	TLCA: ReadE = no;
	TRCN: ReadE = no;
	TLCN: ReadE = no;

	TDC: ReadE = yes;
	TSC: ReadE = yes;
	TDCE: ReadE = yes;
	TSCE: ReadE = yes;
	TDCA: ReadE = yes;
	TSCA: ReadE = yes;
	TDCN: ReadE = yes;
	TSCN: ReadE = yes;

	TRO: ReadE = no;
	TLO: ReadE = no;
	TROE: ReadE = no;
	TLOE: ReadE = no;
	TROA: ReadE = no;
	TLOA: ReadE = no;
	TRON: ReadE = no;
	TLON: ReadE = no;

	TDO: ReadE = yes;
	TSO: ReadE = yes;
	TDOE: ReadE = yes;
	TSOE: ReadE = yes;
	TDOA: ReadE = yes;
	TSOA: ReadE = yes;
	TDON: ReadE = yes;
	TSON: ReadE = yes;
	
	IO_INSTRUCTION:
	  if (user && !userIO)
	    dispatch = 'o710;
	  else
	    case (instIOOP(inst))
	      BLKI: dispatch = 'o700;  // C(E) <- I/O Data and AOB AC skip if not 0
	      DATAI: dispatch = 'o701; // C(E) <- I/O Data
	      BLKO: dispatch = 'o702;  // I/O Data <- C(E) and AOB AC skip if not 0
	      DATAO: { ReadE, dispatch } = { yes, 9'o703 }; // I/O Data <- C(E)
	      CONO: { dispatch, io_conditions } = { 9'o704, yes }; // I/O Cond <- 0,E
		
	      CONI:		// C(E) <- I/O Cond
		{ dispatch, condition_code, io_conditions } = { 9'o705, skip_never, yes };
	      CONSZ:		// E & Cond, Skip if 0
		{ dispatch, condition_code, Comp0, io_conditions } = { 9'o706, skipe, yes, yes };
	      CONSO:		// E | Cond, Skip if not 0
		{ dispatch, condition_code, Comp0, io_conditions } = { 9'o707, skipn, yes, yes };
	    endcase // case (IOOP(inst))

      endcase
   end // always @ (*)

endmodule // decode
