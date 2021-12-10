  ;; printhex -- print reg X0 as 16 char hex string 000000000000002A
  ;; X1: pointer to output buffer hexbuf
  ;; W2: scratch register
  ;; X3: pointer to hex characters hexchars
  ;; W4: holds next hex digit
  ;; W5: loop counter

  .text
  .balign 8
printhex:

  PUSH  LR
  PUSH  X1
  PUSH  X2
  PUSH  X3
  PUSH  X4
  PUSH  X5

  KLOAD   X1, hexbuf            ; X1 = &hexbuf
  ADD     X1, X1, #15           ; X1 = X1 + 15 (length of hexbuf)
  MOV     W5, #16               ; loop counter: 16 characters to print
printhex1:
  AND     W2, W0, #0xf          ; W2 = W0 & 0xf   LLDB: reg read x0, x2
  KLOAD   X3, hexchars          ; LLDB: mem read $x3
  LDR     W4, [X3, X2]          ; W4 = *[X3 + X2]
  STRB    W4, [X1]              ; *X1 = W4
  SUB     X1, X1, #1            ; X1 = X1 - 1
  LSR     X0, X0, #4            ; X0 = X0 >> 4
  SUBS    W5, W5, #1            ; X5 = X5 - 1 (update condition flags)
  B.NE    printhex1             ; if X5 != 0 GOTO printhex1

  ;; Print string hexbuf
  MOV     X0, #1                ; 1 = StdOut
  KLOAD   X1, hexbuf            ; string to print
  MOV     X2, #16               ; length of our string
  MOV     X16, #4               ; MacOS write system call
  SVC     0                     ; Output the string

  POP X5
  POP X4
  POP X3
  POP X2
  POP X1
  POP LR

  RET

	.balign 8
	.data
hexchars:
  .ascii  "0123456789ABCDEF"
  .data
hexbuf:
  .ascii  "0000000000000000"
