#
# FILE:
# Makefile
#
# FUNCTION:
# Makefile for libpowercom

CC=gcc

NAME=libpowercom
VERSION=0.0.1

CFLAGS	= -Wall -O3 -fPIC

all: libpowercom

libpowercom: commun.o  pcm.o
	$(CC) $(CFLAGS) -o libpowercom.so commun.o pcm.o -lpthread  -shared -I.


commun.o: commun.c powercom.h
	$(CC) $(CFLAGS) -c commun.c -I.


pcm.o: pcm.c powercom.h 
	$(CC) $(CFLAGS) -c  pcm.c -I.

clean:
	rm -f  ~* *~ *.ASV *.bak *.o core> /dev/null

install:
	chown root.root libpowercom.so
	cp libpowercom.so /usr/lib/
	cp powercom.h /usr/include
	mkdir /usr/share/doc/libpowercom
	cp README /usr/share/doc/libpowercom
#	cp AUTHORS /usr/share/doc/libpowercom
#	cp COPYING /usr/share/doc/libmodbus
uninstall:
	rm /usr/lib/libpowercom.so
	rm /usr/include/powercom.h
	rm /usr/doc/libpowercom -rf

tar:	clean
	tar -C .. -c -v -z -f ../tar/$(NAME)-$(VERSION).tar.gz $(NAME)-$(VERSION)
