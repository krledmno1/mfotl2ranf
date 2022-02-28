CC = g++
CFLAGS = -std=c++17 -O3 -Wno-unused-result

all: gen_sinceuntil run

gen_sinceuntil: util.h util.cpp gen_sinceuntil.cpp
	$(CC) $(CFLAGS) -I../src/ -o gen_sinceuntil util.cpp gen_sinceuntil.cpp

run: run.cpp
	$(CC) $(CFLAGS) -o $@ $@.cpp
