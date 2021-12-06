\ The primitive word /MOD leaves both the quotient and
\ the remainder on the stack. Now we can define / and
\ MOD in terms of /MOD
: / /MOD SWAP DROP ;
: MOD /MOD DROP ;

\ Define some character constants
: '\n' 10 ;  \ newline
: BL 32 ;    \ BL is a standard FORTH word for space

\ CR prints a carriage return
: CR '\n' EMIT ;

\ SPACE prints a space
: SPACE BL EMIT ;

\ NEGATE leaves the negative of a number on the stack
: NEGATE 0 SWAP - ;

\ Standard words for booleans
: TRUE -1 ;      \ Note: -1 used for TRUE, instead of 1
: FALSE 0 ;
: NOT 0= ;

\ LITERAL takes whatever is on the stack and compiles LIT <foo>
: LITERAL IMMEDIATE
  ' LIT ,
  ,
  ;

: ':' [ CHAR : ] LITERAL ;
: '(' [ CHAR ( ] LITERAL ;
: ')' [ CHAR ) ] LITERAL ;
: '"' [ CHAR " ] LITERAL ;
: 'A' [ CHAR A ] LITERAL ;
: '0' [ CHAR 0 ] LITERAL ;
: '-' [ CHAR - ] LITERAL ;
: '.' [ CHAR . ] LITERAL ;

\ '[COMPILE] word' compiles 'word' if it would otherwise be IMMEDIATEn
: [COMPILE] IMMEDIATE
  WORD   \ get the next word
  FIND   \ find it in the dictionary
  >CFA   \ get its codeword
 ,      \ and compile that
;

\ RECURSE makes a recursive call to the current word that is being compiled.
\ Normally, while a word is being compiled, it is marked HIDDEN so that
\ references to the same word within are calls to the previous definition
\ of the word. However, we still have access to the word which we are
\ currently compiling through the LATEST pointer so we can use that to
\ compile a recursive call.
: RECURSE IMMEDIATE
  LATEST @  \ LATEST points to the word being compiled at the moment
  >CFA      \ get the codeword
  ,         \ compile it
;

\ CONTROL STRUCTURES
\ Please note that the control structures as defined here will only
\ work inside compiled words.  In immediate mode, they won't work.

\ Algol: IF <condition> THEN <true-part> ; <rest-part>
\ FORTH: <condition> IF <true-part> THEN <rest-part> 
\    ==> <condition> 0BRANCH OFFSET <true-part> <rest-part>
\ where OFFSET is the offset of <rest-part>
\

\ Algol: IF <condition> THEN <true-part> ELSE <false-part> ; <rest-part>
\ FORTH: <condition> IF <true-part> ELSE <false-part> THEN <rest-part>
\    ==> <condition> 0BRANCH OFFSET <true-part>
\                    BRANCH OFFSET2 <false-part> <rest-part>          
\ where OFFSET is the offset of <false-part>
\ and OFFSET2 is the offset of <rest-part>

: IF IMMEDIATE
  ' 0BRANCH ,   \ compile 0BRANCH
  HERE @        \ save location of the offset on the stack
  0 ,           \ compile a dummy offset
;

: THEN IMMEDIATE
  DUP
  HERE @ SWAP - \ calculate the offset from the address saved on the stack
  SWAP !        \ store the offset in the back-filled location
;

: ELSE IMMEDIATE
  ' BRANCH ,    \ definite branch to just over the false-part
  HERE @        \ save location of the offset on the stack
  0 ,           \ compile a dummy offset
  SWAP          \ now back-fill the original (IF) offset
  DUP           \ same as for THEN word above
  HERE @ SWAP -
  SWAP !
;

: SIGN 0 < IF -1 ELSE 1 THEN ;
: TEST#0 
  -3 SIGN .
   3 SIGN .
;

\ ALGOL: DO <loop-part> WHILE <condition>
\ FORTH: BEGIN <loop-part> <condition> UNTIL
\    ==> <loop-part> <condition> 0BRANCH OFFSET
\ where OFFSET points back to <loop-part>

: BEGIN IMMEDIATE
  HERE @      \ save location on the stack
;

: UNTIL IMMEDIATE
  ' 0BRANCH , \ compile 0BRANCH
  HERE @ -    \ calculate offset from the address saved on the stack
  ,           \ compile the offset here
;

: TEST#1
  10                \ start with 10
  BEGIN
    DUP .           \ print it
    -1 +            \ subtract 1
    DUP 0 = UNTIL   \ until it's 0
;

\ ALGOL: WHILE true DO <loop-part>
\ FORTH: BEGIN <loop-part> AGAIN
\    ==> <loop-part> BRANCH OFFSET
\ where OFFSET point back to <loop-part>
\ In other words, an infinite loop which can only be returned from with EXIT

: AGAIN IMMEDIATE
  ' BRANCH ,        \ compile BRANCH
  HERE @ -          \ calculate the offset back
  ,                 \ compile the offset here
;

: TEST#3
  RANDOMIZE
  BEGIN
    RND 10 MOD 
  AGAIN
;

\ ALGOL: while <condition> DO <loop-part> 
\ FORTH: BEGIN <condition> WHILE <loop-part> REPEAT
\    ==> <condition> 0BRANCH OFFSET2 <loop-part> BRANCH OFFSET
\ where OFFSET points back to <condition> (the beginning)
\ and OFFSET2 points to after the whole piece of code.

: WHILE IMMEDIATE
  ' 0BRANCH ,   \ compile 0BRANCH
  HERE @        \ save location of OFFSET2 on the stack
  0 ,           \ compile a dummy OFFSET2
;

: REPEAT IMMEDIATE
  ' BRANCH ,    \ compile BRANCH
  SWAP          \ get the original OFFSET (from BEGIN)
  HERE @ - ,    \ and compile it after BRANCH
  DUP           
  HERE @ SWAP - \ calculate OFFSET2
  SWAP !        \ and back-fill it in the original location
;

: TEST#4
  1
  BEGIN
    DUP 10 <>
  WHILE
    DUP .
    1 + 
  REPEAT
;

\ UNLESS is the same as IF but the test is reversed:
\ 
\ <condition> UNLESS <true-part> THEN
\
\ Note the use of [COMPILE]: Since IF is IMMEDIATE we don't want it to be
\ executed while UNLESS is compiling, but while UNLESS is running (which
\ happens to be when whatever word using UNLESS is being compiled -- whew!).
\ So we use [COMPILE] to reverse the effect of marking IF as immediate.
\ This trick is generally used when we want to write our own control words
\ without having to implement them all in terms of the primitives 0BRANCH
\ and BRANCH, but instead reusing simpler control words like (in this
\ instance) IF.

: UNLESS IMMEDIATE
  ' NOT ,       \ compile NOT (to reverse the test)
  [COMPILE] IF  \ continue by calling the normal IF
;

: TEST#5
  -1 0 = IF '-' EMIT THEN     \ should not print
   0 0 = IF '0' EMIT THEN     \ should print '0'
  -1 0 = UNLESS '-' EMIT THEN \ should print '-'
   0 0 = UNLESS '0' EMIT THEN \ should not print
;

\ FORTH allows ( ... ) as comments within function definitions.
\ This works by having an IMMEDIATE word called ( which just drops
\ input characters until it hits the corresponding ).
: ( IMMEDIATE
  1         \ allow nested parenthesis by keeping track of depth
  BEGIN
    KEY
    DUP '(' = IF
        DROP
        1+
    ELSE
        ')' = IF
            1-
        THEN
    THEN
  DUP 0= UNTIL
  DROP
;

( This is a comment ( and you can nest them too! ) )


          

: ABS DUP 0 < IF NEGATE THEN ;
: COUNTDOWN DUP 1 <
       IF QUIT
       THEN -1 + DUP . RECURSE
;

