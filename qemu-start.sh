#!/bin/sh
# Created by Philip "5n4k3" Simonson.

if [ $# -eq 2 ]
then
	if [ "$1" = "-hda" ]
	then
		sudo -E qemu-system-x86_64 -hda $2 -m 8192 -bios /usr/share/qemu/bios.bin
	elif [ "$1" = "-cdrom" ]
	then
		sudo -E qemu-system-x86_64 -cdrom $2 -m 8192 -bios /usr/share/qemu/bios.bin
	else
		sudo -E qemu-system-x86_64 -hda $1 -cdrom $2 -m 8192 -bios /usr/share/qemu/bios.bin
	fi
elif [ $# -eq 3 ]
then
	sudo -E qemu-system-x86_64 -hda $1 -cdrom $2 -boot $3 -m 8192 -bios /usr/share/qemu/bios.bin
else
	echo "Usage: $0 [[-hda or -cdrom] [harddisk-image]] or [[harkdisk-image] [cdrom] [boot]]"
fi
