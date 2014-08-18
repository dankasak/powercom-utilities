/*
#ifndef __powercom__

#define __powercom__ 1
*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <termios.h>
#include <pthread.h>

#define VERSION "0.0.1"

struct termios Pc_saved_tty_parameters;		/* old serial port setting (restored on close) */
struct termios Pc_tio;				/* new serial port setting */


int Pc_verbose;					/* print debug informations */
int Pc_status;					/* stat of the software : This number is free, it's use with function #07 */
char Pc_serial[12];


typedef unsigned char byte;			/* create byte type */

/* master structure */
typedef struct {
   int device;					/* powercom device (serial port: /dev/ttyS0 ...) */
   int slave; 					/* number of the slave to call*/
   int function; 				/* powercom function to emit*/
						/* 1=Seriennummer abfragen */
						/* 2=Anmelden mit Seriennummer */
						/* 3= */
						/* 4=Zähler abfragen */
   int address;					/* slave address */
   int length;					/* data length */
   int timeout;					/* timeout in ms */
} Pcm_trame;

/*pointer functions */
void (*Pc_ptr_rcv_data) ();			/* run when receive a char in master or slave */
void (*Pc_ptr_snd_data) ();			/* run when send a char  in master or slave */
void (*Pc_ptr_end_slve) ();			/* run when slave finish to send response trame */

/* master main function :
- trame informations
- data in
- data out
- pointer function called when master send a data on serial port (can be NULL if not use)
- pointer function called when master receive a data on serial port (can be NULL if not use)*/
int Pc_master(Pcm_trame, int [] , int [], void*, void*);

/* commun functions */
int Pc_open_device(char *, int , int , int ,int );		/* open device and configure it */
void Pc_close_device();						/* close device and restore old parameters */
int Pc_test_checksum(unsigned char[] ,int );			/* check checksum */
int Pc_calcul_checksum(unsigned char[] ,int );			/* compute checksum */

void Pc_rcv_print(unsigned char);				/* print a char (can be call by master or slave with Mb_ptr_rcv_data)*/
void Pc_snd_print(unsigned char);				/* print a char (can be call by master or slave with Mb_ptr_rcv_data)*/
char *Pc_version(void);						/* return libpowercom version */

