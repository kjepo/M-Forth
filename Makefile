SRC=M
LIBS=kload.s kprint.s pushpop.s printhex.s
# Comment out the following line if you don't want M-FORTH
# to check for stack overflow -- a small time overhead.
CFLAGS=-DSTACKWARNING
$(SRC): $(SRC).s $(LIBS) words.py Makefile
	./words.py > primitives.s
	cc $(CFLAGS) -arch arm64 -o $@ $<

