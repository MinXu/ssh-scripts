#!/bin/sh
#set -x

STOP_PROCESS="ecallService xletDiagService WifiSvc xmApp WicomeSCP natp  embeddedPhone sideStreamer UISpeechService rOpenNavController NaviServer henticationService iPodTagger MediaService ndr "
PROCESS="ldProxy lvic prefilter server_gx serverFake LedHMI SoundHMI DBusGateway mk3Fake"
CMC_IP="192.168.1.102"
DEST_IP="192.168.1.159"
BROADCAST_IP="192.168.1.255"
RUN_DIR="/fs/usb0"
#RUN_DIR=$(pwd)
CMD_ROOT=$RUN_DIR/v2x
TIME=$(date "+%F_%H-%M-%S")
LOG_TAG=
LOG_SERVER_GX="log_server_gx_"$TIME
LOG_LED="log_led_"$TIME
LOG_PREFILTER="log_prefilter_"$TIME
LOG_LVIC="log_lvic_"$TIME
LOG_LD="log_ldProxy_"$TIME
LOG_SOUND="log_sound_"$TIME
LOG_SERVER_FAKE="serverFake_"$TIME
FIRST_PARAM="$1"
SECOND_PARAM="nolog"
TAR="Empty"
MACHINE=`$CMD_ROOT/uname -m`

STOP(){
	slay adl >/dev/null 2>&1 
	for F in $PROCESS
	do
		P=$(pidin|grep $F|awk '{print $1}'|$CMD_ROOT/xargs)
		if [ -n "$P" ];then
			kill -9 $P >/dev/null 2>&1 
		fi
	done
}

STOP_SOME_PROCESS(){
	for F in $STOP_PROCESS
	do
		P=$(pidin|grep $F|awk '{print $1}'|$CMD_ROOT/xargs)
		if [ -n "$P" ];then
			kill -9 $P >/dev/null 2>&1 
		fi
	done
}

checklog(){
	loop=true
	i=1;
	while $loop
	do
	{
		LOG_TAG=$RUN_DIR/log/$(date "+%F")/$i
		if [ -f $LOG_TAG ];then
			i=$(($i+1))
		else
			loop=false
			mkdir -p $RUN_DIR/log/$(date "+%F")
			touch $LOG_TAG
		fi		
	}
	done
}

START_DBUS(){
	P=$(pidin|grep dbus-daemon|awk '{print $1}'|$CMD_ROOT/xargs)
	if [ -n "$P" ];then
		kill -9 $P >/dev/null 2>&1 
		sleep 1
	fi

	mkdir -p /tmp /usr/var/run/dbus
	mkdir -p $CMD_ROOT/dbus/dbus-1/session.d
	mkdir -p $CMD_ROOT/dbus/dbus-1/system.d
	mkdir -p /usr/var/lib/dbus
	export LD_LIBRARY_PATH=$RUN_DIR/lib:$LD_LIBRARY_PATH
	export PATH=$CMD_ROOT/dbus:$CMD_ROOT:$PATH
	dbus-uuidgen > /usr/var/lib/dbus/machine-id
	dbus-launch --sh-syntax --config-file=$CMD_ROOT/dbus/dbus-1/session.conf > /tmp/envars.sh  2>/dev/null
	echo "export SVCIPC_DISPATCH_PRIORITY=12;" >> /tmp/envars.sh
	. /tmp/envars.sh
	sleep 2
}

START(){

	if [ $SECOND_PARAM = "log" ];then
    		checklog
	fi

	if [ $MACHINE = "x86pc" ];then
		START_DBUS
	fi 

#	ifconfig en0 $CMC_IP up
	
	if [ $MACHINE != "x86pc" ];then
		slay adl >/dev/null 2>&1 
		sleep 1
	fi

	if [ -x $CMD_ROOT/ldProxy ];then
		if [ $SECOND_PARAM = "log" ];then
			LOG="$LOG_TAG"$LOG_LD
			echo $LOG
			D_LEVEL=7 $CMD_ROOT/ldProxy >"$LOG"  2>&1 &
		else
			D_LEVEL=4 $CMD_ROOT/ldProxy >/dev/null 2>&1 &

		fi
	fi

	if [ -x $CMD_ROOT/prefilter ];then
		if [ -e $CMD_ROOT/debug ];then
			DEBUG_F="-D 1"
		else
			DEBUG_F=
		fi
	
		if [ $SECOND_PARAM = "log" ];then
			LOG="$LOG_TAG"$LOG_PREFILTER
			echo $LOG
			D_LEVEL=5 $CMD_ROOT/prefilter -F 18100.111439 $DEBUG_F>"$LOG"  2>&1 &
		else
			D_LEVEL=4 $CMD_ROOT/prefilter -F 18100.111439 $DEBUG_F>/dev/null 2>&1 &
		fi
	fi

	if [ -x $CMD_ROOT/lvic ];then
		if [ -e $CMD_ROOT/debug ];then
			DEBUG_F="-d 1"
		else
			DEBUG_F=
		fi

		if [ $SECOND_PARAM = "log" ];then
			LOG="$LOG_TAG"$LOG_LVIC
			echo $LOG
			D_LEVEL=7 $CMD_ROOT/lvic -u $BROADCAST_IP $DEBUG_F >"$LOG"  2>&1 &
		else
			D_LEVEL=4 $CMD_ROOT/lvic -u $BROADCAST_IP $DEBUG_F >/dev/null 2>&1 &

		fi
	fi

	if [ -x $CMD_ROOT/server_gx ];then
		if [ -e $CMD_ROOT/debug ];then
			DEBUG_F="-d"
		else
			DEBUG_F=
		fi

		if [ $SECOND_PARAM = "log" ];then
			LOG="$LOG_TAG"$LOG_SERVER_GX
			echo $LOG
			D_LEVEL=5 $CMD_ROOT/server_gx $DEBUG_F > "$LOG" 2>&1 &
		else
			D_LEVEL=4 $CMD_ROOT/server_gx $DEBUG_F > /dev/null 2>&1 &
		fi
	fi

	if [ -x $CMD_ROOT/LedHMI ];then
		if [ $SECOND_PARAM = "log" ];then
			LOG="$LOG_TAG"$LOG_LED
			echo $LOG
			D_LEVEL=7 $CMD_ROOT/LedHMI > "$LOG" 2>&1 &
		else
			D_LEVEL=4 $CMD_ROOT/LedHMI > /dev/null 2>&1 &
		fi
	fi

	if [ -x $CMD_ROOT/SoundHMI ];then
		if [ $SECOND_PARAM = "log" ];then
			LOG="$LOG_TAG"$LOG_SOUND
			echo $LOG
			D_LEVEL=7 $CMD_ROOT/SoundHMI > "$LOG" 2>&1 &
		else
			D_LEVEL=4 $CMD_ROOT/SoundHMI > /dev/null 2>&1 &
		fi

		. /tmp/envars.sh
		if [ $MACHINE != "x86pc" ];then
			dbus-send --print-reply --type="method_call" --dest='com.harman.service.AudioSettings' /com/harman/service/AudioSettings com.harman.ServiceIpc.Invoke string:"setVolume" string:'{"volume":21}'
			sleep 2
			dbus-send --print-reply --type="method_call" --dest='com.harman.service.AudioSettings' /com/harman/service/AudioSettings com.harman.ServiceIpc.Invoke string:"setVolume" string:'{"volume":24}'
			cat /pps/audio/settings
		fi
	fi

	if [ -x $CMD_ROOT/DBusGateway ];then
			$CMD_ROOT/DBusGateway >/dev/null 2>&1 &
	fi

	if [ -e $CMD_ROOT/main.xml ];then
		if [ $MACHINE != "x86pc" ];then
			export FONTCONFIG_PATH=/fs/mmc0/etc/fonts
			MALLOC_ARENA_SIZE=65535 nice -n-1 adl -runtime /lib/air/runtimeSDK $CMD_ROOT/main.xml >/dev/null 2>&1 &
		fi
	fi

#	the play back log file in the /fs/usb0/log/ directory
	if [ $MACHINE = "x86pc" ];then
	    	echo "\033[2J\033[1;34m\033[1m\033[4m\033[15;1H please input the start time \033[K"
		read num
		isdigit=`echo $num| awk '{print($0~/^[-]?([0-9])+[.]?([0-9])+$/)}'`
		if [ $isdigit -eq 0 ];then
		    num="18100.111439"
		fi
		D_LEVEL=4 $CMD_ROOT/mk3Fake -F $num -u 127.0.0.1 &
		
		loop=true;
		while $loop;do
			read num
			case $num in
			"s")
			    echo "\033[1;34m\033[1m\033[4m\033[15;1H mk3Fake stop \033[K"
			    P=$(pidin|grep "mk3Fake"|awk '{print $1}'|$CMD_ROOT/xargs)
			    if [ -n "$P" ];then
				kill -TSTP $P >/dev/null 2>&1
			    fi
			;;
			"c")
			    echo "\033[1;34m\033[1m\033[4m\033[15;1H mk3Fake continue \033[K"
			    P=$(pidin|grep "mk3Fake"|awk '{print $1}'|$CMD_ROOT/xargs)
			    if [ -n "$P" ];then
				kill -CONT $P 
			    fi
			;;
			"q")
			    echo "\033[1;34m\033[1m\033[4m\033[15;1H quit debug mode \033[K"
			    loop=false
			;;
			"r")
			    echo "\033[2J\033[1;34m\033[1m\033[4m\033[15;1H reset the mk3Fake \033[K"
			    P=$(pidin|grep "mk3Fake"|awk '{print $1}'|$CMD_ROOT/xargs)
			    if [ -n "$P" ];then
				kill -9 $P >/dev/null 2>&1
			    fi

			    echo "\033[2J\033[1;34m\033[1m\033[4m\033[15;1H please input the start time \033[K"
			    read num
			    isdigit=`echo $num| awk '{print($0~/^[-]?([0-9])+[.]?([0-9])+$/)}'`
			    if [ $isdigit -eq 0 ];then
			        num="18100.111439"
			    fi
			    D_LEVEL=4 $CMD_ROOT/mk3Fake -F $num -u 127.0.0.1 &
			    ;;
		    	*)
			    echo "\033[1;34m\033[1m\033[4m\033[15;1H input error \033[K"
			    echo "\033[1;34m\033[1m\033[4m\033[16;1H mk3Fake debug mode: \033[K"
			    echo "\033[1;34m\033[1m\033[4m\033[17;5H s: stop the mk3Fake \033[K"
			    echo "\033[1;34m\033[1m\033[4m\033[18;5H c: continue the mk3Fake \033[K"
			    echo "\033[1;34m\033[1m\033[4m\033[19;5H r: reset the mk3Fake \033[K"
			    echo "\033[1;34m\033[1m\033[4m\033[20;5H q: quit the debug mode \033[K"
			;;
			esac
	    	done
		echo "\033[2J\033[0m"
		STOP
	fi

	
}

HMI(){
	if [ $SECOND_PARAM = "log" ];then
    		checklog
	fi

	if [ $MACHINE = "x86pc" ];then
		START_DBUS
	fi 

#	ifconfig en0 $CMC_IP up
	
	if [ $MACHINE != "x86pc" ];then
		slay adl >/dev/null 2>&1 
		sleep 1
	fi

	if [ -x $CMD_ROOT/serverFake ];then
		if [ $SECOND_PARAM = "log" ];then
			LOG="$LOG_TAG"$LOG_SERVER_FAKE
			echo $LOG	
			D_LEVEL=7 $CMD_ROOT/serverFake > "$LOG" 2>&1 &
		else
			D_LEVEL=4 $CMD_ROOT/serverFake > /dev/null 2>&1 &
		fi
	fi

	if [ $MACHINE != "x86pc" ];then
		if [ -x $CMD_ROOT/LedHMI ];then
			if [ $SECOND_PARAM = "log" ];then
				LOG="$LOG_TAG"$LOG_LED
				echo $LOG
				D_LEVEL=7 $CMD_ROOT/LedHMI > "$LOG" 2>&1 &
			else
				D_LEVEL=4 $CMD_ROOT/LedHMI > /dev/null 2>&1 &
			fi
		fi

		if [ -x $CMD_ROOT/SoundHMI ];then
			if [ $SECOND_PARAM = "log" ];then
				LOG="$LOG_TAG"$LOG_SOUND
				echo $LOG
				D_LEVEL=7 $CMD_ROOT/SoundHMI > "$LOG" 2>&1 &
			else
				D_LEVEL=4 $CMD_ROOT/SoundHMI > /dev/null 2>&1 &
			fi

			. /tmp/envars.sh
			dbus-send --print-reply --type="method_call" --dest='com.harman.service.AudioSettings' /com/harman/service/AudioSettings com.harman.ServiceIpc.Invoke string:"setVolume" string:'{"volume":21}'
			sleep 2
			dbus-send --print-reply --type="method_call" --dest='com.harman.service.AudioSettings' /com/harman/service/AudioSettings com.harman.ServiceIpc.Invoke string:"setVolume" string:'{"volume":24}'
			cat /pps/audio/settings

		fi
	fi

	if [ -x $CMD_ROOT/DBusGateway ];then
		$CMD_ROOT/DBusGateway >/dev/null 2>&1 &
	fi

	if [ $MACHINE != "x86pc" ];then
		if [ -e $CMD_ROOT/main.xml ];then
			export FONTCONFIG_PATH=/fs/mmc0/etc/fonts
			MALLOC_ARENA_SIZE=65535 nice -n-1 adl -runtime /lib/air/runtimeSDK $CMD_ROOT/main.xml >/dev/null 2>&1 &
		fi
	fi

}


KEY_PATH=$RUN_DIR/v2x/reference/ssh
KEY_TMP_PATH="/fs/etfs"
REMOTE_LOG_FILE="origGps_W2S.txt newGps_W2S.txt calibratedGpsOutput.txt"
REMOTE_PATH="/mnt/ubi/dbg"
LOCAL_LOG_FILE="log-bsm-input.txt log-lvic-input.txt log-lvic-output.txt log-wl-input.txt log-wl-output.txt"
LOCAL_PATH=$RUN_DIR
SSH="ssh -q -i /fs/etfs/id_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
SCP="scp -q -p -i /fs/etfs/id_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
REMOTE_HOME="/.ssh"

export SSH SCP

SETUP_SSH(){
	if [ -e $KEY_PATH/id_rsa ] && [ -e $KEY_PATH/id_rsa.pub ];then
		echo "find the ssh key!!"
	else
		echo "ssh keygen in"$KEY_PATH
		if [ -x $KEY_PATH/ssh-keygen ];then
			$KEY_PATH/ssh-keygen -b 1024 -t rsa -f $KEY_PATH/id_rsa -N ""
		else
			echo "ssh keygen failed, not find the keygen in"$KEY_PATH
			exit -1
		fi
	fi
	

	cp $KEY_PATH/id_rsa  $KEY_TMP_PATH
	chmod 0600 $KEY_TMP_PATH/id_rsa
#	scp $SSH_FLAG $RUN_DIR/v2x/reference/ssh/id_rsa.pub user@$DEST_IP:/home/user/.ssh/
#	ssh $SSH_FLAG -tt user@$DEST_IP 'sudo -E mv /home/user/.ssh /'
	$SSH root@$DEST_IP " mkdir -p ${REMOTE_HOME} && cat > ${REMOTE_HOME}/authorized_keys "<$KEY_PATH/id_rsa.pub
}

START_SSH_AGENT()
{
	if [ -x $KEY_PATH/ssh-agent ] && [ -e $KEY_PATH/id_rsa ];then
		$KEY_PATH/ssh-agent $SHELL
		$KEY_PATH/ssh-add $KEY_PATH/id_rsa
	fi
}

LOG_FUNC(){
	mkdir -p $LOG_PATH/$LOG_NAME
	$SSH root@$DEST_IP 'sync'
	for F in $REMOTE_LOG_FILE
	do
		echo "************$F***************"
		$SCP root@$DEST_IP:$REMOTE_PATH/$F $LOG_PATH/$LOG_NAME/
	done

	sync
	for F in $LOCAL_LOG_FILE
	do
		echo "************$F***************"
		cp $LOCAL_PATH/$F $LOG_PATH/$LOG_NAME/
	done
	rm -rf $KEY_TMP_PATH/id_rsa
}

LOG_BAKEUP_FUNC(){
	mkdir -p $LOG_PATH/$LOG_NAME
	$SSH root@$DEST_IP 'sync'
	for F in $REMOTE_LOG_FILE
	do
		echo "************$F***************"
		$SCP root@$DEST_IP:$REMOTE_PATH/${F}_bak $LOG_PATH/$LOG_NAME/
	done

	sync
	for F in $LOCAL_LOG_FILE
	do
		echo "************$F***************"
		cp $LOCAL_PATH/${F}_bak $LOG_PATH/$LOG_NAME/
	done
	rm -rf $KEY_TMP_PATH/id_rsa
}

UPGRADE_MK3()
{
	echo "kill bsm-shell on mk3 and update it from " $RUN_DIR
	if [ -e $KEY_TMP_PATH/id_rsa ];then
		$SSH root@$DEST_IP 'killall -9 bsm-shell'
	else
		echo "upgrade mk3 failed, not find /fs/etfs/id_rsa"
	fi
	
	if [ -e $LOCAL_PATH/bsm-shell ];then
		$SCP $LOCAL_PATH/bsm-shell root@$DEST_IP:$REMOTE_PATH
	else
		echo "upgrade mk3 failed, not find the "$LOCAL_PATH/bsm-shell	
	fi
}

STOP_MK3()
{
	echo "stoping bsm-shell on mk3"
	if [ -e $KEY_TMP_PATH/id_rsa ];then
		$SSH root@$DEST_IP 'killall -9 bsm-shell'
	else
		echo "stop mk3 failed, not find "$KEY_TMP_PATH/id_rsa
	fi
}

START_MK3()
{
	echo "starting bsm-shell on mk3"
	if [ -e $KEY_TMP_PATH/id_rsa ];then
		$SSH root@$DEST_IP "[ -e $REMOTE_PATH/test/start.sh ] && source /etc/profile && nohup $REMOTE_PATH/test/start.sh>/dev/null 2>&1" 
		$SSH root@$DEST_IP "[ -e $REMOTE_PATH/loacal_test/start.sh ] && source /etc/profile && nohup $REMOTE_PATH/loacal_test/start.sh>/dev/null 2>&1"
	else
		echo "start mk3 failed, not find "$KEY_TMP_PATH/id_rsa
	fi
	rm -rf $KEY_TMP_PATH/id_rsa
}

HELP(){
	echo "commond for v2x: start.sh [start|stop|restart|hmi|get|agent] [cmc|mk3|both] [nolog]"
	echo "	start: start the app"
	echo "	stop:	stop the app"
	echo "		nolog:	not log the run statusing"
	echo "	restart: stop and start the app"
	echo "  	cmc: restart the cmc v2x"
	echo "  	mk3: restart the mk3 bsm-shell"
	echo "  	both: restart the mk3 bsm-shell and cmc v2x"
	echo "			nolog:	not log the run statusing"
	echo "	hmi:	test the sound ,led, screen"
	echo "  get:	collect the log files to usb disk"
	echo "		fist parameter: archive path"
	echo "		second parameter: file name"
	echo "		sh start.sh get log_path log_name"
	echo "  getbak:	collect the log files backup to usb disk"
	echo "		fist parameter: archive path"
	echo "		second parameter: file name"
	echo "		sh start.sh getbak log_path log_name"
	echo "  upgrade: update the bsm-shell on mk3"
	echo "  agent: start the ssh agent in the new shell"

}

if [ $# -gt 1 ];then
	if [ $2 = "log" ];then
		SECOND_PARAM="log"
	fi
fi

if [ $MACHINE = "x86pc" ];then
	CMC_IP=`ifconfig en0|awk 'END{print $2}'`
	DEST_IP=`ifconfig en0|awk 'END{print $2}'`
fi 
	BROADCAST_IP=$DEST_IP


if [ $FIRST_PARAM = "stop" ];then
	STOP
elif [ $FIRST_PARAM = "start" ];then
	START
	STOP_SOME_PROCESS
elif [ $FIRST_PARAM = "restart" ];then
	[ $# -gt 1 ] && TAR=$2
	case $TAR in
	"mk3")
		echo "restart the mk3"
		SETUP_SSH
		STOP_MK3
		START_MK3
	;;
	"both")
		[ $# -gt 2 ] && SECOND_PARAM=$3
		echo "restart the mk3 and cmc"
		SETUP_SSH
		STOP_MK3
		STOP
		START_MK3
		START
	;;
	"cmc")
		echo "restart the cmc"
		[ $# -gt 2 ] && SECOND_PARAM=$3
		STOP
		START
	;;
	*)
		echo "restart the default cmc"
		[ $# -gt 1 ] && [ $2 = "nolog" ] && SECOND_PARAM=$2
		[ $# -gt 1 ] && [ $2 = "log" ] && SECOND_PARAM=$2
		STOP
		START
	;;
	esac
elif [ $FIRST_PARAM = "hmi" ];then
	HMI
elif [ $FIRST_PARAM = "get" ];then
	if [ $# -gt 2 ];then
		LOG_PATH=$RUN_DIR/$2
		LOG_NAME=$3
		echo $LOG_PATH
		echo $LOG_NAME
		SETUP_SSH
		LOG_FUNC
	else
		echo "collect the log need more parameter"
		HELP 
	fi
elif [ $FIRST_PARAM = "getbak" ];then
	if [ $# -gt 2 ];then
		LOG_PATH=$RUN_DIR/$2
		LOG_NAME=$3
		echo $LOG_PATH
		echo $LOG_NAME
		SETUP_SSH
		LOG_BAKEUP_FUNC
	else
		echo "collect the log need more parameter"
		HELP 
	fi
elif [ $FIRST_PARAM = "upgrade" ];then
	SETUP_SSH
	UPGRADE_MK3
	START_MK3
elif [ $FIRST_PARAM = "agent" ];then
	START_SSH_AGENT
else
     HELP   
fi 
