#!/bin/sh 
#set -e

SEND_NAME=$1
PROJECT_ROOT="/home/xumin/tcp_source"
TEST_DIR=$PROJECT_ROOT/test
NC_DIR=$PROJECT_ROOT/nc

echo xumin|sudo -S ifconfig eth0:0 192.168.1.111
echo xumin|sudo -S ifconfig eth0:1 192.168.1.222

#open the tcp server
test $(pgrep -f receive_lo |wc -l) -ne "0"
if [ "$?" -eq 0 ];
then
    echo "restart the process receive_lo "
    killall receive_lo
    $TEST_DIR/receive_lo&
else
    echo "runing the process receive_lo "
    $TEST_DIR/receive_lo&
fi

#clean the log
rm -rf $PROJECT_ROOT/../log

#compile and insmod the nc modules
cd $NC_DIR
make > /dev/null 2>$PROJECT_ROOT/../log
if [ "$?" -ne 0 ];then echo "compile nc error,please check the log";exit 1; 
fi
echo xumin|sudo -S rmmod nc > /dev/null 2>&1
sudo insmod nc.ko

#close the tso gso set mtu
echo xumin|sudo -S ifconfig eth0 mtu 1500
sudo ethtool -K eth0 tso off
sudo ethtool -K eth0 gso off
sudo ethtool -K eth0 gro off
sudo ifconfig lo mtu 1500
sudo ethtool -K lo tso off
sudo ethtool -K lo gso off
sudo ethtool -K lo gro off

#send the packet
cd $TEST_DIR
if test -z $SEND_NAME ;then    
    SEND_NAME=bbb
fi
echo $SEND_NAME|time $TEST_DIR/send

#rommd nc modules
sudo rmmod nc


#echo ttyS0 > /sys/module/kgdboc/parameters/kgdboc
#echo "g" > /proc/sysrq-trigger
