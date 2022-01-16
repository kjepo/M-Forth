( A few words on arrays )
: ARRAY ( n -- ) CELLS ALLOT CONSTANT ;
: INDEX! ( a n -- ) CELLS + ! ;
: INDEX@ ( a n -- a[n] ) CELLS + @ ;

( Create space for 100 frames of local variables a ... z )
2600 ARRAY LOCAL-VARS

( Use >a to create a local variable a, use a> to push value of a on stack )
: >a ( n -- ) LOCAL-VARS  0 INDEX! ;  : a> ( n -- ) LOCAL-VARS  0 INDEX@ ;
: >b ( n -- ) LOCAL-VARS  1 INDEX! ;  : b> ( n -- ) LOCAL-VARS  1 INDEX@ ;
: >c ( n -- ) LOCAL-VARS  2 INDEX! ;  : c> ( n -- ) LOCAL-VARS  2 INDEX@ ;
: >d ( n -- ) LOCAL-VARS  3 INDEX! ;  : d> ( n -- ) LOCAL-VARS  3 INDEX@ ;
: >e ( n -- ) LOCAL-VARS  4 INDEX! ;  : e> ( n -- ) LOCAL-VARS  4 INDEX@ ;
: >f ( n -- ) LOCAL-VARS  5 INDEX! ;  : f> ( n -- ) LOCAL-VARS  5 INDEX@ ;
: >g ( n -- ) LOCAL-VARS  6 INDEX! ;  : g> ( n -- ) LOCAL-VARS  6 INDEX@ ;
: >h ( n -- ) LOCAL-VARS  7 INDEX! ;  : h> ( n -- ) LOCAL-VARS  7 INDEX@ ;
: >i ( n -- ) LOCAL-VARS  8 INDEX! ;  : i> ( n -- ) LOCAL-VARS  8 INDEX@ ;
: >j ( n -- ) LOCAL-VARS  9 INDEX! ;  : j> ( n -- ) LOCAL-VARS  9 INDEX@ ;
: >k ( n -- ) LOCAL-VARS 10 INDEX! ;  : k> ( n -- ) LOCAL-VARS 10 INDEX@ ;
: >l ( n -- ) LOCAL-VARS 11 INDEX! ;  : l> ( n -- ) LOCAL-VARS 11 INDEX@ ;
: >m ( n -- ) LOCAL-VARS 12 INDEX! ;  : m> ( n -- ) LOCAL-VARS 12 INDEX@ ;
: >n ( n -- ) LOCAL-VARS 13 INDEX! ;  : n> ( n -- ) LOCAL-VARS 13 INDEX@ ;
: >o ( n -- ) LOCAL-VARS 14 INDEX! ;  : o> ( n -- ) LOCAL-VARS 14 INDEX@ ;
: >p ( n -- ) LOCAL-VARS 15 INDEX! ;  : p> ( n -- ) LOCAL-VARS 15 INDEX@ ;
: >q ( n -- ) LOCAL-VARS 16 INDEX! ;  : q> ( n -- ) LOCAL-VARS 16 INDEX@ ;
: >r ( n -- ) LOCAL-VARS 17 INDEX! ;  : r> ( n -- ) LOCAL-VARS 17 INDEX@ ;
: >s ( n -- ) LOCAL-VARS 18 INDEX! ;  : s> ( n -- ) LOCAL-VARS 18 INDEX@ ;
: >t ( n -- ) LOCAL-VARS 19 INDEX! ;  : t> ( n -- ) LOCAL-VARS 19 INDEX@ ;
: >u ( n -- ) LOCAL-VARS 20 INDEX! ;  : u> ( n -- ) LOCAL-VARS 20 INDEX@ ;
: >v ( n -- ) LOCAL-VARS 21 INDEX! ;  : v> ( n -- ) LOCAL-VARS 21 INDEX@ ;
: >w ( n -- ) LOCAL-VARS 22 INDEX! ;  : w> ( n -- ) LOCAL-VARS 22 INDEX@ ;
: >x ( n -- ) LOCAL-VARS 23 INDEX! ;  : x> ( n -- ) LOCAL-VARS 23 INDEX@ ;
: >y ( n -- ) LOCAL-VARS 24 INDEX! ;  : y> ( n -- ) LOCAL-VARS 24 INDEX@ ;
: >z ( n -- ) LOCAL-VARS 25 INDEX! ;  : z> ( n -- ) LOCAL-VARS 25 INDEX@ ;

( Start a new frame for local variables a ... z )
: LSP-> 26 +TO LOCAL-VARS ;

( End most recent frame )
: <-LSP -26 +TO LOCAL-VARS ;

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
