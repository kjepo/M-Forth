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
	KLOAD	X8, MTEST3
	NEXT				// won't return
	
DOCOL:
	PUSHRSP	X8		
	ADD	X8, X0, #8	
	NEXT
	
	.set 	F_IMMED,0x80		// three masks for the length field [*] below
	.set 	F_HIDDEN,0x20
	.set 	F_LENMASK,0x1f		// length mask
	.set	link, 0
	
.macro 	DEFWORD name, namelen, flags=0, label
	.data
	.align 	4
	.globl 	name_\label
name_\label :
	.quad 	link\@	
	.set 	link\@, name_\label
	.byte 	\flags+\namelen		// flags + length byte [*]
	.ascii 	"\name"			// the name
	.align 	4			// padding to next 4 byte boundary
	.globl 	\label
\label :
	.quad 	DOCOL			// codeword - the interpreter
	// list of word pointers follow
	.endm

.macro 	DEFCODE name, namelen, flags=0, label
	.data
	.align 	4
	.globl 	name_\label
name_\label :
	.quad 	link\@			// link
	.set 	link\@, name_\label
	.byte 	\flags+\namelen		// flags + length byte
	.ascii 	"\name"			// the name
	.align 	4			// padding to next 4 byte boundary
	.globl 	\label
\label :
	.quad 	code_\label		// codeword
	.text
	.globl 	code_\label
code_\label :				// assembler code follows
	.endm

// Help assembler routines	

printnl:
	// printnl -- print newline character
	// Note: printnl is a leaf function, no need to save LR
	MOV 	X0, #1			// 1 = stdout
	KLOAD 	X1, newline		// string to print
	MOV   	X2, #1	 		// length of our string
	MOV   	X16, #4      		// MacOS write system call
	SVC   	0     	 		// Output the string
	RET

printhex:	
	// printhex -- print reg X0 as 16 char hex string 000000000000002A
	// X1: pointer to output buffer hexbuf
	// W2: scratch register 
	// X3: pointer to hex characters hexchars
	// W4: holds next hex digit 
	// W5: loop counter
	// Note 1: W2 is the lower 32-bit word of 64-bit register X2
	// Note 2: printhex is a leaf function, no need to save LR
	
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
	
	RET

sysexit:	
	MOV   	X0, #0      		// Use 0 for return code, echo $? in bash to see it
	MOV   	X16, #1     		// Service command code 1 terminates this program
	SVC   	0           		// Call MacOS to terminate the program
	
hexchars:
	.ascii  "0123456789ABCDEF"
	.data
hexbuf:
	.ascii  "0000000000000000"
newline:
	.ascii	"\n"
	
	.align 4			// FIXME: Align to page size (4096 doesn't work)
return_stack:	
	.space 8192			// Allocate 8K memory for the return stack
return_stack_top:

// --------------------------
// Primitive Word Definitions
// --------------------------

	DEFCODE	"EXIT",4,,EXIT		
	POPRSP	X8
	NEXT
	
	DEFCODE "PLUS",4,,PLUS		// ( a b -- c ) 
	POP	X0
	POP	X1
	ADD	X0, X0, X1
	PUSH	X0
	NEXT
	
	DEFCODE "TIMES",5,,TIMES	// ( a b -- c ) 
	POP	X0
	POP	X1
	MUL	X0, X0, X1
	PUSH	X0
	NEXT
	
	DEFCODE	"DUP",3,,DUP		// ( a -- a a )
	POP	X0
	PUSH	X0
	PUSH	X0
	NEXT
		
	DEFCODE "PUSH27",6,,PUSH27	// ( -- a )
	MOV	X0, #27
	PUSH	X0
	NEXT

	DEFCODE ".",1,,DOT		// ( a -- )
	POP	X0
	BL	printhex
	BL	printnl
	NEXT

	// special form: push next word as constant
	// Assembler considers labels beginning with L as locals, hence DOLIT instead of LIT
	DEFCODE	"LIT",3,,DOLIT		// ( -- n ) 
	LDR	X0, [X8], #8
	PUSH	X0
	NEXT

	DEFCODE "HALT",4,,HALT	
	B	sysexit
	NEXT

	DEFWORD "DOUBLE",6,,DOUBLE  	// ( n -- n)
	.quad 	DUP,PLUS,EXIT

	DEFWORD "TRIPLE",6,,TRIPLE	// ( n -- n)
	.quad 	DUP,DUP,PLUS,PLUS,EXIT


	.data
	.align	4
MTEST:
	.quad 	PUSH27		// pointer to codeword of PUSH27
	.quad 	DOUBLE	
	.quad 	DOT		
	.quad 	HALT
	.quad 	EXIT		

MTEST2:
	.quad 	DOLIT
	.quad	4
	.quad 	TRIPLE	
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
	
