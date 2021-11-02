# M-Forth

## Abstract
M-Forth is an implementation of FORTH for the M1 processor on Mac OS X.

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

As we've seen, FORTH words can be either primitives &mdash; consisting entirely
of assembly language snippets &mdash; or user-defined &mdash; referencing a list
of previously defined words (which, in themselves, reference other words).
We will define the inner interpreter &mdash; the core of the FORTH system.
To execute a primitive word is obvious: simply call the assembly code.
But in order to execute a user-defined word, we must potentially invoke the
interpreter recursively.  For instance, when executing <tt>QUADRUPLE</tt>
we must (twice) execute the word <tt>DOUBLE</tt> which, in itself, must
execute <tt>DUP</tt> and <tt>PLUS</tt>.
In a higher-level language, the interpreter could probably be expressed
recursively but here we must create a tight and fast interpreter in
assembly language.  It is therefore necessary for the interpreter
to maintain another stack to remember the location before going off
to execute the list of words in the referenced word.
More specifically, when we execute the body of <tt>QUADRUPLE</tt> we first
encounter <tt>DOUBLE</tt> so before calling the interpreter again with
<tt>DOUBLE</tt> we save the location of where we must continue when we
are done (which, incidentally, is another call to <tt>DOUBLE</tt>).


M-Forth uses "Indirect Threading".  In the first stage we write the so called
"inner interpreter" which can execute words but does not handle user input,
i.e., all words (primitive or not) must be defined in the assembler file.
</p>
First we need to look at the data structure for word definitions.
Let's look at the previous example:
<pre>
: DOUBLE DUP PLUS ;
: QUADRUPLE DOUBLE DOUBLE ;
</pre>

<img src="http://beta.rad.pub/ftp/m2.png">

In this figure, gray cells denote the so called "codewords" which contains
a pointer to a piece of code that handles the word.  What is meant by
"handling" the word depends on the word being a primitive (written in assembler)
or not (consisting of links to other words).

