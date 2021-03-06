#!/usr/bin/env python

prev = "0"

def header(name, label, flags):
    print("\t.data")
    print("\t.balign M_WORDSIZE")
    print("\t.globl name_" + label)
    print("name_" + label + ":")
    print("\t.quad " + prev)
    if flags:
        print("\t.byte " + str(len(name)) + " + " + str(flags))
    else:
        print("\t.byte " + str(len(name)))
    print("\t.ascii \"" + name + "\"")
    print("\t.balign M_WORDSIZE")
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
		 ".balign M_WORDSIZE",
		 "var_" + name + ":",
		 ".quad " + str(initial)
	 ], flags)

def mkop(name, label, op):
    return mkcode(name, label, ["POP X0", "POP X1", op + " X0, X1, X0", "PUSH X0", "NEXT"])

prev = mkcode("EXIT", "EXIT", ["POPRSP X8", "NEXT"])
prev = mkop("+", "PLUS", "ADD")
prev = mkop("-", "MINUS", "SUB")
prev = mkop("*", "TIMES", "MUL")
prev = mkop("/", "DIV", "SDIV")

# MOD is implemented more as a remainder function rather than
# the more mathematical definition with equivalence classes.
# For positive numbers, this is irrelevant but if you throw
# negative numbers at MOD you may want to check its behaviour.
# What's implemented here is the same as the C library fmod(3)
#  printf(" 10 mod  3 == %f\n", fmod( 10,  3)); // => +1
#  printf(" 10 mod -3 == %f\n", fmod( 10, -3)); // => +1
#  printf("-10 mod  3 == %f\n", fmod(-10,  3)); // => -1
#  printf("-10 mod -3 == %f\n", fmod(-10, -3)); // => -1
# See also https://torstencurdt.com/tech/posts/modulo-of-negative-numbers/

prev = mkcode("MOD", "MOD", [
    "POP  X0",
    "POP  X1",
    "UDIV X2, X1, X0",
    "MUL  X3, X0, X2",
    "SUB  X0, X1, X3",
    "PUSH X0",
    "NEXT"
])

# /MOD ( a b -- c d ) where c = a MOD b and d=a/b
prev = mkcode("/MOD", "DIVMOD", [
    "POP  X0",                  # X0 = b
    "POP  X1",                  # X1 = a
    "UDIV X2, X1, X0",          # X2 = a/b
    "MUL  X3, X0, X2",          # X3 = b*(a/b)
    "SUB  X0, X1, X3",          # X0 = a - b*(a/b)
    "PUSH X0",                  # push remainder
    "PUSH X2",                  # push quotient
    "NEXT" ])

prev = mkcode("1+", "INCR", ["POP X0", "ADD X0, X0, #1", "PUSH X0", "NEXT"])
prev = mkcode("1-", "DECR", ["POP X0", "SUB X0, X0, #1", "PUSH X0", "NEXT"])

prev = mkcode("DUP", "DUP", [
    "POP X0",
    "PUSH X0",
    "PUSH X0",
    "NEXT"
])

prev = mkcode("2DUP", "TWODUP", [  # ( a b -- a b a b )
    "POP X0",
    "POP X1",
    "PUSH X1",
    "PUSH X0",
    "PUSH X1",
    "PUSH X0",
    "NEXT"
])

prev = mkcode("?DUP", "QDUP", [  # duplicate top of stack if non-zero
    "POP X0",
    "PUSH X0",
    "CMP X0, #0",
    "B.EQ 1f",
    "PUSH X0",
    "1: NEXT"
])

prev = mkcode("ROT", "ROT", [  # rotate top 3 stack items ( a b c -- b c a )
    "POP X0",
    "POP X1",
    "POP X2",
    "PUSH X1",
    "PUSH X0",
    "PUSH X2",
    "NEXT"
])

prev = mkcode("-ROT", "NROT", [  # rotate top 3 stack items ( a b c -- c a b )
    "POP X0",
    "POP X1",
    "POP X2",
    "PUSH X0",
    "PUSH X2",
    "PUSH X1",
    "NEXT"
])


prev = mkcode("DROP", "DROP", ["POP X0", "NEXT"])
prev = mkcode("2DROP", "TWODROP", ["POP X0", "POP X0", "NEXT"])
prev = mkcode("SWAP", "SWAP", ["POP X0", "POP X1", "PUSH X0", "PUSH X1", "NEXT"])

# ( a b -- a b a )
prev = mkcode("OVER", "OVER", ["POP X0", "POP X1", "PUSH X1", "PUSH X0", "PUSH X1", "NEXT"])
#prev = mkcode(".", "DOT", ["POP X0", "BL printhex", "BL _CR", "NEXT"])
prev = mkcode(".", "DOT", ["POP X0", "BL printhex", "NEXT"])
prev = mkcode(".8", "DOT8", ["POP X0", "BL printhex8", "NEXT"])
prev = mkcode("INCR8", "INCR8", ["POP X0", "ADD X0, X0, #8", "PUSH X0", "NEXT"])

# Access to the return stack

prev = mkcode(">R", "TOR", ["POP X0", "PUSHRSP X0", "NEXT"])
prev = mkcode("R>", "FROMR", ["POPRSP X0", "PUSH X0", "NEXT"])

# push top of return stack
prev = mkcode("R->1", "RGET1", ["LDR X0, [X9]", "PUSH X0", "NEXT" ])
# push 2nd item of return stack
prev = mkcode("R->2", "RGET2", ["LDR X0, [X9, #M_STACKITEMSIZE]", "PUSH X0", "NEXT" ])
# push 3rd item of return stack
prev = mkcode("R->3", "RGET3", ["LDR X0, [X9, #M_STACKITEMSIZE+M_STACKITEMSIZE]", "PUSH X0", "NEXT" ])



prev = mkcode("RSP!", "RSPSTORE", ["POP X9", "NEXT"])
prev = mkcode("RSP@", "RSPFETCH", ["PUSH X9", "NEXT"])
prev = mkcode("RDROP", "RDROP", ["POPRSP X0", "NEXT"])

prev = mkcode("DSP@", "DSPFETCH", ["MOV X0, SP", "PUSH X0", "NEXT"])
prev = mkcode("DSP!", "DSPSTORE", ["POP X0", "MOV X0, SP", "NEXT"])

# special form: push next word as constant
# Assembler considers labels beginning with L as locals, hence DOLIT instead of LIT
prev = mkcode("LIT", "_LIT", ["LDR X0, [X8], #8", "PUSH X0", "NEXT"])

# ANS FORTH says that the comparison words should return -1 for TRUE and 0 for FALSE
# Jones Forth uses the C programming convention 1 for TRUE and 0 for FALSE.
# Here, I'm using the ANS FORTH convention but if you prefer Jones Forth way of doing it,
# replace CSETM with CSET below.

# ( a b -- a ) top two words are equal?
prev = mkcode("=", "EQU", [
    "POP X0",
    "POP X1",
    "CMP X1, X0",
    "CSETM X0, EQ",
    "PUSH X0",
    "NEXT"])

# ( a b -- a ) top two words not equal?
prev = mkcode("<>", "NEQ", [
    "POP X0",
    "POP X1",
    "CMP X1, X0",
    "CSETM X0, NE",
    "PUSH X0",
    "NEXT"])

prev = mkcode("<", "_LT", [
    "POP X0",
    "POP X1",
    "CMP X1, X0",
    "CSETM X0, LT",
    "PUSH X0",
    "NEXT"])

prev = mkcode(">", "_GT", [
    "POP X0",
    "POP X1",
    "CMP X1, X0",
    "CSETM X0, GT",
    "PUSH X0",
    "NEXT"])

prev = mkcode(">=", "_GE", [
    "POP X0",
    "POP X1",
    "CMP X1, X0",
    "CSETM X0, GE",
    "PUSH X0",
    "NEXT"])

prev = mkcode("<=", "_LE", [
    "POP X0",
    "POP X1",
    "CMP X1, X0",
    "CSETM X0, LE",
    "PUSH X0",
    "NEXT"])

prev = mkcode("0=", "ZEQU", [   # top of stack == 0?
    "POP X0",
    "CMP X0, #0",
    "CSETM X0, EQ",
    "PUSH X0",
    "NEXT"
])

prev = mkcode("0<", "ZLT", [   # top of stack < 0?
    "POP X0",
    "CMP X0, #0",
    "CSETM X0, LT",
    "PUSH X0",
    "NEXT"
])

prev = mkcode("0>", "ZGT", [   # top of stack > 0?
    "POP X0",
    "CMP X0, #0",
    "CSETM X0, GT",
    "PUSH X0",
    "NEXT"
])

prev = mkcode("0>=", "ZGE", [   # top of stack >= 0?
    "POP X0",
    "CMP X0, #0",
    "CSETM X0, GE",
    "PUSH X0",
    "NEXT"
])

prev = mkcode("0<>", "ZNEQU", [   # top of stack not 0?
    "POP X0",
    "CMP X0, #0",
    "CSETM X0, NE",
    "PUSH X0",
    "NEXT"
])

prev = mkcode("AND", "AND", [  
    "POP  X0",
    "POP  X1",
    "AND  X0, X0, X1",
    "PUSH X0",
    "NEXT"
])

prev = mkcode("OR", "OR", [
    "POP  X0",
    "POP  X1",
    "ORR  X0, X0, X1",
    "PUSH X0",
    "NEXT"
])

prev = mkcode("INVERT", "INVERT", [   # ( a -- ~a ) bitwise NOT
    "POP X0",
    "MVN X0, X0",
    "PUSH X0",
    "NEXT"
])

# I/O

# KEY ( -- c ) where c is next character from stdin
prev = mkcode("KEY", "KEY", ["BL _KEY", "PUSH X0", "NEXT"])

# WORD ( -- addr n ) where n is length of string starting at addr
# read next word from stdin (up until whitespace)
prev = mkcode("WORD", "WORD", ["BL _WORD", "PUSH X1", "PUSH X2", "NEXT"])

# NUMBER ( addr length -- n e )
# convert string -> number: n is parsed number, e is nr of unparsed chars
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

prev = mkcode("!", "STORE", [   # ( n addr -- )  *addr = n
    "POP X0",                   # address to store at
    "POP X1",                   # data to store there
    "STR X1, [X0]",             # store it
    "NEXT" ])

prev = mkcode("C@", "FETCHBYTE", [
    "POP  X0",                  # address to store at
    "MOV  X1, #0",
    "LDRB W1, [X0]",            # fetch byte
    "PUSH X1",
    "NEXT"
])

# CMOVE is a block copy operation
prev = mkcode("CMOVE", "CMOVE", [
    "POP  X0",                   # length
    "POP  X1",                   # destination address
    "POP  X2",                   # source address
    "1: CMP X0, #0",
    "LDRB W3, [X2], #1",        # W3 = *X2++
    "STRB W3, [X1], #1",        # *X1++ = W3
    "SUBS X0, X0, #1",           # until length = 0
    "B.GT 1b",
    "NEXT"
])


prev = mkcode("C!", "STOREBYTE", [
    "POP X0",                   # address to store at
    "POP X1",                   # data to store there
    "STR X1, [X0]",             # store it
    "NEXT"
])

prev = mkcode("+!", "ADDSTORE", [
    "POP X0",                   # address
    "POP X1",                   # amount to add
    "LDR X2, [X0]",
    "ADD X2, X2, X1",
    "STR X2, [X0]",             # store *X0+X1
    "NEXT"
])

# ( addr length -- addr ) get dictionary entry for string
prev = mkcode("FIND", "FIND", [     
    "POP  X2",                      # X2 = length
    "POP  X1",                      # X1 = addr
    "BL   _FIND",
    "PUSH X4",
    "NEXT"])

prev = mkcode(">CFA", "TCFA", ["POP X0", "BL _TCFA", "PUSH X0", "NEXT"])

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
    "LDR  X0, [X8], #8",        # get the length of the string
    "PUSH X8",                  # push addr of start of string
    "PUSH X0",                  # push length of the string
    "ADD  X8, X0, X8",          # skip past the string
    "ADD  X8, X8, #M_WORDSIZE1",
    "AND  X8, X8, #~M_WORDSIZE1",
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
    "LDR  X1, [X0]",            # important that X0 points to codeword
    "BLR  X1"                   # jump to it
])

prev = mkcode("SYSCALL1", "SYSCALL1", [
    "POP X16",                  # system call number
    "POP X0",                   # argument
    "SVC 0",
    "PUSH X0",
    "NEXT"
])

prev = mkcode("SYSCALL2", "SYSCALL2", [
    "POP X16",                  # system call number
    "POP X1",                   # argument
    "POP X0",                   # argument
    "SVC 0",
    "PUSH X0",
    "NEXT"
])

prev = mkcode("SYSCALL3", "SYSCALL3", [
    "POP X16",                  # system call number
    "POP X2",                   # argument (nr of bytes)
    "POP X1",                   # argument (buffer address)
    "POP X0",                   # argument (file descriptor)
    "SVC 0",
    "PUSH X0",
    "NEXT"
])

prev = mkcode("SYSCALL4", "SYSCALL4", [
    "POP X16",                  # system call number
    "POP X3",                   # argument
    "POP X2",                   # argument
    "POP X1",                   # argument
    "POP X0",                   # argument
    "SVC 0",
    "PUSH X0",
    "NEXT"
])


prev = mkcode("DATA_SEGMENT", "DATA_SEGMENT", [
    "KLOAD X0, data_segment",
    "PUSH X0",
    "NEXT"
])

prev = mkcode("DATA_SEGMENT_SIZE", "DATA_SEGMENT_SIZE", [
    "MOV X0, #INITIAL_DATA_SEGMENT_SIZE",
    "PUSH X0",
    "NEXT"
])



# prev = mkword("DOUBLE", "DOUBLE", ["DUP", "PLUS"])
# prev = mkword("QUADRUPLE", "QUADRUPLE", ["DOUBLE", "DOUBLE"])
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


prev = mkconstaddr("DOCOL", "__DOCOL", "DOCOL")
prev = mkconstaddr("R0", "RZ", "return_stack_top")
prev = mkconstint("__WORDSIZE", "__WORDSIZE", "M_WORDSIZE")
prev = mkconstint("__WORDSIZE1", "__WORDSIZE1", "M_WORDSIZE1")
prev = mkconstint("__STACKITEMSIZE", "__STACKITEMSIZE", "M_STACKITEMSIZE")
prev = mkconstint("VERSION", "VERSION", "M_VERSION")
prev = mkconstint("F_HIDDEN", "__F_HIDDEN", "F_HIDDEN")
prev = mkconstint("F_IMMED", "__F_IMMED", "F_IMMED")
prev = mkconstint("F_LENMASK", "__F_LENMASK", "F_LENMASK")
prev = mkconstint("SYS_EXIT", "SYS_EXIT", "__NR_exit")
prev = mkconstint("SYS_OPENAT", "SYS_OPENAT", "__NR_openat")
prev = mkconstint("SYS_CLOSE", "SYS_CLOSE", "__NR_close")
prev = mkconstint("SYS_READ", "SYS_READ", "__NR_read")

# these are from fcntl.h 
prev = mkconstint("O_RDONLY", "O_RDONLY", "__O_RDONLY")
prev = mkconstint("O_WRONLY", "O_WRONLY", "__O_WRONLY")
prev = mkconstint("O_RDWR", "O_RDWR", "__O_RDWR")
prev = mkconstint("O_CREAT", "O_CREAT", "__O_CREAT")
prev = mkconstint("O_TRUNC", "O_TRUNC", "__O_TRUNC")
prev = mkconstint("AT_FDCWD", "AT_FDCWD", "__AT_FDCWD")

prev = mkvar("STATE", "STATE")
prev = mkvar("HERE", "HERE")
prev = mkvar("S0", "SZ")
prev = mkvar("UNIX_ARGC", "UNIX_ARGC")
prev = mkvar("UNIX_ARGV", "UNIX_ARGV")
prev = mkvar("UNIX_ENVP", "UNIX_ENVP")
prev = mkvar("BASE", "BASE", 10)
# substitute in the _last_ entry for name_RNDSEED below:
prev = mkvar("LATEST", "_LATEST", "name_RNDSEED")
prev = mkvar("RNDSEED", "RNDSEED", "0xACE1")  # can be initialized to any non-zero seed
