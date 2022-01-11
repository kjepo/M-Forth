( This example illustrates what happens when a FORTH word takes more
  than three arguments.  We can run into a situation where operations
  like SWAP, ROLL, OVER etc are not enough to "reach down" into the
  stack, so we must use ROLL and PICK.  Alternatively, we can temporarily
  shuffle arguments over to the return stack, also shown below. )

( Calculate distance from x1,y1 to x2,y2 )
( x1 y1 x2 y2 -- distance = sqrt((x2-x1)^2 + (y2-y1)^2) )
: dist
  2 ROLL    \ x1 x2 y2 y1
  - DUP *   \ x1 x2 (y2-y1)^2
  -ROT	    \ (y2-y1)^2 x1 x2
  - DUP *   \ (y2-y1)^2 (x1-x2)^2
  + SQRT    \ sqrt((y2-y1)^2 + (x1-x2)^2)
;

( Alternative version, using the return stack, and without using ROLL )
( x1 y1 x2 y2 -- dist )
: dist'
  >R	    \ x1 y1 x2
  SWAP	    \ x1 x2 y1
  R>        \ x1 x2 y1 y2
  - DUP *   \ x1 x2 (y1-y2)^2
  >R	    \ x1 x2
  - DUP *   \ (x1-x2)^2
  R>	    \ (x1-x2)^2 (y1-y2)^2
  + SQRT
;

CR
." distance from 10,20 to 300,400 = " 10 20 300 400 dist . CR
." distance from 10,20 to 300,400 = " 10 20 300 400 dist' . CR
." the answer in both cases will be 478" CR
