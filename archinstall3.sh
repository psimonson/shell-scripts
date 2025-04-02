#!/bin/sh
# Created by Philip "5n4k3" Simonson.
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# This script will set up an Arch installation with a 300 MB /boot partition
# and an encrypted LVM partition with swap and / inside.  It also installs
# and configures systemd as the init system (removing sysvinit).
#
# You should read through this script before running it in case you want to
# make any modifications, in particular, the variables just below, and the
# following functions:
#
#    partition_drive - Customize to change partition sizes (/boot vs LVM)
#    setup_lvm - Customize for partitions inside LVM
#    install_packages - Customize packages installed in base system
#                       (desktop environment, etc.)
#    install_aur_packages - More packages after packer (AUR helper) is
#                           installed
#    set_netcfg - Preload netcfg profiles

## CONFIGURE THESE VARIABLES
## ALSO LOOK AT THE install_packages FUNCTION TO SEE WHAT IS ACTUALLY INSTALLED

# NVMe drive or not.
NVME='TRUE'

# Drive to install to.
DRIVE=''
if [ -n "$NVME" ]
then
	DRIVE='/dev/nvme0n1'
else
	DRIVE='/dev/sda'
fi

# Hostname of the installed machine.
HOSTNAME='localhost'

# Encrypt everything (except /boot).  Leave blank to disable.
ENCRYPT_DRIVE='TRUE'

# Passphrase used to encrypt the drive (leave blank to be prompted).
DRIVE_PASSPHRASE='change'

# Root password (leave blank to be prompted).
ROOT_PASSWORD='change'

# Main user to create (by default, added to wheel group, and others).
USER_NAME='change'

# The main user's password (leave blank to be prompted).
USER_PASSWORD='change'

# System timezone.
TIMEZONE='America/New_York'

# Have /tmp on a tmpfs or not.  Leave blank to disable.
# Only leave this blank on systems with very little RAM.
TMP_ON_TMPFS='TRUE'

# AMD or Intel processor
PROCTYPE='Intel' # Intel or AMD

KEYMAP='us'
#KEYMAP='dvorak'

# Choose your video driver
# For Intel
#VIDEO_DRIVER="i915"
# For nVidia
#VIDEO_DRIVER="nouveau"
# For nVidia Proprietary
VIDEO_DRIVER="nvidia"
# For ATI
#VIDEO_DRIVER="radeon"
# For AMDGPU
#VIDEO_DRIVER="amdgpu"
# For generic stuff
#VIDEO_DRIVER="vesa"

# Wireless device, leave blank to not use wireless and use DHCP instead.
WIRELESS_DEVICE="wlan0"
# For tc4200's
#WIRELESS_DEVICE="eth1"

setup() {
    local boot_dev=""
    local lvm_dev=""

    if [ -n "$NVME" ]
    then
	    boot_dev="$DRIVE"p1
	    lvm_dev="$DRIVE"p2
    else
	    boot_dev="$DRIVE"1
	    lvm_dev="$DRIVE"2
    fi

    #echo 'Creating partitions'
    #partition_drive "$DRIVE"

    if [ -n "$ENCRYPT_DRIVE" ]
    then
        local lvm_part="/dev/mapper/lvm"

        if [ -z "$DRIVE_PASSPHRASE" ]
        then
            echo 'Enter a passphrase to encrypt the disk:'
            stty -echo
            read DRIVE_PASSPHRASE
            stty echo
        fi

        echo 'Encrypting partition'
        encrypt_drive "$lvm_dev" "$DRIVE_PASSPHRASE" lvm

    else
        local lvm_part="$lvm_dev"
    fi

    echo 'Setting up LVM'
    setup_lvm "$lvm_part" vg00

    echo 'Formatting filesystems'
    format_filesystems

    echo 'Mounting filesystems'
    mount_filesystems

    echo 'Installing base system'
    install_base

    echo 'Chrooting into installed system to continue setup...'
    cp $0 /mnt/setup.sh
    arch-chroot /mnt ./setup.sh chroot

    if [ -f /mnt/setup.sh ]
    then
        echo 'ERROR: Something failed inside the chroot, not unmounting filesystems so you can investigate.'
        echo 'Make sure you unmount everything before you try to run this script again.'
    else
        echo 'Unmounting filesystems'
        unmount_filesystems
        echo 'Done! Reboot system.'
    fi
}

configure() {
    echo 'Redoing pacman.conf'
    sed -i '90s/\#//' /etc/pacman.conf
    sed -i '91s/\#//' /etc/pacman.conf

    echo 'Installing additional packages'
    install_packages

    echo 'Setting hostname'
    set_hostname "$HOSTNAME"

    echo 'Setting timezone'
    set_timezone "$TIMEZONE"

    echo 'Setting locale'
    set_locale

    echo 'Setting console keymap'
    set_keymap

    echo 'Setting hosts file'
    set_hosts "$HOSTNAME"

    echo 'Setting fstab'
    set_fstab

    echo 'Setting initial modules to load'
    set_modules_load

    echo 'Configuring initial ramdisk'
    set_initcpio

    echo 'Setting initial daemons'
    set_daemons "$TMP_ON_TMPFS"

    echo 'Configuring bootloader'
    set_syslinux

    echo 'Configuring sudo'
    set_sudoers

    echo 'Configuring slim'
    set_slim

    if [ -z "$ROOT_PASSWORD" ]
    then
        echo 'Enter the root password:'
        stty -echo
        read ROOT_PASSWORD
        stty echo
    fi
    echo 'Setting root password'
    set_root_password "$ROOT_PASSWORD"

    if [ -z "$USER_PASSWORD" ]
    then
        echo "Enter the password for user $USER_NAME"
        stty -echo
        read USER_PASSWORD
        stty echo
    fi

    echo 'Creating initial user'
    create_user "$USER_NAME" "$USER_PASSWORD"

    echo 'Installing pikaur'
    install_packer

    echo 'Clearing package tarballs'
    clean_packages

    echo 'Updating pkgfile database'
    update_pkgfile

    echo 'Building locate database'
    update_locate

    rm /setup.sh
}

partition_drive() {
    local dev="$1"; shift

    # 100 MB /boot partition, everything else under LVM
    parted -s "$dev" \
        mklabel gpt \
	mkpart primary fat32 1 2G \
        mkpart primary ext2 2G 100% \
        set 1 esp on \
        set 2 LVM on
}

encrypt_drive() {
    local dev="$1"; shift
    local passphrase="$1"; shift
    local name="$1"; shift

    echo -en "$passphrase" | cryptsetup -c aes-xts-plain -y -s 512 luksFormat "$dev"
    echo -en "$passphrase" | cryptsetup luksOpen "$dev" lvm
}

setup_lvm() {
    local partition="$1"; shift
    local volgroup="$1"; shift

    pvcreate "$partition"
    vgcreate "$volgroup" "$partition"

    # Create a 1GB swap partition
    lvcreate -C y -L 32G "$volgroup" -n swap

    # Use the rest of the space for root
    lvcreate -l '+100%FREE' "$volgroup" -n root

    # Enable the new volumes
    vgchange -ay
}

format_filesystems() {
    local boot_dev=""

    if [ -n "$NVME" ]
    then
	    boot_dev="$DRIVE"p1
    else
	    boot_dev="$DRIVE"1
    fi

    mkfs.fat -F 32 "$boot_dev"
    mkfs.ext4 -L root /dev/vg00/root
    mkswap /dev/vg00/swap
}

mount_filesystems() {
    local boot_dev=""

    if [ -n "$NVME" ]
    then
	    boot_dev="$DRIVE"p1
    else
	    boot_dev="$DRIVE"1
    fi

    mount /dev/vg00/root /mnt
    mkdir /mnt/boot
    mount "$boot_dev" /mnt/boot
    swapon /dev/vg00/swap
}

install_base() {
    echo 'Server = http://mirrors.kernel.org/archlinux/$repo/os/$arch' >> /etc/pacman.d/mirrorlist

    pacstrap /mnt base base-devel linux linux-headers linux-firmware wireless_tools iwd wpa_supplicant networkmanager network-manager-applet efibootmgr
}

unmount_filesystems() {
    umount /mnt/boot
    umount /mnt
    swapoff /dev/vg00/swap
    vgchange -an
    if [ -n "$ENCRYPT_DRIVE" ]
    then
        cryptsetup luksClose lvm
    fi
}

install_packages() {
    local packages=''

    # General utilities/libraries
    packages+=' alsa-utils aspell-en firefox cpupower gvim mlocate net-tools ntp openssh p7zip pkgfile powertop python rfkill rsync sudo unrar unzip wget zip systemd-sysvcompat zsh grml-zsh-config thin-provisioning-tools lvm2 gdb valgrind strace debuginfod pulseaudio pulseaudio-alsa pavucontrol plymouth'

    # Development packages
    packages+=' autoconf automake libtool make cmake gdb git mercurial subversion tcpdump valgrind freetype2 libx11 libxft libxinerama webkit2gtk gcr glib2'

    # Netcfg
    if [ -n "$WIRELESS_DEVICE" ]
    then
        packages+=' dialog iw'
    fi

    # SDL 1.2 stuff
    packages+=' sdl12-compat sdl_mixer sdl_image sdl_ttf sdl_net'

    # SDL 2.0 stuff
    packages+=' sdl2 sdl2_image sdl2_mixer sdl2_ttf sdl2_net'

    # Misc programs
    packages+=' mplayer vlc gparted dosfstools ntfsprogs discord blender gimp steam mpv imagemagick w3m lynx galculator gnome-multi-writer bluez bluez-tools bluez-utils blueman xclip pt2-clone'

    # Xserver
    packages+=' xorg-apps xorg-server xorg-xinit mate mate-extra'

    # Login manager and window manager
    packages+=' xdm-archlinux'

    # Fonts
    packages+=' ttf-dejavu ttf-liberation'

    # On AMD or Intel processors
    if [ "$PROCTYPE" = "AMD" ]
    then
	    packages+=' amd-ucode'
    elif [ "$PROCTYPE" = "Intel" ]
    then
	    packages+=' intel-ucode'
    else
	    echo 'Processor type not available...'
	    exit 1
    fi

    # For laptops
    packages+=' xf86-input-synaptics'

    # Extra packages for tc4200 tablet
    #packages+=' ipw2200-fw xf86-input-wacom'

    if [ "$VIDEO_DRIVER" = "i915" ]
    then
        packages+=' xf86-video-intel libva-intel-driver'
    elif [ "$VIDEO_DRIVER" = "nouveau" ]
    then
        packages+=' xf86-video-nouveau'
    elif [ "$VIDEO_DRIVER" = "nvidia" ]
    then
	packages+=' nvidia nvidia-utils lib32-nvidia-utils opencl-nvidia nvidia-settings vulkan-icd-loader lib32-vulkan-icd-loader vulkan-headers vulkan-tools'
    elif [ "$VIDEO_DRIVER" = "vbox" ]
    then
	packages+=' virtualbox-guest-additions'
    elif [ "$VIDEO_DRIVER" = "radeon" ]
    then
        packages+=' xf86-video-ati'
    elif [ "$VIDEO_DRIVER" = "amdgpu" ]
    then
	packages+=' xf86-video-amdgpu vulkan-icd-loader lib32-vulkan-icd-loader vulkan-headers vulkan-tools'
    elif [ "$VIDEO_DRIVER" = "vesa" ]
    then
        packages+=' xf86-video-vesa'
    fi

    pacman -Sy --needed --noconfirm $packages
}

install_dwm() {
    if [ ! -x "/root/src" ]
    then
        mkdir -p /root/src
        cd /root/src
        git clone https://git.suckless.org/dwm
        git clone https://git.suckless.org/st
        git clone https://git.suckless.org/surf
        git clone https://git.suckless.org/dmenu
        make PREFIX=/usr -C dwm clean all install
        make PREFIX=/usr -C st clean all install
        make PREFIX=/usr -C surf clean all install
        make PREFIX=/usr -C dmenu clean all install
        cd /root
    else
	echo 'Source directory already exists.'
    fi
}

install_packer() {
    cat > /home/$USER_NAME/pikaur.sh <<EOF
cd /home/$USER_NAME
git clone https://aur.archlinux.org/pikaur.git
cd pikaur
yes | makepkg -si --noconfirm -S
cd /home/$USER_NAME
rm -rf /home/$USER_NAME/pikaur
EOF

    su - $USER_NAME -c 'sh pikaur.sh'
    rm /home/$USER_NAME/pikaur.sh
}

install_aur_packages() {
    pikaur -Sy --noconfirm
}

clean_packages() {
    yes | pacman -Scc
}

update_pkgfile() {
    pkgfile -u
}

set_hostname() {
    local hostname="$1"; shift

    echo "$hostname" > /etc/hostname
}

set_timezone() {
    local timezone="$1"; shift

    ln -sfT "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
}

set_locale() {
    echo 'LANG="en_US.UTF-8"' >> /etc/locale.conf
    echo 'LC_COLLATE="C"' >> /etc/locale.conf
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    locale-gen
}

set_keymap() {
    echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf
}

set_hosts() {
    local hostname="$1"; shift

    cat > /etc/hosts <<EOF
127.0.0.1 localhost.localdomain localhost $hostname
::1       localhost.localdomain localhost $hostname
EOF
}

set_fstab() {
    local boot_dev=""

    if [ -n "$NVME" ]
    then
	    boot_dev="$DRIVE"p1
    else
	    boot_dev="$DRIVE"1
    fi

    cat > /etc/fstab <<EOF
#
# /etc/fstab: static file system information
#
# <file system> <dir>    <type> <options>    <dump> <pass>

/dev/vg00/swap none swap  sw                0 0
/dev/vg00/root /    ext4  defaults,relatime 0 1

$boot_dev /boot vfat defaults,relatime 0 2
EOF
}

set_modules_load() {
	if [ "$PROCTYPE" = "AMD" ]
	then
		echo 'microcode' > /etc/modules-load.d/amd-ucode.conf
	else
		echo 'microcode' > /etc/modules-load.d/intel-ucode.conf
	fi
}

set_initcpio() {
    local modules

    if [ "$VIDEO_DRIVER" = "i915" ]
    then
        modules=' i915'
    elif [ "$VIDEO_DRIVER" = "nouveau" ]
    then
        modules=' nouveau'
    elif [ "$VIDEO_DRIVER" = "nvidia" ]
    then
	modules=' nvidia'
    elif [ "$VIDEO_DRIVER" = "radeon" ]
    then
        modules=' radeon'
    elif [ "$VIDEO_DRIVER" = "amdgpu" ]
    then
	modules=' amdgpu'
    fi

    local encrypt=""
    if [ -n "$ENCRYPT_DRIVE" ]
    then
        encrypt="encrypt"
    fi


    # Set MODULES with your video driver
    cat > /etc/mkinitcpio.conf <<EOF
# vim:set ft=sh
# MODULES
# The following modules are loaded before any boot hooks are
# run.  Advanced users may wish to specify all system modules
# in this array.  For instance:
#     MODULES="piix ide_disk reiserfs"
MODULES="vfat ext4${modules}"

# BINARIES
# This setting includes any additional binaries a given user may
# wish into the CPIO image.  This is run last, so it may be used to
# override the actual binaries included by a given hook
# BINARIES are dependency parsed, so you may safely ignore libraries
BINARIES=""

# FILES
# This setting is similar to BINARIES above, however, files are added
# as-is and are not parsed in any way.  This is useful for config files.
# Some users may wish to include modprobe.conf for custom module options
# like so:
#    FILES="/etc/modprobe.d/modprobe.conf"
FILES=""

# HOOKS
# This is the most important setting in this file.  The HOOKS control the
# modules and scripts added to the image, and what happens at boot time.
# Order is important, and it is recommended that you do not change the
# order in which HOOKS are added.  Run 'mkinitcpio -H <hook name>' for
# help on a given hook.
# 'base' is _required_ unless you know precisely what you are doing.
# 'udev' is _required_ in order to automatically load modules
# 'filesystems' is _required_ unless you specify your fs modules in MODULES
# Examples:
##   This setup specifies all modules in the MODULES setting above.
##   No raid, lvm2, or encrypted root is needed.
#    HOOKS="base"
#
##   This setup will autodetect all modules for your system and should
##   work as a sane default
#    HOOKS="base udev autodetect pata scsi sata filesystems"
#
##   This is identical to the above, except the old ide subsystem is
##   used for IDE devices instead of the new pata subsystem.
#    HOOKS="base udev autodetect ide scsi sata filesystems"
#
##   This setup will generate a 'full' image which supports most systems.
##   No autodetection is done.
#    HOOKS="base udev pata scsi sata usb filesystems"
#
##   This setup assembles a pata mdadm array with an encrypted root FS.
##   Note: See 'mkinitcpio -H mdadm' for more information on raid devices.
#    HOOKS="base udev pata mdadm encrypt filesystems"
#
##   This setup loads an lvm2 volume group on a usb device.
#    HOOKS="base udev usb lvm2 filesystems"
#
##   NOTE: If you have /usr on a separate partition, you MUST include the
#    usr, fsck and shutdown hooks.
HOOKS="base udev autodetect modconf block keymap keyboard $encrypt lvm2 resume filesystems fsck"

# COMPRESSION
# Use this to compress the initramfs image. By default, gzip compression
# is used. Use 'cat' to create an uncompressed image.
#COMPRESSION="gzip"
#COMPRESSION="bzip2"
#COMPRESSION="lzma"
#COMPRESSION="xz"
#COMPRESSION="lzop"

# COMPRESSION_OPTIONS
# Additional options for the compressor
#COMPRESSION_OPTIONS=""
EOF

    mkinitcpio -p linux
}

set_daemons() {
    local tmp_on_tmpfs="$1"; shift

    systemctl enable cpupower.service ntpd.service xdm-archlinux.service NetworkManager.service iwd.service

    if [ -z "$tmp_on_tmpfs" ]
    then
        systemctl mask tmp.mount
    fi
}

set_syslinux() {
    local lvm_dev=""

    if [ -n "$NVME" ]
    then
	    lvm_dev="$DRIVE"p2
    else
	    lvm_dev="$DRIVE"2
    fi

    bootctl install

    cat > /boot/loader/loader.conf <<EOF
default arch
timeout 4
#console-mode keep
editor no
EOF

    cat > /boot/loader/entries/arch.conf <<EOF
title Arch Linux
linux vmlinuz-linux
initrd initramfs-linux.img
options root=/dev/vg00/root resume=/dev/vg00/swap cryptdevice=$lvm_dev:lvm rw
EOF
    cat > /boot/loader/entries/arch-fallback.conf <<EOF
title Arch Linux Fallback
linux vmlinuz-linux
initrd initramfs-linux-fallback.img
options root=/dev/vg00/root resume=/dev/vg00/swap cryptdevice=$lvm_dev:lvm rw
EOF

    bootctl remove
    bootctl install
}

set_sudoers() {
    cat > /etc/sudoers <<EOF
## sudoers file.
##
## This file MUST be edited with the 'visudo' command as root.
## Failure to use 'visudo' may result in syntax or file permission errors
## that prevent sudo from running.
##
## See the sudoers man page for the details on how to write a sudoers file.
##

##
## Host alias specification
##
## Groups of machines. These may include host names (optionally with wildcards),
## IP addresses, network numbers or netgroups.
# Host_Alias	WEBSERVERS = www1, www2, www3

##
## User alias specification
##
## Groups of users.  These may consist of user names, uids, Unix groups,
## or netgroups.
# User_Alias	ADMINS = millert, dowdy, mikef

##
## Cmnd alias specification
##
## Groups of commands.  Often used to group related commands together.
# Cmnd_Alias	PROCESSES = /usr/bin/nice, /bin/kill, /usr/bin/renice, \
# 			    /usr/bin/pkill, /usr/bin/top

##
## Defaults specification
##
## You may wish to keep some of the following environment variables
## when running commands via sudo.
##
## Locale settings
# Defaults env_keep += "LANG LANGUAGE LINGUAS LC_* _XKB_CHARSET"
##
## Run X applications through sudo; HOME is used to find the
## .Xauthority file.  Note that other programs use HOME to find   
## configuration files and this may lead to privilege escalation!
# Defaults env_keep += "HOME"
##
## X11 resource path settings
# Defaults env_keep += "XAPPLRESDIR XFILESEARCHPATH XUSERFILESEARCHPATH"
##
## Desktop path settings
# Defaults env_keep += "QTDIR KDEDIR"
##
## Allow sudo-run commands to inherit the callers' ConsoleKit session
# Defaults env_keep += "XDG_SESSION_COOKIE"
##
## Uncomment to enable special input methods.  Care should be taken as
## this may allow users to subvert the command being run via sudo.
# Defaults env_keep += "XMODIFIERS GTK_IM_MODULE QT_IM_MODULE QT_IM_SWITCHER"
##
## Uncomment to enable logging of a command's output, except for
## sudoreplay and reboot.  Use sudoreplay to play back logged sessions.
# Defaults log_output
# Defaults!/usr/bin/sudoreplay !log_output
# Defaults!/usr/local/bin/sudoreplay !log_output
# Defaults!/sbin/reboot !log_output

##
## Runas alias specification
##

##
## User privilege specification
##
root ALL=(ALL) ALL

## Uncomment to allow members of group wheel to execute any command
%wheel ALL=(ALL) ALL

## Same thing without a password
# %wheel ALL=(ALL) NOPASSWD: ALL

## Uncomment to allow members of group sudo to execute any command
# %sudo ALL=(ALL) ALL

## Uncomment to allow any user to run sudo if they know the password
## of the user they are running the command as (root by default).
# Defaults targetpw  # Ask for the password of the target user
# ALL ALL=(ALL) ALL  # WARNING: only use this together with 'Defaults targetpw'

%rfkill ALL=(ALL) NOPASSWD: /usr/sbin/rfkill
%network ALL=(ALL) NOPASSWD: /usr/bin/netcfg, /usr/bin/wifi-menu

## Read drop-in files from /etc/sudoers.d
## (the '#' here does not indicate a comment)
#includedir /etc/sudoers.d
EOF

    chmod 440 /etc/sudoers
}

set_slim() {
    # Setup xdm (with xsession)
    cat > /etc/skel/.xsession <<EOF
mate-session
EOF

    chown root:root /etc/skel/.xsession
    chmod 755 /etc/skel/.xsession
}

set_root_password() {
    local password="$1"; shift

    echo -en "$password\n$password" | passwd
}

create_user() {
    local name="$1"; shift
    local password="$1"; shift

    useradd -m -s /bin/zsh -G adm,systemd-journal,wheel,rfkill,games,network,video,audio,optical,floppy,storage,scanner,power "$name"
    echo -en "$password\n$password" | passwd "$name"
}

update_locate() {
    updatedb
}

get_uuid() {
    blkid -o export "$1" | grep UUID | awk -F= '{print $2}'
}

set -ex

if [ "$1" == "chroot" ]
then
    configure
else
    setup
fi
