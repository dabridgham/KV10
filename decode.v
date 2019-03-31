//	-*- mode: Verilog; fill-column: 96 -*-
//
// Instruction Decode ROM
//

`include "constants.vh"

`timescale 1 ns / 1 ns

module decode
  (
   input [`WORD]    inst, // instruction
   input 	    user, // user/exec mode
   input 	    userIO, // userIO is enabled
   output reg [8:0] dispatch, // main instruction branch in the state machine
   output reg 	    ReadE, // the instruction reads the value from E
   output reg [0:2] condition_code, // jump or skip condition
   output [`DEVICE] io_dev, // the I/O device
   output reg 	    io_cond, // if the I/O is for the Device Conditions
   output reg 	    int_jump, // interrupt instruction is a jump
   output reg 	    int_skip, //  interrupt instruction is a skip
   output reg 	    xct	      // it's the XCT instruction
   );

`include "opcodes.vh"
`include "decode.vh"
`include "functions.vh"

   localparam 
     no = 1'b0,
     yes = 1'b1;

   assign io_dev = instIODEV(inst); // Send the I/O Device number back

   always @(*) begin
      // defaults
      dispatch = instOP(inst);
      ReadE = no;
      condition_code = skip_never;
      io_cond = no;
      int_jump = no;
      int_skip = no;
      xct = no;

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

	IBP: ReadE = yes;	// Increment Byte Pointer
	ILDB: ReadE = yes;	// Increment and Load Byte
	LDB: ReadE = yes;	// Load Byte
	IDPB: ReadE = yes;	// Increment and Deposit Byte
	DPB: ReadE = yes;	// Deposit Byte

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
	
	// Shifts and Rotates
	ASH, ROT, LSH, JFFO, ASHC, ROTC, LSHC, CIRC:
	  ;

	EXCH: ReadE = yes;	// Exchange, AC <-> C(E)
	BLT: ;			// Block Transfer
	
	AOBJP: condition_code = skipge; // Add One to Both halves of AC, Jump if Positive
	AOBJN: condition_code = skipl; // Add One to Both halves of AC, Jump if Negative

	JRST:			// Jump and Restory Flags
	  // Special optimization for JRST.
	  if (!(user & ~userIO & (inst[9] | inst[10]))) begin
	     int_jump = yes;
	     dispatch = 9'o720 | { 5'b0, inst[9:12] };
	  end
	// if the JRST is illegal, either halt or dismiss interrupt when in user mode, then the
	// dispatch goes to the normal spot in the dispatch table where it's treated as an MUUO

	JFCL: ;			// Jump on Flag and Clear

	// ReadE here will read E with memory reference class D1.  Should it be IF? !!!
	XCT: { ReadE, xct } = { yes, yes };	// Execute instruction at E
	
	MAP: ;

	PUSHJ: int_jump = yes;	// Push down and Jump: AC <- aob(AC) then C(AC) <- PSW,PC
	PUSH: ReadE = yes;	// AC <- aob(AC) then C(AC) <- C(E)
	POP: ;			// C(E) <- C(AC) then AC <- sob(AC)
	POPJ: ;			// Pop up and Jump: 

	JSR: int_jump = yes;	// Jump to Subroutine: C(E) <- PSW,PC  PC <- E+1
	JSP: int_jump = yes;	// Jump and Save PC: AC <- PSW,PC  PC <- E
	JSA: int_jump = yes;	// Jump and Save AC: C(E) <- AC  AC <- E,PC  PC <- E+1
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
	JUMP: condition_code = skip_never;
	JUMPL: condition_code = skipl;
	JUMPE: condition_code = skipe;
	JUMPLE: condition_code = skiple;
	JUMPA: condition_code = skipa;
	JUMPGE: condition_code = skipge;
	JUMPN: condition_code = skipn;
	JUMPG: condition_code = skipg;

	// Add one to AC and jump
	AOJ: condition_code = skip_never;
	AOJL: condition_code = skipl;
	AOJE: condition_code = skipe;
	AOJLE: condition_code = skiple;
	AOJA: condition_code = skipa;
	AOJGE: condition_code = skipge;
	AOJN: condition_code = skipn;
	AOJG: condition_code = skipg;

	// Add one to Memory and skip
	AOS: { ReadE, condition_code, int_skip } = { yes, skip_never, yes };
	AOSL: { ReadE, condition_code, int_skip } = { yes, skipl, yes };
	AOSE: { ReadE, condition_code, int_skip } = { yes, skipe, yes };
	AOSLE: { ReadE, condition_code, int_skip } = { yes, skiple, yes };
	AOSA: { ReadE, condition_code, int_skip } = { yes, skipa, yes };
	AOSGE: { ReadE, condition_code, int_skip } = { yes, skipge, yes };
	AOSN: { ReadE, condition_code, int_skip } = { yes, skipn, yes };
	AOSG: { ReadE, condition_code, int_skip } = { yes, skipg, yes };

	// Subtract One from AC and jump
	SOJ: condition_code = skip_never;
	SOJL: condition_code = skipl;
	SOJE: condition_code = skipe;
	SOJLE: condition_code = skiple;
	SOJA: condition_code = skipa;
	SOJGE: condition_code = skipge;
	SOJN: condition_code = skipn;
	SOJG: condition_code = skipg;

	// Subtract One from Memory and skip
	SOS: { ReadE, condition_code, int_skip } = { yes, skip_never, yes };
	SOSL: { ReadE, condition_code, int_skip } = { yes, skipl, yes };
	SOSE: { ReadE, condition_code, int_skip } = { yes, skipe, yes };
	SOSLE: { ReadE, condition_code, int_skip } = { yes, skiple, yes };
	SOSA: { ReadE, condition_code, int_skip } = { yes, skipa, yes };
	SOSGE: { ReadE, condition_code, int_skip } = { yes, skipge, yes };
	SOSN: { ReadE, condition_code, int_skip } = { yes, skipn, yes };
	SOSG: { ReadE, condition_code, int_skip } = { yes, skipg, yes };
	
	// Logical Operations
	// AC <- AC <op> 0,E
	SETZI, ANDI, ANDCAI, SETMI, ANDCMI, SETAI, XORI, ORI, ANDCBI, 
	  EQVI, SETCAI, ORCAI, SETCMI, ORCMI, ORCBI, SETOI:
	    ;
   
	// AC <- AC <op> C(E)
	// SETZ, for instance, doesn't really need to Read E.  Optimize !!!
	SETZ, AND, ANDCA, SETM, ANDCM, SETA, XOR, OR,
	  ANDCB, EQV, SETCA, ORCA, SETCM, ORCM, ORCB, SETO: 
	    ReadE = yes;
   
	// C(E) <- AC <op> C(E)
	SETZM, ANDM, ANDCAM, SETMM, ANDCMM, SETAM, XORM, ORM, 
	  ANDCBM, EQVM, SETCAM, ORCAM, SETCMM, ORCMM, ORCBM, SETOM: 
	    ReadE = yes;
   
	// C(E) and AC <- AC <op> C(E)
	SETZB, ANDB, ANDCAB, SETMB, ANDCMB, SETAB, XORB, ORB, 
	  ANDCBB, EQVB, SETCAB, ORCAB, SETCMB, ORCMB, ORCBB, SETOB: 
	    ReadE = yes;

	// Compare Memory with 0 and skip
	SKIP: { ReadE, condition_code, int_skip } = { yes, skip_never, yes };
	SKIPL: { ReadE, condition_code, int_skip } = { yes, skipl, yes };
	SKIPE: { ReadE, condition_code, int_skip } = { yes, skipe, yes };
	SKIPLE: { ReadE, condition_code, int_skip } = { yes, skiple, yes };
	SKIPA: { ReadE, condition_code, int_skip } = { yes, skipa, yes };
	SKIPGE: { ReadE, condition_code, int_skip } = { yes, skipge, yes };
	SKIPN: { ReadE, condition_code, int_skip } = { yes, skipn, yes };
	SKIPG: { ReadE, condition_code, int_skip } = { yes, skipg, yes };
	
	// Half-word moves - Halfword[LR][LR][- Zeros Ones Extend][- Immediate Memory Self]
	//   Mode     Suffix    Source     Destination
	//  Basic                (E)           AC
	//  Immediate   I        0,E           AC
	//  Memory      M         AC           (E)
	//  Self        S        (E)           (E) and AC if AC nonzero
	HLL, HLLM, HLLS: ReadE = yes;
	HLLI: ReadE = no;
	HRL, HRLM, HRLS: ReadE = yes;
	HRLI: ReadE = no;
		      
	HLLZ, HLLZM, HLLZS: ReadE = yes;
	HLLZI: ReadE = no;
	HRLZ, HRLZM, HRLZS: ReadE = yes;
	HRLZI: ReadE = no;
	
	HLLO, HLLOM, HLLOS: ReadE = yes;
	HLLOI: ReadE = no;
	HRLO, HRLOM, HRLOS: ReadE = yes;
	HRLOI: ReadE = no;
	
	HLLE, HLLEM, HLLES: ReadE = yes;
	HLLEI: ReadE = no;
	HRLE, HRLEM, HRLES: ReadE = yes;
	HRLEI: ReadE = no;

	HRR, HRRM, HRRS: ReadE = yes;
	HRRI: ReadE = no;
	HLR, HLRM, HLRS: ReadE = yes;
	HLRI: ReadE = no;
		      
	HRRZ, HRRZM, HRRZS: ReadE = yes;
	HRRZI: ReadE = no;
	HLRZ, HLRZM, HLRZS: ReadE = yes;
	HLRZI: ReadE = no;
	
	HRRO, HRROM, HRROS: ReadE = yes;
	HRROI: ReadE = no;
	HLRO, HLROM, HLROS: ReadE = yes;
	HLROI: ReadE = no;
	
	HRRE, HRREM, HRRES: ReadE = yes;
	HRREI: ReadE = no;
	HLRE, HLREM, HLRES: ReadE = yes;
	HLREI: ReadE = no;

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
	TRN, TLN, TRNE, TLNE, TRNA, TLNA, TRNN, TLNN: ReadE = no;
	TDN, TSN, TDNE, TSNE, TDNA, TSNA, TDNN, TSNN: ReadE = yes;
	TRZ, TLZ, TRZE, TLZE, TRZA, TLZA, TRZN, TLZN: ReadE = no;
	TDZ, TSZ, TDZE, TSZE, TDZA, TSZA, TDZN, TSZN: ReadE = yes;
	TRC, TLC, TRCE, TLCE, TRCA, TLCA, TRCN, TLCN: ReadE = no;
	TDC, TSC, TDCE, TSCE, TDCA, TSCA, TDCN, TSCN: ReadE = yes;
	TRO, TLO, TROE, TLOE, TROA, TLOA, TRON, TLON: ReadE = no;
	TDO, TSO, TDOE, TSOE, TDOA, TSOA, TDON, TSON: ReadE = yes;
	
	IO_INSTRUCTION:
	  if (user && !userIO)
	    dispatch = 'o710;
	  else
	    case (instIOOP(inst))
	      BLKI: {dispatch, int_skip } = { 9'o700, yes }; // C(E) <- I/O Data and AOB AC skip if not 0
	      DATAI: dispatch = 'o701; // C(E) <- I/O Data
	      BLKO: { dispatch, int_skip } = { 9'o702, yes }; // I/O Data <- C(E) and AOB AC skip if not 0
	      DATAO: { dispatch, ReadE } = { 9'o703, yes }; // I/O Data <- C(E)

	      CONO: { dispatch, io_cond } = { 9'o704, yes }; // I/O Cond <- 0,E
		
	      CONI:		// C(E) <- I/O Cond
		{ dispatch, condition_code, io_cond } = { 9'o705, skip_never, yes };
	      CONSZ:		// E & Cond, Skip if 0
		{ dispatch, condition_code, io_cond, int_skip } = { 9'o706, skipe, yes, yes };
	      CONSO:		// E | Cond, Skip if not 0
		{ dispatch, condition_code, io_cond, int_skip } = { 9'o707, skipn, yes, yes };
	    endcase // case (IOOP(inst))

      endcase
   end // always @ (*)

endmodule // decode
