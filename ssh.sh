#!/bin/bash
#set -e

USR_NAME="xumin"

remote_ip="10.80.104.125"
remote_path="/home/$USR_NAME/tcp/nc"
local_path="/home/$USR_NAME/tcp_source/nc"
remote_vod_path="/home/$USR_NAME/www"
KEY_PATH="/home/$USR_NAME/.ssh"
option="NULL"

SSH="ssh -q    -i $KEY_PATH/id_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
SCP="scp -q -p -r -i $KEY_PATH/id_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"

if [ $# -ge 1 ];then
    option=$1
fi

HELP()
{
	echo "ssh.sh gen|ls|get|put|run|agent|mount"
}

if [ $option = "gen" ];then
	ssh-keygen -b 1024 -t rsa -f $KEY_PATH/id_rsa -N ""
#	ssh -q    -i $KEY_PATH/id_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $USR_NAME@$remote_ip " mkdir -p ${KEY_PATH} && cat > ${KEY_PATH}/authorized_keys "<$KEY_PATH/id_rsa.pub
	ssh-copy-id -i $KEY_PATH/id_rsa.pub $USR_NAME@$remote_ip
elif [ $option = "ls" ];then
	$SSH $USR_NAME@$remote_ip "ls -l $remote_path"
elif [ $option = "get" ];then
        $SCP $USR_NAME@$remote_ip:$remote_path/* $local_path
elif [ $option = "put" ];then
        $SCP $local_path/* $USR_NAME@$remote_ip:$remote_path
elif [ $option = "run" ];then
	$SSH $USR_NAME@$remote_ip "[ -e $remote_vod_path/vlc.sh ] && source /etc/profile && nohup $remote_vod_path/vlc.sh server http" 
elif [ $option = "agent" ];then
	ssh-agent $SHELL
	ssh-add $KEY_PATH/id_rsa
elif [ $option = "mount" ];then
	sshfs $USR_NAME@$remote_ip:/home/$USR_NAME/www /home/$USR_NAME/www
else
    HELP
fi






