SRC=M
FLAGS=-lSystem -syslibroot `xcrun -sdk macosx --show-sdk-path` -e _main -arch arm64

$(SRC): $(SRC).o
	ld -macosx_version_min 11.0.0 -o $(SRC) $(SRC).o $(FLAGS)

%.o : %.s
	as -o $@ $<
