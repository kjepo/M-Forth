//------------------------------------------------
//
//    M FORTH for the M1 processor on MacOS X
//
//    Copyright (C) K.Post kjell@irstafoto.se
//
//                    Abstract
//
//     M Forth is an implementation of Forth
//     for the M1 ARM  processor on MacOS X.
//     The idea is to bootstrap a reasonably
//     capable language from zero. This is a
//     first in a series of documents on the
//     implementation on computer languages.
//
//------------------------------------------------
//
// 1. WHAT IS M1?
// 
// The M1 ("Apple Silicon") is the first Apple ARM processor.
// It is a 64-bit processor with registers X0-X30:
//	X0-X7	For function parameters.  
//	X0-X18	Registers that a function is free to use without saving.
//	X19-X30	These are callee saved so must be pushed to a stack if used.
//	SP	is the stackpointer
// 	LR	is the link register and holds the return address
//	PC	is the program counter
// Note that while, e.g., X7 is the full 64 bits of data, W7 is the lower 32 bits.
//
// Each ARM instruction is 32 bits long.
//
// The ARM is a load/store architecture, i.e., operations like adding, shifting, etc are
// performed on registers and the only instructions interacting with memory are load/store.

//	ARM Notes
//	=========
//
//	SUB a, b, c <=> a = b - c
//	RSB a, b, c <=> a = c - b
//
//	CMP a, b <=> flags (only!) for a - b
//	SUBS a, b, c <=> a = b - c (and flags!)
//
//	LDR a, [b, #c]  <=> a = M[b + #c]
//	LDR a, [b, #c]! <=> a = M[b + #c], b = b + #c
//	LDR a, [b], #c  <=> a = M[b], b = b + #c
//

//
// 2. M FORTH
//
// M Forth register usage:
// 	X0 contains the current codeword when going from NEXT to DOCOL
// 	X8 is the instruction pointer       (%esi in Jones Forth)
//	X9 is the return stack pointer      (%ebp in Jones Forth)
// 	SP (X13) is the data stack pointer  (%esp in Jones Forth)


// On MacOS you can't use ADR to load an address into the register,
// since a 64-bit address won't fit into a 32-bit instruction so
// this operation is done in two steps: first load the address of
// the page, then add the offset.  I guess it's possible to design
// a 32-bit FORTH by sticking to one 32-bit address space, but 
// this is not something I have investigated.	

// footnote: this is how cc compiles it:
//	adrp	x19, _buffer@GOTPAGE
//	ldr	x19, [x19, _buffer@GOTPAGEOFF]


.macro 	KLOAD register, addr			
	ADRP \register, \addr@PAGE		
	ADD \register, \register, \addr@PAGEOFF 
.endm

// ARM hardware requires that the stack pointer is always 16-byte aligned.
// We're wasting 8 bytes here because \register is only 8 bytes in size.
// Note that stacks grown downwards.  (They don't have to, but that's the choice.)

.macro	PUSH  	register			// push register on data stack
	STR   	\register, [SP, #-16]!
.endm

.macro	POP   	register			// pop register from data stack
	LDR   	\register, [SP], #16
.endm	

.macro	PUSHRSP	register			// push register on return stack
	STR   	\register, [X9, #-16]!
.endm

.macro	POPRSP 	register			// pop register from return stack
	LDR   	\register, [X9], #16
.endm	

.macro  NEXT
	LDR	X0, [X8], #8
	LDR	X1, [X0]
	BLR   	X1	
.endm
	.global _main          		// Provide program starting address to linker
	.align 4			// MacOS
_main:
	KLOAD	X9, return_stack_top
	KLOAD	X8, MTEST12
	NEXT				// won't return
	
DOCOL:
	PUSHRSP	X8		
	ADD	X8, X0, #8	
	NEXT
	
	.set M_VERSION,1
	.set RETURN_STACK_SIZE, 8192	
	.set BUFFER_SIZE,4096	// input buffer

	.set 	F_IMMED,0x80		// three masks for the length field [*] below
	.set 	F_HIDDEN,0x20
	.set 	F_LENMASK,0x1f		// length mask
        .set    link, 0

	.text
	.align 4
printhex:	
	// printhex -- print reg X0 as 16 char hex string 000000000000002A
	// X1: pointer to output buffer hexbuf
	// W2: scratch register 
	// X3: pointer to hex characters hexchars
	// W4: holds next hex digit 
	// W5: loop counter
	// Note 1: W2 is the lower 32-bit word of 64-bit register X2
	// Note 2: printhex is a leaf function, no need to save LR
	
	PUSH	LR
	PUSH	X1
	PUSH	X2
	PUSH	X3
	PUSH	X4
	PUSH	X5

	KLOAD 	X1, hexbuf		// X1 = &hexbuf
	ADD   	X1, X1, #15		// X1 = X1 + 15 (length of hexbuf)
	MOV   	W5, #16			// loop counter: 16 characters to print
printhex1:
	AND   	W2, W0, #0xf		// W2 = W0 & 0xf   LLDB: reg read x0, x2
	KLOAD 	X3, hexchars		// LLDB: mem read $x3
	LDR   	W4, [X3, X2]		// W4 = *[X3 + X2]
	STRB  	W4, [X1]		// *X1 = W4
	SUB   	X1, X1, #1		// X1 = X1 - 1
	LSR   	X0, X0, #4		// X0 = X0 >> 4
	SUBS  	W5, W5, #1		// X5 = X5 - 1 (update condition flags)
	B.NE  	printhex1		// if X5 != 0 GOTO printhex1

	// Print string hexbuf
	MOV   	X0, #1    	 	// 1 = StdOut
	KLOAD 	X1, hexbuf		// string to print
	MOV   	X2, #16	 		// length of our string
	MOV   	X16, #4      		// MacOS write system call
	SVC   	0     	 		// Output the string
	
	POP	X5
	POP	X4
	POP	X3
	POP	X2
	POP	X1
	POP	LR
	
	RET

hexchars:
	.ascii  "0123456789ABCDEF"
	.data
hexbuf:
	.ascii  "0000000000000000"
	
	.align 4			// FIXME: Align to page size (4096 doesn't work)
return_stack:	
	.space RETURN_STACK_SIZE	// Allocate static memory for the return stack
return_stack_top:

	// This is used as a temporary input buffer when reading from files or the terminal
	.align 4
buffer:
	.space BUFFER_SIZE
	

// --------------------------
// Primitive Word Definitions
// --------------------------
	
#include "primitives.s"
	
	.text
_HALT:
	MOV   	X0, #0      		// Use 0 for return code, echo $? in bash to see it
	MOV   	X16, #1     		// Service command code 1 terminates this program
	SVC   	0           		// Call MacOS to terminate the program
	
//--------------------------------------------------	
// 	I/O
//--------------------------------------------------	
	
/*	
	KEY reads the next byte from stdin and pushes it on the stack.
	It uses a buffer and two pointers, buffer and bufftop.

	#define BUFFER_SIZE 4096
	char buffer[BUFFER_SIZE];
	char *bufftop = buffer; 
	char *currkey = buffer;

	char key() {
	    int n;	
	l1:
	    if (currkey >= bufftop)
	        goto l2;
	    return *currkey++;
	l2:
	    n = read(0, buffer, BUFFER_SIZE);
	    if (n <= 0)
		exit(0);
	    currkey = buffer;
	    bufftop = n + buffer;
	    goto l1;
	}
*/

_KEY:
1:	
	KLOAD	X1, currkey
	LDR	X2, [X1]	// X2 = currkey
	KLOAD	X3, bufftop
	LDR	X4, [X3]	// X4 = bufftop
	CMP	X2, X4		// currkey == bufftop ?
	B.GE	2f		// exhausted the input buffer?
	MOV	X0, #0	
	LDRB	W0, [X2], #1	// W0 = *currkey++
	STR	X2, [X1]
	RET
2:	
	// Out of input; use read(2) to fetch more input from stdin.
	MOV	W0, 0		// stdin
	KLOAD	X1, buffer
	KLOAD	X2, currkey	
	STR	X1, [X2]	// currkey = buffer
	MOV	X2, BUFFER_SIZE
	MOV	X16, #3		// MacOS read system call
	SVC	0
	CMP	W0, 0		// returns with number of chars read
	B.LE	_HALT		// <= 0 means EOF or error, so exit
	KLOAD	X1, buffer	
	ADD	X0, X0, X1	// bufftop = X0 + buffer
	KLOAD	X2, bufftop
	STR	X0, [X2]
	B	1b

	.data
	.align 4
currkey:
	.quad 	buffer		// Current place in input buffer (next character to read).
bufftop:
	.quad	buffer		// Last valid data in input buffer + 1.

	/* WORD reads the next the full word of input 

	char word_buffer[32];

	char *word(int *len) {                                
	    char c;
	    char *p = word_buffer;
	l1:
	    c = key();
	    if (c == '\\') goto l3;
	    if (c == ' ') goto l1;
	l2:
	    *p++ = c;
	    c = key();
	    if (c != ' ') goto l2;
	    *len = p - word_buffer;
	    return word_buffer;
	l3:
	    if (key() != '\n') goto l3;
	    goto l1;
	} 
        */

	.text
_WORD:
	PUSH	LR
1:	
	BL	_KEY		// read next char into X0
	CMP	X0, '\\'
	B.EQ	3f
	CMP	X0, ' '
	B.EQ	1b
	KLOAD	X2, word_buffer
2:
	STRB	W0, [X2], #1	// *word_buffer++ = W0
	PUSH	X2
	BL	_KEY
	POP	X2
	CMP	X0, ' '
	B.NE	2b
	KLOAD	X1, word_buffer
	SUB	X0, X2, X1
	POP	LR
	RET
3:				// consume comment until EOL
	BL	_KEY
	CMP	X0, '\n'
	B.NE	3b
	B	1b

	.data
word_buffer:
	.space	32

	// ( addr length -- n e ) convert string -> number
	// n: parsed number, e: number of unparsed characters	
	// fixme: "1a" is not same as "1A" - perhaps leaves unparsed characters?
	
	.text
_NUMBER:
	PUSH	LR
	MOV	X2, X0			// string address
	MOV	X0, #0			// result after conversion
	CMP	X1, #0
	B.LE	5f			// error if length <= 0
	
	KLOAD	X3, var_BASE
	LDR	X3, [X3]		// X3 = BASE
//	MOV	X3, #10

	LDRB	W4, [X2], #1		// load first char
	MOV	X5, #0
	CMP	X4, '-'
	B.NE	2f			// number is positive
	MOV	X5, #1
	SUB	X1, X1, #1
	CMP	X1, #0			// do we have more than just "-" ?
	B.GT	1f			// yes, proceed with conversion
	MOV	X1, #1			// error
	B	5f
1:
	MUL 	X6, X0, X3		//
	MOV	X0, X6			// number *= BASE
	LDRB	W4, [X2], #1
2:
	SUB 	X4, X4, '0'
	CMP	X4, #0
	B.LT	4f			// < 0, end
	CMP	X4, #9
	B.LE	3f			// digit
	SUB	X4, X4, #17		// 17 = 'A' - '0'
	CMP 	X4, #0
	B.LT	4f
	ADD	X4, X4, #10
3:
	CMP	X4, X3			// compare to current BASE
	B.GE	4f			// end, > BASE
	ADD	X0, X0, X4		// add digit to result
	SUB	X1, X1, #1
	CMP	X1, #0
	B.GT 	1b			// continue processing while there are characters
4:
	CMP	X5, #1			// number is negative if X5==1
	B.NE	5f
	NEG	X0, X0			
5:
	POP	LR
	RET
	
	.text
_EMIT:
	KLOAD	X1, emit_buf	// string to print
	STR	W0, [X1]	// store character
	MOV	X0, #1		// 1 = stdout
	MOV	X2, #1		// length of our string
	MOV   	X16, #4		// MacOS write system call
	SVC	0
	RET
	.data			// NB: easier to fit in the .data section
emit_buf:
	.space 1		// buffer used by EMIT
	
	.text
_CR:
	PUSH	X0
	PUSH	X1
	PUSH	X2
	MOV 	X0, #1			// 1 = stdout
	KLOAD 	X1, newline		// string to print
	MOV   	X2, #1	 		// length of our string
	MOV   	X16, #4      		// MacOS write system call
	SVC   	0     	 		// Output the string
	POP	X2
	POP	X1
	POP	X0
	RET
	.data
newline:
	.ascii	"\n"
	
	.text
_EMITWORD:			// upon entering: X1 = buffer, X2 = length
	MOV	X0, #1		// 1 = stdout
	MOV	X16, #4
	SVC 	0
	RET

//--------------------------------------------------	
// 	Dictionary
//--------------------------------------------------	
	
	// X1 = length, X0 = address
_FIND:
	PUSH	X8		// save instruction pointer for later
	KLOAD	X3, var_LATEST
1:	LDR	X3, [X3]
	CMP	X3, #0		// reached end of dictionary chain? 
	B.EQ	3f
	MOV	X4, #0
	LDRB	W4, [X3, #8]	// load length + flags
	AND	W4, W4, F_HIDDEN|F_LENMASK	// W4 = name length
	CMP	W4, W1
	B.NE	1b		// different lengths, try previous word
	// compare strings, word by word
2:	
	LDRB	W5, [X0], #1
	LDRB	W6, [X3], #1
	CMP	W5, W6
	B.NE	1b		// not same, try previous word
	SUB	W4, W4, #1
	B.NE	2b
3:	
	MOV 	X0, #0
	BL	printhex
	BL	_HALT
	RET

	//==================================================
	// Test suites
	//==================================================

	.data
	.align	4
MTEST2:
	.quad 	DOLIT
	.quad	4
	.quad 	QUADRUPLE	
	.quad 	DOT		
	.quad 	HALT
	.quad 	EXIT		
	
MTEST3:
	.quad 	DOLIT
	.quad	2
	.quad	DOLIT
	.quad 	3
	.quad 	TIMES	
	.quad 	DOT		
	.quad 	HALT
	.quad 	EXIT		

MTEST4:
	.quad 	DOLIT
	.quad	3
	.quad 	QUADRUPLE
	.quad 	DOT
	.quad	HALT
	.quad	EXIT

MTEST5:
	.quad 	DOLIT
	.quad	3
	.quad 	DOLIT
	.quad	4
	.quad	NEQ
	.quad 	DOT
	.quad	HALT
	.quad	EXIT

MTEST6:
	.quad 	DOLIT
	.quad	65
	.quad 	EMIT
	.quad	HALT
	.quad	EXIT
	
MTEST7:
	.quad 	KEY // 1
	.quad	EMIT
	.quad 	KEY // 2
	.quad	EMIT
	.quad 	KEY // 3
	.quad	EMIT
	.quad 	KEY // 4
	.quad	EMIT
	.quad 	KEY // 5
	.quad	EMIT
	.quad 	KEY // 6
	.quad	EMIT
	.quad	HALT
	.quad	EXIT

MTEST8:
	.quad	WORD
	.quad	EMITWORD
	.quad	DOLIT
	.quad	10
	.quad	EMIT
	.quad	WORD
	.quad	EMITWORD
	.quad	DOLIT
	.quad	10
	.quad	EMIT
	.quad	HALT
	.quad	EXIT

MTEST9:
	.quad	WORD
	.quad	NUMBER
	.quad	DROP
	.quad	WORD
	.quad	NUMBER
	.quad	DROP
	.quad 	PLUS
	.quad	DOT
	.quad	HALT
	.quad	EXIT
	
MTEST10:
	.quad	RZ
	.quad	DOT
	.quad	HALT
	
MTEST11:	
	.quad	BASE
	.quad 	FETCH
	.quad	DOT
	.quad	VERSION
	.quad	DOT
	.quad	XLATEST
	.quad	FETCH
	.quad	DOT
	.quad	HALT

MTEST12:
	.quad	WORD
	.quad	FIND
	.quad	DOT
	.quad	HALT
	
