;;; Microcode for the KV10
;;;

;;; 0000
	;; at startup or reset, we begin executing from location 0000
reset:	aluSETZ,loadM		clrPSW	; move 0 into M
clrPSW:	mM,aluSETM,loadPSW	initpc	; clear the PSW (could do this and the previos instruction in one step now!!!)
initpc:	aINIT,loadPC		fetch	; setup the initial PC
	;; This is the only use of aPC and it could be implemented elsewise (loading E and jumping there) !!!
fetch:	aPC,readMEM,memIF,brREAD	fetchI	; a common point to start an instruction fetch from PC
	halt
	halt
	halt
	halt
;;; 0010
	;; load an instruction from the PC
fetchI:	brREAD	. ; loop, waiting for a response
	;; load the instruction and start the EA calculation saveFLAGS has the effect here
	;; of clearing the saved flags
	mMEM,aluSETM,saveFLAGS,loadM,loadOPA,loadIX,loadY,brIX	calcEA
	halt
	halt
	;; Read the Index Register.  In some cases (using XCTR) this could actually be
	;; reading from memory.
readX:	brREAD	.
	aE,mMEM,aluADD,loadY,loadM,brI	checkI ; E <- E+(X) does this need to load M with MEM rather than the sum? !!!
	halt
	halt
;;; 0020
	;; 3-way branch on Index and Indirect (taken from write_data).
calcEA:	aX,readMEM,memE1,brREAD	readX ; read the Index Register
	aE,readMEM,memE1,brREAD	readI ; Indirect
	brDISPATCH		dispatch ; EAcalc done, dispatch on the OpCode
	halt
	;; do the read for an Indirect and loop back to calcEA
readI:	brREAD	.
	mMEM,aluSETM,loadIX,loadY,loadM,brIX	calcEA
	halt
	halt
;;; 0030
	;; If there was a Index, now check if there's an Indirect too
checkI:	brDISPATCH		dispatch ; EAcalc done, dispatch on the OpCode
	aE,readMEM,memE1,brREAD	readI	 ; start the read for the Indirect
	halt
	halt
	halt
	halt
	halt
	halt
;;; 0040
	;; conditional jump
jumpc:	aPCnext,aluSETA,loadPC,readMEM,memIF,brREAD	fetchI
	aE,mE,aluSETM,loadPC,readMEM,memIF,brREAD	fetchI
	;; conditional skip
skipc:	aPCnext,aluSETA,loadPC,readMEM,memIF,brREAD	fetchI
	aPCskip,aluSETA,loadPC,readMEM,memIF,brREAD	fetchI
	;; for SKIP and SOS instructions, write M to AC if AC not 0
wrskip:	mM,aluSETM,brCOMP0		skipc
	mM,aluSETM,writeAC,brCOMP0	skipc
	halt
	halt
;;; 0050
	;; write M to memory
wrmem1:	brWRITE	.
	aPCnext,aluSETA,setFLAGS,loadPC,readMEM,memIF,brREAD	fetchI
wrmem:	aE,mM,aluSETM,writeMEM,memD1,brWRITE	wrmem1
	halt
	;; write M to memory and then to AC if AC not 0
wrself1:	brWRITE	.
	setFLAGS,brSELF	wrselfA
wrself:	aE,mM,aluSETM,writeMEM,memD1,brWRITE	wrself1
	halt
;;; 0060
	;; write M to AC if AC is not 0
wrselfA:	aPCnext,aluSETA,loadPC,readMEM,memIF,brREAD	fetchI
	aPCnext,mM,aluSETM,writeAC,loadPC,readMEM,memIF,brREAD	fetchI
	halt
	halt
	;; write M to memory and then to AC
wrboth1:	brWRITE	.
	aPCnext,mM,aluSETM,setFLAGS,writeAC,loadPC,readMEM,memIF,brREAD	fetchI
wrboth:	aE,mM,aluSETM,writeMEM,memD1,brWRITE	wrboth1
	;; finish up with a jump to E
jumpe:	aE,aluSETA,loadPC,readMEM,memIF,brREAD	fetchI
;;; 0070
	;; finish up the EXCH instruction
exch:	brWRITE	.
	aPCnext,mM,aluSETM,writeAC,loadPC,readMEM,memIF,brREAD	fetchI ; write M to AC and we're done
	halt
	halt
	;; Jump if any of the flags were cleared
jfcl:	aPCnext,aluSETA,loadPC,readMEM,memIF,brREAD	fetchI ; no jump
	aE,aluSETA,loadPC,readMEM,memIF,brREAD		fetchI ; jump
	halt
	halt
;;; 0100
	;; finish up JSA
jsa:	brWRITE	.
	aPCnext,mE,swapM,aluHLL,writeAC	jsa1 ; AC <- E,PC
	halt
jsa1:	aE,aluSETA,loadPC	next ; jump E+1
	halt
	halt
	halt
	halt
;;; 0110
	;; Write to memory after SOS, then write to self and save flags
sosWR1:	brWRITE				.      ; wait for the memory write to complete
	mM,aluSETM,setFLAGS,brSELF	wrskip ; now that the memory write completed, set flags
sosWR:	aE,mM,aluSETM,writeMEM,memD1,brWRITE	sosWR1 ; start write to memory
	halt
	;; finish up JSR
jsr1:	brWRITE	.
	aE,aluSETA,loadPC,clrFPD	next ; jump E+1
	halt
jsr:	aE,mM,aluSETM,writeMEM,memD1,brWRITE	jsr1
;;; 0120
	;; For the Test instructions
	;; The next and skip labels are for general use when we need an unconditional next or skip operation
	;; if the operands and'd together are 0, then skip
teste:	aPCskip,loadPC,readMEM,memIF,brREAD	fetchI
next:	aPCnext,loadPC,readMEM,memIF,brREAD	fetchI
	;; if the operands and'd together are not 0, then skip
testn:	aPCnext,loadPC,readMEM,memIF,brREAD	fetchI
skip:	aPCskip,loadPC,readMEM,memIF,brREAD	fetchI
	halt
	halt
	halt
	halt
;;; 0130
	;; finish up JRA
jra1:	brREAD			.
	mMEM,aluSETM,writeAC	jumpe ; AC now gets C(LEFT(AC))
	halt
	halt
jra:	aA,readMEM,memD1,brREAD	jra1 ; A has swapped AC
	halt
	halt
	halt
;;; 0140
	;; finish up PUSH
push1:	brWRITE			.
	aA,aluSETA,writeAC	next ; saved the increment AC in A into AC
	halt
push:	aA,mM,aluSETM,writeMEM,memD1,brWRITE	push1
	halt
	halt
	halt
	halt
;;; 0150
	;; finish up POP
pop:	brREAD			.
	mMEM,aluSETM,loadM	pop2
	halt
	halt
pop3:	brWRITE	.
	aPCnext,mAC,aluSOB,writeAC,loadPC,setPDO,readMEM,memIF,brREAD	fetchI
	halt
pop2:	aE,mM,aluSETM,writeMEM,memD1,brWRITE	pop3
;;; 0160
	;; Finish up PUSHJ
pushj3:	brWRITE	.
	aA,aluSETA,writeAC,clrFPD	jumpe ; saved the incremented AC in A into AC
	halt
pushj:	mAC,aluAOB,loadA,setPDO	pushj2 ; increment AC into A
pushj2:	aA,mM,aluSETM,writeMEM,memD1,brWRITE	pushj3 ; C(AC) <- PSW,PCnext (which is in M)
	halt
	halt
	halt
;;; 0170
	;; Finish up POPJ
popj:	brREAD	.
	mMEM,aluSETM,loadM	popj2
	;; writes M into PC and SOB(AC) into AC
popj2:	aM,mAC,aluSOB,loadPC,setPDO,writeAC,readMEM,memIF,brWRITE	fetch ; decrement AC
	halt
	halt
	halt
	halt
	halt
;;; 0200
ashc:	aAC,mE,aluASHC,loadB,writeAC,saveFLAGS,setFLAGS	wrb
rotc:	aAC,mE,aluROTC,loadB,writeAC				wrb
lshc:	aAC,mE,aluLSHC,loadB,writeAC				wrb
wrb:	aPCnext,aluSETB,ACnext,writeAC,loadPC,readMEM,memIF,brREAD	fetchI ; write B into A+1
	halt
	halt
	halt
	halt
;;; 0210
	;; MULx and IMULx
mul0:	aA,mM,aluMULADD,loadA,loadB	mul1
mul1:	aA,mM,aluMULADD,loadA,loadB	mul2
mul2:	aA,mM,aluMULADD,loadA,loadB	mul3
mul3:	aA,mM,aluMULADD,loadA,loadB	mul4
mul4:	aA,mM,aluMULADD,loadA,loadB	mul5
mul5:	aA,mM,aluMULADD,loadA,loadB	mul6
mul6:	aA,mM,aluMULADD,loadA,loadB	mul7
mul7:	aA,mM,aluMULADD,loadA,loadB	mul10
;;; 0220
mul10:	aA,mM,aluMULADD,loadA,loadB	mul11
mul11:	aA,mM,aluMULADD,loadA,loadB	mul12
mul12:	aA,mM,aluMULADD,loadA,loadB	mul13
mul13:	aA,mM,aluMULADD,loadA,loadB	mul14
mul14:	aA,mM,aluMULADD,loadA,loadB	mul15
mul15:	aA,mM,aluMULADD,loadA,loadB	mul16
mul16:	aA,mM,aluMULADD,loadA,loadB	mul17
mul17:	aA,mM,aluMULADD,loadA,loadB	mul20
;;; 0230
mul20:	aA,mM,aluMULADD,loadA,loadB	mul21
mul21:	aA,mM,aluMULADD,loadA,loadB	mul22
mul22:	aA,mM,aluMULADD,loadA,loadB	mul23
mul23:	aA,mM,aluMULADD,loadA,loadB	mul24
mul24:	aA,mM,aluMULADD,loadA,loadB	mul25
mul25:	aA,mM,aluMULADD,loadA,loadB	mul26
mul26:	aA,mM,aluMULADD,loadA,loadB	mul27
mul27:	aA,mM,aluMULADD,loadA,loadB	mul30
;;; 0240
mul30:	aA,mM,aluMULADD,loadA,loadB	mul31
mul31:	aA,mM,aluMULADD,loadA,loadB	mul32
mul32:	aA,mM,aluMULADD,loadA,loadB	mul33
mul33:	aA,mM,aluMULADD,loadA,loadB	mul34
mul34:	aA,mM,aluMULADD,loadA,loadB	mul35
mul35:	aA,mM,aluMULADD,loadA,loadB	mul36
mul36:	aA,mM,aluMULADD,loadA,loadB	mul37
mul37:	aA,mM,aluMULADD,loadA,loadB	mul40
;;; 0250
mul40:	aA,mM,aluMULADD,loadA,loadB	mul41
mul41:	aA,mM,aluMULADD,loadA,loadB	mul42
mul42:	aA,mM,aluMULADD,loadA,loadB,brMUL	imulwr
	halt
	;;  writing to memory for IMULB
imulb1:	brWRITE	.
	aPCnext,mM,aluSETM,loadPC,setFLAGS,writeAC,readMEM,memIF,brREAD	fetchI ; write to AC
	halt
imulb:	aE,mM,aluSETM,writeMEM,memD1,brWRITE	imulb1 ; start the write to memory
;;; 0260
	;; Do final operation to finish the multiply and then write answer where it needs to go
imulwr:	aA,mM,aluIMULSUB,saveFLAGS,setFLAGS,writeAC,loadB	next ; MUL  : write to AC
	aA,mM,aluIMULSUB,saveFLAGS,setFLAGS,writeAC,loadB	next ; IMUL : write to AC
	aA,mM,aluIMULSUB,saveFLAGS,loadM,loadA,loadB		mulm ; MULM : put answer in M also
	aA,mM,aluIMULSUB,saveFLAGS,loadM,loadA,loadB		imulb ; MULB : put answer in M also
mulwr:	aA,mM,aluMULSUB,saveFLAGS,setFLAGS,writeAC,loadB	wrb ; MUL  : write to AC and then AC+1
	aA,mM,aluMULSUB,saveFLAGS,setFLAGS,writeAC,loadB	wrb ; IMUL : write to AC and then AC+1
	aA,mM,aluMULSUB,saveFLAGS,loadM,loadA,loadB		mulm ; MULM : put answer in M also
	aA,mM,aluMULSUB,saveFLAGS,loadM,loadA,loadB		mulb ; MULB : put answer in M also
;;; 0270
	;; writing to memory for MULM and IMULM
mulm1:	brWRITE	.
	aPCnext,setFLAGS,loadPC,readMEM,memIF,brREAD	fetchI ; set flags and move on
	halt
mulm:	aE,mM,aluSETM,writeMEM,memD1,brWRITE		mulm1 ; start the write to memory
	;;  writing to memory for MULB
mulb1:	brWRITE	.
	mM,aluSETM,setFLAGS,writeAC			wrb ; write to AC and then AC+1
	halt
mulb:	aE,mM,aluSETM,writeMEM,memD1,brWRITE		mulb1 ; start the write to memory
;;; 0300
	;; IDIVx and DIVx
	;; div01 is a little different because it's where the check for overflow happens
div00:	aA,mM,aluDIVOP,loadA,loadB,brOVR	div01
	halt
div02:	aA,mM,aluDIVOP,loadA,loadB	div03
div03:	aA,mM,aluDIVOP,loadA,loadB	div04
div04:	aA,mM,aluDIVOP,loadA,loadB	div05
div05:	aA,mM,aluDIVOP,loadA,loadB	div06
div06:	aA,mM,aluDIVOP,loadA,loadB	div07
div07:	aA,mM,aluDIVOP,loadA,loadB	div10
;;; 0310
div10:	aA,mM,aluDIVOP,loadA,loadB	div11
div11:	aA,mM,aluDIVOP,loadA,loadB	div12
div12:	aA,mM,aluDIVOP,loadA,loadB	div13
div13:	aA,mM,aluDIVOP,loadA,loadB	div14
div14:	aA,mM,aluDIVOP,loadA,loadB	div15
div15:	aA,mM,aluDIVOP,loadA,loadB	div16
div16:	aA,mM,aluDIVOP,loadA,loadB	div17
div17:	aA,mM,aluDIVOP,loadA,loadB	div20
;;; 0320
div20:	aA,mM,aluDIVOP,loadA,loadB	div21
div21:	aA,mM,aluDIVOP,loadA,loadB	div22
div22:	aA,mM,aluDIVOP,loadA,loadB	div23
div23:	aA,mM,aluDIVOP,loadA,loadB	div24
div24:	aA,mM,aluDIVOP,loadA,loadB	div25
div25:	aA,mM,aluDIVOP,loadA,loadB	div26
div26:	aA,mM,aluDIVOP,loadA,loadB	div27
div27:	aA,mM,aluDIVOP,loadA,loadB	div30
;;; 0330
div30:	aA,mM,aluDIVOP,loadA,loadB	div31
div31:	aA,mM,aluDIVOP,loadA,loadB	div32
div32:	aA,mM,aluDIVOP,loadA,loadB	div33
div33:	aA,mM,aluDIVOP,loadA,loadB	div34
div34:	aA,mM,aluDIVOP,loadA,loadB	div35
div35:	aA,mM,aluDIVOP,loadA,loadB	div36
div36:	aA,mM,aluDIVOP,loadA,loadB	div37
div37:	aA,mM,aluDIVOP,loadA,loadB	div40
;;; 0340
div40:	aA,mM,aluDIVOP,loadA,loadB	div41
div41:	aA,mM,aluDIVOP,loadA,loadB	div42
div42:	aA,mM,aluDIVOP,loadA,loadB	div43
div43:	aA,mM,aluDIVOP,loadA,loadB	fixr
fixr:	aA,mM,aluDIVFIXR,loadA,loadB,brMUL	idivwr
	;; loads A,B <- |AC,B|
divhi:	aAC,aluDIVMAG72,loadA,loadB	div00
	;; check for overflow
div01:	aA,mM,aluDIVOP,loadA,loadB	div02
	aPCnext,aluSETA,loadPC,setOVF,setNODIV,readMEM,memIF,brREAD	fetchI
;;; 0350
	;; Do final fixup for DIV and write answer where it needs to go
idivwr:	aA,mM,aluDIVFIXUP,loadA,loadB,writeAC	wrb  ; IDIV  : AC <- A (quotient)
	aA,mM,aluDIVFIXUP,loadA,loadB,writeAC	wrb  ; IDIVI : AC <- A (quotient)
	aA,mM,aluDIVFIXUP,loadA,loadB,loadM	divm ; IDIVM : move quotient to M
	aA,mM,aluDIVFIXUP,loadA,loadB,loadM	divb ; IDIVB : move quotient to M
	aA,mM,aluDIVFIXUP,loadA,loadB,writeAC	wrb  ; DIV  : AC <- A (quotient)
	aA,mM,aluDIVFIXUP,loadA,loadB,writeAC	wrb  ; DIVI : AC <- A (quotient)
	aA,mM,aluDIVFIXUP,loadA,loadB,loadM	divm ; DIVM : move quotient to M
	aA,mM,aluDIVFIXUP,loadA,loadB,loadM	divb ; DIVB : move quotient to M
;;; 0360
	;; write to memory for IDIVM and DIVM
divm1:	brWRITE	.
	aPCnext,aluSETA,loadPC,readMEM,memIF,brREAD	fetchI
	halt
divm:	aE,mM,aluSETM,writeMEM,memD1,brWRITE	divm1
	;; write to memory for IDIVB and DIVB
divb1:	brWRITE	.
	mM,aluSETM,writeAC		wrb ; AC <- quotient
	halt
divb:	aE,mM,aluSETM,writeMEM,memD1,brWRITE	divb1
;;; 0370
	;; EA Calculation for Byte instructions
byteEA:	aX,readMEM,memE2,brREAD	readXBP	; Index
	aE,readMEM,memE2,brREAD	readIBP	; Indirect
	aE,readMEM,memD2,brREAD	bpREAD	; EAcalc done, read in byte
	halt
	;; do the read for an Indirect and loop back to byteEA
readIBP:	brREAD	.
	mMEM,aluSETM,loadIX,loadY,brIX	byteEA
	;; Read Index Register for Byte Instructions
readXBP:	brREAD	.
	aE,mMEM,aluADD,loadY,brI	checkIBP ; E <- E+(X)
;;; 0400
	;; If there was a Index, now check if there's an Indirect too
checkIBP:	aE,readMEM,memD2,brREAD	bpREAD  ; EAcalc done, read in byte
	aE,readMEM,memE2,brREAD		readIBP ; start the read for the Indirect
	halt
	halt
	;; finish writing the incremented Byte Pointer back to memory
wrBP:	brWRITE	.
	mM,aluSETM,setFPD,loadBP,loadIX,loadY,brIX	byteEA	; First-Part done, now BP EA calc
	halt
ldb:	aBPMASK,mM,aluAND,writeAC	next ; AC <- M & BPmask
;;; 0410
bpREAD:	brREAD	.
	mMEM,aluSETM,loadM,brBPDISP	bpdisp ; store the byte word in M
	halt
	halt
bpdisp:	aM,mBPPNEG,aluLSH,loadM,clrFPD	ldb   ; ILDB : M <- M >> P
	aM,mBPPNEG,aluLSH,loadM		ldb   ; LDB : M <- M >> P
	aBPMASK,mBPP,aluLSH,loadB	idpb1 ; IDPB : B <- BPmask << P
	aBPMASK,mBPP,aluLSH,loadB	dpb1  ; DPB : B <- BPmask << P
;;; 0420
	;; Finish up DPB
dpbwr:	brWRITE	.
	aPCnext,loadPC,readMEM,memIF,brREAD	fetchI
	halt
dpb1:	aAC,mBPP,aluLSH,loadA			dpb2  ; A <- AC << P
dpb2:	aA,mM,aluDPB,loadM			dpb3  ; M <- A | M (masked by B)
dpb3:	aE,mM,aluSETM,writeMEM,memD2,brWRITE	dpbwr ; C(E) <- M
	halt
	halt
;;; 0430
	;; Finish up IDPB.  This is identical to DPB except for clearing FPD at the end
idpbwr:	brWRITE	.
	clrFPD,aPCnext,loadPC,readMEM,memIF,brREAD	fetchI ; clear FPD and done
	halt
idpb1:	aAC,mBPP,aluLSH,loadA			idpb2  ; A <- AC << P
idpb2:	aA,mM,aluDPB,loadM			idpb3  ; M <- A | M (masked by B)
idpb3:	aE,mM,aluSETM,writeMEM,memD2,brWRITE	idpbwr ; C(E) <- M
	;; Either ILDP or IDPB, skip incrementing the byte pointer if FPD is set
fpd:	aE,mM,aluIBP,loadM,writeMEM,memD1,brWRITE	wrBP
	mM,aluSETM,setFPD,loadBP,loadIX,loadY,brIX	byteEA	; First-Part done, now BP EA calc
;;; 0440
	;; Read from AC left for BLT
bltrd:	brREAD	.
	aAC,mMEM,aluSETM,loadM,writeMEM,memD1,brWRITE	bltwr ; start write.
bltwr:	brWRITE	.
	brBLTDONE	bltfin
	;; check if we're done with the BLT (if the last write was to E)
bltfin:	mAC,aluAOB,writeAC	blt
	aPCnext,aluSETA,loadPC,readMEM,memIF,brREAD	fetchI
	;; start the BLT read here
bltst:	aA,readMEM,memD2,brREAD			bltrd ; BLT : start read from AC left
	halt
;;; 0450
	halt
	halt
	halt
	halt
	;; Write the JFFO result into AC+1 and either jump or not
jffo:	aPCnext,mM,aluSETM,ACnext,writeAC,loadPC,readMEM,memIF,brREAD	fetchI
	mM,aluSETM,ACnext,writeAC	jumpe
	halt
	halt
;;; 0460
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 0470
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 0500
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 0510
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 0520
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 0530
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 0540
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 0550
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 0560
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 0570
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 0600
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 0610
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 0620
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 0630
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 0640
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 0650
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 0660
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 0670
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 0700
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 0710
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 0720
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 0730
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 0740
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 0750
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 0760
	;; Read the trap instruction for a UUO
uuord:	brREAD	.
	mMEM,aluSETM,saveFLAGS,loadOPA,loadIX,loadY,loadM,brIX	calcEA ; execute the instruction
	halt
	halt
	;; write the faulting instruction into memory
uuowr:	brWRITE	.
	aONE,mM,aluADD,loadM	uuofetch ; increment the address in M
	halt
uuofetch:	aM,readMEM,memD1,brREAD	uuord ; start reading the trap instruction
;;; 0770
	halt
UUO:	aVECTOR,aluSETA,loadM	uuo1 ; move the trap address into M
uuo1:	aM,mINST,aluSETM,writeMEM,memD1,brWRITE	uuowr ; start the write
MUUO:	setMUUO	UUO
unass:	setMUUO	UUO		; unassigned code - same as MUUO for now
	;; This Page Fault handler address is known to the micro-engine.  Don't move this
	;; without changing the other.
FAULT:	jump	fetch
	;; This interrupt handler is as an address known by the micro-engine.  Don't
	;; change one without changing the other.  It spends a cycle, saving the vector in
	;; A, to let the memory read where this interrupt was recognized clear before
	;; trying to read the interrupt vector.
int1:	aA,readMEM,memIF,brREAD	fetchI
INTRPT:	aVECTOR,aluSETA,loadA		int1
;;; 1000
	;; The instruction dispatch table starts here
dispatch:	jump	MUUO
	jump	UUO
	jump	UUO
	jump	UUO
	jump	UUO
	jump	UUO
	jump	UUO
	jump	UUO
;;; 1010
	jump	UUO
	jump	UUO
	jump	UUO
	jump	UUO
	jump	UUO
	jump	UUO
	jump	UUO
	jump	UUO
;;; 1020
	jump	UUO
	jump	UUO
	jump	UUO
	jump	UUO
	jump	UUO
	jump	UUO
	jump	UUO
	jump	UUO
;;; 1030
	jump	UUO
	jump	UUO
	jump	UUO
	jump	UUO
	jump	UUO
	jump	UUO
	jump	UUO
	jump	UUO
;;; 1040
	jump	MUUO
	jump	MUUO
	jump	MUUO
	jump	MUUO
	jump	MUUO
	jump	MUUO
	jump	MUUO
	jump	MUUO
;;; 1050
	jump	MUUO
	jump	MUUO
	jump	MUUO
	jump	MUUO
	jump	MUUO
	jump	MUUO
	jump	MUUO
	jump	MUUO
;;; 1060
	jump	MUUO
	jump	MUUO
	jump	MUUO
	jump	MUUO
	jump	MUUO
	jump	MUUO
	jump	MUUO
	jump	MUUO
;;; 1070
	jump	MUUO
	jump	MUUO
	jump	MUUO
	jump	MUUO
	jump	MUUO
	jump	MUUO
	jump	MUUO
	jump	MUUO
;;; 1100
	jump	unass		; UJEN
	jump	unass		; UNK101
	jump	unass		; GFAD
	jump	unass		; GFSB
	jump	unass		; JSYS
	jump	unass		; ADJSP
	jump	unass		; GFMP
	jump	unass		; GFDV 
;;; 1110
	jump	unass		; DFAD
	jump	unass		; DFSB
	jump	unass		; DFMP
	jump	unass		; DFDV
	jump	unass		; DADD
	jump	unass		; DSUB
	jump	unass		; DMUL
	jump	unass		; DDIV
;;; 1120
	jump	unass		; DMOVE
	jump	unass		; DMOVN
	jump	unass		; FIX
	jump	unass		; EXTEND
	jump	unass		; DMOVEM
	jump	unass		; DMOVNM
	jump	unass		; FIXR
	jump	unass		; FLTR
;;; 1130
	jump	unass		; UFA
	jump	unass		; DFN
	jump	unass		; FSC
	;; The Byte Instructions
	aE,mM,aluIBP,loadM,writeMEM,memD1,brWRITE	wrmem1 ; IBP - Do I need to clearFPD here !!!
	brFPD					fpd    ; ILDB - Could make the FPD check part of DISPATCH !!!
	mM,aluSETM,loadBP,loadIX,loadY,brIX	byteEA ; LDB - move M over to BP, I, X, and Y
	brFPD					fpd    ; IDBP - Could make the FPD check part of DISPATCH !!!
	mM,aluSETM,loadBP,loadIX,loadY,brIX	byteEA ; DPB - move M over to BP, I, X, and Y
;;; 1140
	jump	unass		; FAD
	jump	unass		; FADL
	jump	unass		; FADM
	jump	unass		; FADB
	jump	unass		; FADR
	jump	unass		; FADRL
	jump	unass		; FADRM
	jump	unass		; FADRB
;;; 1150
	jump	unass		; FSB
	jump	unass		; FSBL
	jump	unass		; FSBM
	jump	unass		; FSBB
	jump	unass		; FSBR
	jump	unass		; FSBRL
	jump	unass		; FSBRM
	jump	unass		; FSBRB
;;; 1160
	jump	unass		; FMP
	jump	unass		; FMPL
	jump	unass		; FMPM
	jump	unass		; FMPB
	jump	unass		; FMPR
	jump	unass		; FMPRL
	jump	unass		; FMPRM
	jump	unass		; FMPRB
;;; 1170
	jump	unass		; FDV
	jump	unass		; FDVL
	jump	unass		; FDVM
	jump	unass		; FDVB
	jump	unass		; FDVR
	jump	unass		; FDVRL
	jump	unass		; FDVRM
	jump	unass		; FDVRB
;;; 1200
	aPCnext,mM,aluSETM,writeAC,loadPC,readMEM,memIF,brREAD	fetchI ; MOVE - AC <- C(E)
	aPCnext,mE,aluSETM,writeAC,loadPC,readMEM,memIF,brREAD	fetchI ; MOVEI - AC <- 0,E
	aE,mAC,aluSETM,loadM,writeMEM,memD1,brWRITE		wrmem1 ; MOVEM - C(E) <- AC
	aE,mM,aluSETM,writeMEM,memD1,brWRITE			wrself1 ; MOVES - C(E) and AC (if not 0) <- C(E)
	aPCnext,mM,swapM,aluSETM,writeAC,loadPC,readMEM,memIF,brREAD	fetchI ; MOVS - AC <- swap(C(E))
	aPCnext,mE,swapM,aluSETM,writeAC,loadPC,readMEM,memIF,brREAD	fetchI ; MOVSI - AC <- E,0
	aE,mAC,swapM,aluSETM,loadM,writeMEM,memD1,brWRITE		wrmem1 ; MOVSM - C(E) <- swap(AC)
	aE,mM,swapM,aluSETM,loadM,writeMEM,memD1,brWRITE		wrself1 ; MOVSS - C(E) and AC (if not 0) <- swap(C(E))
;;; 1210
	aPCnext,mM,aluNEGATE,saveFLAGS,setFLAGS,writeAC,loadPC,readMEM,memIF,brREAD	fetchI ; MOVN - AC <- C(E)
	aPCnext,mE,aluNEGATE,saveFLAGS,setFLAGS,writeAC,loadPC,readMEM,memIF,brREAD	fetchI ; MOVNI - AC <- 0,E
	aE,mAC,aluNEGATE,saveFLAGS,loadM,writeMEM,memD1,brWRITE		wrmem1 ; MOVNM - C(E) <- AC
	aE,mM,aluNEGATE,saveFLAGS,loadM,writeMEM,memD1,brWRITE		wrself1 ; MOVNS - C(E) and AC (if not 0) <- C(E)
	aPCnext,mM,aluMAGNITUDE,saveFLAGS,setFLAGS,writeAC,loadPC,readMEM,memIF,brREAD	fetchI ; MOVM - AC <- C(E)
	aPCnext,mE,aluMAGNITUDE,saveFLAGS,setFLAGS,writeAC,loadPC,readMEM,memIF,brREAD	fetchI ; MOVMI - AC <- 0,E
	aE,mAC,aluMAGNITUDE,saveFLAGS,loadM,writeMEM,memD1,brWRITE		wrmem1 ; MOVMM - C(E) <- AC
	aE,mM,aluMAGNITUDE,saveFLAGS,loadM,writeMEM,memD1,brWRITE		wrself1 ; MOVMS - C(E) and AC (if not 0) <- C(E)
;;; 1220
imul:	aAC,aluSETB,loadB,mulstart	mul0 ; IMUL : move AC to B, mulstart also clears A
	mE,aluSETM,loadM		imul  ; IMULI : move E into M and then proceed as MUL
	;; the same as IMUL until it's time to write the answer
	aAC,aluSETB,loadB,mulstart	mul0 ; IMULM
	aAC,aluSETB,loadB,mulstart	mul0 ; IMULB
mul:	aAC,aluSETB,loadB,mulstart	mul0 ; MUL : move AC to B, mulstart also clears A
	mE,aluSETM,loadM		mul  ; MULI : move E into M and then proceed as MUL
	;; the same as IMUL until it's time to write the answer
	aAC,aluSETB,loadB,mulstart	mul0 ; MULM
	aAC,aluSETB,loadB,mulstart	mul0 ; MULB
;;; 1230
idiv:	aAC,aluDIVMAG36,loadA,loadB		div00 ; IDIV : A,B <- |AC| << 1
	mE,aluSETM,loadM			idiv  ; IDIVI : move E to M
	;;  the same as IDIV until it's time to write the answer
	aAC,aluDIVMAG36,loadA,loadB		div00 ; IDIVM
	aAC,aluDIVMAG36,loadA,loadB		div00 ; IDIVB
div:	aAC,ACnext,aluSETB,loadB		divhi ; DIV  : B <- AC+1
	mE,aluSETM,loadM			div   ; DIVI : move E to M
	;;  the same as DIV until it's time to write the answer
	aAC,ACnext,aluSETB,loadB		divhi ; DIVM : B <- AC+1
	aAC,ACnext,aluSETB,loadB		divhi ; DIVB : B <- AC+1
;;; 1240
	aAC,mE,aluASH,saveFLAGS,setFLAGS,writeAC	next ; ASH
	aAC,mE,aluROT,writeAC				next ; ROT
	aAC,mE,aluLSH,writeAC				next ; LSH
	mAC,aluJFFO,loadM,brOVR		jffo ; JFFO : M <- JFFO(AC)
	aAC,ACnext,aluSETB,loadB	ashc ; ASHC
	aAC,ACnext,aluSETB,loadB	rotc ; ROTC
	aAC,ACnext,aluSETB,loadB	lshc ; LSHC
	jump	unass			     ; CIRC
;;; 1250
	aE,mAC,aluSETM,writeMEM,memD1,brWRITE		exch  ; EXCH : start writing AC here
blt:	mAC,swapM,aluSETM,loadA			bltst ; BLT : move LEFT(AC) to A
	mAC,aluAOB,writeAC,loadM,brCOMP0	jumpc ; AOBJP
	mAC,aluAOB,writeAC,loadM,brCOMP0	jumpc ; AOBJN
	;; Most of the JRST variants are dispatched to 1720.  If the
	;; instruction is disallowed, it comes here for the MUUO.
	jump	MUUO
	clrFLAGS,brJFCL	jfcl	; JFCL
	;; If we need to read the instruction with memIF, will have to change this as
	;; well as changing the entry in decode.v !!!
	aE,mM,aluSETM,saveFLAGS,loadOPA,loadIX,loadY,brIX	calcEA ; XCT
	jump	unass				       ; MAP
;;; 1260
	aPCnext,aluSETA,loadM			pushj ; PUSHJ
	mAC,aluAOB,loadA,setPDO			push  ; PUSH
	aAC,readMEM,memD1,brREAD		pop   ; POP
	aAC,readMEM,memD1,brREAD		popj  ; POPJ
	aPCnext,aluSETA,loadM			jsr   ; JSR : C(E) <- PSW,PC, jump E+1
	aPCnext,aluSETA,writeAC,clrFPD		jumpe ; JSP : AC <- PSW,PC, jump E
	aE,mAC,aluSETM,writeMEM,memD1,brWRITE	jsa   ; JSA : C(E) <- AC, AC <- E,PC, jump E+1
	mAC,swapM,aluSETM,loadA			jra   ; JRA : AC <- C(LEFT(AC)), jump E
;;; 1270
	aAC,mM,aluADD,saveFLAGS,setFLAGS,writeAC	next ; ADD
	aAC,mE,aluADD,saveFLAGS,setFLAGS,writeAC	next ; ADDI
	aAC,mM,aluADD,saveFLAGS,loadM			wrmem ; ADDM
	aAC,mM,aluADD,saveFLAGS,loadM			wrboth ; ADDB
	aAC,mM,aluSUB,saveFLAGS,setFLAGS,writeAC	next ; SUB
	aAC,mE,aluSUB,saveFLAGS,setFLAGS,writeAC	next ; SUBI
	aAC,mM,aluSUB,saveFLAGS,loadM			wrmem ; SUBM
	aAC,mM,aluSUB,saveFLAGS,loadM			wrboth ; SUBB
;;; 1300
	;; Compare AC with 0,E and Skip
	aAC,mE,aluSUB,brCOMP	skipc ; CAI -- could optimize!!!
	aAC,mE,aluSUB,brCOMP	skipc ; CAIL
	aAC,mE,aluSUB,brCOMP	skipc ; CAIE
	aAC,mE,aluSUB,brCOMP	skipc ; CAILE
	aAC,mE,aluSUB,brCOMP	skipc ; CAIA -- could optimize!!!
	aAC,mE,aluSUB,brCOMP	skipc ; CAIGE
	aAC,mE,aluSUB,brCOMP	skipc ; CAIN
	aAC,mE,aluSUB,brCOMP	skipc ; CAIG
;;; 1310
	;; Compare AC with Memory and Skip
	aAC,mM,aluSUB,brCOMP	skipc ; CAM -- could optimize!!!
	aAC,mM,aluSUB,brCOMP	skipc ; CAML
	aAC,mM,aluSUB,brCOMP	skipc ; CAME
	aAC,mM,aluSUB,brCOMP	skipc ; CAMLE
	aAC,mM,aluSUB,brCOMP	skipc ; CAMA -- could optimize!!!
	aAC,mM,aluSUB,brCOMP	skipc ; CAMGE
	aAC,mM,aluSUB,brCOMP	skipc ; CAMN
	aAC,mM,aluSUB,brCOMP	skipc ; CAMG
;;; 1320
	;; Compare AC with 0 and Jump
	mAC,aluSETM,brCOMP0	jumpc ; JUMP -- could optimize!!!
	mAC,aluSETM,brCOMP0	jumpc ; JUMPL
	mAC,aluSETM,brCOMP0	jumpc ; JUMPE
	mAC,aluSETM,brCOMP0	jumpc ; JUMPLE
	mAC,aluSETM,brCOMP0	jumpc ; JUMPA -- could optimize!!!
	mAC,aluSETM,brCOMP0	jumpc ; JUMPGE
	mAC,aluSETM,brCOMP0	jumpc ; JUMPN
	mAC,aluSETM,brCOMP0	jumpc ; JUMPG
;;; 1330
	;; Compare Memory wih 0 and Skip, write Memory to AC if AC not 0
	brSELF	wrskip		; SKIP
	brSELF	wrskip		; SKIPL
	brSELF	wrskip		; SKIPE
	brSELF	wrskip		; SKIPLE
	brSELF	wrskip		; SKIPA
	brSELF	wrskip		; SKIPGE
	brSELF	wrskip		; SKIPN
	brSELF	wrskip		; SKIPG
;;; 1340
	;; Add 1 to AC and Jump
	aONE,mAC,aluADD,saveFLAGS,setFLAGS,writeAC,brCOMP0	jumpc ; AOJ
	aONE,mAC,aluADD,saveFLAGS,setFLAGS,writeAC,brCOMP0	jumpc ; AOJL
	aONE,mAC,aluADD,saveFLAGS,setFLAGS,writeAC,brCOMP0	jumpc ; AOJE
	aONE,mAC,aluADD,saveFLAGS,setFLAGS,writeAC,brCOMP0	jumpc ; AOJLE
	aONE,mAC,aluADD,saveFLAGS,setFLAGS,writeAC,brCOMP0	jumpc ; AOJA
	aONE,mAC,aluADD,saveFLAGS,setFLAGS,writeAC,brCOMP0	jumpc ; AOJGE
	aONE,mAC,aluADD,saveFLAGS,setFLAGS,writeAC,brCOMP0	jumpc ; AOJN
	aONE,mAC,aluADD,saveFLAGS,setFLAGS,writeAC,brCOMP0	jumpc ; AOJG
;;; 1350
	;; Add 1 to Memory and Skip, write back to Memory and also AC if AC not 0
	aONE,mM,aluADD,saveFLAGS,loadM	sosWR ; AOS
	aONE,mM,aluADD,saveFLAGS,loadM	sosWR ; AOSL
	aONE,mM,aluADD,saveFLAGS,loadM	sosWR ; AOSE
	aONE,mM,aluADD,saveFLAGS,loadM	sosWR ; AOSLE
	aONE,mM,aluADD,saveFLAGS,loadM	sosWR ; AOSA
	aONE,mM,aluADD,saveFLAGS,loadM	sosWR ; AOSGE
	aONE,mM,aluADD,saveFLAGS,loadM	sosWR ; AOSN
	aONE,mM,aluADD,saveFLAGS,loadM	sosWR ; AOSG
;;; 1360
	;; Subtract 1 from AC and Jump
	;; Adding -1 makes the condition codes come out right
	aMONE,mAC,aluADD,saveFLAGS,setFLAGS,writeAC,brCOMP0	jumpc ; SOJ
	aMONE,mAC,aluADD,saveFLAGS,setFLAGS,writeAC,brCOMP0	jumpc ; SOJL
	aMONE,mAC,aluADD,saveFLAGS,setFLAGS,writeAC,brCOMP0	jumpc ; SOJE
	aMONE,mAC,aluADD,saveFLAGS,setFLAGS,writeAC,brCOMP0	jumpc ; SOJLE
	aMONE,mAC,aluADD,saveFLAGS,setFLAGS,writeAC,brCOMP0	jumpc ; SOJA
	aMONE,mAC,aluADD,saveFLAGS,setFLAGS,writeAC,brCOMP0	jumpc ; SOJGE
	aMONE,mAC,aluADD,saveFLAGS,setFLAGS,writeAC,brCOMP0	jumpc ; SOJN
	aMONE,mAC,aluADD,saveFLAGS,setFLAGS,writeAC,brCOMP0	jumpc ; SOJG
;;; 1370
	;; Subtract 1 from Memory and Skip, write back to Memory and also AC if AC not 0
	;; Adding -1 makes the condition codes come out right
	aMONE,mM,aluADD,saveFLAGS,loadM	sosWR ; SOS
	aMONE,mM,aluADD,saveFLAGS,loadM	sosWR ; SOSL
	aMONE,mM,aluADD,saveFLAGS,loadM	sosWR ; SOSE
	aMONE,mM,aluADD,saveFLAGS,loadM	sosWR ; SOSLE
	aMONE,mM,aluADD,saveFLAGS,loadM	sosWR ; SOSA
	aMONE,mM,aluADD,saveFLAGS,loadM	sosWR ; SOSGE
	aMONE,mM,aluADD,saveFLAGS,loadM	sosWR ; SOSN
	aMONE,mM,aluADD,saveFLAGS,loadM	sosWR ; SOSG
;;; 1400
	;; The logic instructions
	aAC,mM,aluSETZ,writeAC		next   ; SETZ
	aAC,mE,aluSETZ,writeAC		next   ; SETZI
	aAC,mM,aluSETZ,loadM		wrmem  ; SETZM
	aAC,mM,aluSETZ,loadM		wrboth ; SETZB
	
	aAC,mM,aluAND,writeAC		next   ; AND
	aAC,mE,aluAND,writeAC		next   ; ANDI
	aAC,mM,aluAND,loadM		wrmem  ; ANDM
	aAC,mM,aluAND,loadM		wrboth ; ANDB
;;; 1410
	aAC,mM,aluANDCA,writeAC		next   ; ANDCA
	aAC,mE,aluANDCA,writeAC		next   ; ANDCAI
	aAC,mM,aluANDCA,loadM		wrmem  ; ANDCAM
	aAC,mM,aluANDCA,loadM		wrboth ; ANDCAB

	aAC,mM,aluSETM,writeAC		next   ; SETM
	aAC,mE,aluSETM,writeAC		next   ; SETMI
	aAC,mM,aluSETM,loadM		wrmem  ; SETMM
	aAC,mM,aluSETM,loadM		wrboth ; SETMB
;;; 1420
	aAC,mM,aluANDCM,writeAC		next   ; ANDCM
	aAC,mE,aluANDCM,writeAC		next   ; ANDCMI
	aAC,mM,aluANDCM,loadM		wrmem  ; ANDCMM
	aAC,mM,aluANDCM,loadM		wrboth ; ANDCMB

	aAC,mM,aluSETA,writeAC		next   ; SETA
	aAC,mE,aluSETA,writeAC		next   ; SETAI
	aAC,mM,aluSETA,loadM		wrmem  ; SETAM
	aAC,mM,aluSETA,loadM		wrboth ; SETAB
;;; 1430
	aAC,mM,aluXOR,writeAC		next   ; XOR
	aAC,mE,aluXOR,writeAC		next   ; XORI
	aAC,mM,aluXOR,loadM		wrmem  ; XORM
	aAC,mM,aluXOR,loadM		wrboth ; XORB

	aAC,mM,aluIOR,writeAC		next   ; IOR
	aAC,mE,aluIOR,writeAC		next   ; IORI
	aAC,mM,aluIOR,loadM		wrmem  ; IORM
	aAC,mM,aluIOR,loadM		wrboth ; IORB
;;; 1440
	aAC,mM,aluANDCB,writeAC		next   ; ANDCB
	aAC,mE,aluANDCB,writeAC		next   ; ANDCBI
	aAC,mM,aluANDCB,loadM		wrmem  ; ANDCBM
	aAC,mM,aluANDCB,loadM		wrboth ; ANDCBB

	aAC,mM,aluEQV,writeAC		next   ; EQV
	aAC,mE,aluEQV,writeAC		next   ; EQVI
	aAC,mM,aluEQV,loadM		wrmem  ; EQVM
	aAC,mM,aluEQV,loadM		wrboth ; EQVB
;;; 1450
	aAC,mM,aluSETCA,writeAC		next   ; SETCA
	aAC,mE,aluSETCA,writeAC		next   ; SETCAI
	aAC,mM,aluSETCA,loadM		wrmem  ; SETCAM
	aAC,mM,aluSETCA,loadM		wrboth ; SETCAB

	aAC,mM,aluORCA,writeAC		next   ; ORCA
	aAC,mE,aluORCA,writeAC		next   ; ORCAI
	aAC,mM,aluORCA,loadM		wrmem  ; ORCAM
	aAC,mM,aluORCA,loadM		wrboth ; ORCAB
;;; 1460
	aAC,mM,aluSETCM,writeAC		next   ; SETCM
	aAC,mE,aluSETCM,writeAC		next   ; SETCMI
	aAC,mM,aluSETCM,loadM		wrmem  ; SETCMM
	aAC,mM,aluSETCM,loadM		wrboth ; SETCMB

	aAC,mM,aluORCM,writeAC		next   ; ORCM
	aAC,mE,aluORCM,writeAC		next   ; ORCMI
	aAC,mM,aluORCM,loadM		wrmem  ; ORCMM
	aAC,mM,aluORCM,loadM		wrboth ; ORCMB
;;; 1470
	aAC,mM,aluORCB,writeAC		next   ; ORCB
	aAC,mE,aluORCB,writeAC		next   ; ORCBI
	aAC,mM,aluORCB,loadM		wrmem  ; ORCBM
	aAC,mM,aluORCB,loadM		wrboth ; ORCBB

	aAC,mM,aluSETO,writeAC		next   ; SETO
	aAC,mE,aluSETO,writeAC		next   ; SETOI
	aAC,mM,aluSETO,loadM		wrmem  ; SETOM
	aAC,mM,aluSETO,loadM		wrboth ; SETOB
;;; 1500
	;; Half-word moves - Halfword[LR][LR][- Zeros Ones Extend][- Immediate Memory Self]
	;;   Mode     Suffix    Source     Destination
	;;  Basic                (E)           AC
	;;  Immediate   I        0,E           AC
	;;  Memory      M         AC           (E)
	;;  Self        S        (E)           (E) and AC if AC nonzero
	aAC,mM,aluHLL,writeAC			next   ; HLL
	aAC,mE,aluHLL,writeAC			next   ; HLLI
	aM,mAC,aluHLL,loadM			wrmem  ; HLLM
	aM,mM,aluHLL,loadM			wrself ; HLLS

	aAC,mM,swapM,aluHLL,writeAC		next   ; HRL
	aAC,mE,swapM,aluHLL,writeAC		next   ; HRLI
	aM,mAC,swapM,aluHLL,loadM		wrmem  ; HRLM
	aM,mM,swapM,aluHLL,loadM		wrself ; HRLS
;;; 1510
	aZERO,mM,aluHLL,writeAC			next   ; HLLZ
	aZERO,mE,aluHLL,writeAC			next   ; HLLZI
	aZERO,mAC,aluHLL,loadM			wrmem  ; HLLZM
	aZERO,mM,aluHLL,loadM			wrself ; HLLZS

	aZERO,mM,swapM,aluHLL,writeAC		next   ; HRLZ
	aZERO,mE,swapM,aluHLL,writeAC		next   ; HRLZI
	aZERO,mAC,swapM,aluHLL,loadM		wrmem  ; HRLZM
	aZERO,mM,swapM,aluHLL,loadM		wrself ; HRLZS
;;; 1520
	aMONE,mM,aluHLL,writeAC			next   ; HLLO
	aMONE,mE,aluHLL,writeAC			next   ; HLLOI
	aMONE,mAC,aluHLL,loadM			wrmem  ; HLLOM
	aMONE,mM,aluHLL,loadM			wrself ; HLLOS

	aMONE,mM,swapM,aluHLL,writeAC		next   ; HRLO
	aMONE,mE,swapM,aluHLL,writeAC		next   ; HRLOI
	aMONE,mAC,swapM,aluHLL,loadM		wrmem  ; HRLOM
	aMONE,mM,swapM,aluHLL,loadM		wrself ; HRLOS
;;; 1530
	aSXT,mM,aluHLL,writeAC			next   ; HLLE
	aSXT,mE,aluHLL,writeAC			next   ; HLLEI
	aSXT,mAC,aluHLL,loadM			wrmem  ; HLLEM
	aSXT,mM,aluHLL,loadM			wrself ; HLLES

	aSXT,mM,swapM,aluHLL,writeAC		next   ; HRLE
	aSXT,mE,swapM,aluHLL,writeAC		next   ; HRLEI
	aSXT,mAC,swapM,aluHLL,loadM		wrmem  ; HRLEM
	aSXT,mM,swapM,aluHLL,loadM		wrself ; HRLES
;;; 1540
	aAC,mM,swapM,aluHLR,writeAC		next   ; HRR
	aAC,mE,swapM,aluHLR,writeAC		next   ; HRRI
	aM,mAC,swapM,aluHLR,loadM		wrmem  ; HRRM
	aM,mM,swapM,aluHLR,loadM		wrself ; HRRS

	aAC,mM,aluHLR,writeAC			next   ; HLR
	aAC,mE,aluHLR,writeAC			next   ; HLRI
	aM,mAC,aluHLR,loadM			wrmem  ; HLRM
	aM,mM,aluHLR,loadM			wrself ; HLRS
;;; 1550
	aZERO,mM,swapM,aluHLR,writeAC		next   ; HRRZ
	aZERO,mE,swapM,aluHLR,writeAC		next   ; HRRZI
	aZERO,mAC,swapM,aluHLR,loadM		wrmem  ; HRRZM
	aZERO,mM,swapM,aluHLR,loadM		wrself ; HRRZS

	aZERO,mM,aluHLR,writeAC			next   ; HLRZ
	aZERO,mE,aluHLR,writeAC			next   ; HLRZI
	aZERO,mAC,aluHLR,loadM			wrmem  ; HLRZM
	aZERO,mM,aluHLR,loadM			wrself ; HLRZS
;;; 1560
	aMONE,mM,swapM,aluHLR,writeAC		next   ; HRRO
	aMONE,mE,swapM,aluHLR,writeAC		next   ; HRROI
	aMONE,mAC,swapM,aluHLR,loadM		wrmem  ; HRROM
	aMONE,mM,swapM,aluHLR,loadM		wrself ; HRROS

	aMONE,mM,aluHLR,writeAC			next   ; HLRO
	aMONE,mE,aluHLR,writeAC			next   ; HLROI
	aMONE,mAC,aluHLR,loadM			wrmem  ; HLROM
	aMONE,mM,aluHLR,loadM			wrself ; HLROS
;;; 1570
	aSXT,mM,swapM,aluHLR,writeAC		next   ; HRRE
	aSXT,mE,swapM,aluHLR,writeAC		next   ; HRREI
	aSXT,mAC,swapM,aluHLR,loadM		wrmem  ; HRREM
	aSXT,mM,swapM,aluHLR,loadM		wrself ; HRRES

	aSXT,mM,aluHLR,writeAC			next   ; HLRE
	aSXT,mE,aluHLR,writeAC			next   ; HLREI
	aSXT,mAC,aluHLR,loadM			wrmem  ; HLREM
	aSXT,mM,aluHLR,loadM			wrself ; HLRES
;;; 1600
	;; Logical Testing and Modification (Bit Testing)
	;; R - mask right half of AC with 0,E
	;; L - mask left half of AC with E,0
	;; D - mask AC with C(E)
	;; S - mask AC with swap(C(E))
	;;
	;; N - no modification to AC
	;; Z - zeros in masked bit positions
	;; C - complement masked bit positions
	;; O - ones in masked bit positions
	;;
	;;   - never skip
	;; E - skip if all masked bits equal 0
	;; A - always skip
	;; N - skip if any masked bit is 1
	aAC,mE					next  ; TRN
	aAC,mE,swapM				next  ; TLN
	aAC,mE,brTEST				teste ; TRNE
	aAC,mE,swapM,brTEST			teste ; TLNE
	aAC,mE					skip  ; TRNA
	aAC,mE,swapM				skip  ; TLNA
	aAC,mE,brTEST				testn ; TRNN
	aAC,mE,swapM,brTEST			testn ; TLNN
;;; 1610
	aAC,mM					next  ; TDN
	aAC,mM,swapM				next  ; TSN
	aAC,mM,brTEST				teste ; TDNE
	aAC,mM,swapM,brTEST			teste ; TSNE
	aAC,mM					skip  ; TDNA
	aAC,mM,swapM				skip  ; TSNA
	aAC,mM,brTEST				testn ; TDNN
	aAC,mM,swapM,brTEST			testn ; TSNN
;;; 1620
	aAC,mE,aluANDCM,writeAC			next  ; TRZ
	aAC,mE,swapM,aluANDCM,writeAC		next  ; TLZ
	aAC,mE,brTEST,aluANDCM,writeAC		teste ; TRZE
	aAC,mE,swapM,brTEST,aluANDCM,writeAC	teste ; TLZE
	aAC,mE,aluANDCM,writeAC			skip  ; TRZA
	aAC,mE,swapM,aluANDCM,writeAC		skip  ; TLZA
	aAC,mE,brTEST,aluANDCM,writeAC		testn ; TRZN
	aAC,mE,swapM,brTEST,aluANDCM,writeAC	testn ; TLZN
;;; 1630
	aAC,mM,aluANDCM,writeAC			next  ; TDZ
	aAC,mM,swapM,aluANDCM,writeAC		next  ; TSZ
	aAC,mM,brTEST,aluANDCM,writeAC		teste ; TDZE
	aAC,mM,swapM,brTEST,aluANDCM,writeAC	teste ; TSZE
	aAC,mM,aluANDCM,writeAC			skip  ; TDZA
	aAC,mM,swapM,aluANDCM,writeAC		skip  ; TSZA
	aAC,mM,brTEST,aluANDCM,writeAC		testn ; TDZN
	aAC,mM,swapM,brTEST,aluANDCM,writeAC	testn ; TSZN
;;; 1640
	aAC,mE,aluXOR,writeAC			next  ; TRC
	aAC,mE,swapM,aluXOR,writeAC		next  ; TLC
	aAC,mE,brTEST,aluXOR,writeAC		teste ; TRCE
	aAC,mE,swapM,brTEST,aluXOR,writeAC	teste ; TLCE
	aAC,mE,aluXOR,writeAC			skip  ; TRCA
	aAC,mE,swapM,aluXOR,writeAC		skip  ; TLCA
	aAC,mE,brTEST,aluXOR,writeAC		testn ; TRCN
	aAC,mE,swapM,brTEST,aluXOR,writeAC	testn ; TLCN
;;; 1650
	aAC,mM,aluXOR,writeAC			next  ; TDC
	aAC,mM,swapM,aluXOR,writeAC		next  ; TSC
	aAC,mM,brTEST,aluXOR,writeAC		teste ; TDCE
	aAC,mM,swapM,brTEST,aluXOR,writeAC	teste ; TSCE
	aAC,mM,aluXOR,writeAC			skip  ; TDCA
	aAC,mM,swapM,aluXOR,writeAC		skip  ; TSCA
	aAC,mM,brTEST,aluXOR,writeAC		testn ; TDCN
	aAC,mM,swapM,brTEST,aluXOR,writeAC	testn ; TSCN
;;; 1660
	aAC,mE,aluIOR,writeAC			next  ; TRO
	aAC,mE,swapM,aluIOR,writeAC		next  ; TLO
	aAC,mE,brTEST,aluIOR,writeAC		teste ; TROE
	aAC,mE,swapM,brTEST,aluIOR,writeAC	teste ; TLOE
	aAC,mE,aluIOR,writeAC			skip  ; TROA
	aAC,mE,swapM,aluIOR,writeAC		skip  ; TLOA
	aAC,mE,brTEST,aluIOR,writeAC		testn ; TRON
	aAC,mE,swapM,brTEST,aluIOR,writeAC	testn ; TLON
;;; 1670
	aAC,mM,aluIOR,writeAC			next  ; TDO
	aAC,mM,swapM,aluIOR,writeAC		next  ; TSO
	aAC,mM,brTEST,aluIOR,writeAC		teste ; TDOE
	aAC,mM,swapM,brTEST,aluIOR,writeAC	teste ; TSOE
	aAC,mM,aluIOR,writeAC			skip  ; TDOA
	aAC,mM,swapM,aluIOR,writeAC		skip  ; TSOA
	aAC,mM,brTEST,aluIOR,writeAC		testn ; TDON
	aAC,mM,swapM,brTEST,aluIOR,writeAC	testn ; TSON
;;; 1700
	;; I/O Instructions are dispatched here
	jump	MUUO			      ; BLKI (need to implement !!!)
	readIO,brIOREAD			rdio  ; DATAI : C(E) <- Device Data
	jump	MUUO			      ; BKLO (need to implement !!!)
	mM,aluSETM,writeIO,brIOWRITE	wrio  ; DATAO : Device Data <- C(E)
	mE,aluSETM,writeIO,brIOWRITE	wrio  ; CONO  : Device Cond <- 0,E
	readIO,brIOREAD			rdio  ; CONI  : C(E) <- Device Cond
	readIO,brIOREAD			consz ; CONSZ : E & Cond, Skip if 0
	readIO,brIOREAD			conso ; CONSO : E | Cond, Skip if not 0
;;; 1710
	;; If an I/O instruction is executed in User mode without UserIO set
userio:	jump	MUUO
jhalt:	halt			; JRST halts come here !!!
	halt
	halt
	halt
	halt
	halt
	halt
;;; 1720
	;; If JRST tries to do something not allowed in user mode, it's sent to the normal
	;; spot in the dispatch table to be executed as an MUUO.  All others come here.
jrst:	aE,loadPC,readMEM,memIF,brREAD				fetchI ; JRST 0 -- JRST
	aE,loadPC,setUSER,readMEM,memIF,brREAD			fetchI ; JRST 1 -- PORTAL
	aE,loadPC,mM,aluSETM,loadPSW,readMEM,memIF,brREAD	fetchI ; JRST 2 -- JRSTF
	aE,loadPC,mM,aluSETM,loadPSW,readMEM,memIF,brREAD	fetchI ; JRST 3
	aE,loadPC						jhalt  ; JRST 4 -- HALT
	aE,loadPC,setUSER					jhalt  ; JRST 5
	aE,loadPC,mM,aluSETM,loadPSW				jhalt  ; JRST 6
	aE,loadPC,mM,aluSETM,loadPSW				jhalt  ; JRST 7
;;; 1730
	;; delay one cycle here to let the interrupt be dismissed
	;; before fetching the next instruction
	disINT							jumpe ; JRST 10
	setUSER,disINT						jumpe ; JRST 11
	mM,aluSETM,loadPSW,disINT				jumpe ; JRST 12 -- JEN
	mM,aluSETM,loadPSW,disINT				jumpe ; JRST 13
	disINT							jhalt ; JRST 14
	setUSER,disINT						jhalt ; JRST 15
	mM,aluSETM,loadPSW,disINT				jhalt ; JRST 16
	mM,aluSETM,loadPSW,disINT				jhalt ; JRST 17
;;; 1740
	;; if the instruction is flagged with ReadE, come here.
	;; read C(E) into M and dispatch on the instruction again
	aE,readMEM,memD1,brREAD	ReadE
	halt
ReadE:	brREAD	.
	mMEM,aluSETM,loadM,brDISPATCH	dispatch
	halt
	halt
	halt
	halt
;;; 1750
	;; Finish up an I/O write
wrio:	brIOWRITE	.
	aPCnext,loadPC,readMEM,memIF,brREAD	fetchI
	jump	nxd
	halt
	;; Finish up an I/O read
rdio:	brIOREAD	.
	aE,mIO,aluSETM,loadM,writeMEM,memD1,brWRITE	wrmem1 ; write data to memory
	jump	nxd
	halt
;;; 1760
consz:	brIOREAD	.
	mIO,aluSETM,loadM	consz1
	jump	nxd
consz1:	aE,mM,aluAND,brCOMP0	skipc
conso:	brIOREAD	.
	mIO,aluSETM,loadM	conso1
	jump	nxd
conso1:	aE,mM,aluIOR,brCOMP0	skipc
;;; 1770
nxd:	halt			; what do I do here? !!!
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2000
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2010
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2020
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2030
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2040
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2050
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2060
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2070
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2100
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2110
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2120
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2130
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2140
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2150
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2160
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2170
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2200
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2210
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2220
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2230
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2240
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2250
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2260
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2270
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2300
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2310
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2320
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2330
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2340
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2350
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2360
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2370
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2400
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2410
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2420
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2430
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2440
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2450
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2460
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2470
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2500
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2510
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2520
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2530
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2540
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2550
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2560
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2570
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2600
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2610
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2620
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2630
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2640
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2650
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2660
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2670
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2700
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2710
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2720
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2730
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2740
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2750
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2760
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 2770
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3000
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3010
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3020
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3030
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3040
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3050
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3060
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3070
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3100
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3110
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3120
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3130
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3140
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3150
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3160
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3170
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3200
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3210
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3220
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3230
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3240
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3250
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3260
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3270
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3300
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3310
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3320
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3330
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3340
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3350
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3360
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3370
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3400
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3410
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3420
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3430
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3440
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3450
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3460
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3470
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3500
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3510
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3520
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3530
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3540
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3550
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3560
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3570
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3600
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3610
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3620
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3630
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3640
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3650
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3660
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3670
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3700
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3710
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3720
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3730
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3740
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3750
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3760
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 3770
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
