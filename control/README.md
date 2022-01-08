# Implementing the DO-LOOP

We want to have a `DO` ... `LOOP` feature in FORTH which should work like this:
```
." loop starts" CR
10 1 DO
  I 5 > IF LEAVE THEN
  I . CR
LOOP
." loop finished" CR
```
The arguments to `DO` are the limit and index.
The loop will, regardless of initial values of limit and index,
execute the body at least once.
In the body, the word `I` can be used to access the current index.
Each time after the body is executed, the index is incremented.
If the index is smaller than the limit, the loop runs again.
The word `LEAVE` can be used to exit the loop prematurely: when
this happens, the program continues to whatever is after `LOOP`.

We want to translate the above to something which does the same
using the primitives `BRANCH` and `0BRANCH` which both take an
offset as their argument: +n to jump forwards n words and -n to
jump backwards n words.

There are several problems here:

- The body can contain more than one `LEAVE` so we potentially
need to backfill more than one `BRANCH` offset.
- The address to the beginning of the loop can not be kept on top
of the stack &mdash; a technique used by Jones Forth to compile
control structures &mdash; because there can be `IF`-statements
inside the loop body and we would interfere with its translation
by placing the loop's start address on top of the stack.
- The loop index and limit can not be kept on the stack either:
when the loop is executed, the user will certainly use
the stack for his own purposes and we wouldn't know where
the index and limits are.

Let's start with the last problem by placing index and limit on
the return stack.  We are then left with the problem of translating
the loop to something like this:

```
  10 1
  ." loop starts" CR
  SWAP	  	  	\ 1 10
  >R >R			\ return stack: 10 1
  R->1 5 > IF
    R> R> BRANCH [ 96 , ]
  THEN 	 
  R->1 . CR
  R> R> SWAP		\ 10 1
  1+ 2DUP <
  0BRANCH [ -184 , ]	\ 10 2
  ." loop finished" CR
```

In essence, the `DO` word only serves as a target for the `0BRANCH` offset,
`LEAVE` should compile to a forward `BRANCH` and `I` only needs to
reference the top element on the return stack (`R->1`, which grabs
the 1st element of the return stack, the equivalent of `R> DUP >R`).