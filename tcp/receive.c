#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <poll.h>
#include <netdb.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <net/if.h>
#include <sys/ioctl.h>
#include <time.h>

#define LISTENQ					   5
#define FILENAMESIZE		         128
#define BUFSIZE                        150000
#define SVC_INTERFACE                      "eth0:0"
#define SVC_PORT                           1234
#define RECVTIMEOUT                 15*1000*1000//ms
//#define HOST_ADDR                   "10.80.104.139"

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


int msgDispatch(int connfd, struct sockaddr_in cliaddr)
{
		char profilename[FILENAMESIZE];
		struct pollfd fds[1];
		char *iobuffer;
		int profilefd;
		int ret,length,offset,count;
		
		fds[0].fd = connfd;
		fds[0].events = POLLIN|POLLRDHUP;
		ret = poll(fds, sizeof(fds)/sizeof(fds[0]), RECVTIMEOUT);
		if(-1 == ret)
		{
			perror("poll failed: ");
			return -2;
		}
		else if(0 == ret)
		{
			perror("poll timeout: ");
			return 0;
		}
		else
		{
#if 0
            /*lo can`t used the POLLRDHUP*/
            if(fds[ret-1].revents & POLLRDHUP)
            {
				perror("poll socket has been closed: ");
				return -3;
			}
			else if(fds[ret-1].revents & POLLIN)
#endif
            if(fds[ret-1].revents & POLLIN)
			{
				fprintf(stdout,"poll socket has inputing data\n");
			}
			else
			{
				perror("poll revents error: ");
				return -4;
			}
		}

		iobuffer = malloc(BUFSIZE);
		if(!iobuffer)
		{
			perror("malloc iobuffer failed: ");
			return -5;
		}
		time_t clock = time(NULL);
        struct tm *tm   = localtime(&clock);
		snprintf(profilename, sizeof(profilename)-1 ,"/home/xumin/%s-%d_%d-%d-%d_%02d:%02d:%02d", 
                inet_ntoa(cliaddr.sin_addr), 
                ntohs(cliaddr.sin_port),
                tm->tm_year+1900,
                tm->tm_mon,
                tm->tm_mday,
                tm->tm_hour,
                tm->tm_min,
                tm->tm_sec);
                profilename[strlen(profilename)] = '\0';
                if((profilefd = open(profilename, O_WRONLY|O_CREAT|O_TRUNC, S_IWUSR|S_IRUSR))==-1)
                {
			free(iobuffer);
                        perror("profile open failed: ");
                        return -6;
                }
                lseek(profilefd, 0L, SEEK_SET);		

		count = 0;
		while((length = recv(connfd, iobuffer, BUFSIZE,0))>0)
		{
			if(0 >= length)
			{
				free(iobuffer);
				close(profilefd);
				perror("recv faild: ");
				return -7;
			}
			else 
			{   offset = 0;
				do{
					ret = write(profilefd, &iobuffer[offset], length);
					if(0 < ret)
					{
						length -= ret;
						offset += ret;
                        count  += ret;
					}
					else
					{
						free(iobuffer);
						close(profilefd);
						perror("write profile faild: ");
						return -8;
					}
				}
				while(length);
			}
		}
		free(iobuffer);
		close(profilefd);
		return	count;
}

int main()
{
	pid_t childpid;
	int listenfd, connfd;
	struct sockaddr_in svcaddr, cliaddr;
	int ret;
    char svc_addr[20];

    get_nic_info(SVC_INTERFACE);
	printf("IP:%s NETMASK:%s MAC:%s\n", sys_nic_ip, sys_nic_mask, sys_nic_mac);
	snprintf(svc_addr, sizeof(svc_addr), "%s", sys_nic_ip);

	listenfd = socket(AF_INET, SOCK_STREAM,0);
	if(listenfd < 0)
	{
		perror("socket created failed: ");
		return -1;
	}

	svcaddr.sin_family = AF_INET;
	svcaddr.sin_port = htons(SVC_PORT);
//	svcaddr.sin_addr.s_addr = htonl(INADDR_ANY);
	if(inet_aton(svc_addr,&svcaddr.sin_addr)<0)
	{
		close(listenfd);
		printf("inet_aton error.\n");
		return -2;
	}

    int opt = SO_REUSEADDR;
    setsockopt(listenfd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

	if(bind(listenfd, (struct sockaddr *)&svcaddr, sizeof(svcaddr))<0)
	{
		perror("bind failed: ");
		return -2;
	}
	fprintf(stdout, "listening....\n");
	listen(listenfd, LISTENQ);
	
	while(1)
	{
		socklen_t length;
		length = sizeof(cliaddr);
          /*TO DO:check for exit the loop*/
		connfd = accept(listenfd,(struct sockaddr *)&cliaddr, &length);
		childpid = fork();
		if(0 == childpid)
		{
			fprintf(stdout, "connect from %s,port %d \n", inet_ntoa(cliaddr.sin_addr), ntohs(cliaddr.sin_port));
			ret = msgDispatch(connfd, cliaddr);
			if(ret < 0)
			{
				fprintf(stderr, "msgDispatch failed: %d\n",ret);
			}
			else if(ret == 0)
			{
				fprintf(stderr, "msgDispatch timeout: \n");
			}
			else
				fprintf(stdout, "total receive bytes %d\n", ret);

			close(connfd);
		}
		close(connfd);
	}
	close(listenfd);
}
