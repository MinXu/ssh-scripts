#!/bin/sh
#set -x

fs-nfs3 10.80.104.100:/home/xumin/cmc/x86 /fs/usb0 
ln -sf /fs/usb0/bin /fs/usb0/v2x
ln -sf /fs/usb0/v2x/start.sh /fs/usb0/start.sh

