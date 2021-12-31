  ;; ARM hardware requires that the stack pointer is
  ;; always 16-byte aligned.   We're wasting 8 bytes
  ;; here because \register is only 8 bytes in size.

  ;; Push register on data stack
.macro	PUSH  	register
	;; don't know how to detect if we've blown the data stack
	STR   	\register, [SP, #-M_STACKITEMSIZE]!
.endm

	;; Pop register from data stack
.macro	POP   	register

	#ifdef STACKWARNING
  KLOAD X19, var_S0
  LDR X19, [X19]                ; X19 = original stack pointer
  CMP SP, X19
  B.GE STACKUNDERFLOW
  #endif

	LDR   	\register, [SP], #M_STACKITEMSIZE
.endm

	;; Push register on return stack
  .macro	PUSHRSP	register

	#ifdef STACKWARNING
  KLOAD X19, return_stack
	CMP X9, X19
  B.LE STACKOVERFLOW
  #endif
	
	STR   	\register, [X9, #-M_STACKITEMSIZE]!
.endm

	;; Pop register from return stack
.macro	POPRSP 	register
  ;; detection of empty RSP is not implemented
	LDR   	\register, [X9], #M_STACKITEMSIZE
.endm

	.text
  .balign M_WORDSIZE
STACKOVERFLOW:
  KPRINT "STACK OVERFLOW\n"
  B _main

STACKUNDERFLOW:
  KPRINT "STACK EMPTY\n"
  B _main
