;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;SMPAC80 -- GWMON-80 Small Monitor for Pacific-80
;
;This customization uses 8251 UART on Pacific-80
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Hardware Equates
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CTLPRT	equ	029H		;UART status & control port
DATPRT	equ	028H		;UART data port
BANK0	equ	008H		;Memory bank 0
BANK1	equ	048H		;Memory bank 1
BANK2	equ	088H		;Memory bank 2
BANK3	equ	0C8H		;Memory bank 3
PSG	equ	038H		;Programmable Sound Generator
SRC	equ	00600H
DST	equ	0F600H
STACK	equ	10000H		;64K system

	ORG	00000H

	INCLUDE	'vectors.inc'	;Standard GWMON-80 jump table

	MVI	A, 0FFH		;ROM page
	OUT	BANK0		;Set current bank first
	MVI	A, 0F3H		;RAM page 3
	OUT	BANK3		;SP is not pointing at ROM anymore

	INCLUDE	'sm.inc'	;The small monitor
	INCLUDE	'scmdstd.inc'	;SM standard commands

	db	'c'
	dw	GOCPM

	INCLUDE 'scmdnull.inc'	;Command table terminator

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;SETUP -- Prepare the system for running the monitor
;
;Once the USART is initialized, check for garbage characters
;that would otherwise flow into the command processor on
;cold start. This is a problem particular to old 8251 USARTs
;and generally does not affect 8251A and later CMOS USARTs.
;
;pre: none
;post: stack and console are initialized
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
IOSET:	LXI	H, INIUART$
	MVI	B, INILEN	;Length of USART init string
IOSET1:	MOV	A, M
	OUT	CTLPRT
	INX	H
	DCR	B
	JNZ	IOSET1
IOSET2:	IN	DATPRT		;Eat garbage following a reset
	DCR	B
	JNZ	IOSET2		;Check for more garbage

	LXI	H, INIPSG$
	MVI	B, PSGLEN	;Length of PSG init string
IOSET3:	MOV	A, M
	OUT	PSG		;Loop takes 35 cycles
	INX	H
	DCR	B
	JNZ	IOSET3

	MOV	C, B		;BC=0000h; 65536 cycles is ~1 sec
IOSET4:	IN	CTLPRT		;Get 8251 status
	ANI	02H		;Test for key press
	IN	DATPRT		;Eat input
	RNZ			;Proceed with gwmon
	DCX	B
	MOV	A, B
	ORA	C		;Timeout?
	JNZ	IOSET4

GOCPM:	XRA	A
	LXI	H, SRC
	SPHL
	LXI	H, DST
GOCPM1:	POP	B
	MOV	M, C
	INX	H
	MOV	M, B
	INX	H
	CMP	H
	JNZ	GOCPM1
	JMP	DST

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;CINNE -- Get a char from the console, no echo
;
;pre: console device is initialized
;post: received char is in A register
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CINNE:	IN	CTLPRT
	ANI	02H
	JZ	CINNE
	IN	DATPRT
	CPI	CANCEL
	JZ	WSTART
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;COUT -- Output a character to the console
;
;This routine *must* preserve the contents of the A register
;or CIN will not function properly.
;
;pre: A register contains char to be printed
;post: character is printed to the console
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
COUT:	PUSH	PSW		;Save char to print on stack
COUT1:  IN	CTLPRT
	RRC			;Test TX bit
	JNC	COUT1
	POP	PSW		;Restore char to print
	OUT	DATPRT
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;INIUART$ -- Init string for the 8251 USART
;
;This fixed-length string initializes an 8251 USART from an
;unknown state. Sending three NULLs will ensure command
;mode.
;
;INILEN specifies the length of the initialization string.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
INIUART$:	db 00H, 00H, 00H, 40H, 4EH, 37H
INILEN	equ	* - INIUART$

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;INIPSG$ -- Init string for SN76489 PSG
;
;This fixed-length string initializes an SN76489 PSG from an
;unknown state. It just mutes all 3 tone channels and noise
;channel.
;
;PSGLEN specifies the length of the initialization string.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
INIPSG$:	db 09FH, 0BFH, 0DFH, 0FFH
PSGLEN	equ	* - INIPSG$

	END
