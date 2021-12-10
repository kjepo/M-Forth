// ARM hardware requires that the stack pointer is always 16-byte aligned.
// We're wasting 8 bytes here because \register is only 8 bytes in size.

.macro	PUSH  	register			// push register on data stack
	;; don't know how to detect if we've blown the data stack
	STR   	\register, [SP, #-16]!
.endm

.macro	POP   	register			// pop register from data stack
	#ifdef STACKWARNING
  KLOAD X19, var_S0
  LDR X19, [X19]                ; X19 = original stack pointer
  CMP SP, X19
  B.GE _STACKUNDERFLOW
  #endif
	LDR   	\register, [SP], #16
.endm	

.macro	PUSHRSP	register			// push register on return stack
	#ifdef STACKWARNING
  KLOAD X19, return_stack
	CMP X9, X19
  B.LE _STACKOVERFLOW
  #endif
	STR   	\register, [X9, #-16]!
.endm

.macro	POPRSP 	register			// pop register from return stack
  ;; detection of empty RSP is not implemented
	LDR   	\register, [X9], #16
.endm	

_STACKOVERFLOW:
  KPRINT "STACK OVERFLOW\n"
  B _main
_STACKUNDERFLOW:
  KPRINT "STACK EMPTY\n"
  B _main
