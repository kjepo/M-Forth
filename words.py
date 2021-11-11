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

# some constants are simple integers, like M_VERSION, while others are addresses
# we need MOV X0, value for the first but KLOAD X0, value for the other
def mkconstint(name, label, value, flags=0):
    return mkcode(name, label, ["MOV X0, #" + value, "PUSH X0", "NEXT"], flags)
def mkconstaddr(name, label, value, flags=0):
    return mkcode(name, label, ["KLOAD X0, " + value, "PUSH X0", "NEXT"], flags)
    
def mkvar(name, label, initial=0, flags=0):
    return mkcode(name, label, [
    		 "KLOAD X0, var_" + name,
		 "PUSH X0",
		 "NEXT",
		 ".data",
		 ".align 4",
		 "var_" + name + ":",
		 ".quad " + str(initial)
		 ], flags)

prev = mkcode("EXIT", "EXIT", ["POPRSP X8", "NEXT"])
prev = mkcode("PLUS", "PLUS", ["POP X0", "POP X1", "ADD X0, X0, X1", "PUSH X0", "NEXT"])
prev = mkcode("TIMES", "TIMES", ["POP X0", "POP X1", "MUL X0, X0, X1", "PUSH X0", "NEXT"])
prev = mkcode("DUP", "DUP", ["POP X0", "PUSH X0", "PUSH X0", "NEXT"])
prev = mkcode("DROP", "DROP", ["POP X0", "NEXT"])
prev = mkcode(".", "DOT", ["POP X0", "BL printhex", "BL _CR", "NEXT"])
prev = mkcode("INCR8", "INCR8", ["POP X0", "ADD X0, X0, #8", "PUSH X0", "NEXT"])


# special form: push next word as constant
# Assembler considers labels beginning with L as locals, hence DOLIT instead of LIT
prev = mkcode("LIT", "_LIT", ["LDR X0, [X8], #8", "PUSH X0", "NEXT"])

prev = mkcode("HALT", "HALT", ["BL _HALT", "NEXT"])

# ANS FORTH says that the comparison words should return -1 for TRUE and 0 for FALSE
# Jones Forth uses the C programming convention 1 for TRUE and 0 for FALSE.
# Here, I'm using the ANS FORTH convention but if you prefer Jones Forth way of doing it, 
# replace CSETM with CSET below.

# ( a b -- a ) top two words are equal?
prev = mkcode("=", "EQU", ["POP	X0", "POP X1", "CMP X0, X1", "CSETM X0, EQ", "PUSH X0", "NEXT"])
# ( a b -- a ) top two words not equal?
prev = mkcode("<>", "NEQ", ["POP X0", "POP X1", "CMP X0, X1", "CSETM X0, NE", "PUSH X0", "NEXT"])

# I/O

# KEY ( -- c ) where c is next character from stdin
prev = mkcode("KEY", "KEY", ["BL _KEY", "PUSH X0", "NEXT"])
# WORD ( -- addr n ) where n is length of string starting at addr
prev = mkcode("WORD", "WORD", ["BL _WORD", "PUSH X1", "PUSH X0", "NEXT"])
# NUMBER ( addr length -- n e ) convert string -> number: n is parsed number, e is nr of unparsed chars
prev = mkcode("NUMBER", "NUMBER", ["POP X1", "POP X0", "BL _NUMBER", "PUSH X0", "PUSH X1", "NEXT"])
# EMIT ( a -- ) emit top of stack as ASCII
prev = mkcode("EMIT", "EMIT", ["POP X0", "BL _EMIT", "NEXT"])
# fixme: rewrite this as a mkword using _LIT 10, EMIT
prev = mkcode("EMITWORD", "EMITWORD", ["POP X2", "POP X1", "BL _EMITWORD", "NEXT"])
prev = mkcode("CR", "CR", ["BL _CR", "NEXT"])
prev = mkcode("@", "FETCH", ["POP X0", "LDR X0, [X0]", "PUSH X0", "NEXT"])
# dictionary lookup ( length addr -- dictionaryp ) 
prev = mkcode("FIND", "FIND", ["POP X1", "POP X0", "BL _FIND", "PUSH X4", "NEXT"])
prev = mkcode(">CFA", "TCFA", ["POP X0", "BL _TCFA", "PUSH X1", "NEXT"])
prev = mkcode("PRINTWORD", "PRINTWORD", ["POP X1", "BL _PRINTWORD", "PUSH X1", "NEXT"])
prev = mkcode("CREATE", "CREATE", ["POP X1", "POP X0", "BL _CREATE", "NEXT"])
prev = mkcode(",", "COMMA", ["POP X0", "BL _COMMA", "NEXT"])

# [ sets STATE=0 (immediate mode)
prev = mkcode("[", "_LBRAC", ["KLOAD X0, var_STATE", "MOV X1, #0", "STR X1, [X0]", "NEXT"], "F_IMMED");
# ] sets STATE=1 (compile mode)
prev = mkcode("]", "_RBRAC", ["KLOAD X0, var_STATE", "MOV X1, #1", "STR X1, [X0]", "NEXT"], "F_IMMED");
prev = mkcode("HIDDEN", "HIDDEN", [
     "POP  X0",          	  # dictionary entry
     "ADD  X0, X0, #8",  	  # advance to length/flags byte
     "LDRB W1, [X0]",		  # get length/flags
     "EOR  W1, W1, F_HIDDEN",	  # toggle the HIDDEN bit
     "STRB W1, [X0]",
     "NEXT"])

prev = mkword("DOUBLE", "DOUBLE", ["DUP", "PLUS"])
prev = mkword("QUADRUPLE", "QUADRUPLE", ["DOUBLE", "DOUBLE"])
prev = mkword(">DFA", "TDFA", ["TCFA", "INCR8"])
prev = mkword(":", "COLON", [
     "WORD",	   # get the name of the word
     "CREATE",	   # CREATE the new dictionary entry/header
     "_LIT",	   # Append DOCOL (the codeword)
     "DOCOL",
     "COMMA",
     "_LATEST",	   # Make the word hidden
     "FETCH",	   
     "HIDDEN",
     "_RBRAC",	   # Go into compile mode
     "EXIT"]);

prev = mkconstaddr("R0", "RZ", "return_stack_top")
prev = mkconstint("VERSION", "VERSION", "M_VERSION")

prev = mkvar("STATE", "STATE")
prev = mkvar("HERE", "HERE")
prev = mkvar("S0", "SZ")
prev = mkvar("BASE", "BASE", 10)
# substitute in the last entry for name_BASE below:
prev = mkvar("LATEST", "_LATEST", "name_BASE")
