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

: COUNTDOWN#2 ( print 10 random numbers between 0..9 )
  10   
  RANDOMIZE
  BEGIN
    DUP 0= IF
        EXIT
    THEN
    1-
    RND 10 MOD .
  AGAIN
;


: NIP ( x y -- y ) SWAP DROP ;
: TUCK ( x y -- y x y ) SWAP OVER ;
: PICK ( x_u ... x_1 x_0 u -- x_u ... x_1 x_0 x_u )
  1+              ( add one because of 'u' on the stack )
  16 *            ( multiply by the word size )
  DSP@ +          ( add to the stack pointer )
  @               ( and fetch )
;

( With the looping constructs, we can now write SPACES, which writes n spaces to stdout. )
: SPACES          ( n -- )
  BEGIN
    DUP 0>        ( while n > 0 )
  WHILE
    SPACE         ( print a space )
    1-            ( until we count down to 0 )
  REPEAT
  DROP
;

( Standard words for manipulating BASE. )
: DECIMAL ( -- ) 10 BASE ! ;
: HEX ( -- ) 16 BASE ! ;

( ------------------------------ NUMBERS ------------------------------ 

 The standard FORTH word . (DOT) is very important.  It takes the number at the
 top of the stack and prints it out.  However first I'm going to implement some
 lower-level FORTH words:

   U.R ( u width -- )  which prints an unsigned number, padded to a certain width
   U.  ( u -- )        which prints an unsigned number
   .R  ( n width -- )  which prints a signed number, padded to a certain width.

 For example:

   -123 6 .R

 will print out these characters:

   <space> <space> - 1 2 3

 In other words, the number padded left to a certain number of characters.
 The full number is printed even if it is wider than width, and this is what
 allows us to define the ordinary functions U. and . (we just set width to
 zero knowing that the full number will be printed anyway).

 Another wrinkle of . and friends is that they obey the current base in the
 variable BASE. BASE can be anything in the range 2 to 36.

 While we're defining . &c we can also define .S which is a useful debugging
 tool.  This word prints the current stack (non-destructively) from top to bottom.
 
)

( This is the underlying recursive definition of U. )
: U.              ( u -- )
  BASE @ /MOD     ( width rem quot )
	?DUP IF         ( if quotient <> 0 then )
    RECURSE       ( print the quotient )
  THEN

	( print the remainder )
  DUP 10 < IF
    '0'           ( decimal digits 0..9 )
  ELSE
    10 -          ( hex and beyond digits A..Z )
    'A'
  THEN
  +
  EMIT
;

(
  FORTH word .S prints the contents of the stack.  It doesn't alter the stack.
  Very useful for debugging.
)
: .S              ( -- )
  DSP@            ( get current stack pointer )
  BEGIN
    DUP S0 @ <
  WHILE
    DUP @ U.      ( print the stack element )
    SPACE
    16 +          ( move up )
  REPEAT
  DROP
;

( This word returns the width (in characters) of an unsigned number in the current base )
: UWIDTH          ( u -- width )
  BASE @ /        ( rem quot )
  ?DUP IF         ( if quotient <> 0 then )
    RECURSE 1+    ( return 1+recursive call )
  ELSE
    1             ( return 1 )
  THEN
;

: U.R             ( u width -- )
  SWAP            ( width u )
  DUP             ( width u u )
  UWIDTH          ( width u uwidth )
  ROT             ( u uwidth width )
  SWAP -          ( u width-uwidth )

  (
    At this point if the requested width is narrower, we'll have a negative number on the
    stack. Otherwise the number on the stack is the number of spaces to print. But SPACES
    won't print a negative number of spaces anyway, so it's now safe to call SPACES ...
  )

  SPACES

  ( ... and then call the underlying implementation of U. )

  U.
;

(
  .R prints a signed number, padded to a certain width.  We can't just print the sign and
  call U.R because we want the sign to be next to the number ('-123' instead of '-  123').
)
: .R              ( n width -- )
  SWAP            ( width n )
  DUP 0< IF
    NEGATE        ( width u )
    1             ( save a flag to remember that it was negative | width n 1 )
    SWAP          ( width 1 u )
    ROT           ( 1 u width )
    1-            ( 1 u width-1 )
  ELSE
    0             ( width u 0 )
    SWAP          ( width 0 u )
    ROT           ( 0 u width )
  THEN
  SWAP            ( flag width u )
  DUP             ( flag width u u )
  UWIDTH          ( flag width u uwidth )
  ROT             ( flag u uwidth width )
  SWAP -          ( flag u width-uwidth )

  SPACES          ( flag u )
  SWAP            ( u flag )

  IF              ( was it negative? print the - character )
    '-' EMIT
  THEN

  U.
;

( Finally we can define word . in terms of .R, with a trailing space. )
: . 0 .R SPACE ;

( The real U., note the trailing space. )
: U. U. SPACE ;

( ? fetches the integer at an address and prints it. )
: ? ( addr -- ) @ . ;

( c a b WITHIN returns true if a <= c and c < b )
( or define without if:s    OVER - >R - R> U<   )
: WITHIN
  -ROT            ( b c a )
  OVER
  <= IF
    > IF          ( b c -- )
      TRUE
    ELSE
      FALSE
    THEN
  ELSE
    2DROP         ( b c -- )
    FALSE
  THEN
;

( DEPTH returns the depth of the stack )
: DEPTH           ( -- n )
  S0 @ DSP@ -
  16 -            ( adjust because S0 was on the stack when we pushed DSP )
;

( ALIGNED takes an address and rounds it up (aligns it)
  to the next 16 byte boundary )
: ALIGNED         ( addr -- addr )
  15 + 
  15 INVERT AND   ( (addr+15) & ~15 )
;

( ALIGN aligns the HERE pointer, so the next word appended will be aligned )
: ALIGN HERE @ ALIGNED HERE ! ;

( ------------------------------ STRINGS ------------------------------

 S" string" is used in FORTH to define strings.  It leaves the address of the
 string and its length on the stack (length at the top of stack).  The space
 following S" is the normal space between FORTH words and is not a part of the
 string.

 This is tricky to define because it has to do different things depending on
 whether we are compiling or in immediate mode.  (Thus the word is marked
 IMMEDIATE so it can detect this and do different things).

 In compile mode we append

    LITSTRING <string length> <string rounded up 16 bytes>

 to the current word.  The primitive LITSTRING does the right thing when the
 current word is executed.

 In immediate mode there isn't a particularly good place to put the string, but
 in this case we put the string at HERE (but we _don't_ change HERE).  This is
 meant as a temporary location, likely to be overwritten soon after.
)

( C, appends a byte to the current compiled word )
: C,
  HERE @ C!       ( store the character in the compiled image )
  1 HERE +!       ( increment HERE pointer by 1 byte )
;

