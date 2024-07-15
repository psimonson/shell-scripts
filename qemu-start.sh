#!/bin/sh
# Created by Philip "5n4k3" Simonson.

if [ $# -eq 2 ]
then
	if [ "$1" = "-hda" ]
	then
		sudo sh -c "qemu-system-x86_64 -hda $2 -m 4096 -cpu host -enable-kvm &"
	elif [ "$1" = "-cdrom" ]
	then
		sudo sh -c "qemu-system-x86_64 -cdrom $2 -m 4096 -cpu host -enable-kvm &"
	else
		sudo sh -c "qemu-system-x86_64 -hda $1 -cdrom $2 -m 4096 -cpu host -enable-kvm &"
	fi
elif [ $# -eq 3 ]
then
	sudo sh -c "qemu-system-x86_64 -hda $1 -cdrom $2 -boot $3 -m 4096 -cpu host -enable-kvm &"
else
	echo "Usage: $0 [harkdisk-image] <cdrom>"
fi
