#!/bin/sh
#set -x
src_ip="10.80.104.125"
dst_ip="10.80.104.125"

darwin_rtsp_port=7070
apache_port=9090
vlc_port=8989

role=$1
option=
HELP()
{
	echo "sh vlc.sh server/client [rtsp/rtp/udp/http/darwin/apache]"
}

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
		vlc -vvv qqq.avi --sout  "#transcode{vcodec=h264,vb=800,scale=1,acodec=mpga,ab=128,channels=2,samplerate=44100}:std{access=udp{ttl=10},mux=ts,dst=$dst_ip:$vlc_port}"
	elif [ $option = "rtp" ];then
		#RTP
		vlc -vvv qqq.avi --sout "#transcode{vcodec=h264,vb=0,scale=0,acodec=mpga,ab=128,channels=2,samplerate=44100}:rtp{dst=$dst_ip,port=$vlc_port,mux=ts,ttl=10}"
	elif [ $option = "http" ];then
		#HTTP
		vlc -vvv qqq.avi --sout "#transcode{vcodec=h264,vb=0,scale=0,acodec=mpga,ab=128,channels=2,samplerate=44100}:http{mux=ffmpeg{mux=flv},dst=:$vlc_port/test}"
	elif [ $option = "audio" ];then
		#AUDIO
		vlc -vvv mmm.mp3 --sout "#standard{access=http,mux=ogg,dst=$src_ip:$vlc_port}"
	else
		vlc -vvv ddd.mp4 --sout "#transcode{vcodec=mp4v,acodec=mpga,vb=800,ab=128}:standard{access=http,mux=ogg,dst=$src_ip:$vlc_port}"
	fi
elif [ $role = "client" ];then
	#client
	if [ $option = "rtsp" ];then
		#RSTP
		vlc rtsp://$dst_ip:$vlc_port/test  --rtsp-tcp --network-caching=300
	elif [ $option = "udp" ];then
	    #UDP
		vlc udp://@:$vlc_port
	elif [ $option = "rtp" ];then
	    #RTP
		vlc rtp://@:$vlc_port
	elif [ $option = "http" ];then
	    #HTTP
		vlc http://$dst_ip:$vlc_port/test
	elif [ $option = "darwin" ];then
		#Darwin Streaming Svr
		vlc rtsp://$dst_ip:$darwin_rtsp_port/ccc.sdp --rtsp-tcp --network-caching=300
	elif [ $option = "apache" ];then
	    #Apache Svr
		vlc http://$dst_ip:$apache_port/ddd.mp4 --network-caching=300
	else
		vlc http://$dst_ip:$vlc_port --network-caching=300
	fi
else
	HELP
fi
