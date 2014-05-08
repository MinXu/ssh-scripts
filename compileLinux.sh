#!/bin/bash set -e
#compile the linux kernel and trigger the debug mode


option="NULL"

if [ $# -ge 1 ];then
	option=$1
fi

HELP()
{
	echo "compileLinux [deb|image|debug]"
}

if [ $option = "image" ];then
	make bzImage;make modules;make modules_install;make install;mkinitramfs $(uname -r) –o /boot/initrd.img-$(uname -r);update-grub2;
elif [ $option = "deb" ];then
# instll the comple tools :make-kpkg:
#sudo apt-get install kernel-package
	sudo time fakeroot make-kpkg --initrd --append-to-version=-tweak kernel-image kernel-headers
	echo xumin |sudo -S dpkg -i linux-image-3.2.35-tweak_3.2.35-tweak-10.00.Custom_i386.deb
	echo xumin |sudo -S dpkg -i linux-headers-3.2.35-tweak_3.2.35-tweak-10.00.Custom_i386.deb
elif [ $option = "debug" ];then
	echo ttyS0 > /sys/module/kgdboc/parameters/kgdboc
	echo "g" > /proc/sysrq-trigger
elif [ $option = "help" ];then
	HELP
else
	make bzImage; make install;
fi

