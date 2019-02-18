//	-*- mode: Verilog; fill-column: 96 -*-
//
// Instruction Decode ROM
//

`timescale 1 ns / 1 ns

`include "constants.vh"

module decode
  (
   input [`WORD] 	inst, // instruction
   input 		user, // user/exec mode
   input 		userIO, // userIO is enabled
   output reg [0:4] 	dispatch, // main instruction branch in the state machine
   output reg [`aluCMD] ALUinst, // the ALU operation needed by this instruction
   output reg 		ReadE, // the instruction reads the value from E
   output reg 		ReadAC, // the instruction puts AC on the Mmux
   output reg 		ReadOne, // select 1 on the Amux
   output reg 		ReadMinusOne, // select -1 on the Amux
   output reg 		ReadMonA, // select Mreg on the Amux
   output reg 		Aswap, // swap A input to ALU
   output reg 		Mswap, // swap M input to ALU
   output reg 		Cswap, // swap output from ALU
   output reg 		SetFlags, // the instruction sets the processor flags
   output reg 		WriteE, // the instruction writes to E
   output reg 		WriteAC, // the instruction writes to AC
   output reg 		WriteSelf, // the instruction writes to AC if AC != 0
   output reg [0:2] 	condition_code, // jump or skip condition
   output reg 		Comp0, // use jump_condition_0 instead of jump_condition
   output reg 		jump, // jump instead of skip (if the condition_code hits)
   output [`ADDR] 	io_dev	// the I/O device
   );

`include "opcodes.vh"
`include "decode.vh"

   localparam 
     no = 1'b0,
     yes = 1'b1;

   // build up an address for I/O devices from the device field in the
   // instruction and whether it's a data or conditions operation
   reg 			io_conditions;
   assign io_dev = { 9'b0, instIODEV(inst), 1'b0, io_conditions };

   always @(*) begin
      // defaults
      dispatch = dCommon;
      ALUinst = `aluSETA;
      ReadE = 0;
      ReadAC = 0;
      ReadOne = 0;
      ReadMinusOne = 0;
      ReadMonA = 0;
      Aswap = 0;
      Mswap = 0;
      Cswap = 0;
      SetFlags = 0;
      WriteSelf = 0;
      WriteE = 0;
      WriteAC = 0;
      condition_code = skip_never;
      Comp0 = 0;
      jump = 0;
      io_conditions = 0;

      casex (instOP(inst))	// synopsys full_case parallel_case

	LUUO01, LUUO02, LUUO03, LUUO04, LUUO05, LUUO06, LUUO07,
	LUUO10, LUUO11, LUUO12, LUUO13, LUUO14, LUUO15, LUUO16, LUUO17,
	LUUO20, LUUO21, LUUO22, LUUO23, LUUO24, LUUO25, LUUO26, LUUO27,
	LUUO30, LUUO31, LUUO32, LUUO33, LUUO34, LUUO35, LUUO36, LUUO37:
	  dispatch = dMUUO;
	  
	UUO00, 		  
	CALL, INITI, MUUO42, MUUO43, MUUO44, MUUO45, MUUO46, CALLI,
	OPEN, TTCALL, MUUO52, MUUO53, MUUO54, RENAME, IN, OUT,
	SETSTS, STATO, STATUS, GETSTS, INBUF, OUTBUF, INPUT, OUTPUT,
	CLOSE, RELEAS, MTAPE, UGETF, USETI, USETO, LOOKUP, ENTER:
	  dispatch = dMUUO;

	UJEN, UNK101, GFAD, GFSB, JSYS, ADJSP, GFMP, GFDV,
	DFAD, DFSB, DFMP, DFDV, DADD, DSUB, DMUL, DDIV,
	DMOVE, DMOVN, FIX, EXTEND, DMOVEM, DMOVNM, FIXR, FLTR,
	UFA, DFN, FSC,  // byte instructions come out of here
	FAD, FADL, FADM, FADB, FADR, FADRL, FADRM, FADRB,
	FSB, FSBL, FSBM, FSBB, FSBR, FSBRL, FSBRM, FSBRB,
	FMP, FMPL, FMPM, FMPB, FMPR, FMPRL, FMPRM, FMPRB,
	FDV, FDVL, FDVM, FDVB, FDVR, FDVRL, FDVRM, FDVRB:
	  dispatch = dUnassigned;

	//
	// Full Word MOVE instructions
	//

	MOVE:			// AC <- C(E)
	  { ALUinst, ReadE, Mswap, SetFlags, WriteAC } = { `aluSETM, yes, no, yes, yes };
	MOVEI:			// AC <- 0,E
	  { ALUinst, ReadE, Mswap, SetFlags, WriteAC } = { `aluSETM, no, no, yes, yes };
	MOVEM:			// C(E) <- AC
	  { ALUinst, ReadAC, Mswap, SetFlags, WriteE } = { `aluSETM, yes, no, yes, yes };
	MOVES:			// C(E) and AC (if not 0) <= C(E)
	  { ALUinst, ReadE, Mswap, SetFlags, WriteE, WriteSelf } = { `aluSETM, yes, no, yes, yes, yes };

	MOVS: 			// AC <- swap(C(E))
	  { ALUinst, ReadE, Mswap, SetFlags, WriteAC } = { `aluSETM, yes, yes, yes, yes };
	MOVSI: 			// AC <- E,0
	  { ALUinst, ReadE, Mswap, SetFlags, WriteAC } = { `aluSETM, no, yes, yes, yes };
	MOVSM: 			// C(E) <- swap(AC)
	  { ALUinst, ReadAC, Mswap, SetFlags, WriteE } = { `aluSETM, yes, yes, yes, yes };
	MOVSS:			// C(E) and AC (if not 0) <= swap(C(E))
	  { ALUinst, ReadE, Mswap, SetFlags, WriteE, WriteSelf } = { `aluSETM, yes, yes, yes, yes, yes };

	MOVN:			// AC <- -C(E)
	  { ALUinst, ReadE, Mswap, SetFlags, WriteAC } = { `aluNEGATE, yes, no, yes, yes };
	MOVNI:			// AC <- -0,E
	  { ALUinst, ReadE, Mswap, SetFlags, WriteAC } = { `aluNEGATE, no, no, yes, yes };
	MOVNM:			// C(E) <- -AC
	  { ALUinst, ReadAC, Mswap, SetFlags, WriteE } = { `aluNEGATE, yes, no, yes, yes };
	MOVNS:			// C(E) and AC (if not 0) <= -C(E)
	  { ALUinst, ReadE, Mswap, SetFlags, WriteE, WriteSelf } = { `aluNEGATE, yes, no, yes, yes, yes };

	MOVM:			// AC <- |C(E)|
	  { ALUinst, ReadE, Mswap, SetFlags, WriteAC } = { `aluMAGNITUDE, yes, no, yes, yes };
	MOVMI:			// AC <- |0,E|
	  { ALUinst, ReadE, Mswap, SetFlags, WriteAC } = { `aluMAGNITUDE, no, no, yes, yes };
	MOVMM:			// C(E) <- |AC|
	  { ALUinst, ReadAC, Mswap, SetFlags, WriteE } = { `aluMAGNITUDE, yes, no, yes, yes };
	MOVMS:			// C(E) and AC (if not 0) <= |C(E)|
	  { ALUinst, ReadE, Mswap, SetFlags, WriteE, WriteSelf } = { `aluMAGNITUDE, yes, no, yes, yes, yes };

	//
	// Integer Multiply and Divide
	//

	IMUL: { dispatch, ReadE, WriteE, WriteAC, SetFlags } = { dIMUL, yes, no, yes, yes };
	IMULI: { dispatch, ReadE, WriteE, WriteAC, SetFlags } = { dIMUL, no, no, yes, yes };
	IMULM: { dispatch, ReadE, WriteE, WriteAC, SetFlags } = { dIMUL, yes, yes, no, yes };
	IMULB: { dispatch, ReadE, WriteE, WriteAC, SetFlags } = { dIMUL, yes, yes, yes, yes };

	MUL: { dispatch, ReadE, WriteE, WriteAC, SetFlags } = { dMUL, yes, no, yes, yes };
	MULI: { dispatch, ReadE, WriteE, WriteAC, SetFlags } = { dMUL, no, no, yes, yes };
	MULM: { dispatch, ReadE, WriteE, WriteAC, SetFlags } = { dMUL, yes, yes, no, yes };
	MULB: { dispatch, ReadE, WriteE, WriteAC, SetFlags } = { dMUL, yes, yes, yes, yes };
	
	IDIV: {dispatch, ReadE, WriteE, WriteAC, SetFlags } = { dIDIV, yes, no, yes, yes };
	IDIVI: {dispatch, ReadE, WriteE, WriteAC, SetFlags } = { dIDIV, no, no, yes, yes };
	IDIVM: {dispatch, ReadE, WriteE, WriteAC, SetFlags } = { dIDIV, yes, yes, no, yes };
	IDIVB: {dispatch, ReadE, WriteE, WriteAC, SetFlags } = { dIDIV, yes, yes, yes, yes };
	
	DIV: {dispatch, ReadE, WriteE, WriteAC, SetFlags } = { dDIV, yes, no, yes, yes };
	DIVI: {dispatch, ReadE, WriteE, WriteAC, SetFlags } = { dDIV, no, no, yes, yes };
	DIVM: {dispatch, ReadE, WriteE, WriteAC, SetFlags } = { dDIV, yes, yes, no, yes };
	DIVB: {dispatch, ReadE, WriteE, WriteAC, SetFlags } = { dDIV, yes, yes, yes, yes };
	
	//
	// Shifts and Rotates
	//

	ASH: { ALUinst, WriteAC, SetFlags } = { `aluASH, yes, yes };
	ROT: { ALUinst, WriteAC, SetFlags } = { `aluROT, yes, no };
	LSH: { ALUinst, WriteAC, SetFlags } = { `aluLSH, yes, no };
	JFFO: dispatch = dJFFO;
	ASHC: { dispatch, ALUinst, SetFlags } = { dSHIFTC, `aluASHC, yes };
	ROTC: { dispatch, ALUinst} = { dSHIFTC, `aluROTC };
	LSHC: { dispatch, ALUinst} = { dSHIFTC, `aluLSHC };
`ifdef CIRC
	CIRC: decodec(ALUstep, `aluCIRC, E_word, 0, none, none, none); // I need to write a diagnostic for CIRC !!!
`endif

	EXCH:			// Exchange, AC <-> C(E)
	  { dispatch, ALUinst, ReadE, WriteE } = { dEXCH, `aluSETA, yes, yes };
	BLT:			// Block Transfer
	  dispatch = dBLT;
	
	AOBJP:			// Add One to Both halves of AC, Jump if Positive
	  { ALUinst, WriteAC, condition_code, Comp0, jump } = { `aluAOB, yes, skipge, yes, yes };
	AOBJN:			// Add One to Both halves of AC, Jump if Negative
	  { ALUinst, WriteAC, condition_code, Comp0, jump } = { `aluAOB, yes, skipl, yes, yes };

	JRST:			// Jump and Restory Flags
	  dispatch = dJRST;
	JFCL:			// Jump on Flag and Clear
	  dispatch = dJFCL;
	XCT: // Execute instruction at E (I don't read E here as it would read in the wrong mode)
	  dispatch = dXCT;

	
`ifdef NOTDEF
	MAP: ;
`endif

	PUSHJ:			// Push down and Jump: AC <- aob(AC) then C(AC) <- PSW,PC
	  dispatch = dPUSHJ;
	PUSH:			// AC <- aob(AC) then C(AC) <- C(E)
	  dispatch = dPUSH;
	POP:			// C(E) <- C(AC) then AC <- sob(AC)
	  dispatch = dPOP;
	POPJ:			// Pop up and Jump: 
	  dispatch = dPOPJ;

	JSR: 			// Jump to Subroutine: C(E) <- PSW,PC  PC <- E+1
	  dispatch = dJSR;
	JSP:			// Jump and Save PC: AC <- PSW,PC  PC <- E
	  dispatch = dJSP;
	JSA:			// Jump and Save AC: C(E) <- AC  AC <- E,PC  PC <- E+1
	  dispatch = dJSA;
	JRA:			// Jump and Restore AC: AC <- C(left(AC))  PC <- E
	  dispatch = dJRA;

	ADD:			// AC <- AC + C(E)
	  { ReadE, ALUinst, SetFlags, WriteAC } = { yes, `aluADD, yes, yes };
	ADDI:			// AC <- AC + 0,,E
	  { ReadE, ALUinst, SetFlags, WriteAC } = { no, `aluADD, yes, yes };
	ADDM:			// C(E) <- AC + C(E)
	  { ReadE, ALUinst, SetFlags, WriteE } = { yes, `aluADD, yes, yes };
	ADDB:			// AC and C(E) <- AC + C(E)
	  { ReadE, ALUinst, SetFlags, WriteE, WriteAC } = { yes, `aluADD, yes, yes, yes };

	SUB:			// AC <- AC - C(E)
	  { ReadE, ALUinst, SetFlags, WriteAC } = { yes, `aluSUB, yes, yes };
	SUBI:			// AC <- AC - 0,,E
	  { ReadE, ALUinst, SetFlags, WriteAC } = { no, `aluSUB, yes, yes };
	SUBM:			// C(E) <- AC - C(E)
	  { ReadE, ALUinst, SetFlags, WriteE } = { yes, `aluSUB, yes, yes };
	SUBB:			// AC and C(E) <- AC - C(E)
	  { ReadE, ALUinst, SetFlags, WriteE, WriteAC } = { yes, `aluSUB, yes, yes, yes };

	// Compare Accumulator to Immediate
	CAI: { ALUinst, ReadE, condition_code } = { `aluSUB, no, skip_never };
	CAIL: { ALUinst, ReadE, condition_code } = { `aluSUB, no, skipl };
	CAIE: { ALUinst, ReadE, condition_code } = { `aluSUB, no, skipe };
	CAILE: { ALUinst, ReadE, condition_code } = { `aluSUB, no, skiple };
	CAIA: { ALUinst, ReadE, condition_code } = { `aluSUB, no, skipa };
	CAIGE: { ALUinst, ReadE, condition_code } = { `aluSUB, no, skipge };
	CAIN: { ALUinst, ReadE, condition_code } = { `aluSUB, no, skipn };
	CAIG: { ALUinst, ReadE, condition_code } = { `aluSUB, no, skipg };
	// Compare Accumulator to Memory
	CAM: { ALUinst, ReadE, condition_code } = { `aluSUB, yes, skip_never };
	CAML: { ALUinst, ReadE, condition_code } = { `aluSUB, yes, skipl };
	CAME: { ALUinst, ReadE, condition_code } = { `aluSUB, yes, skipe };
	CAMLE: { ALUinst, ReadE, condition_code } = { `aluSUB, yes, skiple };
	CAMA: { ALUinst, ReadE, condition_code } = { `aluSUB, yes, skipa };
	CAMGE: { ALUinst, ReadE, condition_code } = { `aluSUB, yes, skipge };
	CAMN: { ALUinst, ReadE, condition_code } = { `aluSUB, yes, skipn };
	CAMG: { ALUinst, ReadE, condition_code } = { `aluSUB, yes, skipg };

	// Compare AC with 0
	JUMP: { ALUinst, ReadAC, condition_code, Comp0, jump } = { `aluSETM, yes, skip_never, yes, yes };
	JUMPL: { ALUinst, ReadAC, condition_code, Comp0, jump } = { `aluSETM, yes, skipl, yes, yes };
	JUMPE: { ALUinst, ReadAC, condition_code, Comp0, jump } = { `aluSETM, yes, skipe, yes, yes };
	JUMPLE: { ALUinst, ReadAC, condition_code, Comp0, jump } = { `aluSETM, yes, skiple, yes, yes };
	JUMPA: { ALUinst, ReadAC, condition_code, Comp0, jump } = { `aluSETM, yes, skipa, yes, yes };
	JUMPGE: { ALUinst, ReadAC, condition_code, Comp0, jump } = { `aluSETM, yes, skipge, yes, yes };
	JUMPN: { ALUinst, ReadAC, condition_code, Comp0, jump } = { `aluSETM, yes, skipn, yes, yes };
	JUMPG: { ALUinst, ReadAC, condition_code, Comp0, jump } = { `aluSETM, yes, skipg, yes, yes };

	// Add one to AC and jump
`define AOJ(cond) { ALUinst, ReadOne, ReadAC, WriteAC, SetFlags, condition_code, jump } = { `aluADD, yes, yes, yes, yes, cond, yes }
	AOJ: `AOJ(skip_never);
	AOJL: `AOJ(skipl);
	AOJE: `AOJ(skipe);
	AOJLE: `AOJ(skiple);
	AOJA: `AOJ(skipa);
	AOJGE: `AOJ(skipge);
	AOJN: `AOJ(skipn);
	AOJG: `AOJ(skipg);

	// Add one to Memory and skip
`define AOS(cond) { ALUinst, ReadOne, ReadE, WriteE, WriteSelf, SetFlags, condition_code, Comp0 } = { `aluADD, yes, yes, yes, yes, yes, cond, yes }
	AOS: `AOS(skip_never);
	AOSL: `AOS(skipl);
	AOSE: `AOS(skipe);
	AOSLE: `AOS(skiple);
	AOSA: `AOS(skipa);
	AOSGE: `AOS(skipge);
	AOSN: `AOS(skipn);
	AOSG: `AOS(skipg);

	// Adding -1 rather than Subtracting 1 makes the carry flags come out right
`define SOJ(cond) { ALUinst, ReadMinusOne, ReadAC, WriteAC, SetFlags, condition_code, jump } = { `aluADD, yes, yes, yes, yes, cond, yes }
	SOJ: `SOJ(skip_never);
	SOJL: `SOJ(skipl);
	SOJE: `SOJ(skipe);
	SOJLE: `SOJ(skiple);
	SOJA: `SOJ(skipa);
	SOJGE: `SOJ(skipge);
	SOJN: `SOJ(skipn);
	SOJG: `SOJ(skipg);

	// Adding -1 rather than Subtracting 1 makes the carry flags come out right
`define SOS(cond) { ALUinst, ReadMinusOne, ReadE, WriteE, WriteSelf, SetFlags, condition_code, Comp0 } = { `aluADD, yes, yes, yes, yes, yes, cond, yes }
	SOS: `SOS(skip_never);
	SOSL: `SOS(skipl);
	SOSE: `SOS(skipe);
	SOSLE: `SOS(skiple);
	SOSA: `SOS(skipa);
	SOSGE: `SOS(skipge);
	SOSN: `SOS(skipn);
	SOSG: `SOS(skipg);
	
	// Logical Operations
	// AC <- AC <op> 0,E
	SETZI: { ALUinst, WriteAC } = { `aluSETZ, yes };
	ANDI: { ALUinst, WriteAC } = { `aluAND, yes };
	ANDCAI: { ALUinst, WriteAC } = { `aluANDCA, yes };
	SETMI: { ALUinst, WriteAC } = { `aluSETM, yes };
	ANDCMI: { ALUinst, WriteAC } = { `aluANDCM, yes };
	SETAI: { ALUinst, WriteAC } = { `aluSETA, yes };
	XORI: { ALUinst, WriteAC } = { `aluXOR, yes };
	ORI: { ALUinst, WriteAC } = { `aluIOR, yes };
	ANDCBI: { ALUinst, WriteAC } = { `aluANDCB, yes };
	EQVI: { ALUinst, WriteAC } = { `aluEQV, yes };
	SETCAI: { ALUinst, WriteAC } = { `aluSETCA, yes };
	ORCAI: { ALUinst, WriteAC } = { `aluORCA, yes };
	SETCMI: { ALUinst, WriteAC } = { `aluSETCM, yes };
	ORCMI: { ALUinst, WriteAC } = { `aluORCM, yes };
	ORCBI: { ALUinst, WriteAC } = { `aluORCB, yes };
	SETOI: { ALUinst, WriteAC } = { `aluSETO, yes };
   
	 // AC <- AC <op> C(E)
	SETZ: { ALUinst, ReadE, WriteAC } = { `aluSETZ, yes, yes };
	AND: { ALUinst, ReadE, WriteAC } = { `aluAND, yes, yes };
	ANDCA: { ALUinst, ReadE, WriteAC } = { `aluANDCA, yes, yes };
	SETM: { ALUinst, ReadE, WriteAC } = { `aluSETM, yes, yes };
	ANDCM: { ALUinst, ReadE, WriteAC } = { `aluANDCM, yes, yes };
	SETA: { ALUinst, ReadE, WriteAC } = { `aluSETA, yes, yes };
	XOR: { ALUinst, ReadE, WriteAC } = { `aluXOR, yes, yes };
	OR: { ALUinst, ReadE, WriteAC } = { `aluIOR, yes, yes };
	ANDCB: { ALUinst, ReadE, WriteAC } = { `aluANDCB, yes, yes };
	EQV: { ALUinst, ReadE, WriteAC } = { `aluEQV, yes, yes };
	SETCA: { ALUinst, ReadE, WriteAC } = { `aluSETCA, yes, yes };
	ORCA: { ALUinst, ReadE, WriteAC } = { `aluORCA, yes, yes };
	SETCM: { ALUinst, ReadE, WriteAC } = { `aluSETCM, yes, yes };
	ORCM: { ALUinst, ReadE, WriteAC } = { `aluORCM, yes, yes };
	ORCB: { ALUinst, ReadE, WriteAC } = { `aluORCB, yes, yes };
	SETO: { ALUinst, ReadE, WriteAC } = { `aluSETO, yes, yes };
   
	// C(E) <- AC <op> C(E)
	SETZM: { ALUinst, ReadE, WriteE } = { `aluSETZ, yes, yes };
	ANDM: { ALUinst, ReadE, WriteE } = { `aluAND, yes, yes };
	ANDCAM: { ALUinst, ReadE, WriteE } = { `aluANDCA, yes, yes };
	SETMM: { ALUinst, ReadE, WriteE } = { `aluSETM, yes, yes };
	ANDCMM: { ALUinst, ReadE, WriteE } = { `aluANDCM, yes, yes };
	SETAM: { ALUinst, ReadE, WriteE } = { `aluSETA, yes, yes };
	XORM: { ALUinst, ReadE, WriteE } = { `aluXOR, yes, yes };
	ORM: { ALUinst, ReadE, WriteE } = { `aluIOR, yes, yes };
	ANDCBM: { ALUinst, ReadE, WriteE } = { `aluANDCB, yes, yes };
	EQVM: { ALUinst, ReadE, WriteE } = { `aluEQV, yes, yes };
	SETCAM: { ALUinst, ReadE, WriteE } = { `aluSETCA, yes, yes };
	ORCAM: { ALUinst, ReadE, WriteE } = { `aluORCA, yes, yes };
	SETCMM: { ALUinst, ReadE, WriteE } = { `aluSETCM, yes, yes };
	ORCMM: { ALUinst, ReadE, WriteE } = { `aluORCM, yes, yes };
	ORCBM: { ALUinst, ReadE, WriteE } = { `aluORCB, yes, yes };
	SETOM: { ALUinst, ReadE, WriteE } = { `aluSETO, yes, yes };
   
	// C(E) and AC <- AC <op> C(E)
	SETZB: { ALUinst, ReadE, WriteE, WriteAC } = { `aluSETZ, yes, yes, yes };
	ANDB: { ALUinst, ReadE, WriteE, WriteAC } = { `aluAND, yes, yes, yes };
	ANDCAB: { ALUinst, ReadE, WriteE, WriteAC } = { `aluANDCA, yes, yes, yes };
	SETMB: { ALUinst, ReadE, WriteE, WriteAC } = { `aluSETM, yes, yes, yes };
	ANDCMB: { ALUinst, ReadE, WriteE, WriteAC } = { `aluANDCM, yes, yes, yes };
	SETAB: { ALUinst, ReadE, WriteE, WriteAC } = { `aluSETA, yes, yes, yes };
	XORB: { ALUinst, ReadE, WriteE, WriteAC } = { `aluXOR, yes, yes, yes };
	ORB: { ALUinst, ReadE, WriteE, WriteAC } = { `aluIOR, yes, yes, yes };
	ANDCBB: { ALUinst, ReadE, WriteE, WriteAC } = { `aluANDCB, yes, yes, yes };
	EQVB: { ALUinst, ReadE, WriteE, WriteAC } = { `aluEQV, yes, yes, yes };
	SETCAB: { ALUinst, ReadE, WriteE, WriteAC } = { `aluSETCA, yes, yes, yes };
	ORCAB: { ALUinst, ReadE, WriteE, WriteAC } = { `aluORCA, yes, yes, yes };
	SETCMB: { ALUinst, ReadE, WriteE, WriteAC } = { `aluSETCM, yes, yes, yes };
	ORCMB: { ALUinst, ReadE, WriteE, WriteAC } = { `aluORCM, yes, yes, yes };
	ORCBB: { ALUinst, ReadE, WriteE, WriteAC } = { `aluORCB, yes, yes, yes };
	SETOB: { ALUinst, ReadE, WriteE, WriteAC } = { `aluSETO, yes, yes, yes };

	IBP:			// Increment Byte Pointer
	  { ALUinst, ReadE, WriteE } = { `aluIBP, yes, yes };
	LDB:			// Load Byte
	  { dispatch, ReadE } = { dLDB, yes };
	ILDB:			// Increment and Load Byte
	  { dispatch, ReadE, WriteE } = { dILDB, yes, yes };
	DPB:			// Deposit Byte
	  { dispatch, ReadE } = { dDPB, yes };
	IDPB:			// Increment and Deposit Byte
	  { dispatch, ReadE, WriteE } = { dIDPB, yes, yes };

	SKIP: { ALUinst, ReadE, WriteSelf, condition_code, Comp0 } = { `aluSETM, yes, yes, skip_never, yes };
	SKIPL: { ALUinst, ReadE, WriteSelf, condition_code, Comp0 } = { `aluSETM, yes, yes, skipl, yes };
	SKIPE: { ALUinst, ReadE, WriteSelf, condition_code, Comp0 } = { `aluSETM, yes, yes, skipe, yes };
	SKIPLE: { ALUinst, ReadE, WriteSelf, condition_code, Comp0 } = { `aluSETM, yes, yes, skiple, yes };
	SKIPA: { ALUinst, ReadE, WriteSelf, condition_code, Comp0 } = { `aluSETM, yes, yes, skipa, yes };
	SKIPGE: { ALUinst, ReadE, WriteSelf, condition_code, Comp0 } = { `aluSETM, yes, yes, skipge, yes };
	SKIPN: { ALUinst, ReadE, WriteSelf, condition_code, Comp0 } = { `aluSETM, yes, yes, skipn, yes };
	SKIPG: { ALUinst, ReadE, WriteSelf, condition_code, Comp0 } = { `aluSETM, yes, yes, skipg, yes };
	
	// Half-word moves - Halfword[LR][LR][- Zeros Ones Extend][- Immediate Memory Self]
	//   Mode     Suffix    Source     Destination
	//  Basic                (E)           AC
	//  Immediate   I        0,E           AC
	//  Memory      M         AC           (E)
	//  Self        S        (E)           (E) and AC if AC nonzero
`define HMOVE(alu, aswap, mswap, cswap, readac, readm, reade, writeac, writes, writee) { ALUinst, Aswap, Mswap, Cswap, ReadAC, ReadMonA, ReadE, WriteAC, WriteSelf, WriteE } = { alu, aswap, mswap, cswap, readac, readm, reade, writeac, writes, writee }

	HLL: `HMOVE(`aluHMN, no, no, no, no, no, yes, yes, no, no);
	HLLI: `HMOVE(`aluHMN, no, no, no, no, no, no, yes, no, no);
	HLLM: `HMOVE(`aluHMN, no, no, no, yes, yes, yes, no, no, yes);
	HLLS: `HMOVE(`aluHMN, no, no, no, no, yes, yes, no, yes, yes);
	HRL: `HMOVE(`aluHMN, no, yes, no, no, no, yes, yes, no, no);
	HRLI: `HMOVE(`aluHMN, no, yes, no, no, no, no, yes, no, no);
	HRLM: `HMOVE(`aluHMN, no, yes, no, yes, yes, yes, no, no, yes);
	HRLS: `HMOVE(`aluHMN, no, yes, no, no, yes, yes, no, yes, yes);
		      
	HLLZ: `HMOVE(`aluHMZ, no, no, no, no, no, yes, yes, no, no);
	HLLZI: `HMOVE(`aluHMZ, no, no, no, no, no, no, yes, no, no);
	HLLZM: `HMOVE(`aluHMZ, no, no, no, yes, yes, yes, no, no, yes);
	HLLZS: `HMOVE(`aluHMZ, no, no, no, no, yes, yes, no, yes, yes);
	HRLZ: `HMOVE(`aluHMZ, no, yes, no, no, no, yes, yes, no, no);
	HRLZI: `HMOVE(`aluHMZ, no, yes, no, no, no, no, yes, no, no);
	HRLZM: `HMOVE(`aluHMZ, no, yes, no, yes, yes, yes, no, no, yes);
	HRLZS: `HMOVE(`aluHMZ, no, yes, no, no, yes, yes, no, yes, yes);
	
	HLLO: `HMOVE(`aluHMO, no, no, no, no, no, yes, yes, no, no);
	HLLOI: `HMOVE(`aluHMO, no, no, no, no, no, no, yes, no, no);
	HLLOM: `HMOVE(`aluHMO, no, no, no, yes, yes, yes, no, no, yes);
	HLLOS: `HMOVE(`aluHMO, no, no, no, no, yes, yes, no, yes, yes);
	HRLO: `HMOVE(`aluHMO, no, yes, no, no, no, yes, yes, no, no);
	HRLOI: `HMOVE(`aluHMO, no, yes, no, no, no, no, yes, no, no);
	HRLOM: `HMOVE(`aluHMO, no, yes, no, yes, yes, yes, no, no, yes);
	HRLOS: `HMOVE(`aluHMO, no, yes, no, no, yes, yes, no, yes, yes);
	
	HLLE: `HMOVE(`aluHME, no, no, no, no, no, yes, yes, no, no);
	HLLEI: `HMOVE(`aluHME, no, no, no, no, no, no, yes, no, no);
	HLLEM: `HMOVE(`aluHME, no, no, no, yes, yes, yes, no, no, yes);
	HLLES: `HMOVE(`aluHME, no, no, no, no, yes, yes, no, yes, yes);
	HRLE: `HMOVE(`aluHME, no, yes, no, no, no, yes, yes, no, no);
	HRLEI: `HMOVE(`aluHME, no, yes, no, no, no, no, yes, no, no);
	HRLEM: `HMOVE(`aluHME, no, yes, no, yes, yes, yes, no, no, yes);
	HRLES: `HMOVE(`aluHME, no, yes, no, no, yes, yes, no, yes, yes);

	HRR: `HMOVE(`aluHMN, yes, yes, yes, no, no, yes, yes, no, no);
	HRRI: `HMOVE(`aluHMN, yes, yes, yes, no, no, no, yes, no, no);
	HRRM: `HMOVE(`aluHMN, yes, yes, yes, yes, yes, yes, no, no, yes);
	HRRS: `HMOVE(`aluHMN, yes, yes, yes, no, yes, yes, no, yes, yes);
	HLR: `HMOVE(`aluHMN, yes, no, yes, no, no, yes, yes, no, no);
	HLRI: `HMOVE(`aluHMN, yes, no, yes, no, no, no, yes, no, no);
	HLRM: `HMOVE(`aluHMN, yes, no, yes, yes, yes, yes, no, no, yes);
	HLRS: `HMOVE(`aluHMN, yes, no, yes, no, yes, yes, no, yes, yes);
		      
	HRRZ: `HMOVE(`aluHMZ, yes, yes, yes, no, no, yes, yes, no, no);
	HRRZI: `HMOVE(`aluHMZ, yes, yes, yes, no, no, no, yes, no, no);
	HRRZM: `HMOVE(`aluHMZ, yes, yes, yes, yes, yes, yes, no, no, yes);
	HRRZS: `HMOVE(`aluHMZ, yes, yes, yes, no, yes, yes, no, yes, yes);
	HLRZ: `HMOVE(`aluHMZ, yes, no, yes, no, no, yes, yes, no, no);
	HLRZI: `HMOVE(`aluHMZ, yes, no, yes, no, no, no, yes, no, no);
	HLRZM: `HMOVE(`aluHMZ, yes, no, yes, yes, yes, yes, no, no, yes);
	HLRZS: `HMOVE(`aluHMZ, yes, no, yes, no, yes, yes, no, yes, yes);
	
	HRRO: `HMOVE(`aluHMO, yes, yes, yes, no, no, yes, yes, no, no);
	HRROI: `HMOVE(`aluHMO, yes, yes, yes, no, no, no, yes, no, no);
	HRROM: `HMOVE(`aluHMO, yes, yes, yes, yes, yes, yes, no, no, yes);
	HRROS: `HMOVE(`aluHMO, yes, yes, yes, no, yes, yes, no, yes, yes);
	HLRO: `HMOVE(`aluHMO, yes, no, yes, no, no, yes, yes, no, no);
	HLROI: `HMOVE(`aluHMO, yes, no, yes, no, no, no, yes, no, no);
	HLROM: `HMOVE(`aluHMO, yes, no, yes, yes, yes, yes, no, no, yes);
	HLROS: `HMOVE(`aluHMO, yes, no, yes, no, yes, yes, no, yes, yes);
	
	HRRE: `HMOVE(`aluHME, yes, yes, yes, no, no, yes, yes, no, no);
	HRREI: `HMOVE(`aluHME, yes, yes, yes, no, no, no, yes, no, no);
	HRREM: `HMOVE(`aluHME, yes, yes, yes, yes, yes, yes, no, no, yes);
	HRRES: `HMOVE(`aluHME, yes, yes, yes, no, yes, yes, no, yes, yes);
	HLRE: `HMOVE(`aluHME, yes, no, yes, no, no, yes, yes, no, no);
	HLREI: `HMOVE(`aluHME, yes, no, yes, no, no, no, yes, no, no);
	HLREM: `HMOVE(`aluHME, yes, no, yes, yes, yes, yes, no, no, yes);
	HLRES: `HMOVE(`aluHME, yes, no, yes, no, yes, yes, no, yes, yes);

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

	// repurpose condition_code here
`define TEST(alu, reade, mswap, writea, cc) { dispatch, ALUinst, ReadE, Mswap, WriteAC, condition_code } = { dTEST, alu, reade, mswap, writea, cc }

	TRN: `TEST(`aluSETA, no, no, no, skip_never);
	TLN: `TEST(`aluSETA, no, yes, no, skip_never);
	TRNE: `TEST(`aluSETA, no, no, no, skipe);
	TLNE: `TEST(`aluSETA, no, yes, no, skipe);
	TRNA: `TEST(`aluSETA, no, no, no, skipa);
	TLNA: `TEST(`aluSETA, no, yes, no, skipa);
	TRNN: `TEST(`aluSETA, no, no, no, skipn);
	TLNN: `TEST(`aluSETA, no, yes, no, skipn);

	TDN: `TEST(`aluSETA, yes, no, no, skip_never);
	TSN: `TEST(`aluSETA, yes, yes, no, skip_never);
	TDNE: `TEST(`aluSETA, yes, no, no, skipe);
	TSNE: `TEST(`aluSETA, yes, yes, no, skipe);
	TDNA: `TEST(`aluSETA, yes, no, no, skipa);
	TSNA: `TEST(`aluSETA, yes, yes, no, skipa);
	TDNN: `TEST(`aluSETA, yes, no, no, skipn);
	TSNN: `TEST(`aluSETA, yes, yes, no, skipn);

	TRZ: `TEST(`aluANDCM, no, no, yes, skip_never);
	TLZ: `TEST(`aluANDCM, no, yes, yes, skip_never);
	TRZE: `TEST(`aluANDCM, no, no, yes, skipe);
	TLZE: `TEST(`aluANDCM, no, yes, yes, skipe);
	TRZA: `TEST(`aluANDCM, no, no, yes, skipa);
	TLZA: `TEST(`aluANDCM, no, yes, yes, skipa);
	TRZN: `TEST(`aluANDCM, no, no, yes, skipn);
	TLZN: `TEST(`aluANDCM, no, yes, yes, skipn);

	TDZ: `TEST(`aluANDCM, yes, no, yes, skip_never);
	TSZ: `TEST(`aluANDCM, yes, yes, yes, skip_never);
	TDZE: `TEST(`aluANDCM, yes, no, yes, skipe);
	TSZE: `TEST(`aluANDCM, yes, yes, yes, skipe);
	TDZA: `TEST(`aluANDCM, yes, no, yes, skipa);
	TSZA: `TEST(`aluANDCM, yes, yes, yes, skipa);
	TDZN: `TEST(`aluANDCM, yes, no, yes, skipn);
	TSZN: `TEST(`aluANDCM, yes, yes, yes, skipn);

	TRC: `TEST(`aluXOR, no, no, yes, skip_never);
	TLC: `TEST(`aluXOR, no, yes, yes, skip_never);
	TRCE: `TEST(`aluXOR, no, no, yes, skipe);
	TLCE: `TEST(`aluXOR, no, yes, yes, skipe);
	TRCA: `TEST(`aluXOR, no, no, yes, skipa);
	TLCA: `TEST(`aluXOR, no, yes, yes, skipa);
	TRCN: `TEST(`aluXOR, no, no, yes, skipn);
	TLCN: `TEST(`aluXOR, no, yes, yes, skipn);

	TDC: `TEST(`aluXOR, yes, no, yes, skip_never);
	TSC: `TEST(`aluXOR, yes, yes, yes, skip_never);
	TDCE: `TEST(`aluXOR, yes, no, yes, skipe);
	TSCE: `TEST(`aluXOR, yes, yes, yes, skipe);
	TDCA: `TEST(`aluXOR, yes, no, yes, skipa);
	TSCA: `TEST(`aluXOR, yes, yes, yes, skipa);
	TDCN: `TEST(`aluXOR, yes, no, yes, skipn);
	TSCN: `TEST(`aluXOR, yes, yes, yes, skipn);

	TRO: `TEST(`aluIOR, no, no, yes, skip_never);
	TLO: `TEST(`aluIOR, no, yes, yes, skip_never);
	TROE: `TEST(`aluIOR, no, no, yes, skipe);
	TLOE: `TEST(`aluIOR, no, yes, yes, skipe);
	TROA: `TEST(`aluIOR, no, no, yes, skipa);
	TLOA: `TEST(`aluIOR, no, yes, yes, skipa);
	TRON: `TEST(`aluIOR, no, no, yes, skipn);
	TLON: `TEST(`aluIOR, no, yes, yes, skipn);

	TDO: `TEST(`aluIOR, yes, no, yes, skip_never);
	TSO: `TEST(`aluIOR, yes, yes, yes, skip_never);
	TDOE: `TEST(`aluIOR, yes, no, yes, skipe);
	TSOE: `TEST(`aluIOR, yes, yes, yes, skipe);
	TDOA: `TEST(`aluIOR, yes, no, yes, skipa);
	TSOA: `TEST(`aluIOR, yes, yes, yes, skipa);
	TDON: `TEST(`aluIOR, yes, no, yes, skipn);
	TSON: `TEST(`aluIOR, yes, yes, yes, skipn);
	
	IO_INSTRUCTION:
	  if (user && !userIO)
	    dispatch = dMUUO;
	  else
	    case (instIOOP(inst))
	      CONO:		// I/O Cond <- 0,E
		{ dispatch, io_conditions } = { dIOwrite, yes };
	      CONI:		// C(E) <- I/O Cond
		{ dispatch, WriteE, condition_code, io_conditions } = { dIOread, yes, skip_never, yes };
	      CONSZ:		// E & Cond, Skip if 0
		{ dispatch, ALUinst, condition_code, Comp0, io_conditions } = { dIOread, `aluAND, skipe, yes, yes };
	      CONSO:		// E | Cond, Skip if not 0
		{ dispatch, ALUinst, condition_code, Comp0, io_conditions } = { dIOread, `aluIOR, skipn, yes, yes };
	      DATAO:		// I/O Data <- C(E)
		{ dispatch, ALUinst, ReadE } = { dIOwrite, `aluSETM, yes };
	      DATAI:		// C(E) <- I/O Data
		{ dispatch, WriteE } = { dIOread, yes };
	      BLKI, BLKO:	// Block In/Out -- gotta get to these one day !!!
		dispatch = dUnassigned;
	    endcase // case (IOOP(inst))

	default:
	  dispatch = dUnassigned;
      endcase
   end // always @ (*)

endmodule // decode
