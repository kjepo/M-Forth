.macro KPRINT str
        B 1f
str\@:  .asciz "\str"
        .align 4
1:      STP X0, X1, [SP, #-16]!
        STP X2, X16, [SP, #-16]!
        STR LR, [SP, #-16]!
        ADR X0, str\@
        MOV X1, X0
2:      LDRB W2, [X0], #1
        CMP W2, #0
        B.NE 2b
        SUB X2, X0, X1          // len
        SUB X2, X2, #1
        MOV X16, #4             // write
        MOV X0, #1              // stdin
        SVC 0
        LDR LR, [SP], #16
        LDP X2, X16, [SP], #16
        LDP X0, X1, [SP], #16
.endm   
