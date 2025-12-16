all: unix

unix:
	mkdir -p ../lib
	$(CC) -c -O2 -Os -fPIC clay.c
	$(AR) rcs ../lib/clay.a        clay.o
	rm *.o

