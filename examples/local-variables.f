( A few words on arrays )
: ARRAY ( n -- ) CELLS ALLOT CONSTANT ;
: [!] ( a n -- ) CELLS + ! ;
: [@] ( a n -- a[n] ) CELLS + @ ;

( The number of local variables in a frame is 26: a ... z )
26 CONSTANT #LOCAL-VARS

( Create space for 100 frames of local variables a ... z )
#LOCAL-VARS 100 * ARRAY LOCAL-VARS

( Use >x to create a local variable x, use x> to push value of x on stack )
: >a LOCAL-VARS  0 [!] ;  : a> LOCAL-VARS  0 [@] ;
: >b LOCAL-VARS  1 [!] ;  : b> LOCAL-VARS  1 [@] ;
: >c LOCAL-VARS  2 [!] ;  : c> LOCAL-VARS  2 [@] ;
: >d LOCAL-VARS  3 [!] ;  : d> LOCAL-VARS  3 [@] ;
: >e LOCAL-VARS  4 [!] ;  : e> LOCAL-VARS  4 [@] ;
: >f LOCAL-VARS  5 [!] ;  : f> LOCAL-VARS  5 [@] ;
: >g LOCAL-VARS  6 [!] ;  : g> LOCAL-VARS  6 [@] ;
: >h LOCAL-VARS  7 [!] ;  : h> LOCAL-VARS  7 [@] ;
: >i LOCAL-VARS  8 [!] ;  : i> LOCAL-VARS  8 [@] ;
: >j LOCAL-VARS  9 [!] ;  : j> LOCAL-VARS  9 [@] ;
: >k LOCAL-VARS 10 [!] ;  : k> LOCAL-VARS 10 [@] ;
: >l LOCAL-VARS 11 [!] ;  : l> LOCAL-VARS 11 [@] ;
: >m LOCAL-VARS 12 [!] ;  : m> LOCAL-VARS 12 [@] ;
: >n LOCAL-VARS 13 [!] ;  : n> LOCAL-VARS 13 [@] ;
: >o LOCAL-VARS 14 [!] ;  : o> LOCAL-VARS 14 [@] ;
: >p LOCAL-VARS 15 [!] ;  : p> LOCAL-VARS 15 [@] ;
: >q LOCAL-VARS 16 [!] ;  : q> LOCAL-VARS 16 [@] ;
: >r LOCAL-VARS 17 [!] ;  : r> LOCAL-VARS 17 [@] ;
: >s LOCAL-VARS 18 [!] ;  : s> LOCAL-VARS 18 [@] ;
: >t LOCAL-VARS 19 [!] ;  : t> LOCAL-VARS 19 [@] ;
: >u LOCAL-VARS 20 [!] ;  : u> LOCAL-VARS 20 [@] ;
: >v LOCAL-VARS 21 [!] ;  : v> LOCAL-VARS 21 [@] ;
: >w LOCAL-VARS 22 [!] ;  : w> LOCAL-VARS 22 [@] ;
: >x LOCAL-VARS 23 [!] ;  : x> LOCAL-VARS 23 [@] ;
: >y LOCAL-VARS 24 [!] ;  : y> LOCAL-VARS 24 [@] ;
: >z LOCAL-VARS 25 [!] ;  : z> LOCAL-VARS 25 [@] ;

( Start a new frame for local variables a ... z )
: LSP-> #LOCAL-VARS +TO LOCAL-VARS ;

( End most recent frame )
: <-LSP #LOCAL-VARS NEGATE +TO LOCAL-VARS ;

( Use :: and ;; to start and define new words that use local variables a...z )
: :: IMMEDIATE : ' LSP-> , ;
: ;; IMMEDIATE ' <-LSP , [COMPILE] ; ;

( -------------------- Examples -------------------- )

:: test2 ( a -- a^2 )
   >a
   a> DUP *
;;

:: test1 ( a b c -- (a+b+c)^2 )
   >c >b >a
   a> b> c> + + test2    
;;

:: dist ( a b c d -- cartestian distance from a,b to c,d )
  >d >c >b >a
  c> a> - DUP * d> b> - DUP * + SQRT
;;


CR
." The square of 1+5+9 is "
1 5 9 test1 . CR

." The distance from (10,20) to (300,400) is "
10 20 300 400 dist . CR
