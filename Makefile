SRC=M
$(SRC): $(SRC).s words.py
	./words.py > primitives.s
	cc -arch arm64 -o $@ $<
