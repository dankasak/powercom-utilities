#include <powercom.h>

/* compiling : gcc powercom-test.c -o powercom-test -lpowercom */

int main()
{
   int device;
   Pcm_trame trame;
   int result;
   int data_in[256];
   int data_out[256];
   char data[256];
//   unsigned short register[16];
   int i;

   /* open device */
   device=Pc_open_device("/dev/ttyUSB0",9600,0,8,1);

   /* print debugging informations */
   Pc_verbose=1;
   
   /* try to read registers first */
   trame.device=device;
   trame.timeout=500;
   trame.function=4;
   result=Pc_master(trame,data_in,data_out,NULL,NULL);
   /* return 0 if ok */
   if (result<0)
   {
      if (result==-1) printf("error : unknow function\n");
      if (result==-2) printf("crc error\n");
      if (result==-3) printf("timeout error\n");
      if (result==-4) printf("error : bad slave answer\n");
   }
   else
   {
      printf("Read registers:\n");
      for(i=0;i<21;i++)
      {
	     printf("Register %d: %d\n",i,data_out[i]);
      }
      Pc_close_device(device);
      exit(0);
   }

   /* OK, no connection, so try to read serial number */
   trame.device=device;
   trame.timeout=500;
   trame.function=1;
   result=Pc_master(trame,data_in,data_out,NULL,NULL);
   /* return 0 if ok */
   if (result<0)
   {
      if (result==-1) printf("error : unknow function\n");
      if (result==-2) printf("crc error\n");
      if (result==-3) printf("timeout error\n");
      if (result==-4) printf("error : bad slave answer\n");
      Pc_close_device(device);
      exit(1);
   }
   else
   {
      printf("ok: serial number %s\n",Pc_serial);
   }
   trame.device=device;
   trame.timeout=1000;
   trame.function=2;
   result=Pc_master(trame,data_in,data_out,NULL,NULL);
   /* return 0 if ok */
   if (result<0)
   {
      if (result==-1) printf("error : unknow function\n");
      if (result==-2) printf("crc error\n");
      if (result==-3) printf("timeout error\n");
      if (result==-4) printf("error : bad slave answer\n");
      Pc_close_device(device);
      exit(1);
   }
   else
   {
      printf("ok: logged in\n");
   }

   trame.device=device;
   trame.timeout=1000;
   trame.function=4;
   result=Pc_master(trame,data_in,data_out,NULL,NULL);
   /* return 0 if ok */
   if (result<0)
   {
      if (result==-1) printf("error : unknow function\n");
      if (result==-2) printf("crc error\n");
      if (result==-3) printf("timeout error\n");
      if (result==-4) printf("error : bad slave answer\n");
      Pc_close_device(device);
      exit(1);
   }
   else
   {
      printf("Read registers:\n");
   }

   for(i=0;i<21;i++)
   {
	printf("Register %d: %d\n",i,data_out[i]);
   }

   Pc_close_device(device);

   return 0;
}

