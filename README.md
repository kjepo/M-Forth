# M-Forth

## Abstract
M-Forth is an implementation of FORTH for the M1 processor on Mac OS X.

### Revision history

<b>2021-12-06</b>: M-Forth is now capable of running
all the code in <tt>stdlib.f</tt>. Not all primitives are ready though,
and documentation is still incomplete. The primitive "." prints in hex
until I've written the proper definition in <tt>stdlib.f</tt>.
</p>
<p>
<b>2021-12-15</b>: M-Forth can now print numbers with <tt>.</tt>
which respects the number base stored in the <tt>BASE</tt> variable.
The words <tt>DECIMAL</tt> and <tt>HEX</tt> in <tt>stdlib.f</tt>
changes <tt>BASE</tt> to 10 or 16, respectively.
</p>
<p>
<b>2021-12-20</b>: Fixed some serious bugs with LITSTRING and >CFA
so now you can print strings with <tt>." Hello world"</tt>.
</p>
<p>
<b>2021-12-28</b>: Very stable now.  Almost all of the library code
in <tt>stdlib.f</tt> is ready.  (Expect to be finished in a few days.)
</p>
<p>
<b>2021-12-31</b>: It's New Year's Eve and I managed to get M-FORTH
up and running.  There's an annoying bug (?) with <tt>FILE-OPEN</tt>
which returns the file descriptor 2 rather than a negative value.
Also, it would be nice if <tt>DOES></tt> could be implemented.
But we have to save something for 2022!

</p>


## Introduction and background
This document will not explain FORTH in detail
&mdash; there are plenty of resources for that.
Rather, we will just cover the salient features of the language,
in order to understand the implementation.

Forth <i>words</i> are akin to subroutines in other programming languages.
Words can be either <i>primitive</i>, i.e., written in assembly language,
or defined in terms of other words.  The syntax for defining a new word is
<p>
<tt>:</tt> <i>word</i> <i>word</i><sub>1</sub> <i>word</i><sub>2</sub>
           &hellip; <i>word</i><sub>n</sub> <tt>;</tt>
</p>
<p>
which is equivalent to
</p>
<p>
<tt>procedure</tt><i>word</i>() { <tt>call</tt> <i>word</i><sub>1</sub>();
                <tt>call</tt> <i>word</i><sub>2</sub>();
                &hellip;
                <tt>call</tt> <i>word</i><sub>n</sub>(); }
</p>
in a traditional programming language.
Notice that in Forth, arguments to words are not named.
Instead, they are assumed to appear on a <i>stack</i>.
As an example, let's look at the following definitions:
<pre>
: DOUBLE DUP PLUS ;
: QUADRUPLE DOUBLE DOUBLE ;
</pre>
Here, we define two new words &mdash; <tt>DOUBLE</tt> and <tt>QUADRUPLE</tt>
&mdash; using the primitives <tt>DUP</tt> and <tt>PLUS</tt>.
(The primitive <tt>DUP</tt> duplicates the top element of the stack.)
In a working FORTH system, we could then continue and enter
<pre>
42 QUADRUPLE .
</pre>
and the system would reply <tt>168</tt>.
(If you find this confusing, I urge you read a tutorial on FORTH first.)
<p>
FORTH programmers can enjoy identifiers with pretty much any character (but not space),
so <tt>.</tt> is another primitive which removes and prints out the top stack element.
</p>

## The inner interpreter
<p>
As we've seen, FORTH words can be either primitives &mdash; consisting entirely
of assembly language snippets &mdash; or user-defined, referencing a list
of previously defined words (which, in themselves, reference other words, etc,
until they ultimately reference a primitive).
</p>
<p>
We will define the inner interpreter &mdash; the core of the FORTH system.
To execute a primitive word like <tt>DUP</tt> or <tt>PLUS</tt> is obvious:
simply call the assembly code.
But in order to execute a user-defined word, we must potentially invoke the
interpreter recursively.  For instance, when executing <tt>QUADRUPLE</tt>
we must (twice) execute the word <tt>DOUBLE</tt> which, in itself, must
execute <tt>DUP</tt> and <tt>PLUS</tt>.
</p>
<p>
In a higher-level language, the interpreter could be expressed
recursively but here we must create a tight and fast interpreter in
assembly language.  It is therefore necessary for the interpreter
to maintain another stack to remember the location before going off
to execute the list of words in the referenced word.
More specifically, when we execute the body of <tt>QUADRUPLE</tt> we first
encounter <tt>DOUBLE</tt> so before calling the interpreter again with
<tt>DOUBLE</tt> we save the location of where we must continue when we
are done (which, incidentally, is another call to <tt>DOUBLE</tt>).
</p>
<p>
M-Forth uses "Indirect Threading".  In the first stage we write the so called
"inner interpreter" which can execute words but does not handle user input,
i.e., all words (primitive or not) must be defined in the assembler file.
</p>
<p>
First we need to look at the data structure for word definitions.
Let's look at the previous example:
</p>
<pre>
: DOUBLE DUP PLUS ;
: QUADRUPLE DOUBLE DOUBLE ;
</pre>

<img src="http://beta.rad.pub/ftp/innerint-1.png">


In this figure, gray cells denote the so called "codewords" which contains
a pointer to a piece of code that handles the word.  What is meant by
"handling" the word depends on the word being a primitive (written in assembler)
or not (consisting of links to other words).

# M-FORTH language specifics

## Control structures

### *condition* `IF` *true-part* `THEN`

Algol equivalent: `IF` *condition* `THEN` *true-part*

```
( Calculate the absolute value, e.g., -3 ABS -- 3 )
: ABS           ( a -- |a| )
  DUP           ( a a )
  0< IF         ( a )
    NEGATE      ( -a )
  THEN
;
```

### *condition* `IF` *true-part* `ELSE` *false-part* `THEN`

Algol equivalent: `IF` *condition* `THEN` *true-part* `ELSE` *else-part*

```
( Find maximum value, e.g., 5 9 MAX -- 9 )
: MAX           ( a b -- max(a,b) )
  2DUP          ( a b a b )
  > IF          ( a b )
    DROP        ( a )
  ELSE
    SWAP DROP   ( b )
  THEN
;
```

### `BEGIN` *loop-part* *condition* `UNTIL`

Algol: `DO` *loop-part* `WHILE` *condition*

```
( Write n spaces, e.g., 10 SPACES writes 10 " " )
: SPACES        ( n -- )
  BEGIN
    SPACE       
    -1 +        ( n-1 -- )
    DUP 0 =
  UNTIL         ( until n=0 )
;
```

### `BEGIN` *loop-part* `AGAIN`

Algol: `WHILE` true `DO` *loop-part*

```
( Print random numbers 0..9 until 0 occurs )
: RANDOM-NUMBERS  ( -- )
  RANDOMIZE
  BEGIN
    RND 10 MOD
    DUP . CR      ( print random number 0..9 )
    0= IF
      EXIT        ( use EXIT to leave infinite loop )
    THEN        
  AGAIN
;
```

Note that since `BEGIN` ... `AGAIN` forms an infinite loop, you must exit with `EXIT`, which returns from the word.

### `BEGIN` *condition* `WHILE` *loop-part* `REPEAT`

Algol: `WHILE` *condition* `DO` *loop-part*

```
( Calculate sum of a + ... + b, e.g., 1 10 SUM -- 55 )
: SUM           ( a b -- sum ) ( if a < b, sum is 0 )
  0             ( a b 0 )
  -ROT          ( 0 a b )
  BEGIN
    2DUP <=     ( while a <= b ... )
  WHILE         ( sum a b )
    -ROT        ( b sum a )
    DUP         ( b sum a a )
    -ROT        ( b a sum a )
    +           ( b a sum+a )
    -ROT        ( sum+a b a )
    1+          ( sum+a b a+1 )
    SWAP        ( sum+a a+1 b )
  REPEAT
  DROP DROP     ( sum )
;
```

### *condition* `UNLESS` *true-part* `THEN`

Algol: `IF` not condition `THEN` *true-part*

```
( Return TRUE if negative, otherwise FALSE, e.g., -3 NEGATIVE -- TRUE )
: NEGATIVE	( a -- TRUE | FALSE )
  TRUE		( a TRUE )
  SWAP		( TRUE a )
  0< UNLESS
    1+		( TRUE -> FALSE )
  THEN
;
```





# Deviations from Jones Forth

- Jones relies heavily on macros <tt>defcode</tt>, <tt>defvar</tt>
and <tt>defconst</tt> for defining primitives, variables and constants.
The assembler I use does not let me re-define the variable <tt>link</tt>
which is used to chain together all the words.  Instead I wrote a small
Python script <tt>words.py</tt> which generates the necessary assembler
definitions for all the primitives, variables and constants.
The Makefile generates the file <tt>primitives.s</tt> which is then
included in the main file <tt>M.s</tt>.

- Rather than putting magic numbers like <tt>4</tt> and <tt>8</tt>
in the code, I've decided to add two constants <tt>__WORDSIZE</tt>
and <tt>__STACKITEMSIZE</tt>.  These are (as the names imply) the
number of bytes in a word (8) and the size of a stack element (16).
These are restrictions enforced by the ARM architecture, so leave
them alone unless you are porting this to another platform.

- As a result of the above, I have not implemented primitives <tt>4+</tt>
and <tt>4-</tt>.  You should use <tt>__WORDSIZE +</tt> if you are
messing around with the internal data structures.

- M-FORTH checks for stack underflow on the data stack, and
stack overflow on the return stack.  You can disable this with
the <tt>STACKWARNING</tt> option in the <tt>Makefile</tt> but
in my experience, checking for stack underflow/overflow doesn't
add much to overall execution time.
While it would be nice to check for data stack
overflow and return stack underflow, this is unfortunately not
implemented (yet).

- I've decided to use <tt>-1</tt> for true and <tt>0</tt> for false,
unlike Jones Forth but in sync with ANS FORTH. I think the reason
for sticking to the ANS FORTH convention is that you can use <tt>AND</tt>,
<tt>OR</tt>, etc both as boolean and bitwise logical operations.

- Jones Forth relies on the brk(2) system call to figure out where
the data segment starts and to request some initial space. In recent
Mac OS X, brk has been discontinued so I allocate space for
the data segment with a constant <tt>INITIAL_DATA_SEGMENT_SIZE</tt>
in the BSS segment. This does not seem to affect the size of the
binary for M-FORTH.

- The user-defined word <tt>.S</tt> prints the contents of the stack
(non-destructively) but in my implementation I've decided to
(1) print the content with <tt>.</tt> rather than <tt>U.</tt> so
that negative values don't appear unsigned; (2) the stack is
printed in the order so that the top element is shown to the right.

- Normally, M-FORTH is started with
```
    cat stdlib.f - | ./M
```
but if M-FORTH is started without loading `stdlib.f`, there is still
a primitive form of `.` which prints the top-of-stack as a 64-bit
hexadecimal number.  This is a useful debugging tool when working
with the core interpreter.

# Things to do (unsorted)

- Documentation
