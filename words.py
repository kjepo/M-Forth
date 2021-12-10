#!/usr/bin/env python

prev = "0"

def header(name, label, flags):
    print("\t.data")
    print("\t.balign 8")
    print("\t.globl name_" + label)
    print("name_" + label + ":")
    print("\t.quad " + prev)
    if flags:
        print("\t.byte " + str(len(name)) + " + " + str(flags))
    else:
        print("\t.byte " + str(len(name)))
    print("\t.ascii \"" + name + "\"")
    print("\t.balign 8")         # should be 8? fixit
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
		 ".balign 8",
		 "var_" + name + ":",
		 ".quad " + str(initial)
		 ], flags)

prev = mkcode("EXIT", "EXIT", ["POPRSP X8", "NEXT"])
prev = mkcode("+", "PLUS", ["POP X0", "POP X1", "ADD X0, X1, X0", "PUSH X0", "NEXT"])
prev = mkcode("-", "MINUS", ["POP X0", "POP X1", "SUB X0, X1, X0", "PUSH X0", "NEXT"])
prev = mkcode("*", "TIMES", ["POP X0", "POP X1", "MUL X0, X0, X1", "PUSH X0", "NEXT"])
prev = mkcode("1+", "INCR", ["POP X0", "ADD X0, X0, #1", "PUSH X0", "NEXT"])
prev = mkcode("1-", "DECR", ["POP X0", "SUB X0, X0, #1", "PUSH X0", "NEXT"])
prev = mkcode("DUP", "DUP", ["POP X0", "PUSH X0", "PUSH X0", "NEXT"])
prev = mkcode("DROP", "DROP", ["POP X0", "NEXT"])
prev = mkcode("SWAP", "SWAP", ["POP X0", "POP X1", "PUSH X0", "PUSH X1", "NEXT"])
prev = mkcode("OVER", "OVER", ["POP X0", "POP X1", "PUSH X1", "PUSH X0", "PUSH X1", "NEXT"])
prev = mkcode(".", "DOT", ["POP X0", "BL printhex", "BL _CR", "NEXT"])
prev = mkcode("INCR8", "INCR8", ["POP X0", "ADD X0, X0, #8", "PUSH X0", "NEXT"])
prev = mkcode("RSP!", "RSPSTORE", ["POP X9", "NEXT"])
prev = mkcode("RSP@", "RSPFETCH", ["PUSH X9", "NEXT"])


# special form: push next word as constant
# Assembler considers labels beginning with L as locals, hence DOLIT instead of LIT
prev = mkcode("LIT", "_LIT", ["LDR X0, [X8], #8", "PUSH X0", "NEXT"])

prev = mkcode("HALT", "HALT", ["BL _HALT", "NEXT"])

# ANS FORTH says that the comparison words should return -1 for TRUE and 0 for FALSE
# Jones Forth uses the C programming convention 1 for TRUE and 0 for FALSE.
# Here, I'm using the ANS FORTH convention but if you prefer Jones Forth way of doing it,
# replace CSETM with CSET below.

# ( a b -- a ) top two words are equal?
prev = mkcode("=", "EQU", ["POP	X0", "POP X1", "CMP X1, X0", "CSETM X0, EQ", "PUSH X0", "NEXT"])
# ( a b -- a ) top two words not equal?
prev = mkcode("<>", "NEQ", ["POP X0", "POP X1", "CMP X1, X0", "CSETM X0, NE", "PUSH X0", "NEXT"])
prev = mkcode("<", "_LT", [ "POP X0", "POP X1", "CMP X1, X0", "CSETM X0, LT", "PUSH X0", "NEXT"])
prev = mkcode("0=", "ZEQU", [   # top of stack equals 0?
    "POP X0",
    "CMP X0, #0",
    "CSETM X0, EQ",
    "PUSH X0",
    "NEXT"
])

# I/O

# KEY ( -- c ) where c is next character from stdin
prev = mkcode("KEY", "KEY", ["BL _KEY", "PUSH X0", "NEXT"])

# WORD ( -- addr n ) where n is length of string starting at addr
# read next word from stdin (up until whitespace)
prev = mkcode("WORD", "WORD", ["BL _WORD", "PUSH X1", "PUSH X2", "NEXT"])

# NUMBER ( addr length -- n e ) convert string -> number: n is parsed number, e is nr of unparsed chars
prev = mkcode("NUMBER", "NUMBER", ["POP X1", "POP X0", "BL _NUMBER", "PUSH X0", "PUSH X1", "NEXT"])

# EMIT ( a -- ) emit top of stack as ASCII
prev = mkcode("EMIT", "EMIT", ["POP X0", "BL _EMIT", "NEXT"])

prev = mkcode("EMITWORD", "EMITWORD", ["POP X2", "POP X1", "BL _EMITWORD", "NEXT"])

# fixme: rewrite this as a mkword using _LIT 10, EMIT
#prev = mkcode("CR", "CR", ["BL _CR", "NEXT"])   # ( -- ) print carriage return


prev = mkcode("@", "FETCH", [       # ( addr -- n ) get contents at addr
    "POP  X0",
    "LDR  X0, [X0]",
    "PUSH X0",
    "NEXT"])

prev = mkcode("!", "STORE", [
    "POP X0",                   # address to store at
    "POP X1",                   # data to store there
    "STR X1, [X0]",             # store it
    "NEXT" ])

prev = mkcode("FIND", "FIND", [     # ( addr length -- addr ) get dictionary entry for string
    "POP  X2",                      # X1 = length
    "POP  X1",                      # X0 = addr
    "BL   _FIND",
    "PUSH X4",
    "NEXT"])

prev = mkcode(">CFA", "TCFA", ["POP X0", "BL _TCFA", "PUSH X0", "NEXT"])

prev = mkcode("PRINTWORD", "PRINTWORD", [    # ( addr -- ) prints info on dictionary entry
    "POP  X1", "BL   _PRINTWORD", "NEXT"])

prev = mkcode("CREATE", "CREATE", [    # ( addr length -- ) creates header for word
    "POP X1",		# length
    "POP X0",		# addr
    "BL  _CREATE",
    "NEXT"])

prev = mkcode(",", "COMMA", [	  # ( n -- ) write n into HERE, increment HERE
    "POP X0",
    "BL  _COMMA",
    "NEXT"])

prev = mkcode("[", "_LBRAC", [    # ( -- ) sets STATE=0 (immediate mode)
    "KLOAD X0, var_STATE",
    "MOV   X1, #0",
    "STR   X1, [X0]",
    "NEXT"], "F_IMMED")


prev = mkcode("]", "_RBRAC", [    # ( -- ) sets STATE=1 (compile mode)
    "KLOAD X0, var_STATE",
    "MOV   X1, #1",
    "STR   X1, [X0]",
    "NEXT"])

prev = mkcode("HIDDEN", "HIDDEN", [  	  # ( addr -- ) toggle HIDDEN bit in dictionary entry
    "POP  X0",                            # dictionary entry
    "ADD  X0, X0, #8",
    "LDRB W1, [X0]",                      # get length/flags byte
    "EOR  W1, W1, F_HIDDEN",              # toggle the HIDDEN bit
    "STRB W1, [X0]",
    "NEXT"])

# ( -- ) toggle IMMED bit for latest dictionary entry
prev = mkcode("IMMEDIATE", "IMMEDIATE", [
    "KLOAD X0, var_LATEST",
    "LDR   X0, [X0]",		              # X0 = LATEST
    "ADD   X0, X0, #8",
    "LDRB  W1, [X0]",                     # get length/flag byte
    "EOR   W1, W1, F_IMMED",	          # toggle IMMED bit
    "STRB  W1, [X0]",
    "NEXT" ], "F_IMMED")

# ( -- addr ) get codeword pointer of next word
# Common usage is ' FOO , which buries the address of FOO into the current word
# Note: this only works in compiled mode
# fixme: detect (and bail out) if not in compiled mode
prev = mkcode("'", "TICK", [
    "LDR  X0, [X8], #8",        # X0 = *(IP+8)
    "PUSH X0",
    "NEXT" ])

# add the offset to the instruction pointer
prev = mkcode("BRANCH", "BRANCH", [
    "LDR X0, [X8]",
    "ADD X8, X8, X0",
    "NEXT"
])

# 0BRANCH is the same as BRANCH but the branch happens conditionally
prev = mkcode("0BRANCH", "ZBRANCH", [
    "POP  X0",
    "CMP  X0, #0",              # top of stack == 0 ?
    "B.EQ code_BRANCH",         # if so, jump back to the branch function above
    "LDR  X0, [X8], #8",        # otherwise, skip the offset
    "NEXT" ])

# /MOD ( a b -- c d ) where c = a%b and d=a/b
prev = mkcode("/MOD", "DIVMOD", [
    "POP  X0",                  # X0 = b
    "POP  X1",                  # X1 = a
    "UDIV X2, X1, X0",          # X2 = a/b
    "MUL  X3, X0, X2",          # X3 = b*(a/b)
    "SUB  X0, X1, X3",          # X0 = a - b*(a/b)
    "PUSH X0",                  # push remainder
    "PUSH X2",                  # push quotient
    "NEXT" ])


# RND ( -- n ) generate a 64-bit random number
prev = mkcode("RND", "RND", [
    "KLOAD X1, var_RNDSEED",        # get current state
    "LDR X0, [X1]",
    "EOR X0, X0, X0, LSL #13",  # X0 ^= X0 << 13
    "EOR X0, X0, X0, LSR #7",   # X0 ^= X0 >> 7
    "EOR X0, X0, X0, LSL #17",  # X0 ^= X0 << 17
    "PUSH X0",
    "STR X0, [X1]",
    "NEXT" ])

# RANDOMIZE ( -- ) initiate random number seed
prev = mkcode("RANDOMIZE", "RANDOMIZE", [ "BL _RANDOMIZE", "NEXT" ])

# LITSTRING is a primitive used to implement the ." and S" operators (which are written in FORTH).
prev = mkcode("LITSTRING", "_LITSTRING", [
    "LDR   X0, [X8], #8",        # get the length of the string
    "PUSH X8",                   # push addr of start of string
    "PUSH X0",                   # push length of the string
    "ADD X8, X0, X8",            # skip past the string
    "NEXT" ])

# TELL prints a string
# X1: addr of string, X2: length of string
prev = mkcode("TELL", "TELL", [
    "MOV X0, #1",               # stdout
    "POP X2",                   # length of string
    "POP X1",                   # addr of string
    "MOV X16, #4",              # write system call
    "SVC 0",
    "NEXT" ])

# INTERPRET is the top loop of the FORTH system
prev = mkcode("INTERPRET", "INTERPRET", [ "BL _INTERPRET", "NEXT" ])

# CHAR puts the ASCII code of the first character of the following word on the stack
# For instance, CHAR A puts 65 on the stack
prev = mkcode("CHAR", "CHAR", [
    "BL   _WORD",
    "MOV  X0, #0",
    "LDRB W0, [X1]",
    "PUSH X0",
    "NEXT"
])

# run execution tokens (xt's)
# after xt runs, its NEXT will continue executing the current word
prev = mkcode("EXECUTE", "EXECUTE", [
    "POP  X0",                  # X0 = execution token
    "BLR  X1"                   # jump to it
])

prev = mkword("DEBUG", "DEBUG", [  # DEBUG <enter> PLUS <enter>
    "WORD",
    "FIND",
    "PRINTWORD",
])

prev = mkword("DEBUGLATEST", "DEBUGLATEST", [  # DEBUGLATEST 
    "_LATEST",
    "FETCH",
    "PRINTWORD",
])


prev = mkword("DOUBLE", "DOUBLE", ["DUP", "PLUS"])
prev = mkword("QUADRUPLE", "QUADRUPLE", ["DOUBLE", "DOUBLE"])
prev = mkword(">DFA", "TDFA", ["TCFA", "INCR8"])

prev = mkword(":", "COLON", [ 	    # start word definition
    "WORD",                         # get the name of the word
    "CREATE",                       # CREATE the new dictionary entry/header
    "_LIT", "DOCOL", "COMMA",       # append DOCOL (the codeword)
    "_LATEST", "FETCH", "HIDDEN",   # make the word hidden
    "_RBRAC", "EXIT" ])             # go into compile mode

prev = mkword(";", "SEMICOLON", [	# finish word definition
    "_LIT", "EXIT", "COMMA",		# append EXIT (so the word will return)
    "_LATEST", "FETCH", "HIDDEN",	# toggle hidden flag -- unhide the word
    "_LBRAC",
    "EXIT",
], "F_IMMED")	# go back to IMMEDIATE mode

# set hidden flag in current word
prev = mkword("HIDE", "HIDE", [ "WORD", "FIND", "HIDDEN", "EXIT" ])

# QUIT doesn't return, it just resets the return stack and calls the interpreter
prev = mkword("QUIT", "QUIT", [
    "RZ", "RSPSTORE",           # R0 RSP! - clear the return stack
    "INTERPRET",                # interpret the next word
    "BRANCH", "-16"             # ... and loop (indefinitely)
    ])




prev = mkconstaddr("R0", "RZ", "return_stack_top")
prev = mkconstint("VERSION", "VERSION", "M_VERSION")

prev = mkvar("STATE", "STATE")
prev = mkvar("HERE", "HERE")
prev = mkvar("S0", "SZ")
prev = mkvar("BASE", "BASE", 10)
# substitute in the _last_ entry for name_RNDSEED below:
prev = mkvar("LATEST", "_LATEST", "name_RNDSEED")
prev = mkvar("RNDSEED", "RNDSEED", "0xACE1")  # can be initialized to any non-zero seed
