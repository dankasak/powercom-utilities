#include <powercom.h>
#include <fcntl.h>

/************************************************************************************
		Pc_test_crc : check the crc of a packet
*************************************************************************************
input :
-------
trame  : packet with is crc
n      : lenght of the packet without tht crc
                              ^^^^^^^
answer :
--------
1 = crc fealure
0 = crc ok
************************************************************************************/
int Pc_test_checksum(byte trame[],int n)
{
	unsigned short checksum;
	int i;
	checksum=0;
	for (i=0;i<n;i++)
	{
		checksum+=trame[i];
	}
	if (Pc_verbose)
		fprintf(stderr,"test checksum IS %0x, SHOULD BE %0x%0x\n",checksum,trame[n],trame[n+1]);
	if ((trame[n]!=(checksum>>8)) || (trame[n+1]!=(checksum&255)))
		return 1;
	else
		return 0;
}

/************************************************************************************
		Pc_calcul_crc : compute the crc of a packet and put it at the end
*************************************************************************************
input :
-------
trame  : packet with is crc
n      : lenght of the packet without tht crc
                              ^^^^^^^
answer :
--------
crc
************************************************************************************/
int Pc_calcul_checksum(byte trame[],int n)
{
	unsigned short checksum;
	int i;
	checksum=0;
	for (i=0;i<n;i++)
	{
		checksum+=trame[i];
	}
	trame[n]=checksum>>8;
	trame[n+1]=checksum&255;
	return checksum;
}
/************************************************************************************
		Mb_close_device : Close the device
*************************************************************************************
input :
-------
Mb_device : device descriptor

no output
************************************************************************************/
void Pc_close_device(int Pc_device)
{
  if (tcsetattr (Pc_device,TCSANOW,&Pc_saved_tty_parameters) < 0)
    perror("Can't restore terminal parameters ");
  close(Pc_device);
}

/************************************************************************************
		Mb_open_device : open the device
*************************************************************************************
input :
-------
Mbc_port   : string with the device to open (/dev/ttyS0, /dev/ttyS1,...)
Mbc_speed  : speed (baudrate)
Mbc_parity : 0=don't use parity, 1=use parity EVEN, -1 use parity ODD
Mbc_bit_l  : number of data bits : 7 or 8 	USE EVERY TIME 8 DATA BITS
Mbc_bit_s  : number of stop bits : 1 or 2    ^^^^^^^^^^^^^^^^^^^^^^^^^^

answer  :
---------
device descriptor
************************************************************************************/
int Pc_open_device(char *Pcc_port, int Pcc_speed, int Pcc_parity, int Pcc_bit_l, int Pcc_bit_s)
{
  int fd;

  /* open port */
  fd = open(Pcc_port,O_RDWR | O_NOCTTY | O_NONBLOCK | O_NDELAY) ;
  if(fd<0)
  {
    perror("Open device failure\n") ;
    return -1;
  }

  /* save olds settings port */
  if (tcgetattr (fd,&Pc_saved_tty_parameters) < 0)
  {
    perror("Can't get terminal parameters ");
    return -1 ;
  }

  /* settings port */
  bzero(&Pc_tio,sizeof(&Pc_tio));

  switch (Pcc_speed)
  {
     case 0:
        Pc_tio.c_cflag = B0;
        break;
      case 1200:
        Pc_tio.c_cflag = B1200;
        break;
     case 1800:
        Pc_tio.c_cflag = B1800;
        break;
     case 2400:
        Pc_tio.c_cflag = B2400;
        break;
     case 4800:
        Pc_tio.c_cflag = B4800;
        break;
     case 9600:
        Pc_tio.c_cflag = B9600;
        break;
     case 19200:
        Pc_tio.c_cflag = B19200;
        break;
     case 38400:
        Pc_tio.c_cflag = B38400;
        break;
     case 57600:
        Pc_tio.c_cflag = B57600;
        break;
     case 115200:
        Pc_tio.c_cflag = B115200;
        break;
     case 230400:
        Pc_tio.c_cflag = B230400;
        break;
     default:
        Pc_tio.c_cflag = B9600;
  }
  switch (Pcc_bit_l)
  {
     case 7:
        Pc_tio.c_cflag = Pc_tio.c_cflag | CS7;
        break;
     case 8:
     default:
        Pc_tio.c_cflag = Pc_tio.c_cflag | CS8;
        break;
  }
  switch (Pcc_parity)
  {
     case 1:
        Pc_tio.c_cflag = Pc_tio.c_cflag | PARENB;
//        Mb_tio.c_iflag = ICRNL;
        break;
     case -1:
        Pc_tio.c_cflag = Pc_tio.c_cflag | PARENB | PARODD;
//        Mb_tio.c_iflag = ICRNL;
        break;
     case 0:
     default:
//        Mb_tio.c_iflag = IGNPAR | ICRNL;
        Pc_tio.c_iflag = IGNPAR;
//        Mb_tio.c_iflag &= ~ICRNL;
        break;
  }
//  Pc_tio.c_iflag &= ~ICRNL;
  Pc_tio.c_iflag |= IGNBRK;

  if (Pcc_bit_s==2)
     Pc_tio.c_cflag = Pc_tio.c_cflag | CSTOPB;

  Pc_tio.c_cflag = Pc_tio.c_cflag | CLOCAL | CREAD;
  Pc_tio.c_oflag = 0;
  Pc_tio.c_lflag = 0;	//ICANON;
  Pc_tio.c_cc[VMIN]=1;
  Pc_tio.c_cc[VTIME]=0;

  /* clean port */
  tcflush(fd, TCIFLUSH);

//  fcntl(fd, F_SETFL, FASYNC);
  /* activate the settings port */
  if (tcsetattr(fd,TCSANOW,&Pc_tio) <0)
  {
    perror("Can't set terminal parameters ");
    return -1 ;
  }
  
  /* clean I & O device */
  tcflush(fd,TCIOFLUSH);
  
   if (Pc_verbose)
   {
      printf("setting ok:\n");
      printf("device        %s\n",Pcc_port);
      printf("speed         %d\n",Pcc_speed);
      printf("data bits     %d\n",Pcc_bit_l);
      printf("stop bits     %d\n",Pcc_bit_s);
      printf("parity        %d\n",Pcc_parity);
   }
   return fd ;
}

/************************************************************************************
		Mb_rcv_print : print a character
This function can be use with slave or master to print a character when it receive one
*************************************************************************************
input :
-------
c : character

no output
************************************************************************************/
void Pc_rcv_print(unsigned char c)
{
   printf("-> receiving byte :0x%x %d \n",c,c);
}

/************************************************************************************
		Mb_snd_print : print a character
This function can be use with slave or master to print a character when it send one
*************************************************************************************
input :
-------
c : character

no output
************************************************************************************/
void Pc_snd_print(unsigned char c)
{
   printf("<- sending byte :0x%x %d \n",c,c);
}

char *Pc_version(void)
{
   return VERSION;
}
