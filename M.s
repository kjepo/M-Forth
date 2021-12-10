  ;; ------------------------------------------------
  ;;
  ;;     M FORTH for the M1 processor on MacOS X
  ;;
  ;;     Copyright (C) K.Post kjell@irstafoto.se
  ;;
  ;;                     Abstract
  ;;
  ;;      M Forth is an implementation of Forth
  ;;      for the M1 ARM  processor on MacOS X.
  ;;      The idea is to bootstrap a reasonably
  ;;      capable language from zero. This is a
  ;;      first in a series of documents on the
  ;;      implementation on computer languages.
  ;; ------------------------------------------------

  ;;  1. WHAT IS M1?
  ;;
  ;;  The M1 ("Apple Silicon") is Apple's first ARM processor.
  ;;  It is a 64-bit processor with registers X0-X30:
  ;;    X0-X7 For function parameters.
  ;;    X0-X18  Registers that a function is free to use without saving.
  ;;    X19-X30 These are callee saved so must be pushed to a stack if used.
  ;;    SP  is the stackpointer
  ;;    LR  is the link register and holds the return address
  ;;    PC  is the program counter
  ;;  Note that, e.g., X7 is the full 64 bits of data, W7 is the lower 32 bits.
  ;;
  ;;  Each ARM instruction is 32 bits long.
  ;;
  ;;  The ARM is a load/store architecture, i.e., operations like adding,
  ;;  shifting, etc are performed on registers and the only instructions
  ;;  interacting with memory are load/store.

  ;; ARM Notes
  ;; =========
  ;;
  ;;  SUB a, b, c <=> a = b - c
  ;;  RSB a, b, c <=> a = c - b
  ;;
  ;;  CMP a, b <=> flags (only!) for a - b
  ;;  SUBS a, b, c <=> a = b - c (and flags!)
  ;;
  ;;  LDR a, [b, #c]  <=> a = M[b + #c]
  ;;  LDR a, [b, #c]! <=> a = M[b + #c], b = b + #c
  ;;  LDR a, [b], #c  <=> a = M[b], b = b + #c
  ;;
  ;;
  ;; 2. M FORTH
  ;;
  ;; M Forth register usage:
  ;; X0 contains the current codeword when going from NEXT to DOCOL
  ;; X1 is commonly used for storing a start address for a string
  ;; X2 is commonly used for storing the length of the string
  ;; X8 is the instruction pointer (IP)       (%esi in Jones Forth)
  ;; X9 is the return stack pointer (SP)      (%ebp in Jones Forth)
  ;; SP is the data stack pointer (RSP)       (%esp in Jones Forth)
  ;; X19 is used when STACKWARNING has been enabled (see pushpop.s)

  ;; On MacOS you can't use ADR to load an address into the register,
  ;; since a 64-bit address won't fit into the instruction.
  ;; Therefore, this operation is done in two steps: first load the
  ;; address of the page, then add the offset.  I guess it's possible
  ;; to design a 32-bit FORTH by sticking to one 32-bit address space,
  ;; but this is not something I have investigated.

  ;; footnote: this is how clang compiles loading a 64-bit address:
  ;; adrp x19, _buffer@GOTPAGE
  ;; ldr  x19, [x19, _buffer@GOTPAGEOFF]

  ;; Footnote on .align
  ;; .align n   means different things in different assemblers
  ;; In this assembler, it means "advance location until n least significant bits are 0".
  ;; In other assemblers it means "advance location until address % n == 0"
  ;; Here we use .balign which explicitly has the latter meaning.

  #include "kload.s"
  #include "kprint.s"
  #include "pushpop.s"
  #include <sys/syscall.h>

  ;; NEXT is the heart of the inner interpreter.
  ;; It fetches and jumps to the next instruction.

  .macro  NEXT
  LDR X0, [X8], #8
  LDR X1, [X0]
  BLR     X1
  .endm

  .global _main                 ; Provide program starting address to linker
  .balign 8                     ; MacOS (and see footnote on align further up)
_main:
  MOV   X0, SP
  KLOAD X9, var_S0
  STR   X0, [X9]                ; let S0 = initial SP
  KLOAD X9, return_stack_top    ; X9 = initial RSP
  KLOAD X8, COLDSTART           ; calls QUIT which starts the REPL
  BL    _set_up_data_segment    ; initialize HERE = next available word in data segment
  NEXT                          ; won't return

DOCOL:
  PUSHRSP X8
  ADD X8, X0, #8
  NEXT

  .set M_VERSION,1
  ;; the size of the return stack _will_ increase the executable
  .set RETURN_STACK_SIZE, 1048576 // 65536 // 8192
  .set INITIAL_DATA_SEGMENT_SIZE, 1024*1024 ; 1 MB
  .set BUFFER_SIZE,4096         ; input buffer
  .set F_IMMED,0x80             ; three masks for the length field [*] below
  .set F_HIDDEN,0x20
  .set F_LENMASK,0x1f           ; length mask
        .set    link, 0

  .text
  .balign 8
printhex:
  // printhex -- print reg X0 as 16 char hex string 000000000000002A
  // X1: pointer to output buffer hexbuf
  // W2: scratch register
  // X3: pointer to hex characters hexchars
  // W4: holds next hex digit
  // W5: loop counter
  // Note 1: W2 is the lower 32-bit word of 64-bit register X2
  // Note 2: printhex is a leaf function, no need to save LR

  PUSH  LR
  PUSH  X1
  PUSH  X2
  PUSH  X3
  PUSH  X4
  PUSH  X5

  KLOAD   X1, hexbuf    // X1 = &hexbuf
  ADD     X1, X1, #15   // X1 = X1 + 15 (length of hexbuf)
  MOV     W5, #16     // loop counter: 16 characters to print
printhex1:
  AND     W2, W0, #0xf    // W2 = W0 & 0xf   LLDB: reg read x0, x2
  KLOAD   X3, hexchars    // LLDB: mem read $x3
  LDR     W4, [X3, X2]    // W4 = *[X3 + X2]
  STRB    W4, [X1]    // *X1 = W4
  SUB     X1, X1, #1    // X1 = X1 - 1
  LSR     X0, X0, #4    // X0 = X0 >> 4
  SUBS    W5, W5, #1    // X5 = X5 - 1 (update condition flags)
  B.NE    printhex1   // if X5 != 0 GOTO printhex1

  // Print string hexbuf
  MOV     X0, #1        // 1 = StdOut
  KLOAD   X1, hexbuf    // string to print
  MOV     X2, #16     // length of our string
  MOV     X16, #4         // MacOS write system call
  SVC     0           // Output the string

  POP X5
  POP X4
  POP X3
  POP X2
  POP X1
  POP LR

  RET

hexchars:
  .ascii  "0123456789ABCDEF"
  .data
hexbuf:
  .ascii  "0000000000000000"

  .balign 8                      ; FIXME: Align to page size
return_stack:
  .space RETURN_STACK_SIZE      ; Allocate static memory for the return stack
return_stack_top:
  .quad 0                       ; FIXME: remove

  // This is used as a temporary input buffer when reading from files or the terminal
  .balign 8
buffer:
  .space BUFFER_SIZE


// --------------------------
// Primitive Word Definitions
// --------------------------

#include "primitives.s"

  .text
_HALT:
  MOV     X0, #0          // Use 0 for return code, echo $? in bash to see it
  MOV     X16, #1         // Service command code 1 terminates this program
  SVC     0               // Call MacOS to terminate the program

//--------------------------------------------------
//  I/O
//--------------------------------------------------

/*
  KEY reads the next byte from stdin and pushes it on the stack.
  The helper routine _KEY (below) returns the next byte in X0.
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
  KLOAD   X1, currkey
  LDR     X2, [X1]              ; X2 = currkey
  KLOAD   X3, bufftop
  LDR     X4, [X3]              ; X4 = bufftop
  CMP     X2, X4                ; currkey == bufftop ?
  B.GE    2f                    ; exhausted the input buffer?
  MOV     X0, #0
  LDRB    W0, [X2], #1          ; W0 = *currkey++
  STR     X2, [X1]
  RET
2:                              ; Out of input; use read(2) to fetch more input from stdin
  MOV     W0, 0                 ; stdin
  KLOAD   X1, buffer
  KLOAD   X2, currkey
  STR     X1, [X2]              ; currkey = buffer
  MOV     X2, BUFFER_SIZE
  MOV     X16, #3               ; MacOS read system call
  SVC     0
  CMP     W0, 0                 ; returns with number of chars read
  B.LE    _HALT                 ; <= 0 means EOF or error, so exit
  KLOAD   X1, buffer
  ADD     X0, X0, X1            ; bufftop = X0 + buffer
  KLOAD   X2, bufftop
  STR     X0, [X2]
  B       1b

  .data
  .balign 8
currkey:
  .quad   buffer                ; Current place in input buffer (next character to read)
bufftop:
  .quad   buffer                ; Last valid data in input buffer + 1

  /*
  WORD reads the next the full word of input
  The helper routine _WORD (below) returns with X1 = start address, X2 = length

  char word_buffer[32];

  char *word(int *len) {
      char c;
      char *p = word_buffer;
  l1:
      c = key();
      if (c == '\\') goto l4;
      if (c == '\n') goto l1;
      if (c == ' ') goto l1;
  l2:
      *p++ = c;
      c = key();
      if (c == ' ') goto l3;
      if (c == '\n') goto l3;
      goto l2;
      *len = p - word_buffer;
      return word_buffer;
  l4:
      if (key() != '\n') goto l3;
      goto l1;
  }
        */

  .text
_WORD:                          ; returns with X1 = start address, X2 = length
  PUSH  LR
1:
  BL    _KEY                    ; read next char into X0
  CMP   X0, '\\'                ; comment?
  B.EQ  4f
  CMP   X0, ' '
  B.EQ  1b                      ; keep looking for non-space
  CMP   X0, '\n'
  B.EQ  1b
  CMP   X0, '\t'
  B.EQ  1b
  KLOAD X2, word_buffer
2:
  STRB  W0, [X2], #1            ; *word_buffer++ = W0
  PUSH  X2
  BL    _KEY
  POP   X2
  CMP   X0, ' '
  B.EQ  3f
  CMP   X0, '\n'
  B.EQ  3f
  CMP   X0, '\t'
  B.EQ  3f
  B     2b
3:
  KLOAD X1, word_buffer
  SUB   X2, X2, X1              ; X2 = length
  POP   LR
  RET
4:                              ; consume comment until EOL
  BL    _KEY
  CMP   X0, '\n'
  B.NE  4b
  B     1b

  .data
word_buffer:
  .space  32



  // ( addr length -- n e ) convert string -> number
  // n: parsed number, e: number of unparsed characters
  // fixme: "1a" is not same as "1A" - perhaps leaves unparsed characters?
  ;; return parsed number in X0; X1 > 0 if error (unparsed characters)
  .text
_NUMBER:
  ;; X0 -- string address
  ;; X1 -- length
  ;; X2 -- returned number

  PUSH    LR
  MOV     X2, X0      // string address
  MOV     X0, #0      // result after conversion
  CMP     X1, #0
  B.LE    5f      // error if length <= 0

  KLOAD   X3, var_BASE
  LDR     X3, [X3]    // X3 = BASE

  LDRB    W4, [X2], #1    // load first char
  MOV     X5, #0
  CMP     X4, '-'
  B.NE    2f      // number is positive
  MOV     X5, #1
  SUB     X1, X1, #1
  CMP     X1, #0      // do we have more than just "-" ?
  B.GT    1f      // yes, proceed with conversion
  MOV     X1, #1      // error
  B       5f
1:
  MUL     X6, X0, X3    //
  MOV     X0, X6      // number *= BASE
  LDRB    W4, [X2], #1
2:
  SUB     X4, X4, '0'
  CMP     X4, #0
  B.LT    4f      // < 0, end
  CMP     X4, #9
  B.LE    3f      // digit
  SUB     X4, X4, #17   // 17 = 'A' - '0'
  CMP     X4, #0
  B.LT    4f
  ADD     X4, X4, #10
3:
  CMP     X4, X3      // compare to current BASE
  B.GE    4f      // end, > BASE
  ADD     X0, X0, X4    // add digit to result
  SUB     X1, X1, #1
  CMP     X1, #0
  B.GT    1b      // continue processing while there are characters
4:
  CMP     X5, #1      // number is negative if X5==1
  B.NE    5f
  NEG     X0, X0
5:
  POP     LR
  RET

  .text
_EMIT:
  PUSH    X1
  PUSH    X2
  PUSH    LR
  KLOAD   X1, emit_buf          ; string to print
  STR     W0, [X1]              ; store character
  MOV     X0, #1                ; 1 = stdout
  MOV     X2, #1                ; length of our string
  MOV     X16, #4               ; MacOS write system call
  SVC     0
  POP     LR
  POP     X2
  POP     X1
  RET
  .data                         ; NB: easier to fit in the .data section
emit_buf:
  .space 1                      ; buffer used by EMIT

  .text
_CR:
  KPRINT  "\n"
  RET

  .text
_EMITWORD:      // upon entering: X1 = buffer, X2 = length
  MOV X0, #1    // 1 = stdout
  MOV X16, #4
  SVC   0
  RET

//--------------------------------------------------
//  Dictionary
//--------------------------------------------------

  ;; FIND dictionary entry, given string
  ;; X1 = address of string
  ;; X2 = length of string
  ;; FIND uses:
  ;; X0 = copy of X1
  ;; X3 = copy of X1
  ;; X4 = current dictionary word
  ;; X5 = copy of X4
  ;; X6 = character in X0 string
  ;; X7 = character in X4 string, also len
  ;; FIND returns with X4 = addr of dictionary entry, or 0 if not found

_FIND:
  KLOAD   X4, var_LATEST
1:
  LDR     X4, [X4]
  MOV     X3, X2                     ; X3 = length
  ADDS    X5, XZR, X4                ;
  B.EQ    3f                         ; end of dictionary
  MOV     X7, #0
  LDRB    W7, [X5, #8]!              ; load length + flags
  AND     W7, W7, F_HIDDEN|F_LENMASK ; W7 = name length
  CMP     W7, W2
  B.NE    1b
  MOV     X0, X1                     ; X0 = copy of start address
  ADD     X5, X5, #1                 ; X5 = pointer to beginning of dictionary string
2:
  LDRB    W6, [X5], #1               ; compare strings, char by char
  LDRB    W7, [X0], #1
  CMP     W6, W7
  B.NE    1b                         ; not same, try previous word
  SUBS    W3, W3, #1
  B.GT    2b                         ; still more characters to compare
3:
  RET                                ; return with X4 -> dictionary header

  ;; X0 - address of dictionary header
  ;; return the code field address in X0
_TCFA:
  MOV     X1, #0
  LDRB    W1, [X0, #8]!         ; skip link pointer and load length + flags
  AND     W1, W1, F_LENMASK     ; strip the flags
  ADD     X0, X0, X1            ; skip characters
  ADD     X0, X0, #8            ; skip length & flags (1) and add 7
  AND     X0, X0, #~7           ; ... to make it 8-byte aligned
  RET

  // X1: length
  // X0: address of name
_CREATE:
  KLOAD   X2, var_LATEST
  LDR     X2, [X2]              ; X2 = LATEST = latest dictionary entry
  KLOAD   X3, var_HERE
  LDR     X3, [X3]              ; X3 = HERE = next available place in data segment
  MOV     X5, X3                ; X5 = copy of original HERE
  STR     X2, [X3], #8          ; *X3++ = LATEST
  MOV     X7, X3
  STRB    W1, [X3], #1          ; *X3++ = length
1:
  LDRB    W2, [X0], #1
  STRB    W2, [X3], #1
  SUBS    X1, X1, #1
  B.NE    1b
  ADD     X3, X3, #7
  AND     X3, X3, ~7
  KLOAD   X2, var_LATEST
  STR     X5, [X2]  // LATEST = original HERE
  KLOAD   X4, var_HERE
  STR     X3, [X4]  // HERE = X3
  RET

  // X0 = code pointer to store
_COMMA:                         ; store X3 in current dictionary definition
  KLOAD   X2, var_HERE
  LDR     X1, [X2]              ; X1 = HERE
  STR     X0, [X1], #8          ; *X1++ = X3
  STR     X1, [X2]              ; HERE = X1
  RET

  /* INTERPRET is the REPL toploop

  interpret_is_lit = 0;
  X1, X2 = word();
  X4 = find(X1, X2);        // returns dictionary header
  if (X4 == 0) goto 1;      // number or word not in the dictionary
  if immediate(X4) goto 4;  // if immediate, execute!
  goto 2;

1: // not in the dictionary so assume it's a literal number
  interpret_is_lit = 1;
  X4, X5 = number();
  if (X5 > 0) goto 6;     // not a number, so syntax error
  X0 = _LIT
2:
  if (STATE == 0) goto 4; // we are executing
  comma(X0);              // write _LIT
  if (interpret_is_lit == 0) goto 3;
  comma(X5);              // write number
3:
  next();

4: // executing (run it)
  if (interpret_is_lit != 0) goto 5;
  goto *X0;                // execute word
5: // execute literal, i.e., push it on the stack
  push(x5);
  next();

6:
  print("PARSE ERROR: ");
  next();

    */

  _INTERPRET:
    ;; read next word
    BL _WORD                      ; { X1: start address X2: length, X3 }
    ;; is the word in the dictionary?
    PUSH X1
    PUSH X2
    BL _FIND                      ; { X4: header (0 if not found) }
    POP X1
    POP X0
    ;; set literal number flag to false (for now)
    MOV W6, #0
    CMP X4, #0
    B.EQ 1f                     ; not found (number or syntax error)
    ;; word is in the dictionary - is it an IMMEDIATE keyword?
    MOV X0, X4                  ; { W6: literal flag, X0 = X4: header != 0 }
    BL _TCFA                    ; get codeword pointer into X0
    MOV X5, #0                  ; fixme: remove?
    LDRB W5, [X4, #8]           ; { W6: literal flag, X0: codeword, X4: header+8, W5: length+flag }
    AND W5, W5, F_IMMED
debug1:
    CMP W5, #0
    B.NE 4f                     ; if IMMEDIATE, jump straight to executing
    B 2f
    ;; { W6: literal flag, X0: codeword, X4: header+8, W5: length+flag }
  1:
    ;; not in the dictionary (not a word) so assume it's a literal number
    BL _NUMBER                  ; { X0: number, X1 > 0 if error, X0: codeword, X4: header+8 }
    MOV W6, #1
    CMP X1, #0
    B.GT 6f
    MOV X5, X0                  ; store number in X5
    KLOAD X0, _LIT              ; the codeword is LIT
  2:
    ;; { X0: codeword, W6: literal flag, X5: number }
    ;; are we compiling or executing?
    KLOAD X2, var_STATE
    LDR X2, [X2]
    CMP X2, #0
    B.EQ 4f                    ; jump if executing
    ;; { X0: codeword, W6: literal flag, X5: number }
    ;; compiling - just append the word in X0 to the current dictionary definition
    BL _COMMA
    CMP W6, #0                  ; was it a literal?
    B.EQ 3f
    MOV X0, X5
    BL _COMMA
  3:
    NEXT
  4:
    ;; { W6: literal flag }
    ;; executing - run it!
    CMP W6, #0
    B.NE 5f
    ;; not a literal, execute it now
    ;; this never returns but the codeword will eventually
    ;; call NEXT which will re-enter the loop in QUIT
    LDR X1, [X0] ; X0 = DOCOL
    BLR X1
  5:
    ;; executing a literal <=> push it on the stack
    ;; { X5: number }
    PUSH X5
    NEXT
  6:
    ;; parse error (not a known word or a number in the current BASE)
    ;; print error message followed by up to 40 characters of context
    KPRINT "PARSE ERROR: "
    KLOAD X2, currkey
    LDR X2, [X2]                ; get value of currkey
    MOV X1, X2
    KLOAD X0, buffer
    SUB X2, X2, X0              ; X2 = currkey - buffer (chars processed)
    CMP X2, #40                 ; cap at 40 chars
    B.LE 7f
    MOV X2, #40
  7:
    SUB X1, X1, X2
    SUB X2, X2, #1
    MOV X0, #2 ; stderr
    MOV X16, #4 ; write
    SVC 0
  8:
    KPRINT "■"                  ; insert your favorite delimiter here
    KLOAD X2, bufftop
    LDR X2, [X2]
    KLOAD X1, currkey
    LDR X1, [X1]
    SUB X2, X2, X1              ; X2 = bufftop - curkey
    CMP X2, #40
    B.LE 9f
    MOV X2, #40
  9:
    MOV X0, #2 ; stderr
    MOV X16, #4
    SVC 0
    KPRINT "\n"
    NEXT

_set_up_data_segment:
  KLOAD   X0, var_HERE
  KLOAD   X1, data_segment
  STR     X1, [X0]
  RET

  ;; Initalize random number generator
  ;; Here, we read a 64-bit word from /dev/urandom
  ;; and put it in var_RNDSEED
_RANDOMIZE:
  MOV     X0, #-2               ; AT_FDCWD
  KLOAD   X1, urandom
  MOV     X2, #0                ; O_RDONLY
  MOV     X3, #0666             ; S_RDWR
  MOV     X16, #SYS_openat
  SVC     0
  ADDS    X11, XZR, X0
  B.PL    3f
  KPRINT  "Error: could not open /dev/urandom\n"
  B       _HALT
3:
  MOV     X0, X11
  KLOAD   X1, var_RNDSEED
  MOV     X2, #4
  MOV     X16, #SYS_read
  SVC     0
  RET

urandom:
  .asciz "/dev/urandom"

  .balign 8
  ;;                  ^
  ;; +------------+   |
  ;; | PREVIOUS --+---'
  ;; +------------+
  ;; |LENGTH+FLAGS|
  ;; +------------+
  ;; |'F' 'O' 'O' |
  ;; +------------+
  ;; | CODEWORD --+--,
  ;; +------------+  |
  ;; |            |<-'
  ;; |    BODY    |
  ;; |            |
  ;; +------------+
  ;;

_CODEWORDS:                     ; print first few codewords at X0
  PUSH    LR
  KPRINT  "codeword: "
  MOV     X5, X0
  LDR     X0, [X5], #8
  BL      printhex
  BL      _CR
  KPRINT  "        : "
  LDR     X0, [X5], #8
  BL      printhex
  BL      _CR
  KPRINT  "        : "
  LDR     X0, [X5], #8
  BL      printhex
  BL      _CR

  POP     LR
  RET




_PRINTWORD:
  PUSH      X0 %% PUSH X1 %% PUSH X2 %% PUSH X3 %% PUSH LR
  BL        _PRINTWORD2
  POP       LR %% POP X3 %% POP X2 %% POP X1 %% POP X0
  RET


_PRINTWORD2:
  // X1 -> beginning of dictionary entry
  CMP X1, #0
  BNE 1f
  RET
1:
  PUSH      LR
  KPRINT    "start:    "
  MOV       X0, X1
  BL        printhex
  BL        _CR
  KPRINT    "previous: "
  LDR       X0, [X1], #8
  PUSH      X0              ; save ptr to previous word in X5
  BL        printhex
  BL        _CR

  KPRINT    "length:   "
  MOV       X0, #0
  LDRB      W0, [X1]
  AND       W0, W0, F_LENMASK // length
  MOV       X2, X0  // len
  BL        printhex

  KPRINT    ", immediate="
  LDRB      W0, [X1]
  AND       W0, W0, F_IMMED // immediate mask
  ASR       W0, W0, #7
  ADD       W0, W0, '0'
  BL        _EMIT

  KPRINT    ", hidden="
  LDRB      W0, [X1], #1
  AND       W0, W0, F_HIDDEN  // hidden mask
  ASR       W0, W0, #5
  ADD       W0, W0, '0'
  BL        _EMIT
  BL        _CR

  PUSH      X1
  KPRINT    "name:     "
  MOV       X3, X1
  MOV       X0, #1  // stdout
  MOV       X1, X3  // str
  MOV       X16, #4
  SVC       0
  POP       X1
  BL        _CR

  ADD       X1, X1, X2
  ADD       X1, X1, #7
  AND       X1, X1, #~7
  LDR       X0, [X1]
  BL        _CODEWORDS

  BL        _CR
  BL        _CR
  POP       X1
  POP       LR
  B         _PRINTWORD2                  ; continue with previous word


  .data
  .balign  8

COLDSTART:
  .quad QUIT


  ;;  The BSS segment won't add to the binary's size
  .bss
data_segment:
  .space INITIAL_DATA_SEGMENT_SIZE
