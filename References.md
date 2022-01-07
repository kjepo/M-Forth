# References

## Forth implementations

Jones Forth
<br>
https://github.com/nornagon/jonesforth/

Moving Forth
<br>
https://github.com/nornagon/jonesforth/blob/master/jonesforth.S

ASE: Writing a Forth interpreter from scratch
<br>
https://sifflez.org/lectures/ASE/C3.pdf

## ARM assembly language programming

Programming with 64-Bit ARM Assembly Language
<br>
https://www.apress.com/de/book/9781484258804?utm_medium=affiliate&utm_source=commission_junction&utm_campaign=3_nsn6445_product_PID%zp&utm_content=de_05032018#otherversion=9781484258804

Mac adaptation and comments to the book:
<br>
https://github.com/below/HelloSilicon

Apple specific ("Apple Silicon")
<br>
https://developer.apple.com/documentation/xcode/writing-arm64-code-for-apple-platforms

Princeton lectures on Assembly language programming:
<br>
https://www.cs.princeton.edu/courses/archive/spr19/cos217/lectures/13_Assembly1.pdf

ARM, load and store architecture:
<br>
https://azeria-labs.com/memory-instructions-load-and-store-part-4/

Code in ARM assembly, working with pointers:
<br>
https://eclecticlight.co/2021/06/21/code-in-arm-assembly-working-with-pointers/

A Guide to ARM64/AArch64 Assembly on Linux with Shellcodes and Cryptography 
<br>
https://modexp.wordpress.com/2018/10/30/arm64-assembly/

Porting Linux assembly programs to macOS:
<br>
https://rudamoura.com/porting-asm.html

ARM Assembler in Raspberry Pi:
<br>
https://thinkingeek.com/categories/raspberry-pi/

CSBIO:
<br>
http://www.csbio.unc.edu/mcmillan/Comp411F18/Lecture07.pdf


## Debugging

Voltron: https://github.com/snare/voltron

## FORTH implementation details

### FORTH's DO-LOOP

The implementation of `DO` .. `LOOP` is not easy: the body of the loop
can contain several `LEAVE` references, all which have to be compiled
into a `BRANCH` instruction with an offset which is not known at
compile time. We can either jump to a pre-known destination - which
then jumps to the end of the loop - so that only one offset has to be
filled in later, *or* we can maintain a list of locations to be filled
in later.  Because Jones Forth in its implementation of `IF`-`THEN`
uses the regular stack for keeping a copy of `HERE` for similar
purposes, *we* can't use the stack as well for remembering offset
locations to be filled in: an `IF` statement may occur inside (or
*will* occur) the loop, before the `LEAVE` instruction.  So we must
store at least one location (to be back filled) somewhere.  We can
perhaps use the return stack, although it we seem to be running out of
places to put things.  Another option is to keep a (global) variable,
a loop stack perhaps.

https://www.forth.com/starting-forth/6-forth-do-loops/

http://turboforth.net/tutorials/looping.html

https://stackoverflow.com/questions/58304029/how-is-forth-leave-loop-implemented-since-number-of-leaves-is-not-known-bef

https://manualzz.com/doc/17965265/---------------------------------------------------------...


### DOES>

https://softwareengineering.stackexchange.com/questions/339283/forth-how-do-create-and-does-work-exactly
