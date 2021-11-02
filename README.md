# M-Forth

M-Forth is an implementation of FORTH for the M1 processor on Mac OS X.

M-Forth uses "Indirect Threading".  In the first stage we write the so called
"inner interpreter" which can execute words but does not handle user input,
i.e., all words (primitive or not) must be defined in the assembler file.

<img src="http://beta.rad.pub/ftp/m1.png">


