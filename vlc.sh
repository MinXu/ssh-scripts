#!/bin/sh
#set -x
ip_src="10.80.104.125"
ip_dst="10.80.104.125"
mac_0="00:0c:29:e5:63:36"
mac_1="3c:97:0e:11:3a:48"
darwin_rtsp_port=7070
apache_port=9090
vlc_port=8989

role="NULL"
option="NULL"

HELP()
{
	echo "sh vlc.sh server/client/mount [rtsp/rtp/udp/http/darwin/apache]"
}

FIND_PEER()
{
    ip_addr=$(arp -n | grep $mac_0)
	if [ $? -eq 0 ];then
		ip_addr=$(echo $ip_addr | awk '{print $1}')
	else
	    ip_addr=$(arp -n | grep $mac_1)	
		if [ $? -eq 0 ];then
			ip_addr=$(echo $ip_addr | awk '{print $1}')
	    else
			echo "	get the remote ip failed!!!";
			return 1;
	    fi
	fi
}

FIND_PEER
if [ $? -eq 1 ];then
    echo "	try again!!!"
	IPV4_RANGE=$(ip -4 addr show eth0| grep global | awk '{print $2}')
	echo xumin|sudo -S ip neigh flush all;
	nmap -sP $IPV4_RANGE 2>&1 > /dev/null;
	FIND_PEER
	if [ $? -eq 1 ];then
	    echo "exit $0 Process ..."&&exit 1;
	fi
fi

ip_dst=$ip_addr
ip_src=$(ip -4 addr show eth0| grep global | awk '{print $2}'|cut -d "/" -f 1)

echo $ip_dst
echo $ip_src

if [ $# -ge 1 ];then
	role=$1
fi

if [ $# -ge 2 ];then
	option=$2
fi

if [ $role = "server" ];then
	# server
	if [ $option = "rtsp" ];then
		#RTSP
		vlc -vvv  qqq.avi --sout "#transcode{vcodec=h264,vb=800,scale=1,acodec=mpga,ab=128,channels=2,samplerate=44100}:rtp{sdp=rtsp://:$vlc_port/test}"
	elif [ $option = "udp" ];then
		#UDP
		vlc -vvv qqq.avi --sout  "#transcode{vcodec=h264,vb=800,scale=1,acodec=mpga,ab=128,channels=2,samplerate=44100}:std{access=udp{ttl=10},mux=ts,dst=$ip_dst:$vlc_port}"
	elif [ $option = "rtp" ];then
		#RTP
		vlc -vvv qqq.avi --sout "#transcode{vcodec=h264,vb=0,scale=0,acodec=mpga,ab=128,channels=2,samplerate=44100}:rtp{dst=$ip_dst,port=$vlc_port,mux=ts,ttl=10}"
	elif [ $option = "http" ];then
		#HTTP
		vlc -vvv aaa.mp4 --sout "#transcode{vcodec=h264,vb=0,scale=0,acodec=mpga,ab=128,channels=2,samplerate=44100}:http{mux=ffmpeg{mux=flv},dst=:$vlc_port/test}"
	elif [ $option = "audio" ];then
		#AUDIO
		vlc -vvv mmm.mp3 --sout "#standard{access=http,mux=ogg,dst=$ip_src:$vlc_port}"
	else
		vlc -vvv ddd.mp4 --sout "#transcode{vcodec=mp4v,acodec=mpga,vb=800,ab=128}:standard{access=http,mux=ogg,dst=$ip_src:$vlc_port}"
	fi
elif [ $role = "client" ];then
	#client
	if [ $option = "rtsp" ];then
		#RSTP
		vlc rtsp://$ip_dst:$vlc_port/test  --rtsp-tcp --network-caching=300
	elif [ $option = "udp" ];then
	    #UDP
		vlc udp://@:$vlc_port
	elif [ $option = "rtp" ];then
	    #RTP
		vlc rtp://@:$vlc_port
	elif [ $option = "http" ];then
	    #HTTP
		vlc http://$ip_dst:$vlc_port/test
	elif [ $option = "darwin" ];then
		#Darwin Streaming Svr
		vlc rtsp://$ip_dst:$darwin_rtsp_port/ccc.sdp --rtsp-tcp --network-caching=300
	elif [ $option = "apache" ];then
	    #Apache Svr
		vlc http://$ip_dst:$apache_port/ddd.mp4 --network-caching=300
	else
		vlc http://$ip_dst:$vlc_port --network-caching=300
	fi
elif [ $role = "mount" ];then
    sshfs xumin@$ip_dst:/home/xumin/www /home/xumin/www
else
	HELP
fi
