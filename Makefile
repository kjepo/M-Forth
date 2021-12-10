SRC=M

# Comment out the following line if you don't want M-FORTH
# to check for stack overflow -- a small time overhead.
CFLAGS=-DSTACKWARNING
$(SRC): $(SRC).s kload.s kprint.s pushpop.s words.py Makefile
	./words.py > primitives.s
	cc $(CFLAGS) -arch arm64 -o $@ $<

