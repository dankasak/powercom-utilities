============================================================================
=                               LibPowercom  	               03/10/2010  =
=                                                                          =
=                   Based on libmodbus by Laurent LOPES.                   =
=           This software is Copyright (C) 2010 by Jörg Falkenberg.        =
=      Use this software at your own risk. I am not responsible for        =
=            anything this software may do to your computer.               =
=     This software falls under the GNU Public License. Please read        =
=                  the COPYING file for more information                   =
============================================================================


======================================
 Author
======================================
 
Author: Jörg Falkenberg
homepage: libpowercom.sourceforge.net
          

======================================
 Scope
======================================
This library offers communication functions to read information from
Powercom Ltd. Taiwan solar inverters. These inverters are known
under Solpower SPxxxx in Germany and Solar Roo in Australia.

Tested with Solarking 2000 and 3000.


======================================
 Thanks
======================================
Thanks to Darryl from Down Under for clarifying some register uses and
flags I could not decode in the beginning. The protocol PDF is done by
him.



======================================
 Requirements
======================================

   libpthread


======================================
 Install
======================================

  Compilation: make
  General install: make install
  Removal: make uninstall


======================================
 Getting started
======================================

Just look at the powercom-test.c to see how to get the data out of the inverter.

LibPowercom uses the GNU thread library. This library is generally provided 
with all Linux distributions.


======================================
Programming the LibPowercom
======================================

1. Open & Close
======================================

Before using master and slave functions you need to initialise the serial port 
with the function :

	int Pc_open_device(char device[], 
			int speed, 
			int parity,
			int data_bits_length,
			int stop_bits_length);


- device is a string which contains the device to open : /dev/ttyS0 for COM1, 
  /dev/ttyS1 for COM2, etc. 
- speed indicate the speed in baud rate. Each values are : 50, 75, 110, 134, 
  150, 200, 300, 600, 1200, 1800, 2400, 4800, 9600, 19200, 38400, 57600, 
  115200, 230400. If you set another value, the function  use automatically 
  9600 bauds.
- parity is the parity off the frame. 0 indicate don't use parity, 1 indicate 
  EVEN parity and -1 indicate ODD parity.
- data_bits_length indicate the length of the data bits. You can set 7 or 
  8 bits.
- data_bits_stop indicate how many bits to send at the end of the frame. 
  You can set 1 or 2 bits.

At least with my Solarking 9600,8,n,1 works.

The serial port is open in bidirectional asynchronous mode. Pc_open_device() 
save oldest parameters of the serial port to restore them when dial is 
terminate.

For more information about serial port configuration please read man pages : 
man 2 open, man 2 read, man 2 write and the serial programming HOWTO.


At the end of your program you can close and restore the oldest parameters 
with :

	void Pc_close_device(int device);

- device indicate the device descriptor returned by the Pc_open_device()
  function.


2. Master
======================================

Before send a packet you need to configure it. There is a struct made for it : 
Pcm_trame. The declaration of the Pcm_trame is declared as below :

		struct {
			int device;
			int slave;
			int function;
			int address;
			int length;
			int timeout;
		} Pcm_trame;

- device indicate the device descriptor returned by Pc_open_device().
- function indicate the function to send:
  * 1=ask for serial number
  * 2=log into inverter
  * 4=ask for registers

When Pcm_trame done, you can call send the request with 

	int Pc_master(Pcm_trame packet,
		int data_in[],
		int data_out[],
		void *ptr_function_send,
		void *ptr_function_receive);

- packet is the struct Pcm_trame set above
- data_in[] is data to send for writing functions. 
- data_out[] is data answered by the slave on reading function
- ptr_function_send is a function called when master send a data on the
                    serial port. If you don't want to call a function set
                    NULL. There is a predefined function to print the
                    character sent : Pc_snd_print(). See below to know
                    more about it.
- ptr_function_receive is a function called when master receive a data
                       from the serial port. If you don't want to call a
                       function set NULL. There is a predefined function
                       to print the character received : Pc_rcv_print().
                       See below to know more about it.

The Pc_master() function compute alone the packet to send, according to the  
setting above. The function send the packet and wait the slave answer during 
the timeout time. If the slave answer before the end of the timeout time, the 
master function check the slave answered packet, and in the case there isn't 
failure write data in data_out[] and return the value 0. 
If you make an error in the setting off the Pcm_trame struct the function 
return -1 and send nothing.
If there is noise on the line, or the slave answer bad data, or the control of 
the checksum in the slave packet is wrong, the function return -2 and store 
nothing in data_out[].

If the slave don"t answer before the end of the timeout, master 
function returns -3.


3. Misc.
======================================

int Pc_verbose;
To debug your program - and the library :) - you can switch on Pc_verbose to 1.
This integer is defined by the libpowercom. Set to 1 indicate master and slave 
function to write everything about the communication on the standard output 
(usually your screen).If you don't use this integer master and slave are 
automatically without verbose.


You can know the version of the libpowercom calling the function :

		char *Pc_version(void);

Maybe one day there will be newest version...


Function pointer :
You can indicate function to call when receive 
or send a data. In the libpowercom there is one 
function predefined for each action :

		void Pc_rcv_print(unsigned char c);

This function prints into the standard output : "receiving byte ->" and the 
character in hexadecimal and decimal mode.

		void Pc_snd_print(unsigned char c);

This function prints into the standard output : "sending byte ->" and the 
character in hexadecimal and decimal mode.

