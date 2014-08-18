#include <powercom.h>
#include <signal.h>

int Pc_device;			/* device to use */
int Pcm_Pid_Child;		/* PID child used to read the slave answer */
int Pcm_Pid_Sleep;		/* PID use to wait the end of the timeout */
byte *Pcm_result;		/* byte readed on the serial port : answer of the slave */


/************************************************************************************
		Pcm_get_data : thread reading data on the serial port
*************************************************************************************
input :
-------
len	:	number of data to read;

no output
************************************************************************************/
void Pcm_get_data(int *len )
{
	int i;
	byte read_data;

	Pcm_Pid_Child=getpid();


	if (Pc_verbose)
		fprintf(stderr,"starting receiving data, total length : %d \n",*len);
	for(i=0;i<(*len);i++)
	{
		/* read data */
		read(Pc_device,&read_data,1);

		/* store data to the slave answer packet */
		Pcm_result[i]=read_data;
		
		/* call the pointer function if exist */
		if(Pc_ptr_rcv_data!=NULL)
			(*Pc_ptr_rcv_data)(read_data);
		if (Pc_verbose)
			fprintf(stderr,"receiving byte :0x%x %d (%d)\n",read_data,read_data,Pcm_result[i]);
	}
	if (Pc_verbose)
		fprintf(stderr,"receiving data done\n");

	Pcm_Pid_Child=0;

}

int Csm_get_data(int len, int timeout)
{
	int i;
	byte read_data;
	time_t t;

	if (Pc_verbose)
		fprintf(stderr,"in get data\n");
	
	t = (time(NULL) + ((timeout * 2)/1000));

	for(i=0;i<(len);i++)
	{
		if(t < time(NULL))
			return(0);

		/* read data */
		while(read(Pc_device,&read_data,1) <= 0)
		{
			if(t < time(NULL))
				return(0);
			usleep(100000);
		}
		/* store data to the slave answer packet */
		Pcm_result[i]=read_data;
		
		if (Pc_verbose)
			fprintf(stderr,"receiving byte :0x%x %d (%d)\n",read_data,read_data,Pcm_result[i]);
	  
	}
	if (Pc_verbose)
		fprintf(stderr,"receiving data done\n");
	return(1);
}


/************************************************************************************
		Pcm_sleep : thread wait timeout
*************************************************************************************
input :
-------
timeout : duduration of the timeout in ms

no output
************************************************************************************/
void Pcm_sleep(int *timeout)
{
	Pcm_Pid_Sleep=getpid();
	if (Pc_verbose)
		fprintf(stderr,"sleeping %d ms\n",*timeout);

	usleep(*timeout*1000);

	Pcm_Pid_Sleep=0;
	if (Pc_verbose)
		fprintf(stderr,"Done sleeping %d ms\n",*timeout);

}

/************************************************************************************
		Pcm_send_and_get_result : send data, and wait the answer of the slave
*************************************************************************************
input :
-------
trame	  : packet to send
timeout	: duduration of the timeout in ms
long_emit : length of the packet to send
longueur  : length of the packet to read

answer :
--------
0			: timeout failure
1			: answer ok
************************************************************************************/
int Pcm_send_and_get_result(byte trame[], int timeout, int long_emit, int longueur)
{
	int i,stat1=-1,stat2=-1;

	pthread_t thread1,thread2;
	Pcm_result = (unsigned char *) malloc(longueur*sizeof(unsigned char));

	/* clean port */
	tcflush(Pc_device, TCIFLUSH);

	/* create 2 threads for read data and to wait end of timeout*/
	pthread_create(&thread2, NULL,(void*)&Pcm_sleep,&timeout);
	pthread_detach(thread2);
	pthread_create(&thread1, NULL,(void*)&Pcm_get_data,&longueur);
	pthread_detach(thread1);

	if (Pc_verbose)
		fprintf(stderr,"start writing \n");
	for(i=0;i<long_emit;i++)
	{
		/* send data */
		write(Pc_device,&trame[i],1);
		/* call pointer function if exist */
		if(Pc_ptr_snd_data!=NULL)
			(*Pc_ptr_snd_data)(trame[i]);
	}

	if (Pc_verbose)
		fprintf(stderr,"write ok\n");

	do {

		if (Pcm_Pid_Child!=0)
			/* kill return 0 if the pid is running or -1 if the pid don't exist */
			stat1=0;
		else
			stat1=-1;

		if (Pcm_Pid_Sleep!=0)
			stat2=0;
		else
			stat2=-1;

		/* answer of the slave terminate or and of the timeout */
		if (stat1==-1 || stat2==-1) 
			break;
		usleep(timeout);

	} while(1); 
	if (Pc_verbose)
	{
		fprintf(stderr,"pid reading %d return %d\n",Pcm_Pid_Child,stat1);
		fprintf(stderr,"pid timeout %d return %d\n",Pcm_Pid_Sleep,stat2);
	}

	/* stop both childs */
	Pcm_Pid_Child=0;
	Pcm_Pid_Sleep=0;
	pthread_cancel(thread1);
	pthread_cancel(thread2);
	/* error : timeout fealure */
	if (stat1==0)
	{
		free(Pcm_result);
		return 0;
	}
	/* ok : store the answer packet in the data trame */
	for (i=0;i<=longueur;i++)
		trame[i]=Pcm_result[i];
	
	free(Pcm_result);
	return 1;
}
		
int Csm_send_and_get_result(unsigned char trame[], int timeout, int long_emit, int longueur)
{
	int i;
	int ret;

	Pcm_result = trame;
	
	if (Pc_verbose)
		fprintf(stderr,"start writing \n");
	for(i=0;i<long_emit;i++)
	{
		/* send data */
		write(Pc_device,&trame[i],1);
		/* call pointer function if exist */
		if(Pc_ptr_snd_data!=NULL)
			(*Pc_ptr_snd_data)(trame[i]);
	}

	tcdrain(Pc_device);

	if (Pc_verbose)
		fprintf(stderr,"write ok\n");

//	Mb_tio.c_cc[VMIN]=0;
//	Mb_tio.c_cc[VTIME]=1;

//	if (tcsetattr(Mb_device,TCSANOW,&Mb_tio) <0) {
//		perror("Can't set terminal parameters ");
//		return 0;
//	}
  
	ret = Csm_get_data(longueur, timeout);

//	Mb_tio.c_cc[VMIN]=1;
//	Mb_tio.c_cc[VTIME]=0;

//	if (tcsetattr(Mb_device,TCSANOW,&Mb_tio) <0) {
//		perror("Can't set terminal parameters ");
//		return 0 ;
//	}
	
	return ret;
}


/************************************************************************************
					Pcm_master : comput and send a master packet
*************************************************************************************
input :
-------
Pc_trame	  : struct describing the packet to comput
						device		: device descriptor
						slave 		: slave number to call
						function 	: modbus function
						address		: address of the slave to read or write
						length		: lenght of data to send
data_in	  : data to send to the slave
data_out	  : data to read from the slave
timeout	  : timeout duration in ms
ptrfoncsnd : function to call when master send data (can be NULL if you don't whant to use it)
ptrfoncrcv : function to call when master receive data (can be NULL if you don't whant to use it)
*************************************************************************************
answer :
--------
0 : OK
-1 : unknow modbus function
-2 : wrong header
-3 : timeout error
-4 : wrong checksum
*************************************************************************************/
int Pc_master(Pcm_trame Pctrame,int data_in[], int data_out[],void *ptrfoncsnd, void *ptrfoncrcv)
{
	int i,longueur,long_emit;
	int slave, function, adresse, nbre;
	byte trame[256];

	Pc_device=Pctrame.device;
	slave=Pctrame.slave;
	function=Pctrame.function;
	adresse=Pctrame.address;
	nbre=Pctrame.length;
	Pc_ptr_snd_data=ptrfoncsnd;
	Pc_ptr_rcv_data=ptrfoncrcv;
		
	/* read n byte */
	switch(Pctrame.function)
	{
	case 1:	/* ask for serial number */
		trame[0]=0xBB;
		trame[1]=0xBB;
		trame[2]=0x00;
		trame[3]=0x00;
		trame[4]=0x00;
		trame[5]=0x00;
		trame[6]=0x00;
		trame[7]=0x00;
		trame[8]=0x00;
		/* compute crc */
		Pc_calcul_checksum(trame,9);
		/* compute length of the packet to send */
		long_emit=11;
		/* compute length of the slave answer */
		longueur=11+11;	// 11 Header+checksum, 11 payload
		break;
	case 2:	/* log into inverter with knwon serial number */
		trame[0]=0xBB;
		trame[1]=0xBB;
		trame[2]=0x00;
		trame[3]=0x00;
		trame[4]=0x00;
		trame[5]=0x00;
		trame[6]=0x00;
		trame[7]=0x01;
		trame[8]=0x0C;
		memcpy(trame+9,Pc_serial,11);
		trame[20]=0x01;
		/* compute crc */
		Pc_calcul_checksum(trame,21);
		/* compute length of the packet to send */
		long_emit=23;
		/* compute length of the slave answer */
		longueur=12;
		break;
	case 4:	/* ask for registers */
		trame[0]=0xBB;
		trame[1]=0xBB;
		trame[2]=0x01;
		trame[3]=0x00;
		trame[4]=0x00;
		trame[5]=0x01;
		trame[6]=0x01;
		trame[7]=0x02;
		trame[8]=0x00;
		/* compute crc */
		Pc_calcul_checksum(trame,9);
		/* compute length of the packet to send */
		long_emit=11;
		/* compute length of the slave answer */
		longueur=11+42;	// 11 Header+checksum, 42 payload
		break;
	}

	if (Pc_verbose) 
	{
		fprintf(stderr,"send packet length %d\n",long_emit);
		for(i=0;i<long_emit;i++)
			fprintf(stderr,"send packet[%d] = %0x\n",i,trame[i]);
	}
	
	/* send packet & read answer of the slave
		answer is stored in trame[] */

	for(i = 0;i < 4; i++){
		if(Csm_send_and_get_result(trame,Pctrame.timeout,long_emit,longueur)){
			i = 1;
			break;
		}
	}
	if(i != 1) 
		return -3;	/* timeout error */

  	if (Pc_verbose)
	{
		fprintf(stderr,"answer :\n");
		for(i=0;i<longueur;i++)
			fprintf(stderr,"answer packet[%d] = %0x\n",i,trame[i]);
	}
	
	/* test received data */
	if (trame[0]!=0xBB || trame[1]!=0xBB)
		return -2;
	if (Pc_test_checksum(trame,longueur-2))
		return -4;
	/* data are ok */
	if (Pc_verbose)
		fprintf(stderr,"Reader data \n");
        if(Pctrame.function==1)
	{
		memcpy(Pc_serial,trame+9,11);
		Pc_serial[11]=0;
	}
	if(Pctrame.function==4)
		for (i=0;i<21;i++)
		{
			data_out[i]=(trame[9+i*2]<<8)+trame[10+i*2];
			if (Pc_verbose)
				fprintf(stderr,"data %d = %0x\n",i,data_out[i]);
		}
	return 0;
}

