if [ "$#" = "2" ]
then
	sudo -E qemu-system-x86_64 -boot menu=on -cdrom "$1" -m 8G -device qemu-xhci,id=xhci -device usb-host,hostdevice=/dev/bus/usb/${2}
else
	echo "Usage: $0 </path/to/cdrom.iso> <bus/usb>"
fi
