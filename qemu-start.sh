#!/bin/sh
# Created by Philip "5n4k3" Simonson.

if [ $# -eq 2 ]
then
	if [ "$1" = "-hda" ]
	then
		sudo -E qemu-system-x86_64 -hda $2 -m 8192
	elif [ "$1" = "-cdrom" ]
	then
		sudo -E qemu-system-x86_64 -cdrom $2 -m 8192
	else
		sudo -E qemu-system-x86_64 -hda $1 -cdrom $2 -m 8192
	fi
elif [ $# -eq 3 ]
then
	sudo -E qemu-system-x86_64 -hda $1 -cdrom $2 -boot $3 -m 8192
else
	echo "Usage: $0 [harkdisk-image] [cdrom] [boot]"
fi
