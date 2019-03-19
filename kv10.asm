;;; Microcode for the KV10
;;;

;;; 0000
	;; at startup or reset, we begin executing from location 0000
reset:	aluSETZ,loadM	clrPSW	; move 0 into Mreg
clrPSW:	loadPSW		initpc	; clear the PSW
initpc:	aINIT,aluSETA,loadPC	fetchPC	; setup the initial PC
	halt
	halt
	halt
	halt
	halt
;;; 0010
	;; load an instruction from the PC
fetchPC:	aPC,readMEM,brREAD	. ; loop, waiting for a response
	;; load the instruction and start the EA calculation
	;; saveFLAGS has the effect here of clearing the saved flags
	aPC,mMEM,aluSETM,saveFLAGS,loadOPA,loadIX,loadY,brIX	calcEA
	jump	fault
	jump	intrpt
	halt
	halt
	halt
	halt
;;; 0020
	;; 3-way branch on Index and Indirect (taken from write_data).
calcEA:	ACindex,aAC,mE,aluADD,loadY,loadM,brI	checkI ; Index
	aE,readMEM,brREAD	fetchI		       ; Indirect
	brDISPATCH	dispatch ; EAcalc done, dispatch on the OpCode
	halt
	;; do the read for an Indirect and loop back to calcEA
fetchI:	aE,readMEM,brREAD	.
	aE,mMEM,aluSETM,loadIX,loadY,loadM,brIX	calcEA
	jump	fault
	jump	intrpt
;;; 0030
	;; If there was a Index, now check if there's an Indirect too
checkI:	brDISPATCH	dispatch ; EAcalc done, dispatch on the OpCode
	aE,readMEM,brREAD	fetchI ; start the read for the Indirect
	halt
	halt
	halt
	halt
	halt
	halt
;;; 0040
	;; conditional jump
jumpc:	aPCnext,aluSETA,loadPC,readMEM,brREAD	fetchPC
	aE,mE,aluSETM,loadPC,readMEM,brREAD	fetchPC
	;; conditional skip
skipc:	aPCnext,aluSETA,loadPC,readMEM,brREAD	fetchPC
	aPCskip,aluSETA,loadPC,readMEM,brREAD	fetchPC
	;; for SKIP and SOS instructions, write Mreg to AC if AC not 0
wrskip:	mM,aluSETM,brCOMP		skipc
	mM,aluSETM,writeAC,brCOMP	skipc
	halt
	halt
;;; 0050
	;; write Mreg to memory
wrmem:	aE,mM,aluSETM,writeMEM,brWRITE	.
	aPCnext,aluSETA,setFLAGS,loadPC,readMEM,brREAD	fetchPC
	jump	fault
	halt
	;; write Mreg to memory and then to AC if AC not 0
wrself:	aE,mM,aluSETM,writeMEM,brWRITE	.
	setFLAGS,brSELF	wrselfA
	jump	fault
	halt
;;; 0060
	;; write Mreg to AC if AC is not 0
wrselfA:	aPCnext,aluSETA,loadPC,readMEM,brREAD	fetchPC
	mM,aluSETM,writeAC	next
	halt
	halt
	;; write Mreg to memory and then to AC
wrboth:	aE,mM,aluSETM,writeMEM,brWRITE	.
	mM,aluSETM,setFLAGS,writeAC	next
	jump	fault
	;; finish up with a jump to E
jumpe:	aE,aluSETA,loadPC,readMEM,brREAD	fetchPC
;;; 0070
	;; finish up the EXCH instruction
exch:	aE,mAC,aluSETM,writeMEM,brWRITE	.
	mM,aluSETM,writeAC	next ; write Mreg to AC and we're done
	jump	fault
	halt
	;; Jump if any of the flags were cleared
jfcl:	aPCnext,aluSETA,loadPC,readMEM,brREAD	fetchPC ; no jump
	aE,aluSETA,loadPC,readMEM,brREAD	fetchPC ; jump
	halt
	halt
;;; 0100
	;; finish up JSA
jsa:	brWRITE	.
	aPCnext,mE,swapM,aluHLL,writeAC	jsa1 ; AC <- E,PC
	jump	fault
jsa1:	aE,aluSETA,loadPC	next ; jump E+1
	halt
	halt
	halt
	halt
;;; 0110
	;; Write to memory after SOS, then write to self and save flags
sosWR:	aE,mM,aluSETM,writeMEM,brWRITE	. ; wait for the memory write to complete
	mM,aluSETM,setFLAGS,brSELF	wrskip ; now that the memory write completed, set flags
	jump	fault
	halt
	;; finish up JSR
jsr1:	brWRITE	.
	aE,aluSETA,loadPC,clrFPD	next ; jump E+1
	jump	fault
jsr:	aE,mM,aluSETM,writeMEM,brWRITE	jsr1
;;; 0120
	;; For the Test instructions
	;; The next and skip labels are for general use when we need an unconditional next or skip operation
	;; if the operands and'd together are 0, then skip
teste:	aPCskip,loadPC,readMEM,brREAD	fetchPC
next:	aPCnext,loadPC,readMEM,brREAD	fetchPC
	;; if the operands and'd together are not 0, then skip
testn:	aPCnext,loadPC,readMEM,brREAD	fetchPC
skip:	aPCskip,loadPC,readMEM,brREAD	fetchPC
	halt
	halt
	halt
	halt
;;; 0130
	;; finish up JRA
jra1:	aA,readMEM,brREAD	.
	aA,mMEM,aluSETM,writeAC	jumpe ; AC now gets C(LEFT(AC))
	jump	fault
	jump	intrpt
jra:	aA,readMEM,brREAD	jra1 ; A has swapped AC
	halt
	halt
	halt
;;; 0140
	;; finish up PUSH
	;; need to catch overflow !!!
push1:	aA,writeMEM,brWRITE	.
	aA,aluSETA,writeAC	next ; saved the increment AC in A into AC
	jump	fault
push:	aA,mM,aluSETM,writeMEM,brWRITE	push1
	halt
	halt
	halt
	halt
;;; 0150
	;; finish up POP
	;; need to catch overflow !!!
pop:	aAC,readMEM,brREAD	.
	aAC,mMEM,aluSETM,loadM	pop2
	jump	fault
	jump	intrpt
pop3:	aE,writeMEM,brWRITE	.
	mAC,aluSOB,writeAC	next
	jump	fault
pop2:	aE,mM,aluSETM,writeMEM,brWRITE	pop3
;;; 0160
	;; Finish up PUSHJ
	;; need to catch overflow!!!
pushj3:	aA,writeMEM,brWRITE	.
	aA,aluSETA,writeAC,clrFPD	jumpe ; saved the incremented AC in A into AC
	jump	fault
pushj:	mAC,aluAOB,loadA	pushj2 ; increment AC into Areg
pushj2:	aA,mM,aluSETM,writeMEM,brWRITE	pushj3 ; C(AC) <- PSW,PCnext (which is in Mreg)
	halt
	halt
	halt
;;; 0170
	;; Finish up POPJ
	;; need to catch overflow !!!
popj:	aAC,readMEM,brREAD	.
	aAC,mMEM,aluSETM,loadPC	popj2
	jump	fault
	jump	intrpt
popj2:	aPC,mAC,aluSOB,writeAC,readMEM,brWRITE	fetchPC ; decrement AC
	halt
	halt
	halt
;;; 0200
ashc:	aAC,mE,aluASHC,loadALOW,writeAC,saveFLAGS,setFLAGS	wralow
rotc:	aAC,mE,aluROTC,loadALOW,writeAC				wralow
lshc:	aAC,mE,aluLSHC,loadALOW,writeAC				wralow
wralow:	aluSETAlow,ACnext,writeAC	next ; write Alow into A+1
	halt
	halt
	halt
	halt
;;; 0210
	;; MULx and IMULx
mul0:	aA,mM,aluMULADD,loadA,loadALOW	mul1
mul1:	aA,mM,aluMULADD,loadA,loadALOW	mul2
mul2:	aA,mM,aluMULADD,loadA,loadALOW	mul3
mul3:	aA,mM,aluMULADD,loadA,loadALOW	mul4
mul4:	aA,mM,aluMULADD,loadA,loadALOW	mul5
mul5:	aA,mM,aluMULADD,loadA,loadALOW	mul6
mul6:	aA,mM,aluMULADD,loadA,loadALOW	mul7
mul7:	aA,mM,aluMULADD,loadA,loadALOW	mul10
;;; 0220
mul10:	aA,mM,aluMULADD,loadA,loadALOW	mul11
mul11:	aA,mM,aluMULADD,loadA,loadALOW	mul12
mul12:	aA,mM,aluMULADD,loadA,loadALOW	mul13
mul13:	aA,mM,aluMULADD,loadA,loadALOW	mul14
mul14:	aA,mM,aluMULADD,loadA,loadALOW	mul15
mul15:	aA,mM,aluMULADD,loadA,loadALOW	mul16
mul16:	aA,mM,aluMULADD,loadA,loadALOW	mul17
mul17:	aA,mM,aluMULADD,loadA,loadALOW	mul20
;;; 0230
mul20:	aA,mM,aluMULADD,loadA,loadALOW	mul21
mul21:	aA,mM,aluMULADD,loadA,loadALOW	mul22
mul22:	aA,mM,aluMULADD,loadA,loadALOW	mul23
mul23:	aA,mM,aluMULADD,loadA,loadALOW	mul24
mul24:	aA,mM,aluMULADD,loadA,loadALOW	mul25
mul25:	aA,mM,aluMULADD,loadA,loadALOW	mul26
mul26:	aA,mM,aluMULADD,loadA,loadALOW	mul27
mul27:	aA,mM,aluMULADD,loadA,loadALOW	mul30
;;; 0240
mul30:	aA,mM,aluMULADD,loadA,loadALOW	mul31
mul31:	aA,mM,aluMULADD,loadA,loadALOW	mul32
mul32:	aA,mM,aluMULADD,loadA,loadALOW	mul33
mul33:	aA,mM,aluMULADD,loadA,loadALOW	mul34
mul34:	aA,mM,aluMULADD,loadA,loadALOW	mul35
mul35:	aA,mM,aluMULADD,loadA,loadALOW	mul36
mul36:	aA,mM,aluMULADD,loadA,loadALOW	mul37
mul37:	aA,mM,aluMULADD,loadA,loadALOW	mul40
;;; 0250
mul40:	aA,mM,aluMULADD,loadA,loadALOW	mul41
mul41:	aA,mM,aluMULADD,loadA,loadALOW	mul42
mul42:	aA,mM,aluMULADD,loadA,loadALOW,brMUL	imulwr
	halt
	;;  writing to memory for IMULB
imulb1:	aE,mM,aluSETM,writeMEM,brWRITE	.
	;; if I loaded PC from mem_addr, this could load the new PC here !!!
	mM,aluSETM,setFLAGS,writeAC		next ; write to AC
	jump	fault
imulb:	aE,mM,aluSETM,writeMEM,brWRITE		imulb1 ; start the write to memory
;;; 0260
	;; Do final operation to finish the multiply and then write answer where it needs to go
imulwr:	aA,mM,aluIMULSUB,saveFLAGS,setFLAGS,writeAC,loadALOW	next ; MUL  : write to AC
	aA,mM,aluIMULSUB,saveFLAGS,setFLAGS,writeAC,loadALOW	next ; IMUL : write to AC
	aA,mM,aluIMULSUB,saveFLAGS,loadM,loadA,loadALOW		mulm ; MULM : put answer in Mreg also
	aA,mM,aluIMULSUB,saveFLAGS,loadM,loadA,loadALOW		imulb ; MULB : put answer in Mreg also
mulwr:	aA,mM,aluMULSUB,saveFLAGS,setFLAGS,writeAC,loadALOW	wralow ; MUL  : write to AC and then AC+1
	aA,mM,aluMULSUB,saveFLAGS,setFLAGS,writeAC,loadALOW	wralow ; IMUL : write to AC and then AC+1
	aA,mM,aluMULSUB,saveFLAGS,loadM,loadA,loadALOW		mulm ; MULM : put answer in Mreg also
	aA,mM,aluMULSUB,saveFLAGS,loadM,loadA,loadALOW		mulb ; MULB : put answer in Mreg also
;;; 0270
	;; writing to memory for MULM and IMULM
mulm1:	aE,mM,aluSETM,writeMEM,brWRITE	.
	aPCnext,setFLAGS,loadPC,readMEM,brREAD	fetchPC ; set flags and move on
	jump	fault
mulm:	aE,mM,aluSETM,writeMEM,brWRITE		mulm1 ; start the write to memory
	;;  writing to memory for MULB
mulb1:	aE,mM,aluSETM,writeMEM,brWRITE	.
	mM,aluSETM,setFLAGS,writeAC		wralow ; write to AC and then AC+1
	jump	fault
mulb:	aE,mM,aluSETM,writeMEM,brWRITE		mulb1 ; start the write to memory
;;; 0300
	;; IDIVx and DIVx
div00:	aA,mM,aluDIVOP,loadA,loadALOW,brOVR	div01
	halt
div02:	aA,mM,aluDIVOP,loadA,loadALOW	div03
div03:	aA,mM,aluDIVOP,loadA,loadALOW	div04
div04:	aA,mM,aluDIVOP,loadA,loadALOW	div05
div05:	aA,mM,aluDIVOP,loadA,loadALOW	div06
div06:	aA,mM,aluDIVOP,loadA,loadALOW	div07
div07:	aA,mM,aluDIVOP,loadA,loadALOW	div10
;;; 0310
div10:	aA,mM,aluDIVOP,loadA,loadALOW	div11
div11:	aA,mM,aluDIVOP,loadA,loadALOW	div12
div12:	aA,mM,aluDIVOP,loadA,loadALOW	div13
div13:	aA,mM,aluDIVOP,loadA,loadALOW	div14
div14:	aA,mM,aluDIVOP,loadA,loadALOW	div15
div15:	aA,mM,aluDIVOP,loadA,loadALOW	div16
div16:	aA,mM,aluDIVOP,loadA,loadALOW	div17
div17:	aA,mM,aluDIVOP,loadA,loadALOW	div20
;;; 0320
div20:	aA,mM,aluDIVOP,loadA,loadALOW	div21
div21:	aA,mM,aluDIVOP,loadA,loadALOW	div22
div22:	aA,mM,aluDIVOP,loadA,loadALOW	div23
div23:	aA,mM,aluDIVOP,loadA,loadALOW	div24
div24:	aA,mM,aluDIVOP,loadA,loadALOW	div25
div25:	aA,mM,aluDIVOP,loadA,loadALOW	div26
div26:	aA,mM,aluDIVOP,loadA,loadALOW	div27
div27:	aA,mM,aluDIVOP,loadA,loadALOW	div30
;;; 0330
div30:	aA,mM,aluDIVOP,loadA,loadALOW	div31
div31:	aA,mM,aluDIVOP,loadA,loadALOW	div32
div32:	aA,mM,aluDIVOP,loadA,loadALOW	div33
div33:	aA,mM,aluDIVOP,loadA,loadALOW	div34
div34:	aA,mM,aluDIVOP,loadA,loadALOW	div35
div35:	aA,mM,aluDIVOP,loadA,loadALOW	div36
div36:	aA,mM,aluDIVOP,loadA,loadALOW	div37
div37:	aA,mM,aluDIVOP,loadA,loadALOW	div40
;;; 0340
div40:	aA,mM,aluDIVOP,loadA,loadALOW	div41
div41:	aA,mM,aluDIVOP,loadA,loadALOW	div42
div42:	aA,mM,aluDIVOP,loadA,loadALOW	div43
div43:	aA,mM,aluDIVOP,loadA,loadALOW	fixr
fixr:	aA,mM,aluDIVFIXR,loadA,loadALOW,brMUL	idivwr
	;; loads Areg,Alow <- |AC,Alow|
divhi:	aAC,aluDIVMAG72,loadA,loadALOW	div00
	;; check for overflow
div01:	aA,mM,aluDIVOP,loadA,loadALOW	div02
	aPCnext,aluSETA,loadPC,setOVF,setNODIV,readMEM,brREAD	fetchPC
;;; 0350
	;; Do final fixup for DIV and write answer where it needs to go
idivwr:	aA,mM,aluDIVFIXUP,loadA,loadALOW,writeAC	wralow ; IDIV  : AC <- Areg (quotient)
	aA,mM,aluDIVFIXUP,loadA,loadALOW,writeAC	wralow ; IDIVI : AC <- Areg (quotient)
	aA,mM,aluDIVFIXUP,loadA,loadALOW,loadM		divm   ; IDIVM : move quotient to Mreg
	aA,mM,aluDIVFIXUP,loadA,loadALOW,loadM		divb   ; IDIVB : move quotient to Mreg
	aA,mM,aluDIVFIXUP,loadA,loadALOW,writeAC	wralow ; DIV  : AC <- Areg (quotient)
	aA,mM,aluDIVFIXUP,loadA,loadALOW,writeAC	wralow ; DIVI : AC <- Areg (quotient)
	aA,mM,aluDIVFIXUP,loadA,loadALOW,loadM		divm   ; DIVM : move quotient to Mreg
	aA,mM,aluDIVFIXUP,loadA,loadALOW,loadM		divb   ; DIVB : move quotient to Mreg
;;; 0360
	;; write to memory for IDIVM and DIVM
divm1:	aE,mM,aluSETM,writeMEM,brWRITE	.
	aPCnext,aluSETA,loadPC,readMEM,brREAD	fetchPC
	jump	fault
divm:	aE,mM,aluSETM,writeMEM,brWRITE	divm1
	;; write to memory for IDIVB and DIVB
divb1:	aE,mM,aluSETM,writeMEM,brWRITE	.
	mM,aluSETM,writeAC		wralow ; AC <- quotient
	jump	fault
divb:	aE,mM,aluSETM,writeMEM,brWRITE	divb1
;;; 0370
	;; EA Calculation for Byte instructions
byteEA:	ACindex,aAC,mE,aluADD,loadY,brI	checkIBP ; Index
	aE,readMEM,brREAD		fetchIBP ; Indirect
	aE,readMEM,brREAD		bpREAD   ; EAcalc done, read in byte
	halt
	;; do the read for an Indirect and loop back to byteEA
fetchIBP:	aE,readMEM,brREAD	.
	aE,mMEM,aluSETM,loadIX,loadY,brIX	byteEA
	jump	fault
	jump	intrpt
;;; 0400
	;; If there was a Index, now check if there's an Indirect too
checkIBP:	aE,readMEM,brREAD	bpREAD   ; EAcalc done, read in byte
	aE,readMEM,brREAD		fetchIBP ; start the read for the Indirect
	halt
	halt
	;; finish writing the incremented Byte Pointer back to memory
wrBP:	aE,mM,aluSETM,writeMEM,brWRITE	.
	mM,aluSETM,setFPD,loadBP,loadIX,loadY,brIX	byteEA	; First-Part done, now BP EA calc
	jump	fault
ldb:	aBPMASK,mM,aluAND,writeAC	next ; AC <- M & BPmask
;;; 0410
bpREAD:	aE,readMEM,brREAD	.
	aE,mMEM,aluSETM,loadM,brBPDISP	bpdisp ; store the byte word in Mreg
	jump	fault
	jump	intrpt
bpdisp:	aM,mBPPNEG,aluLSH,loadM,clrFPD	ldb ; ILDB : M <- M >> P
	aM,mBPPNEG,aluLSH,loadM		ldb ; LDB : M <- M >> P
	aBPMASK,mBPP,aluLSH,loadALOW	idpb1 ; IDPB : Alow <- BPmask << P
	aBPMASK,mBPP,aluLSH,loadALOW	dpb1 ; DPB : Alow <- BPmask << P
;;; 0420
	;; Finish up DPB
dpbwr:	aE,mM,aluSETM,writeMEM,brWRITE	. ; C(E) <- M
	aPCnext,loadPC,readMEM,brREAD	fetchPC
	jump	fault
dpb1:	aAC,mBPP,aluLSH,loadA		dpb2 ; A <- AC << P
dpb2:	aA,mM,aluDPB,loadM		dpbwr ; M <- A | M (masked by Alow)
	halt
	halt
	halt
;;; 0430
	;; Finish up IDPB.  This is identical to DPB except for clearing FPD at the end
idpbwr:	aE,mM,aluSETM,writeMEM,brWRITE	. ; C(E) <- M
	clrFPD,aPCnext,loadPC,readMEM,brREAD	fetchPC ; clear FPD and done
	jump	fault
idpb1:	aAC,mBPP,aluLSH,loadA		idpb2 ; A <- AC << P
idpb2:	aA,mM,aluDPB,loadM		idpbwr ; M <- A | M (masked by Alow)
	halt
	;; Either ILDP or IDPB, skip incrementing the byte pointer if FPD is set
fpd:	aE,mM,aluIBP,loadM,writeMEM,brWRITE	wrBP
	mM,aluSETM,setFPD,loadBP,loadIX,loadY,brIX	byteEA	; First-Part done, now BP EA calc
;;; 0440
	;; Read from AC left
bltrd:	aSWAP,readMEM,brREAD		.
	aSWAP,mMEM,aluSETM,loadM	bltwr ; start write. if I latch the read data, I can start the write here !!!
	jump	fault
	jump	intrpt
bltwr:	aAC,mM,aluSETM,writeMEM,brWRITE	.
	aAC,brBLTDONE	bltdone
	jump	fault
	halt
;;; 0450
bltdone:	mAC,aluAOB,writeAC	bltrd
	aPCnext,aluSETA,loadPC,readMEM,brREAD	fetchPC
	halt
	halt
	;; Write the JFFO result into AC+1 and either jump or not
jffo:	mM,aluSETM,ACnext,writeAC	next
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
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 0770
fault:	halt
intrpt:	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 1000
	;; The instruction dispatch table starts here
dispatch:	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 1010
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 1020
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 1030
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 1040
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 1050
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 1060
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 1070
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 1100
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 1110
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 1120
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 1130
	halt
	halt
	halt
	aE,mM,aluIBP,loadM,writeMEM,brWRITE	wrmem ; IBP
	brFPD					fpd  ; ILDB
	mM,aluSETM,loadBP,loadIX,loadY,brIX	byteEA ; LDB - move Mreg over to BP, I, X, and Y
	brFPD					fpd  ; IDBP
	mM,aluSETM,loadBP,loadIX,loadY,brIX	byteEA ; DPB - move Mreg over to BP, I, X, and Y
;;; 1140
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 1150
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 1160
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 1170
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 1200
	mM,aluSETM,writeAC			next ; MOVE - AC <- C(E)
	mE,aluSETM,writeAC			next ; MOVEI - AC <- 0,E
	aE,mAC,aluSETM,loadM,writeMEM,brWRITE	wrmem ; MOVEM - C(E) <- AC
	aE,mM,aluSETM,writeMEM,brWRITE		wrself ; MOVES - C(E) and AC (if not 0) <- C(E)
	mM,swapM,aluSETM,writeAC		next ; MOVS - AC <- swap(C(E))
	mE,swapM,aluSETM,writeAC		next ; MOVSI - AC <- E,0
	aE,mAC,swapM,aluSETM,loadM,writeMEM,brWRITE	wrmem ; MOVSM - C(E) <- swap(AC)
	aE,mM,swapM,aluSETM,loadM,writeMEM,brWRITE	wrself ; MOVSS - C(E) and AC (if not 0) <- swap(C(E))
;;; 1210
	mM,aluNEGATE,saveFLAGS,setFLAGS,writeAC		next ; MOVN - AC <- C(E)
	mE,aluNEGATE,saveFLAGS,setFLAGS,writeAC		next ; MOVNI - AC <- 0,E
	aE,mAC,aluNEGATE,saveFLAGS,loadM,writeMEM,brWRITE	wrmem ; MOVNM - C(E) <- AC
	aE,mM,aluNEGATE,saveFLAGS,loadM,writeMEM,brWRITE	wrself ; MOVNS - C(E) and AC (if not 0) <- C(E)
	mM,aluMAGNITUDE,saveFLAGS,setFLAGS,writeAC	next ; MOVM - AC <- C(E)
	mE,aluMAGNITUDE,saveFLAGS,setFLAGS,writeAC	next ; MOVMI - AC <- 0,E
	aE,mAC,aluMAGNITUDE,saveFLAGS,loadM,writeMEM,brWRITE	wrmem ; MOVMM - C(E) <- AC
	aE,mM,aluMAGNITUDE,saveFLAGS,loadM,writeMEM,brWRITE	wrself ; MOVMS - C(E) and AC (if not 0) <- C(E)
;;; 1220
imul:	aAC,aluSETAlow,loadALOW,mulstart	mul0 ; IMUL : move AC to Alow, mulstart also clears Areg
	mE,aluSETM,loadM			imul  ; IMULI : move E into Mreg and then proceed as MUL
	;; the same as IMUL until it's time to write the answer
	aAC,aluSETAlow,loadALOW,mulstart	mul0 ; IMULM
	aAC,aluSETAlow,loadALOW,mulstart	mul0 ; IMULB
mul:	aAC,aluSETAlow,loadALOW,mulstart	mul0 ; MUL : move AC to Alow, mulstart also clears Areg
	mE,aluSETM,loadM			mul  ; MULI : move E into Mreg and then proceed as MUL
	;; the same as IMUL until it's time to write the answer
	aAC,aluSETAlow,loadALOW,mulstart	mul0 ; MULM
	aAC,aluSETAlow,loadALOW,mulstart	mul0 ; MULB
;;; 1230
idiv:	aAC,aluDIVMAG36,loadA,loadALOW		div00 ; IDIV : A,Alow <- |AC| << 1
	mE,aluSETM,loadM			idiv  ; IDIVI : move E to Mreg
	;;  the same as IDIV until it's time to write the answer
	aAC,aluDIVMAG36,loadA,loadALOW		div00 ; IDIVM
	aAC,aluDIVMAG36,loadA,loadALOW		div00 ; IDIVB
div:	aAC,ACnext,aluSETAlow,loadALOW		divhi ; DIV  : Alow <- AC+1
	mE,aluSETM,loadM			div   ; DIVI : move E to Mreg
	;;  the same as DIV until it's time to write the answer
	aAC,ACnext,aluSETAlow,loadALOW		divhi ; DIVM : Alow <- AC+1
	aAC,ACnext,aluSETAlow,loadALOW		divhi ; DIVB : Alow <- AC+1
;;; 1240
	aAC,mE,aluASH,saveFLAGS,setFLAGS,writeAC	next ; ASH
	aAC,mE,aluROT,writeAC				next ; ROT
	aAC,mE,aluLSH,writeAC				next ; LSH
	mAC,aluJFFO,loadM,brOVR		jffo ; JFFO : M <- JFFO(AC)
	aAC,ACnext,aluSETAlow,loadALOW	ashc ; ASHC
	aAC,ACnext,aluSETAlow,loadALOW	rotc ; ROTC
	aAC,ACnext,aluSETAlow,loadALOW	lshc ; LSHC
	halt				     ; CIRC
;;; 1250
	aE,mAC,aluSETM,writeMEM,brWRITE	exch  ; EXCH : start writing AC here
	aSWAP,readMEM,brREAD		bltrd ; BLT : start read from AC left
	mAC,aluAOB,writeAC,loadM,brCOMP	jumpc ; AOBJP
	mAC,aluAOB,writeAC,loadM,brCOMP	jumpc ; AOBJN
	;; Plain JRST.  Other variants are dispatched to 1730
	aE,aluSETA,readMEM,loadPC,brREAD	fetchPC
	clrFLAGS,brJFCL	jfcl	; JFCL
	aE,mM,aluSETM,loadOPA,loadIX,loadY,brIX	calcEA ; XCT
	halt					       ; MAP
;;; 1260
	aPCnext,aluSETA,loadM		pushj ; PUSHJ
	mAC,aluAOB,loadA		push  ; PUSH
	aAC,readMEM,brREAD		pop   ; POP
	aAC,readMEM,brREAD		popj  ; POPJ
	aPCnext,aluSETA,loadM		jsr   ; JSR : C(E) <- PSW,PC, jump E+1
	aPCnext,aluSETA,writeAC,clrFPD	jumpe ; JSP : AC <- PSW,PC, jump E
	aE,mAC,aluSETM,writeMEM,brWRITE	jsa   ; JSA : C(E) <- AC, AC <- E,PC, jump E+1
	mAC,swapM,aluSETM,loadA		jra   ; JRA : AC <- C(LEFT(AC)), jump E
;;; 1270
	aAC,mM,aluADD,saveFLAGS,setFLAGS,writeAC	next ; ADD
	aAC,mE,aluADD,saveFLAGS,setFLAGS,writeAC	next ; ADDI
	aAC,mM,aluADD,saveFLAGS,loadM,brWRITE		wrmem ; ADDM
	aAC,mM,aluADD,saveFLAGS,loadM,brWRITE		wrboth ; ADDB
	aAC,mM,aluSUB,saveFLAGS,setFLAGS,writeAC	next ; SUB
	aAC,mE,aluSUB,saveFLAGS,setFLAGS,writeAC	next ; SUBI
	aAC,mM,aluSUB,saveFLAGS,loadM,brWRITE		wrmem ; SUBM
	aAC,mM,aluSUB,saveFLAGS,loadM,brWRITE		wrboth ; SUBB
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
	mAC,aluSETM,brCOMP	jumpc ; JUMP -- could optimize!!!
	mAC,aluSETM,brCOMP	jumpc ; JUMPL
	mAC,aluSETM,brCOMP	jumpc ; JUMPE
	mAC,aluSETM,brCOMP	jumpc ; JUMPLE
	mAC,aluSETM,brCOMP	jumpc ; JUMPA -- could optimize!!!
	mAC,aluSETM,brCOMP	jumpc ; JUMPGE
	mAC,aluSETM,brCOMP	jumpc ; JUMPN
	mAC,aluSETM,brCOMP	jumpc ; JUMPG
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
	aONE,mAC,aluADD,saveFLAGS,setFLAGS,writeAC,brCOMP	jumpc ; AOJ
	aONE,mAC,aluADD,saveFLAGS,setFLAGS,writeAC,brCOMP	jumpc ; AOJL
	aONE,mAC,aluADD,saveFLAGS,setFLAGS,writeAC,brCOMP	jumpc ; AOJE
	aONE,mAC,aluADD,saveFLAGS,setFLAGS,writeAC,brCOMP	jumpc ; AOJLE
	aONE,mAC,aluADD,saveFLAGS,setFLAGS,writeAC,brCOMP	jumpc ; AOJA
	aONE,mAC,aluADD,saveFLAGS,setFLAGS,writeAC,brCOMP	jumpc ; AOJGE
	aONE,mAC,aluADD,saveFLAGS,setFLAGS,writeAC,brCOMP	jumpc ; AOJN
	aONE,mAC,aluADD,saveFLAGS,setFLAGS,writeAC,brCOMP	jumpc ; AOJG
;;; 1350
	;; Add 1 to Memory and Skip, write back to Memory and also AC if AC not 0
	aONE,mM,aluADD,saveFLAGS,loadM,brWRITE	sosWR ; AOS
	aONE,mM,aluADD,saveFLAGS,loadM,brWRITE	sosWR ; AOSL
	aONE,mM,aluADD,saveFLAGS,loadM,brWRITE	sosWR ; AOSE
	aONE,mM,aluADD,saveFLAGS,loadM,brWRITE	sosWR ; AOSLE
	aONE,mM,aluADD,saveFLAGS,loadM,brWRITE	sosWR ; AOSA
	aONE,mM,aluADD,saveFLAGS,loadM,brWRITE	sosWR ; AOSGE
	aONE,mM,aluADD,saveFLAGS,loadM,brWRITE	sosWR ; AOSN
	aONE,mM,aluADD,saveFLAGS,loadM,brWRITE	sosWR ; AOSG
;;; 1360
	;; Subtract 1 from AC and Jump
	;; Adding -1 makes the condition codes come out right
	aMONE,mAC,aluADD,saveFLAGS,setFLAGS,writeAC,brCOMP	jumpc ; SOJ
	aMONE,mAC,aluADD,saveFLAGS,setFLAGS,writeAC,brCOMP	jumpc ; SOJL
	aMONE,mAC,aluADD,saveFLAGS,setFLAGS,writeAC,brCOMP	jumpc ; SOJE
	aMONE,mAC,aluADD,saveFLAGS,setFLAGS,writeAC,brCOMP	jumpc ; SOJLE
	aMONE,mAC,aluADD,saveFLAGS,setFLAGS,writeAC,brCOMP	jumpc ; SOJA
	aMONE,mAC,aluADD,saveFLAGS,setFLAGS,writeAC,brCOMP	jumpc ; SOJGE
	aMONE,mAC,aluADD,saveFLAGS,setFLAGS,writeAC,brCOMP	jumpc ; SOJN
	aMONE,mAC,aluADD,saveFLAGS,setFLAGS,writeAC,brCOMP	jumpc ; SOJG
;;; 1370
	;; Subtract 1 from Memory and Skip, write back to Memory and also AC if AC not 0
	;; Adding -1 makes the condition codes come out right
	aMONE,mM,aluADD,saveFLAGS,loadM,brWRITE	sosWR ; SOS
	aMONE,mM,aluADD,saveFLAGS,loadM,brWRITE	sosWR ; SOSL
	aMONE,mM,aluADD,saveFLAGS,loadM,brWRITE	sosWR ; SOSE
	aMONE,mM,aluADD,saveFLAGS,loadM,brWRITE	sosWR ; SOSLE
	aMONE,mM,aluADD,saveFLAGS,loadM,brWRITE	sosWR ; SOSA
	aMONE,mM,aluADD,saveFLAGS,loadM,brWRITE	sosWR ; SOSGE
	aMONE,mM,aluADD,saveFLAGS,loadM,brWRITE	sosWR ; SOSN
	aMONE,mM,aluADD,saveFLAGS,loadM,brWRITE	sosWR ; SOSG
;;; 1400
	;; The logic instructions
	aAC,mM,aluSETZ,writeAC		next   ; SETZ
	aAC,mE,aluSETZ,writeAC		next   ; SETZI
	aAC,mM,aluSETZ,loadM,brWRITE	wrmem  ; SETZM
	aAC,mM,aluSETZ,loadM,brWRITE	wrboth ; SETZB
	
	aAC,mM,aluAND,writeAC		next   ; AND
	aAC,mE,aluAND,writeAC		next   ; ANDI
	aAC,mM,aluAND,loadM,brWRITE	wrmem  ; ANDM
	aAC,mM,aluAND,loadM,brWRITE	wrboth ; ANDB
;;; 1410
	aAC,mM,aluANDCA,writeAC		next   ; ANDCA
	aAC,mE,aluANDCA,writeAC		next   ; ANDCAI
	aAC,mM,aluANDCA,loadM,brWRITE	wrmem  ; ANDCAM
	aAC,mM,aluANDCA,loadM,brWRITE	wrboth ; ANDCAB

	aAC,mM,aluSETM,writeAC		next   ; SETM
	aAC,mE,aluSETM,writeAC		next   ; SETMI
	aAC,mM,aluSETM,loadM,brWRITE	wrmem  ; SETMM
	aAC,mM,aluSETM,loadM,brWRITE	wrboth ; SETMB
;;; 1420
	aAC,mM,aluANDCM,writeAC		next   ; ANDCM
	aAC,mE,aluANDCM,writeAC		next   ; ANDCMI
	aAC,mM,aluANDCM,loadM,brWRITE	wrmem  ; ANDCMM
	aAC,mM,aluANDCM,loadM,brWRITE	wrboth ; ANDCMB

	aAC,mM,aluSETA,writeAC		next   ; SETA
	aAC,mE,aluSETA,writeAC		next   ; SETAI
	aAC,mM,aluSETA,loadM,brWRITE	wrmem  ; SETAM
	aAC,mM,aluSETA,loadM,brWRITE	wrboth ; SETAB
;;; 1430
	aAC,mM,aluXOR,writeAC		next   ; XOR
	aAC,mE,aluXOR,writeAC		next   ; XORI
	aAC,mM,aluXOR,loadM,brWRITE	wrmem  ; XORM
	aAC,mM,aluXOR,loadM,brWRITE	wrboth ; XORB

	aAC,mM,aluIOR,writeAC		next   ; IOR
	aAC,mE,aluIOR,writeAC		next   ; IORI
	aAC,mM,aluIOR,loadM,brWRITE	wrmem  ; IORM
	aAC,mM,aluIOR,loadM,brWRITE	wrboth ; IORB
;;; 1440
	aAC,mM,aluANDCB,writeAC		next   ; ANDCB
	aAC,mE,aluANDCB,writeAC		next   ; ANDCBI
	aAC,mM,aluANDCB,loadM,brWRITE	wrmem  ; ANDCBM
	aAC,mM,aluANDCB,loadM,brWRITE	wrboth ; ANDCBB

	aAC,mM,aluEQV,writeAC		next   ; EQV
	aAC,mE,aluEQV,writeAC		next   ; EQVI
	aAC,mM,aluEQV,loadM,brWRITE	wrmem  ; EQVM
	aAC,mM,aluEQV,loadM,brWRITE	wrboth ; EQVB
;;; 1450
	aAC,mM,aluSETCA,writeAC		next   ; SETCA
	aAC,mE,aluSETCA,writeAC		next   ; SETCAI
	aAC,mM,aluSETCA,loadM,brWRITE	wrmem  ; SETCAM
	aAC,mM,aluSETCA,loadM,brWRITE	wrboth ; SETCAB

	aAC,mM,aluORCA,writeAC		next   ; ORCA
	aAC,mE,aluORCA,writeAC		next   ; ORCAI
	aAC,mM,aluORCA,loadM,brWRITE	wrmem  ; ORCAM
	aAC,mM,aluORCA,loadM,brWRITE	wrboth ; ORCAB
;;; 1460
	aAC,mM,aluSETCM,writeAC		next   ; SETCM
	aAC,mE,aluSETCM,writeAC		next   ; SETCMI
	aAC,mM,aluSETCM,loadM,brWRITE	wrmem  ; SETCMM
	aAC,mM,aluSETCM,loadM,brWRITE	wrboth ; SETCMB

	aAC,mM,aluORCM,writeAC		next   ; ORCM
	aAC,mE,aluORCM,writeAC		next   ; ORCMI
	aAC,mM,aluORCM,loadM,brWRITE	wrmem  ; ORCMM
	aAC,mM,aluORCM,loadM,brWRITE	wrboth ; ORCMB
;;; 1470
	aAC,mM,aluORCB,writeAC		next   ; ORCB
	aAC,mE,aluORCB,writeAC		next   ; ORCBI
	aAC,mM,aluORCB,loadM,brWRITE	wrmem  ; ORCBM
	aAC,mM,aluORCB,loadM,brWRITE	wrboth ; ORCBB

	aAC,mM,aluSETO,writeAC		next   ; SETO
	aAC,mE,aluSETO,writeAC		next   ; SETOI
	aAC,mM,aluSETO,loadM,brWRITE	wrmem  ; SETOM
	aAC,mM,aluSETO,loadM,brWRITE	wrboth ; SETOB
;;; 1500
	;; Half-word moves - Halfword[LR][LR][- Zeros Ones Extend][- Immediate Memory Self]
	;;   Mode     Suffix    Source     Destination
	;;  Basic                (E)           AC
	;;  Immediate   I        0,E           AC
	;;  Memory      M         AC           (E)
	;;  Self        S        (E)           (E) and AC if AC nonzero
	aAC,mM,aluHLL,writeAC			next   ; HLL
	aAC,mE,aluHLL,writeAC			next   ; HLLI
	aM,mAC,aluHLL,loadM,brWRITE		wrmem  ; HLLM
	aM,mM,aluHLL,loadM,brWRITE		wrself ; HLLS

	aAC,mM,swapM,aluHLL,writeAC		next   ; HRL
	aAC,mE,swapM,aluHLL,writeAC		next   ; HRLI
	aM,mAC,swapM,aluHLL,loadM,brWRITE	wrmem  ; HRLM
	aM,mM,swapM,aluHLL,loadM,brWRITE	wrself ; HRLS
;;; 1510
	aZERO,mM,aluHLL,writeAC			next   ; HLLZ
	aZERO,mE,aluHLL,writeAC			next   ; HLLZI
	aZERO,mAC,aluHLL,loadM,brWRITE		wrmem  ; HLLZM
	aZERO,mM,aluHLL,loadM,brWRITE		wrself ; HLLZS

	aZERO,mM,swapM,aluHLL,writeAC		next   ; HRLZ
	aZERO,mE,swapM,aluHLL,writeAC		next   ; HRLZI
	aZERO,mAC,swapM,aluHLL,loadM,brWRITE	wrmem  ; HRLZM
	aZERO,mM,swapM,aluHLL,loadM,brWRITE	wrself ; HRLZS
;;; 1520
	aMONE,mM,aluHLL,writeAC			next   ; HLLO
	aMONE,mE,aluHLL,writeAC			next   ; HLLOI
	aMONE,mAC,aluHLL,loadM,brWRITE		wrmem  ; HLLOM
	aMONE,mM,aluHLL,loadM,brWRITE		wrself ; HLLOS

	aMONE,mM,swapM,aluHLL,writeAC		next   ; HRLO
	aMONE,mE,swapM,aluHLL,writeAC		next   ; HRLOI
	aMONE,mAC,swapM,aluHLL,loadM,brWRITE	wrmem  ; HRLOM
	aMONE,mM,swapM,aluHLL,loadM,brWRITE	wrself ; HRLOS
;;; 1530
	aSXT,mM,aluHLL,writeAC			next   ; HLLE
	aSXT,mE,aluHLL,writeAC			next   ; HLLEI
	aSXT,mAC,aluHLL,loadM,brWRITE		wrmem  ; HLLEM
	aSXT,mM,aluHLL,loadM,brWRITE		wrself ; HLLES

	aSXT,mM,swapM,aluHLL,writeAC		next   ; HRLE
	aSXT,mE,swapM,aluHLL,writeAC		next   ; HRLEI
	aSXT,mAC,swapM,aluHLL,loadM,brWRITE	wrmem  ; HRLEM
	aSXT,mM,swapM,aluHLL,loadM,brWRITE	wrself ; HRLES
;;; 1540
	aAC,mM,swapM,aluHLR,writeAC		next   ; HRR
	aAC,mE,swapM,aluHLR,writeAC		next   ; HRRI
	aM,mAC,swapM,aluHLR,loadM,brWRITE	wrmem  ; HRRM
	aM,mM,swapM,aluHLR,loadM,brWRITE	wrself ; HRRS

	aAC,mM,aluHLR,writeAC			next   ; HLR
	aAC,mE,aluHLR,writeAC			next   ; HLRI
	aM,mAC,aluHLR,loadM,brWRITE		wrmem  ; HLRM
	aM,mM,aluHLR,loadM,brWRITE		wrself ; HLRS
;;; 1550
	aZERO,mM,swapM,aluHLR,writeAC		next   ; HRRZ
	aZERO,mE,swapM,aluHLR,writeAC		next   ; HRRZI
	aZERO,mAC,swapM,aluHLR,loadM,brWRITE	wrmem  ; HRRZM
	aZERO,mM,swapM,aluHLR,loadM,brWRITE	wrself ; HRRZS

	aZERO,mM,aluHLR,writeAC			next   ; HLRZ
	aZERO,mE,aluHLR,writeAC			next   ; HLRZI
	aZERO,mAC,aluHLR,loadM,brWRITE		wrmem  ; HLRZM
	aZERO,mM,aluHLR,loadM,brWRITE		wrself ; HLRZS
;;; 1560
	aMONE,mM,swapM,aluHLR,writeAC		next   ; HRRO
	aMONE,mE,swapM,aluHLR,writeAC		next   ; HRROI
	aMONE,mAC,swapM,aluHLR,loadM,brWRITE	wrmem  ; HRROM
	aMONE,mM,swapM,aluHLR,loadM,brWRITE	wrself ; HRROS

	aMONE,mM,aluHLR,writeAC			next   ; HLRO
	aMONE,mE,aluHLR,writeAC			next   ; HLROI
	aMONE,mAC,aluHLR,loadM,brWRITE		wrmem  ; HLROM
	aMONE,mM,aluHLR,loadM,brWRITE		wrself ; HLROS
;;; 1570
	aSXT,mM,swapM,aluHLR,writeAC		next   ; HRRE
	aSXT,mE,swapM,aluHLR,writeAC		next   ; HRREI
	aSXT,mAC,swapM,aluHLR,loadM,brWRITE	wrmem  ; HRREM
	aSXT,mM,swapM,aluHLR,loadM,brWRITE	wrself ; HRRES

	aSXT,mM,aluHLR,writeAC			next   ; HLRE
	aSXT,mE,aluHLR,writeAC			next   ; HLREI
	aSXT,mAC,aluHLR,loadM,brWRITE		wrmem  ; HLREM
	aSXT,mM,aluHLR,loadM,brWRITE		wrself ; HLRES
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
	;; I/O Instructions are mapped here
	halt	blki
	halt	datai
	halt	blko
	halt	datao
	halt	cono
	halt	coni
	halt	consz
	halt	conso
;;; 1710
	;; If an I/O instruction is executed in User mode with UserIO set
userio:	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 1720
	;; if the instruction is flagged with ReadE, come here.
	;; read C(E) into Mreg and dispatch on the instruction again
ReadE:	aE,readMEM,brREAD	.
	aE,mMEM,aluSETM,loadM,brDISPATCH	dispatch
	jump	fault	; need to implement !!!
	jump	intrpt	; need to implement !!!
	halt
	halt
	halt
	halt
;;; 1730
	;; Plain JRST used as a jump instruction goes to the normal place in the dispatch table
	;; but other variants come here
	halt						; JRST 4 (HALT)
	aE,aluSETA,readMEM,loadPSW,loadPC,brREAD	fetchPC ; JRST 10 (JRSTF)

	halt
	halt
	halt
	halt
	halt
	halt
;;; 1740
blki:	halt
datai:	halt
blko:	halt
datao:	halt
cono:	halt
coni:	halt
consz:	halt
conso:	halt
;;; 1750
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 1760
	halt
	halt
	halt
	halt
	halt
	halt
	halt
	halt
;;; 1770
	halt
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
