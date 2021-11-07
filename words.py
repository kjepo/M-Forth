#!/usr/bin/env python

prev = "0"

def header(name, label, flags):
    print("\t.data")
    print("\t.align 4")
    print("\t.globl name_" + label)
    print("name_" + label + ":")
    print("\t.quad " + prev)
    print("\t.byte " + str(len(name)))
    print("\t.ascii \"" + name + "\"")
    print("\t.align 4")
    print("\t.globl " + label)
    print(label + ":")

def mkcode(name, label, cmds, flags=0):
    global prev;
    header(name, label, flags)
    print("\t.quad code_" + label)
    print("\t.text")
    print("\t.globl code_" + label)
    print("code_" + label + ":")
    for c in cmds:
    	print("\t" + c)
    print("\tNEXT")
    print	   
    return "name_" + label    
    
def mkword(name, label, cmds, flags=0):
    global prev
    header(name, label, flags)
    print("\t.quad DOCOL")
    for c in cmds:
    	print("\t.quad " + c)
    print("\t.quad EXIT")
    print
    return "name_" + label

prev = mkcode("EXIT", "EXIT", ["POPRSP X8"])
prev = mkcode("PLUS", "PLUS", ["POP X0", "POP X1", "ADD X0, X0, X1", "PUSH X0"])
prev = mkcode("TIMES", "TIMES", ["POP X0", "POP X1", "MUL X0, X0, X1", "PUSH X0"])
prev = mkcode("DUP", "DUP", ["POP X0", "PUSH X0", "PUSH X0"])
prev = mkcode("DROP", "DROP", ["POP X0"])
prev = mkcode(".", "DOT", ["POP X0", "BL printhex", "BL _CR"])

# special form: push next word as constant
# Assembler considers labels beginning with L as locals, hence DOLIT instead of LIT
prev = mkcode("LIT", "DOLIT", ["LDR X0, [X8], #8", "PUSH X0"])
prev = mkcode("HALT", "HALT", ["BL _HALT"])

# ANS FORTH says that the comparison words should return -1 for TRUE and 0 for FALSE
# Jones Forth uses the C programming convention 1 for TRUE and 0 for FALSE.
# Here, I'm using the ANS FORTH convention but if you prefer Jones Forth way of doing it, 
# replace CSETM with CSET below.

# ( a b -- a ) top two words are equal?
prev = mkcode("=", "EQU", ["POP	X0", "POP X1", "CMP X0, X1", "CSETM X0, EQ", "PUSH X0"])
# ( a b -- a ) top two words not equal?
prev = mkcode("<>", "NEQ", ["POP X0", "POP X1", "CMP X0, X1", "CSETM X0, NE", "PUSH X0"])

# I/O

# KEY ( -- c ) where c is next character from stdin
prev = mkcode("KEY", "KEY", ["BL _KEY", "PUSH X0"])
# WORD ( -- addr n ) where n is length of string starting at addr
prev = mkcode("WORD", "WORD", ["BL _WORD", "PUSH X1", "PUSH X0"])
# NUMBER ( addr length -- n e ) convert string -> number: n is parsed number, e is nr of unparsed chars
prev = mkcode("NUMBER", "NUMBER", ["POP X1", "POP X0", "BL _NUMBER", "PUSH X0", "PUSH X1"])
# EMIT ( a -- ) emit top of stack as ASCII
prev = mkcode("EMIT", "EMIT", ["POP X0", "BL _EMIT"])
# fixme: rewrite this as a mkword using DOLIT 10, EMIT
prev = mkcode("EMITWORD", "EMITWORD", ["POP X2", "POP X1", "BL _EMITWORD"])
prev = mkcode("CR", "CR", ["BL _CR"])




prev = mkword("DOUBLE", "DOUBLE", ["DUP", "PLUS"])
prev = mkword("QUADRUPLE", "QUADRUPLE", ["DOUBLE", "DOUBLE"])

