//	-*- mode: Verilog; fill-column: 90 -*-
//
// PDP-10 disassembler, for debugging
//
// 2013-02-02 dab	initial version

// This is not a standalone file but expected to be included at just the right place in APR

reg [6*8:0] opcodes[0:9'o677];
reg [6*8:0] io_opcodes[0:7];

initial begin
   opcodes[9'o0] = "UUO00 ";
   opcodes[9'o1] = "LUUO01";
   opcodes[9'o2] = "LUUO02";
   opcodes[9'o3] = "LUUO03";
   opcodes[9'o4] = "LUUO04";
   opcodes[9'o5] = "LUUO05";
   opcodes[9'o6] = "LUUO06";
   opcodes[9'o7] = "LUUO07";
    
   opcodes[9'o10] = "LUUO10";
   opcodes[9'o11] = "LUUO11";
   opcodes[9'o12] = "LUUO12";
   opcodes[9'o13] = "LUUO13";
   opcodes[9'o14] = "LUUO14";
   opcodes[9'o15] = "LUUO15";
   opcodes[9'o16] = "LUUO16";
   opcodes[9'o17] = "LUUO17";
    
   opcodes[9'o20] = "LUUO20";
   opcodes[9'o21] = "LUUO21";
   opcodes[9'o22] = "LUUO22";
   opcodes[9'o23] = "LUUO23";
   opcodes[9'o24] = "LUUO24";
   opcodes[9'o25] = "LUUO25";
   opcodes[9'o26] = "LUUO26";
   opcodes[9'o27] = "LUUO27";
    
   opcodes[9'o30] = "LUUO30";
   opcodes[9'o31] = "LUUO31";
   opcodes[9'o32] = "LUUO32";
   opcodes[9'o33] = "LUUO33";
   opcodes[9'o34] = "LUUO34";
   opcodes[9'o35] = "LUUO35";
   opcodes[9'o36] = "LUUO36";
   opcodes[9'o37] = "LUUO37";
    
   opcodes[9'o40] = "CALL  ";
   opcodes[9'o41] = "INITI ";
   opcodes[9'o42] = "MUUO42";
   opcodes[9'o43] = "MUUO43";
   opcodes[9'o44] = "MUUO44";
   opcodes[9'o45] = "MUUO45";
   opcodes[9'o46] = "MUUO46";
   opcodes[9'o47] = "CALLI ";
    
   opcodes[9'o50] = "OPEN  ";
   opcodes[9'o51] = "TTCALL";
   opcodes[9'o52] = "MUUO52";
   opcodes[9'o53] = "MUUO53";
   opcodes[9'o54] = "MUUO54";
   opcodes[9'o55] = "RENAME";
   opcodes[9'o56] = "IN	   ";
   opcodes[9'o57] = "OUT   ";
    
   opcodes[9'o60] = "SETSTS";
   opcodes[9'o61] = "STATO ";
   opcodes[9'o62] = "STATUS";
   opcodes[9'o63] = "GETSTS";
   opcodes[9'o64] = "INBUF ";
   opcodes[9'o65] = "OUTBUF";
   opcodes[9'o66] = "INPUT ";
   opcodes[9'o67] = "OUTPUT";
    
   opcodes[9'o70] = "CLOSE ";
   opcodes[9'o71] = "RELEAS";
   opcodes[9'o72] = "MTAPE ";
   opcodes[9'o73] = "UGETF ";
   opcodes[9'o74] = "USETI ";
   opcodes[9'o75] = "USETO ";
   opcodes[9'o76] = "LOOKUP";
   opcodes[9'o77] = "ENTER ";
    
// Floating Point, Byte Manipulation, Other
   opcodes[9'o100] = "UJEN  ";
   opcodes[9'o101] = "UNK101";
   opcodes[9'o102] = "GFAD  ";
   opcodes[9'o103] = "GFSB  ";
   opcodes[9'o104] = "JSYS  ";
   opcodes[9'o105] = "ADJSP ";
   opcodes[9'o106] = "GFMP  ";
   opcodes[9'o107] = "GFDV  ";
    
   opcodes[9'o110] = "DFAD  ";
   opcodes[9'o111] = "DFSB  ";
   opcodes[9'o112] = "DFMP  ";
   opcodes[9'o113] = "DFDV  ";
   opcodes[9'o114] = "DADD  ";
   opcodes[9'o115] = "DSUB  ";
   opcodes[9'o116] = "DMUL  ";
   opcodes[9'o117] = "DDIV  ";
    
   opcodes[9'o120] = "DMOVE ";
   opcodes[9'o121] = "DMOVN ";
   opcodes[9'o122] = "FIX   ";
   opcodes[9'o123] = "EXTEND";
   opcodes[9'o124] = "DMOVEM";
   opcodes[9'o125] = "DMOVNM";
   opcodes[9'o126] = "FIXR  ";
   opcodes[9'o127] = "FLTR  ";
    
   opcodes[9'o130] = "UFA   ";
   opcodes[9'o131] = "DFN   ";
   opcodes[9'o132] = "FSC   ";
   opcodes[9'o133] = "IBP   ";
   opcodes[9'o134] = "ILDB  ";
   opcodes[9'o135] = "LDB   ";
   opcodes[9'o136] = "IDPB  ";
   opcodes[9'o137] = "DPB   ";
    
   opcodes[9'o140] = "FAD   ";
   opcodes[9'o141] = "FADL  ";
   opcodes[9'o142] = "FADM  ";
   opcodes[9'o143] = "FADB  ";
   opcodes[9'o144] = "FADR  ";
   opcodes[9'o145] = "FADRL ";
   opcodes[9'o146] = "FADRM ";
   opcodes[9'o147] = "FADRB ";
    
   opcodes[9'o150] = "FSB   ";
   opcodes[9'o151] = "FSBL  ";
   opcodes[9'o152] = "FSBM  ";
   opcodes[9'o153] = "FSBB  ";
   opcodes[9'o154] = "FSBR  ";
   opcodes[9'o155] = "FSBRL ";
   opcodes[9'o156] = "FSBRM ";
   opcodes[9'o157] = "FSBRB ";
    
   opcodes[9'o160] = "FMP   ";
   opcodes[9'o161] = "FMPL  ";
   opcodes[9'o162] = "FMPM  ";
   opcodes[9'o163] = "FMPB  ";
   opcodes[9'o164] = "FMPR  ";
   opcodes[9'o165] = "FMPRL ";
   opcodes[9'o166] = "FMPRM ";
   opcodes[9'o167] = "FMPRB ";
    
   opcodes[9'o170] = "FDV   ";
   opcodes[9'o171] = "FDVL  ";
   opcodes[9'o172] = "FDVM  ";
   opcodes[9'o173] = "FDVB  ";
   opcodes[9'o174] = "FDVR  ";
   opcodes[9'o175] = "FDVRL ";
   opcodes[9'o176] = "FDVRM ";
   opcodes[9'o177] = "FDVRB ";
    
// Integer Arithmetic, Jump To Subroutine
   opcodes[9'o200] = "MOVE  ";
   opcodes[9'o201] = "MOVEI ";
   opcodes[9'o202] = "MOVEM ";
   opcodes[9'o203] = "MOVES ";
   opcodes[9'o204] = "MOVS  ";
   opcodes[9'o205] = "MOVSI ";
   opcodes[9'o206] = "MOVSM ";
   opcodes[9'o207] = "MOVSS ";
    
   opcodes[9'o210] = "MOVN  ";
   opcodes[9'o211] = "MOVNI ";
   opcodes[9'o212] = "MOVNM ";
   opcodes[9'o213] = "MOVNS ";
   opcodes[9'o214] = "MOVM  ";
   opcodes[9'o215] = "MOVMI ";
   opcodes[9'o216] = "MOVMM ";
   opcodes[9'o217] = "MOVMS ";
    
   opcodes[9'o220] = "IMUL  ";
   opcodes[9'o221] = "IMULI ";
   opcodes[9'o222] = "IMULM ";
   opcodes[9'o223] = "IMULB ";
   opcodes[9'o224] = "MUL   ";
   opcodes[9'o225] = "MULI  ";
   opcodes[9'o226] = "MULM  ";
   opcodes[9'o227] = "MULB  ";
    
   opcodes[9'o230] = "IDIV  ";
   opcodes[9'o231] = "IDIVI ";
   opcodes[9'o232] = "IDIVM ";
   opcodes[9'o233] = "IDIVB ";
   opcodes[9'o234] = "DIV   ";
   opcodes[9'o235] = "DIVI  ";
   opcodes[9'o236] = "DIVM  ";
   opcodes[9'o237] = "DIVB  ";
    
   opcodes[9'o240] = "ASH   ";
   opcodes[9'o241] = "ROT   ";
   opcodes[9'o242] = "LSH   ";
   opcodes[9'o243] = "JFFO  ";
   opcodes[9'o244] = "ASHC  ";
   opcodes[9'o245] = "ROTC  ";
   opcodes[9'o246] = "LSHC  ";
   opcodes[9'o247] = "CIRC  ";
    
   opcodes[9'o250] = "EXCH  ";
   opcodes[9'o251] = "BLT   ";
   opcodes[9'o252] = "AOBJP ";
   opcodes[9'o253] = "AOBJN ";
   opcodes[9'o254] = "JRST  ";
   opcodes[9'o255] = "JFCL  ";
   opcodes[9'o256] = "XCT   ";
   opcodes[9'o257] = "MAP   ";
    
   opcodes[9'o260] = "PUSHJ ";
   opcodes[9'o261] = "PUSH  ";
   opcodes[9'o262] = "POP   ";
   opcodes[9'o263] = "POPJ  ";
   opcodes[9'o264] = "JSR   ";
   opcodes[9'o265] = "JSP   ";
   opcodes[9'o266] = "JSA   ";
   opcodes[9'o267] = "JRA   ";
    
   opcodes[9'o270] = "ADD   ";
   opcodes[9'o271] = "ADDI  ";
   opcodes[9'o272] = "ADDM  ";
   opcodes[9'o273] = "ADDB  ";
   opcodes[9'o274] = "SUB   ";
   opcodes[9'o275] = "SUBI  ";
   opcodes[9'o276] = "SUBM  ";
   opcodes[9'o277] = "SUBB  ";
    
// Hop, Skip, and Jump (codes 3x0 do not skip or jump)
   opcodes[9'o300] = "CAI   ";
   opcodes[9'o301] = "CAIL  ";
   opcodes[9'o302] = "CAIE  ";
   opcodes[9'o303] = "CAILE ";
   opcodes[9'o304] = "CAIA  ";
   opcodes[9'o305] = "CAIGE ";
   opcodes[9'o306] = "CAIN  ";
   opcodes[9'o307] = "CAIG  ";
    
   opcodes[9'o310] = "CAM   ";
   opcodes[9'o311] = "CAML  ";
   opcodes[9'o312] = "CAME  ";
   opcodes[9'o313] = "CAMLE ";
   opcodes[9'o314] = "CAMA  ";
   opcodes[9'o315] = "CAMGE ";
   opcodes[9'o316] = "CAMN  ";
   opcodes[9'o317] = "CAMG  ";
    
   opcodes[9'o320] = "JUMP  ";
   opcodes[9'o321] = "JUMPL ";
   opcodes[9'o322] = "JUMPE ";
   opcodes[9'o323] = "JUMPLE";
   opcodes[9'o324] = "JUMPA ";
   opcodes[9'o325] = "JUMPGE";
   opcodes[9'o326] = "JUMPN ";
   opcodes[9'o327] = "JUMPG ";
    
   opcodes[9'o330] = "SKIP  ";
   opcodes[9'o331] = "SKIPL ";
   opcodes[9'o332] = "SKIPE ";
   opcodes[9'o333] = "SKIPLE";
   opcodes[9'o334] = "SKIPA ";
   opcodes[9'o335] = "SKIPGE";
   opcodes[9'o336] = "SKIPN ";
   opcodes[9'o337] = "SKIPG ";
    
   opcodes[9'o340] = "AOJ   ";
   opcodes[9'o341] = "AOJL  ";
   opcodes[9'o342] = "AOJE  ";
   opcodes[9'o343] = "AOJLE ";
   opcodes[9'o344] = "AOJA  ";
   opcodes[9'o345] = "AOJGE ";
   opcodes[9'o346] = "AOJN  ";
   opcodes[9'o347] = "AOJG  ";
    
   opcodes[9'o350] = "AOS   ";
   opcodes[9'o351] = "AOSL  ";
   opcodes[9'o352] = "AOSE  ";
   opcodes[9'o353] = "AOSLE ";
   opcodes[9'o354] = "AOSA  ";
   opcodes[9'o355] = "AOSGE ";
   opcodes[9'o356] = "AOSN  ";
   opcodes[9'o357] = "AOSG  ";
    
   opcodes[9'o360] = "SOJ   ";
   opcodes[9'o361] = "SOJL  ";
   opcodes[9'o362] = "SOJE  ";
   opcodes[9'o363] = "SOJLE ";
   opcodes[9'o364] = "SOJA  ";
   opcodes[9'o365] = "SOJGE ";
   opcodes[9'o366] = "SOJN  ";
   opcodes[9'o367] = "SOJG  ";
    
   opcodes[9'o370] = "SOS   ";
   opcodes[9'o371] = "SOSL  ";
   opcodes[9'o372] = "SOSE  ";
   opcodes[9'o373] = "SOSLE ";
   opcodes[9'o374] = "SOSA  ";
   opcodes[9'o375] = "SOSGE ";
   opcodes[9'o376] = "SOSN  ";
   opcodes[9'o377] = "SOSG  ";
    
// Two-argument Logical Operations
   opcodes[9'o400] = "SETZ  ";
   opcodes[9'o401] = "SETZI ";
   opcodes[9'o402] = "SETZM ";
   opcodes[9'o403] = "SETZB ";
   opcodes[9'o404] = "AND   ";
   opcodes[9'o405] = "ANDI  ";
   opcodes[9'o406] = "ANDM  ";
   opcodes[9'o407] = "ANDB  ";
    
   opcodes[9'o410] = "ANDCA ";
   opcodes[9'o411] = "ANDCAI";
   opcodes[9'o412] = "ANDCAM";
   opcodes[9'o413] = "ANDCAB";
   opcodes[9'o414] = "SETM  ";
   opcodes[9'o415] = "SETMI ";
   opcodes[9'o416] = "SETMM ";
   opcodes[9'o417] = "SETMB ";
    
   opcodes[9'o420] = "ANDCM ";
   opcodes[9'o421] = "ANDCMI";
   opcodes[9'o422] = "ANDCMM";
   opcodes[9'o423] = "ANDCMB";
   opcodes[9'o424] = "SETA  ";
   opcodes[9'o425] = "SETAI ";
   opcodes[9'o426] = "SETAM ";
   opcodes[9'o427] = "SETAB ";
    
   opcodes[9'o430] = "XOR   ";
   opcodes[9'o431] = "XORI  ";
   opcodes[9'o432] = "XORM  ";
   opcodes[9'o433] = "XORB  ";
   opcodes[9'o434] = "OR    ";
   opcodes[9'o435] = "ORI   ";
   opcodes[9'o436] = "ORM   ";
   opcodes[9'o437] = "ORB   ";
    
   opcodes[9'o440] = "ANDCB ";
   opcodes[9'o441] = "ANDCBI";
   opcodes[9'o442] = "ANDCBM";
   opcodes[9'o443] = "ANDCBB";
   opcodes[9'o444] = "EQV   ";
   opcodes[9'o445] = "EQVI  ";
   opcodes[9'o446] = "EQVM  ";
   opcodes[9'o447] = "EQVB  ";
    
   opcodes[9'o450] = "SETCA ";
   opcodes[9'o451] = "SETCAI";
   opcodes[9'o452] = "SETCAM";
   opcodes[9'o453] = "SETCAB";
   opcodes[9'o454] = "ORCA  ";
   opcodes[9'o455] = "ORCAI ";
   opcodes[9'o456] = "ORCAM ";
   opcodes[9'o457] = "ORCAB ";
    
   opcodes[9'o460] = "SETCM ";
   opcodes[9'o461] = "SETCMI";
   opcodes[9'o462] = "SETCMM";
   opcodes[9'o463] = "SETCMB";
   opcodes[9'o464] = "ORCM  ";
   opcodes[9'o465] = "ORCMI ";
   opcodes[9'o466] = "ORCMM ";
   opcodes[9'o467] = "ORCMB ";
    
   opcodes[9'o470] = "ORCB  ";
   opcodes[9'o471] = "ORCBI ";
   opcodes[9'o472] = "ORCBM ";
   opcodes[9'o473] = "ORCBB ";
   opcodes[9'o474] = "SETO  ";
   opcodes[9'o475] = "SETOI ";
   opcodes[9'o476] = "SETOM ";
   opcodes[9'o477] = "SETOB ";
    
// Half Word {Left,Right} to {Left,Right} with {nochange,Zero,Ones,Extend}, {ac,Immediate,Memory,Self}
   opcodes[9'o500] = "HLL   ";
   opcodes[9'o501] = "HLLI  ";
   opcodes[9'o502] = "HLLM  ";
   opcodes[9'o503] = "HLLS  ";
   opcodes[9'o504] = "HRL   ";
   opcodes[9'o505] = "HRLI  ";
   opcodes[9'o506] = "HRLM  ";
   opcodes[9'o507] = "HRLS  ";
    
   opcodes[9'o510] = "HLLZ  ";
   opcodes[9'o511] = "HLLZI ";
   opcodes[9'o512] = "HLLZM ";
   opcodes[9'o513] = "HLLZS ";
   opcodes[9'o514] = "HRLZ  ";
   opcodes[9'o515] = "HRLZI ";
   opcodes[9'o516] = "HRLZM ";
   opcodes[9'o517] = "HRLZS ";
    
   opcodes[9'o520] = "HLLO  ";
   opcodes[9'o521] = "HLLOI ";
   opcodes[9'o522] = "HLLOM ";
   opcodes[9'o523] = "HLLOS ";
   opcodes[9'o524] = "HRLO  ";
   opcodes[9'o525] = "HRLOI ";
   opcodes[9'o526] = "HRLOM ";
   opcodes[9'o527] = "HRLOS ";
    
   opcodes[9'o530] = "HLLE  ";
   opcodes[9'o531] = "HLLEI ";
   opcodes[9'o532] = "HLLEM ";
   opcodes[9'o533] = "HLLES ";
   opcodes[9'o534] = "HRLE  ";
   opcodes[9'o535] = "HRLEI ";
   opcodes[9'o536] = "HRLEM ";
   opcodes[9'o537] = "HRLES ";
    
   opcodes[9'o540] = "HRR   ";
   opcodes[9'o541] = "HRRI  ";
   opcodes[9'o542] = "HRRM  ";
   opcodes[9'o543] = "HRRS  ";
   opcodes[9'o544] = "HLR   ";
   opcodes[9'o545] = "HLRI  ";
   opcodes[9'o546] = "HLRM  ";
   opcodes[9'o547] = "HLRS  ";
    
   opcodes[9'o550] = "HRRZ  ";
   opcodes[9'o551] = "HRRZI ";
   opcodes[9'o552] = "HRRZM ";
   opcodes[9'o553] = "HRRZS ";
   opcodes[9'o554] = "HLRZ  ";
   opcodes[9'o555] = "HLRZI ";
   opcodes[9'o556] = "HLRZM ";
   opcodes[9'o557] = "HLRZS ";
    
   opcodes[9'o560] = "HRRO  ";
   opcodes[9'o561] = "HRROI ";
   opcodes[9'o562] = "HRROM ";
   opcodes[9'o563] = "HRROS ";
   opcodes[9'o564] = "HLRO  ";
   opcodes[9'o565] = "HLROI ";
   opcodes[9'o566] = "HLROM ";
   opcodes[9'o567] = "HLROS ";
    
   opcodes[9'o570] = "HRRE  ";
   opcodes[9'o571] = "HRREI ";
   opcodes[9'o572] = "HRREM ";
   opcodes[9'o573] = "HRRES ";
   opcodes[9'o574] = "HLRE  ";
   opcodes[9'o575] = "HLREI ";
   opcodes[9'o576] = "HLREM ";
   opcodes[9'o577] = "HLRES ";
    
// Test bits, {Right,Left,Direct,Swapped} with
// {Nochange,Zero,Complement,One} and skip if the masked bits were
// {noskip,Equal,Nonzero,Always}
   opcodes[9'o600] = "TRN   ";
   opcodes[9'o601] = "TLN   ";
   opcodes[9'o602] = "TRNE  ";
   opcodes[9'o603] = "TLNE  ";
   opcodes[9'o604] = "TRNA  ";
   opcodes[9'o605] = "TLNA  ";
   opcodes[9'o606] = "TRNN  ";
   opcodes[9'o607] = "TLNN  ";
    
   opcodes[9'o610] = "TDN   ";
   opcodes[9'o611] = "TSN   ";
   opcodes[9'o612] = "TDNE  ";
   opcodes[9'o613] = "TSNE  ";
   opcodes[9'o614] = "TDNA  ";
   opcodes[9'o615] = "TSNA  ";
   opcodes[9'o616] = "TDNN  ";
   opcodes[9'o617] = "TSNN  ";
    
   opcodes[9'o620] = "TRZ   ";
   opcodes[9'o621] = "TLZ   ";
   opcodes[9'o622] = "TRZE  ";
   opcodes[9'o623] = "TLZE  ";
   opcodes[9'o624] = "TRZA  ";
   opcodes[9'o625] = "TLZA  ";
   opcodes[9'o626] = "TRZN  ";
   opcodes[9'o627] = "TLZN  ";
    
   opcodes[9'o630] = "TDZ   ";
   opcodes[9'o631] = "TSZ   ";
   opcodes[9'o632] = "TDZE  ";
   opcodes[9'o633] = "TSZE  ";
   opcodes[9'o634] = "TDZA  ";
   opcodes[9'o635] = "TSZA  ";
   opcodes[9'o636] = "TDZN  ";
   opcodes[9'o637] = "TSZN  ";
    
   opcodes[9'o640] = "TRC   ";
   opcodes[9'o641] = "TLC   ";
   opcodes[9'o642] = "TRCE  ";
   opcodes[9'o643] = "TLCE  ";
   opcodes[9'o644] = "TRCA  ";
   opcodes[9'o645] = "TLCA  ";
   opcodes[9'o646] = "TRCN  ";
   opcodes[9'o647] = "TLCN  ";
    
   opcodes[9'o650] = "TDC   ";
   opcodes[9'o651] = "TSC   ";
   opcodes[9'o652] = "TDCE  ";
   opcodes[9'o653] = "TSCE  ";
   opcodes[9'o654] = "TDCA  ";
   opcodes[9'o655] = "TSCA  ";
   opcodes[9'o656] = "TDCN  ";
   opcodes[9'o657] = "TSCN  ";
    
   opcodes[9'o660] = "TRO   ";
   opcodes[9'o661] = "TLO   ";
   opcodes[9'o662] = "TROE  ";
   opcodes[9'o663] = "TLOE  ";
   opcodes[9'o664] = "TROA  ";
   opcodes[9'o665] = "TLOA  ";
   opcodes[9'o666] = "TRON  ";
   opcodes[9'o667] = "TLON  ";
    
   opcodes[9'o670] = "TDO   ";
   opcodes[9'o671] = "TSO   ";
   opcodes[9'o672] = "TDOE  ";
   opcodes[9'o673] = "TSOE  ";
   opcodes[9'o674] = "TDOA  ";
   opcodes[9'o675] = "TSOA  ";
   opcodes[9'o676] = "TDON  ";
   opcodes[9'o677] = "TSON  ";

   io_opcodes[0]   = "BLKI  ";
   io_opcodes[1]   = "DATAI ";
   io_opcodes[2]   = "BLKO  ";
   io_opcodes[3]   = "DATAO ";
   io_opcodes[4]   = "CONO  ";
   io_opcodes[5]   = "CONI  ";
   io_opcodes[6]   = "CONSZ ";
   io_opcodes[7]   = "CONSO ";

end // initial begin

   function [23*8:1] disasm;
      input [`WORD] inst;
      reg [23*8:1] 	result;
      reg [8:1] 	indirect;
      reg [4*8:1] 	index;
      reg [3*8:1] 	ac;
      reg [0:6] 	dev;

      reg [`HWORD] 	Y;
      reg [0:3] 	A;
      reg [0:3] 	X;
 	
      begin
	 Y = instY(inst);
	 A = instA(inst);
	 X = instX(inst);
	 
	 indirect = instI(inst) ? "@" : " ";
	 if (instA(inst) == 0)
	   ac = "   ";
	 else
	   $sformat(ac, "%o,", A);
	 if (instX(inst) == 0)
	   index = "    ";
	 else
	   $sformat(index, "(%o)", X);

	 dev = instIODEV(inst)*4;
	       
	 if (instOP(inst) < 9'o700) begin
	    $sformat(result, "%s  %s%s%o%s", opcodes[instOP(inst)], ac, indirect, Y, index);
	    disasm = result;
	 end else begin
	    // I/O Instruction
	    $sformat(result, "%s %o,%s%o%s", io_opcodes[instIOOP(inst)], dev, indirect, Y, index);
	    disasm = result;
	 end
      end
   endfunction

