//	-*- mode: Verilog; fill-column: 90 -*-
//
// PDP-10 Opcode definitions
//
// 2013-02-01 dab	initial version

// Monitor UUOs and Local UUOs
localparam UUO00 = 9'o0;
localparam LUUO01 = 9'o1;
localparam LUUO02 = 9'o2;
localparam LUUO03 = 9'o3;
localparam LUUO04 = 9'o4;
localparam LUUO05 = 9'o5;
localparam LUUO06 = 9'o6;
localparam LUUO07 = 9'o7;
 
localparam LUUO10 = 9'o10;
localparam LUUO11 = 9'o11;
localparam LUUO12 = 9'o12;
localparam LUUO13 = 9'o13;
localparam LUUO14 = 9'o14;
localparam LUUO15 = 9'o15;
localparam LUUO16 = 9'o16;
localparam LUUO17 = 9'o17;
 
localparam LUUO20 = 9'o20;
localparam LUUO21 = 9'o21;
localparam LUUO22 = 9'o22;
localparam LUUO23 = 9'o23;
localparam LUUO24 = 9'o24;
localparam LUUO25 = 9'o25;
localparam LUUO26 = 9'o26;
localparam LUUO27 = 9'o27;
 
localparam LUUO30 = 9'o30;
localparam LUUO31 = 9'o31;
localparam LUUO32 = 9'o32;
localparam LUUO33 = 9'o33;
localparam LUUO34 = 9'o34;
localparam LUUO35 = 9'o35;
localparam LUUO36 = 9'o36;
localparam LUUO37 = 9'o37;
 
localparam CALL = 9'o40;
localparam INITI = 9'o41;
localparam MUUO42 = 9'o42;
localparam MUUO43 = 9'o43;
localparam MUUO44 = 9'o44;
localparam MUUO45 = 9'o45;
localparam MUUO46 = 9'o46;
localparam CALLI = 9'o47;
 
localparam OPEN = 9'o50;
localparam TTCALL = 9'o51;
localparam MUUO52 = 9'o52;
localparam MUUO53 = 9'o53;
localparam MUUO54 = 9'o54;
localparam RENAME = 9'o55;
localparam IN = 9'o56;
localparam OUT = 9'o57;
 
localparam SETSTS = 9'o60;
localparam STATO = 9'o61;
localparam STATUS = 9'o62;
localparam GETSTS = 9'o63;
localparam INBUF = 9'o64;
localparam OUTBUF = 9'o65;
localparam INPUT = 9'o66;
localparam OUTPUT = 9'o67;
 
localparam CLOSE = 9'o70;
localparam RELEAS = 9'o71;
localparam MTAPE = 9'o72;
localparam UGETF = 9'o73;
localparam USETI = 9'o74;
localparam USETO = 9'o75;
localparam LOOKUP = 9'o76;
localparam ENTER = 9'o77;
 
// Floating Point, Byte Manipulation, Other
localparam UJEN = 9'o100;
localparam UNK101 = 9'o101;
localparam GFAD = 9'o102;
localparam GFSB = 9'o103;
localparam JSYS = 9'o104;
localparam ADJSP = 9'o105;
localparam GFMP = 9'o106;
localparam GFDV = 9'o107;
 
localparam DFAD = 9'o110;
localparam DFSB = 9'o111;
localparam DFMP = 9'o112;
localparam DFDV = 9'o113;
localparam DADD = 9'o114;
localparam DSUB = 9'o115;
localparam DMUL = 9'o116;
localparam DDIV = 9'o117;
 
localparam DMOVE = 9'o120;
localparam DMOVN = 9'o121;
localparam FIX = 9'o122;
localparam EXTEND = 9'o123;
localparam DMOVEM = 9'o124;
localparam DMOVNM = 9'o125;
localparam FIXR = 9'o126;
localparam FLTR = 9'o127;
 
localparam UFA = 9'o130;
localparam DFN = 9'o131;
localparam FSC = 9'o132;
localparam IBP = 9'o133;
localparam ILDB = 9'o134;
localparam LDB = 9'o135;
localparam IDPB = 9'o136;
localparam DPB = 9'o137;
 
localparam FAD = 9'o140;
localparam FADL = 9'o141;
localparam FADM = 9'o142;
localparam FADB = 9'o143;
localparam FADR = 9'o144;
localparam FADRL = 9'o145;
localparam FADRM = 9'o146;
localparam FADRB = 9'o147;
 
localparam FSB = 9'o150;
localparam FSBL = 9'o151;
localparam FSBM = 9'o152;
localparam FSBB = 9'o153;
localparam FSBR = 9'o154;
localparam FSBRL = 9'o155;
localparam FSBRM = 9'o156;
localparam FSBRB = 9'o157;
 
localparam FMP = 9'o160;
localparam FMPL = 9'o161;
localparam FMPM = 9'o162;
localparam FMPB = 9'o163;
localparam FMPR = 9'o164;
localparam FMPRL = 9'o165;
localparam FMPRM = 9'o166;
localparam FMPRB = 9'o167;
 
localparam FDV = 9'o170;
localparam FDVL = 9'o171;
localparam FDVM = 9'o172;
localparam FDVB = 9'o173;
localparam FDVR = 9'o174;
localparam FDVRL = 9'o175;
localparam FDVRM = 9'o176;
localparam FDVRB = 9'o177;
 
// Integer Arithmetic, Jump To Subroutine
localparam MOVE = 9'o200;
localparam MOVEI = 9'o201;
localparam MOVEM = 9'o202;
localparam MOVES = 9'o203;
localparam MOVS = 9'o204;
localparam MOVSI = 9'o205;
localparam MOVSM = 9'o206;
localparam MOVSS = 9'o207;
 
localparam MOVN = 9'o210;
localparam MOVNI = 9'o211;
localparam MOVNM = 9'o212;
localparam MOVNS = 9'o213;
localparam MOVM = 9'o214;
localparam MOVMI = 9'o215;
localparam MOVMM = 9'o216;
localparam MOVMS = 9'o217;
 
localparam IMUL = 9'o220;
localparam IMULI = 9'o221;
localparam IMULM = 9'o222;
localparam IMULB = 9'o223;
localparam MUL = 9'o224;
localparam MULI = 9'o225;
localparam MULM = 9'o226;
localparam MULB = 9'o227;
 
localparam IDIV = 9'o230;
localparam IDIVI = 9'o231;
localparam IDIVM = 9'o232;
localparam IDIVB = 9'o233;
localparam DIV = 9'o234;
localparam DIVI = 9'o235;
localparam DIVM = 9'o236;
localparam DIVB = 9'o237;
 
localparam ASH = 9'o240;
localparam ROT = 9'o241;
localparam LSH = 9'o242;
localparam JFFO = 9'o243;
localparam ASHC = 9'o244;
localparam ROTC = 9'o245;
localparam LSHC = 9'o246;
localparam CIRC = 9'o247;
 
localparam EXCH = 9'o250;
localparam BLT = 9'o251;
localparam AOBJP = 9'o252;
localparam AOBJN = 9'o253;
localparam JRST = 9'o254;
localparam JFCL = 9'o255;
localparam XCT = 9'o256;
localparam MAP = 9'o257;
 
localparam PUSHJ = 9'o260;
localparam PUSH = 9'o261;
localparam POP = 9'o262;
localparam POPJ = 9'o263;
localparam JSR = 9'o264;
localparam JSP = 9'o265;
localparam JSA = 9'o266;
localparam JRA = 9'o267;
 
localparam ADD = 9'o270;
localparam ADDI = 9'o271;
localparam ADDM = 9'o272;
localparam ADDB = 9'o273;
localparam SUB = 9'o274;
localparam SUBI = 9'o275;
localparam SUBM = 9'o276;
localparam SUBB = 9'o277;
 
// Hop, Skip, and Jump (codes 3x0 do not skip or jump)
localparam CAI = 9'o300;
localparam CAIL = 9'o301;
localparam CAIE = 9'o302;
localparam CAILE = 9'o303;
localparam CAIA = 9'o304;
localparam CAIGE = 9'o305;
localparam CAIN = 9'o306;
localparam CAIG = 9'o307;
 
localparam CAM = 9'o310;
localparam CAML = 9'o311;
localparam CAME = 9'o312;
localparam CAMLE = 9'o313;
localparam CAMA = 9'o314;
localparam CAMGE = 9'o315;
localparam CAMN = 9'o316;
localparam CAMG = 9'o317;
 
localparam JUMP = 9'o320;
localparam JUMPL = 9'o321;
localparam JUMPE = 9'o322;
localparam JUMPLE = 9'o323;
localparam JUMPA = 9'o324;
localparam JUMPGE = 9'o325;
localparam JUMPN = 9'o326;
localparam JUMPG = 9'o327;
 
localparam SKIP = 9'o330;
localparam SKIPL = 9'o331;
localparam SKIPE = 9'o332;
localparam SKIPLE = 9'o333;
localparam SKIPA = 9'o334;
localparam SKIPGE = 9'o335;
localparam SKIPN = 9'o336;
localparam SKIPG = 9'o337;
 
localparam AOJ = 9'o340;
localparam AOJL = 9'o341;
localparam AOJE = 9'o342;
localparam AOJLE = 9'o343;
localparam AOJA = 9'o344;
localparam AOJGE = 9'o345;
localparam AOJN = 9'o346;
localparam AOJG = 9'o347;
 
localparam AOS = 9'o350;
localparam AOSL = 9'o351;
localparam AOSE = 9'o352;
localparam AOSLE = 9'o353;
localparam AOSA = 9'o354;
localparam AOSGE = 9'o355;
localparam AOSN = 9'o356;
localparam AOSG = 9'o357;
 
localparam SOJ = 9'o360;
localparam SOJL = 9'o361;
localparam SOJE = 9'o362;
localparam SOJLE = 9'o363;
localparam SOJA = 9'o364;
localparam SOJGE = 9'o365;
localparam SOJN = 9'o366;
localparam SOJG = 9'o367;
 
localparam SOS = 9'o370;
localparam SOSL = 9'o371;
localparam SOSE = 9'o372;
localparam SOSLE = 9'o373;
localparam SOSA = 9'o374;
localparam SOSGE = 9'o375;
localparam SOSN = 9'o376;
localparam SOSG = 9'o377;
 
// Two-argument Logical Operations
localparam SETZ = 9'o400;
localparam SETZI = 9'o401;
localparam SETZM = 9'o402;
localparam SETZB = 9'o403;
localparam AND = 9'o404;
localparam ANDI = 9'o405;
localparam ANDM = 9'o406;
localparam ANDB = 9'o407;
 
localparam ANDCA = 9'o410;
localparam ANDCAI = 9'o411;
localparam ANDCAM = 9'o412;
localparam ANDCAB = 9'o413;
localparam SETM = 9'o414;
localparam SETMI = 9'o415;
localparam SETMM = 9'o416;
localparam SETMB = 9'o417;
 
localparam ANDCM = 9'o420;
localparam ANDCMI = 9'o421;
localparam ANDCMM = 9'o422;
localparam ANDCMB = 9'o423;
localparam SETA = 9'o424;
localparam SETAI = 9'o425;
localparam SETAM = 9'o426;
localparam SETAB = 9'o427;
 
localparam XOR = 9'o430;
localparam XORI = 9'o431;
localparam XORM = 9'o432;
localparam XORB = 9'o433;
localparam OR = 9'o434;
localparam ORI = 9'o435;
localparam ORM = 9'o436;
localparam ORB = 9'o437;
 
localparam ANDCB = 9'o440;
localparam ANDCBI = 9'o441;
localparam ANDCBM = 9'o442;
localparam ANDCBB = 9'o443;
localparam EQV = 9'o444;
localparam EQVI = 9'o445;
localparam EQVM = 9'o446;
localparam EQVB = 9'o447;
 
localparam SETCA = 9'o450;
localparam SETCAI = 9'o451;
localparam SETCAM = 9'o452;
localparam SETCAB = 9'o453;
localparam ORCA = 9'o454;
localparam ORCAI = 9'o455;
localparam ORCAM = 9'o456;
localparam ORCAB = 9'o457;
 
localparam SETCM = 9'o460;
localparam SETCMI = 9'o461;
localparam SETCMM = 9'o462;
localparam SETCMB = 9'o463;
localparam ORCM = 9'o464;
localparam ORCMI = 9'o465;
localparam ORCMM = 9'o466;
localparam ORCMB = 9'o467;
 
localparam ORCB = 9'o470;
localparam ORCBI = 9'o471;
localparam ORCBM = 9'o472;
localparam ORCBB = 9'o473;
localparam SETO = 9'o474;
localparam SETOI = 9'o475;
localparam SETOM = 9'o476;
localparam SETOB = 9'o477;
 
// Half Word {Left,Right} to {Left,Right} with {nochange,Zero,Ones,Extend}, {ac,Immediate,Memory,Self}
localparam HLL = 9'o500;
localparam HLLI = 9'o501;
localparam HLLM = 9'o502;
localparam HLLS = 9'o503;
localparam HRL = 9'o504;
localparam HRLI = 9'o505;
localparam HRLM = 9'o506;
localparam HRLS = 9'o507;
 
localparam HLLZ = 9'o510;
localparam HLLZI = 9'o511;
localparam HLLZM = 9'o512;
localparam HLLZS = 9'o513;
localparam HRLZ = 9'o514;
localparam HRLZI = 9'o515;
localparam HRLZM = 9'o516;
localparam HRLZS = 9'o517;
 
localparam HLLO = 9'o520;
localparam HLLOI = 9'o521;
localparam HLLOM = 9'o522;
localparam HLLOS = 9'o523;
localparam HRLO = 9'o524;
localparam HRLOI = 9'o525;
localparam HRLOM = 9'o526;
localparam HRLOS = 9'o527;
 
localparam HLLE = 9'o530;
localparam HLLEI = 9'o531;
localparam HLLEM = 9'o532;
localparam HLLES = 9'o533;
localparam HRLE = 9'o534;
localparam HRLEI = 9'o535;
localparam HRLEM = 9'o536;
localparam HRLES = 9'o537;
 
localparam HRR = 9'o540;
localparam HRRI = 9'o541;
localparam HRRM = 9'o542;
localparam HRRS = 9'o543;
localparam HLR = 9'o544;
localparam HLRI = 9'o545;
localparam HLRM = 9'o546;
localparam HLRS = 9'o547;
 
localparam HRRZ = 9'o550;
localparam HRRZI = 9'o551;
localparam HRRZM = 9'o552;
localparam HRRZS = 9'o553;
localparam HLRZ = 9'o554;
localparam HLRZI = 9'o555;
localparam HLRZM = 9'o556;
localparam HLRZS = 9'o557;
 
localparam HRRO = 9'o560;
localparam HRROI = 9'o561;
localparam HRROM = 9'o562;
localparam HRROS = 9'o563;
localparam HLRO = 9'o564;
localparam HLROI = 9'o565;
localparam HLROM = 9'o566;
localparam HLROS = 9'o567;
 
localparam HRRE = 9'o570;
localparam HRREI = 9'o571;
localparam HRREM = 9'o572;
localparam HRRES = 9'o573;
localparam HLRE = 9'o574;
localparam HLREI = 9'o575;
localparam HLREM = 9'o576;
localparam HLRES = 9'o577;
 
// Test bits, {Right,Left,Direct,Swapped} with
// {Nochange,Zero,Complement,One} and skip if the masked bits were
// {noskip,Equal,Nonzero,Always}
localparam TRN = 9'o600;
localparam TLN = 9'o601;
localparam TRNE = 9'o602;
localparam TLNE = 9'o603;
localparam TRNA = 9'o604;
localparam TLNA = 9'o605;
localparam TRNN = 9'o606;
localparam TLNN = 9'o607;
 
localparam TDN = 9'o610;
localparam TSN = 9'o611;
localparam TDNE = 9'o612;
localparam TSNE = 9'o613;
localparam TDNA = 9'o614;
localparam TSNA = 9'o615;
localparam TDNN = 9'o616;
localparam TSNN = 9'o617;
 
localparam TRZ = 9'o620;
localparam TLZ = 9'o621;
localparam TRZE = 9'o622;
localparam TLZE = 9'o623;
localparam TRZA = 9'o624;
localparam TLZA = 9'o625;
localparam TRZN = 9'o626;
localparam TLZN = 9'o627;
 
localparam TDZ = 9'o630;
localparam TSZ = 9'o631;
localparam TDZE = 9'o632;
localparam TSZE = 9'o633;
localparam TDZA = 9'o634;
localparam TSZA = 9'o635;
localparam TDZN = 9'o636;
localparam TSZN = 9'o637;
 
localparam TRC = 9'o640;
localparam TLC = 9'o641;
localparam TRCE = 9'o642;
localparam TLCE = 9'o643;
localparam TRCA = 9'o644;
localparam TLCA = 9'o645;
localparam TRCN = 9'o646;
localparam TLCN = 9'o647;
 
localparam TDC = 9'o650;
localparam TSC = 9'o651;
localparam TDCE = 9'o652;
localparam TSCE = 9'o653;
localparam TDCA = 9'o654;
localparam TSCA = 9'o655;
localparam TDCN = 9'o656;
localparam TSCN = 9'o657;
 
localparam TRO = 9'o660;
localparam TLO = 9'o661;
localparam TROE = 9'o662;
localparam TLOE = 9'o663;
localparam TROA = 9'o664;
localparam TLOA = 9'o665;
localparam TRON = 9'o666;
localparam TLON = 9'o667;
 
localparam TDO = 9'o670;
localparam TSO = 9'o671;
localparam TDOE = 9'o672;
localparam TSOE = 9'o673;
localparam TDOA = 9'o674;
localparam TSOA = 9'o675;
localparam TDON = 9'o676;
localparam TSON = 9'o677;

// I/O Opcodes 700-777
// Bits 0-2 = "111", bits 3-9 = I/O device address, bits 10-12 = opcode
// 7__    op      description
// 700000         BLKI    Block Input, skip if I/O not finished
// 700040         DATAI   Data Input, from device to memory
// 700100         BLKO    Block Output, skip if I/O not finished
// 700140         DATAO   Data Output, from memory to device
// 700200         CONO    Conditions Out, 36 bits AC to device
// 700240         CONI    Conditions in, 36 bits device to AC
// 700300         CONSZ   Conditions, Skip if Zero (test 18 bits)
// 700340         CONSO   Conditions, Skip if One (test 18 bits)
localparam IO_INSTRUCTION = 9'o7xx;

localparam
  BLKI = 3'o0,
  DATAI = 3'o1,
  BLKO = 3'o2,
  DATAO = 3'o3,
  CONO = 3'o4,
  CONI = 3'o5,
  CONSZ = 3'o6,
  CONSO = 3'o7;
