# M-Forth

M-Forth is an implementation of FORTH for the M1 processor on Mac OS X.

<b>Note:</b> This document will not explain FORTH, there are plenty of resources for that.


M-Forth uses "Indirect Threading".  In the first stage we write the so called
"inner interpreter" which can execute words but does not handle user input,
i.e., all words (primitive or not) must be defined in the assembler file.

First we need to look at the data structure for word definitions.
Let's look at a simple example:
<pre>
: DOUBLE DUP PLUS ;
: QUADRUPLE DOUBLE DOUBLE ;
</pre>

<img src="http://beta.rad.pub/ftp/m2.png">

In this figure, gray cells denote the so called "codewords" which contains
a pointer to a piece of code that handles the word.  What is meant by
"handling" the word depends on the word being a primitive (written in assembler)
or not (consisting of links to other words).

