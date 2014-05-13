#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <netinet/in.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <net/if.h>
#include <sys/ioctl.h>

#define NAMESIZE 100
#define SVC_INTERFACE 		"eth0:0"
#define CLI_INTERFACE	 	"eth0:1"
#define SVC_PORT 		    1234
#define CLI_PORT 		    7777
//#define HOST_ADDR "127.0.0.1"
//#define HOST_ADDR "192.168.1.145"

char sys_nic_ip[20];
char sys_nic_mask[20];
char sys_nic_mac[20];

int get_nic_info(const char *sys_nic_name)
{
	struct ifreq ifreq;
	int sockfd;

	if((sockfd=socket(AF_INET,SOCK_STREAM,0))<0)
	{
	     perror("socket");
	     return;
	}

	strcpy(ifreq.ifr_name,sys_nic_name);
	if(ioctl(sockfd,SIOCGIFADDR,&ifreq)<0)
	{
	     sprintf(sys_nic_ip,"Not set");
	}
	else
	{
	     sprintf(sys_nic_ip,"%d.%d.%d.%d",
		           (unsigned char)ifreq.ifr_addr.sa_data[2],
		           (unsigned char)ifreq.ifr_addr.sa_data[3],
		           (unsigned char)ifreq.ifr_addr.sa_data[4],
		           (unsigned char)ifreq.ifr_addr.sa_data[5]);
	}

	if(ioctl(sockfd,SIOCGIFNETMASK,&ifreq)<0)
	{
	     sprintf(sys_nic_mask,"Not set");
	}
	else
	{
	     sprintf(sys_nic_mask,"%d.%d.%d.%d",
		           (unsigned char)ifreq.ifr_netmask.sa_data[2],
		           (unsigned char)ifreq.ifr_netmask.sa_data[3],
		           (unsigned char)ifreq.ifr_netmask.sa_data[4],
		           (unsigned char)ifreq.ifr_netmask.sa_data[5]);
	}

	if(ioctl(sockfd,SIOCGIFHWADDR,&ifreq)<0)
	{
	     sprintf(sys_nic_mac,"Not set");
	}
	else
	{
	     sprintf(sys_nic_mac,"%02x:%02x:%02x:%02x:%02x:%02x",
		           (unsigned char)ifreq.ifr_netmask.sa_data[0],
		           (unsigned char)ifreq.ifr_netmask.sa_data[1],
		           (unsigned char)ifreq.ifr_netmask.sa_data[2],
		           (unsigned char)ifreq.ifr_netmask.sa_data[3],
		           (unsigned char)ifreq.ifr_netmask.sa_data[4],
		           (unsigned char)ifreq.ifr_netmask.sa_data[5]);
	}
	close(sockfd);
}

int main(int argc, char *argv[])
{
	int ret;
	int sockfd;
	int profilefd;
	char *iobuffer;
	char filename[32];
	unsigned int length;
	struct sockaddr_in svcaddr, cliaddr;
	char svc_addr[20], cli_addr[20];

	get_nic_info(SVC_INTERFACE);
	printf("IP:%s NETMASK:%s MAC:%s\n", sys_nic_ip, sys_nic_mask, sys_nic_mac);
	snprintf(svc_addr, sizeof(svc_addr), "%s", sys_nic_ip);

	get_nic_info(CLI_INTERFACE);
	printf("IP:%s NETMASK:%s MAC:%s\n", sys_nic_ip, sys_nic_mask, sys_nic_mac);
	snprintf(cli_addr, sizeof(cli_addr), "%s", sys_nic_ip);

	sockfd=socket(AF_INET,SOCK_STREAM,0);
	if(sockfd<0)
	{
		printf("Socket created failed.\n");
		return -1;
	}
 
	svcaddr.sin_family=AF_INET;
	svcaddr.sin_port=htons(SVC_PORT);
	//svcaddr.sin_addr.s_addr=inet_addr(HOST_ADDR);
	if(inet_aton(svc_addr,&svcaddr.sin_addr)<0)
	{
		close(sockfd);
		printf("inet_aton error.\n");
		return -2;
	}

	cliaddr.sin_family=AF_INET;
	cliaddr.sin_port=htons(CLI_PORT);
	//svcaddr.sin_addr.s_addr=inet_addr(HOST_ADDR);
	if(inet_aton(cli_addr,&cliaddr.sin_addr)<0)
	{
		close(sockfd);
		printf("inet_aton error.\n");
		return -2;
	}

	int opt = SO_REUSEADDR;
	setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

	if(bind(sockfd, (struct sockaddr *)&cliaddr, sizeof(cliaddr))<0)
	{
		perror("bind failed: ");
		return -2;
	}
	printf("connecting...\n");
	
	if(connect(sockfd,(struct sockaddr *)&svcaddr,sizeof(svcaddr))<0)
	{
		close(sockfd);
		printf("Connect server failed.\n");
		return -3;
	}
#if 1
    printf("please input the send file name:\n");
	fgets(filename,sizeof(filename)-1,stdin);
	filename[strlen(filename)-1] = '\0';
	if((profilefd=open(filename, O_RDONLY, S_IWUSR|S_IRUSR))==-1)
	{
		close(sockfd);
		printf("Target file open error:%s\n",filename);
		return -4;
	}
	length = lseek(profilefd,0,SEEK_END);
	iobuffer = (char*)malloc(length);
	if(NULL == iobuffer)
	{		
		close(sockfd);
		close(profilefd);
		printf("malloc error\n");
		return -5;
	}
	lseek(profilefd,0,SEEK_SET);
	
	int Ret;
	while((ret = read(profilefd,iobuffer,length))>0)
	{
		Ret = send(sockfd,iobuffer,ret,0);
		if(Ret<=0)
		{
			free(iobuffer);
			close(sockfd);
			close(profilefd);			
			printf("send error \n");
			return -6;
		}
		length-=ret;
	}
	free(iobuffer);
	close(sockfd);
	close(profilefd);
#else
    iobuffer = (char*)malloc(1500*4);
    if(!iobuffer)
    {
        printf("client malloc iobuffer error\n");
        close(sockfd);
    }
    memset(iobuffer,'A',1500*4);
    ret = send(sockfd,iobuffer,1500*4,0);
    if(ret<=0)
    {
        printf("client send error\n");
    }
    close(sockfd);
    free(iobuffer);
#endif
	printf("send file success!\n");
	return 0;
}
