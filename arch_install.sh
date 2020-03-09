#!/usr/bin/env sh

# Drives to install to.
DRIVE='/dev/sda'

# Partitions:
# HOME (set 0 or leave blank to not create home partition).
HOME_SIZE='' #GB (recommend 10GB)

# VAR (set 0 or leave blank to not create var partition).
VAR_SIZE=''  #GB (recommend 5GB)

# SWAP (set 0 or leave blank to not create swap partition).
SWAP_SIZE='' #GB (recommend square root of ram)

# EFI (set 0 or leave blank to not create efi partition).
# is used if the system is to be installed on "uefi"
EFI_SIZE=''  #MB (recommend 512MB)

# System language.
LANG='en_US'

# System timezone (leave blank to be prompted).
TIMEZONE='America/New_York'

# System hostname (leave blank to be prompted).
HOSTNAME='host'

# Root password (leave blank to be prompted).
ROOT_PASSWORD='root'

# Main user to create (by default, added to wheel group, and others).
USER_NAME='a'

# The main user's password (leave blank to be prompted).
USER_PASSWORD='a'

KEYMAP='us'
#KEYMAP='dvorak'

# Choose your video driver
# For Intel
VIDEO_DRIVER="i915"
# For nVidia
#VIDEO_DRIVER="nouveau"
# For ATI
#VIDEO_DRIVER="radeon"
# For generic stuff
#VIDEO_DRIVER="vesa"

# Choose hosts file type or leave blank
# Credit to https://github.com/StevenBlack/hosts
# Hosts file type:
# unified (adware + malware)
# fakenews
# gambling
# porn
# social
# fakenews-gambling
# fakenews-porn
# fakenews-social
# gambling-porn
# gambling-social
# porn-social
# fakenews-gambling-porn
# fakenews-gambling-social
# fakenews-porn-social
# gambling-porn-social
# fakenews-gambling-porn-social
HOSTS_FILE_TYPE="unified"

# Customize to install other packages
install_packages() {

	# General utilities/libraries
	packages="pkgfile reflector htop python python-pip rfkill rsync sudo unrar unzip wget zip maim ffmpeg cronie zsh stow xdg-user-dirs libnotify tlp exa"
	deamons="pkgfile-update.timer cronie tlp"

	# Sounds
	packages="$packages alsa-utils pulseaudio pulseaudio-alsa"

	# Development packages
	packages="$packages git cmake gdb qemu libvirt virt-manager iptables ebtables dnsmasq bridge-utils openbsd-netcat ovmf"
	deamons="$deamons iptables libvirtd"

	# Network
	packages="$packages dhcpcd iwd"
	deamons="$deamons dhcpcd iwd"

	# Fonts
	packages="$packages ttf-inconsolata ttf-dejavu ttf-font-awesome ttf-joypixels"

	# Xorg
	packages="$packages xorg-server xorg-xinit xorg-xsetroot xwallpaper xcape xclip slock unclutter arc-gtk-theme"

	# WM
	packages="$packages bspwm sxhkd picom dunst polybar xdo xdotool"

	# Browser
	packages="$packages qutebrowser"

	# Terminal apps
	packages="$packages alacritty ranger-git vifm tmux neomutt abook neovim"

	# Multimedia
	packages="$packages mpv mpd mpc ncmpcpp"

	# Communicators
	packages="$packages irssi telegram-desktop"

	# For laptops
	packages="$packages xf86-input-libinput"

	# Office
	packages="$packages libreoffice-still zathura zathura-pdf-mupdf sxiv"

	# Bluetooth
	packages="$packages bluez bluez-utils pulseaudio-bluetooth"
	deamons="$deamons bluetooth"

	# Printers
	packages="$packages ghostscript gsfonts gutenprint foomatic-db-gutenprint-ppds cups libcups system-config-printer"
	deamons="$deamons cups-browsed"

	# Video drivers
	if [ "$VIDEO_DRIVER" = "i915" ]; then
		packages="$packages xf86-video-intel libva-intel-driver"
	elif [ "$VIDEO_DRIVER" = "nouveau" ]; then
		packages="$packages xf86-video-nouveau"
	elif [ "$VIDEO_DRIVER" = "radeon" ]; then
		packages="$packages xf86-video-ati"
	elif [ "$VIDEO_DRIVER" = "vesa" ]; then
		packages="$packages xf86-video-vesa"
	fi

	# Python pip
	pip_packages="ueberzug pynvim msgpack"

	# Install
	sudo -u $USER_NAME yay --needed --noconfirm -Syu $packages
	sudo -u $USER_NAME pip3 install --user $pip_packages
	pip3 install --upgrade msgpack

	# Configure
	sed -i 's/#AutoEnable=false/AutoEnable=true/g' /etc/bluetooth/main.conf
	rfkill unblock bluetooth

	# Demons
	systemctl enable $deamons

	# Groups
	usermod -a -G kvm,libvirt $USER_NAME

	# Shell
	chsh $USER_NAME -s /usr/bin/zsh
}

#=======
# SETUP
#=======
greeter() {
	cat <<EOF

       /\\
      /  \\
     /\\   \\      Script written by Cherrry9
    /  ..  \\     https://github.com/Cherrry9
   /  '  '  \\
  / ..'  '.. \\
 /_\`        \`_\\

EOF
}

network() {
	ping -c 1 archlinux.org >/dev/null || wifi-menu || {
		echo "Can't connect to the internet!"
		exit 1
	}
	timedatectl set-ntp true
}

prepare_disk() {
	drive="$1"
	boot_type="$2"
	efi_size="$3"
	swap_size="$4"
	home_size="$5"
	var_size="$6"

	# calc end
	case $(echo "$efi_size > 0" | bc) in
	1) efi_end="$efi_size" ;;
	*) efi_end=512 ;;
	esac

	case $(echo "$swap_size > 0" | bc) in
	1)
		swap_end=$(echo "$swap_size * 1024 + $efi_end" | bc)
		swap="yes"
		;;
	*) swap_end="$efi_end" ;;
	esac

	case $(echo "$home_size > 0" | bc) in
	1)
		home_end=$(echo "$home_size * 1024 + $swap_end" | bc)
		home="yes"
		;;
	*) home_end="$swap_end" ;;
	esac

	case $(echo "$var_size > 0" | bc) in
	1)
		var_end=$(echo "$var_size  * 1024 + $home_end" | bc)
		var="yes"
		;;
	*) var_end="$home_end" ;;
	esac

	# label mbr/gpt
	next_part=1
	if [ -n "$boot_type" ]; then
		echo "Detected EFI boot"
		parted -s "$drive" mklabel gpt
	else
		echo "Detected legacy boot"
		parted -s "$drive" mklabel msdos
	fi

	# efi
	if [ -n "$boot_type" ]; then
		parted -s "$drive" select "$drive" mkpart primary fat32 1 "${efi_end}MiB"
		efi="${drive}$next_part"
		next_part=$((next_part + 1))
	fi

	# swap
	if [ -n "$swap" ]; then
		parted -s "$drive" select "$drive" mkpart primary linux-swap "${efi_size}MiB" "${swap_end}MiB"
		swap="${drive}$next_part"
		next_part=$((next_part + 1))
	fi

	# home
	if [ -n "$home" ]; then
		parted -s "$drive" select "$drive" mkpart primary ext4 "${swap_end}MiB" "${home_end}MiB"
		home="${drive}$next_part"
		next_part=$((next_part + 1))
	fi

	# var
	if [ -n "$var" ]; then
		parted -s "$drive" select "$drive" mkpart primary ext4 "${home_end}MiB" "${var_end}MiB"
		var="${drive}$next_part"
		next_part=$((next_part + 1))
	fi

	# root
	parted -s "$drive" select "$drive" mkpart primary ext4 "${var_end}MiB" 100%
	root="${drive}$next_part"

	# format && mount
	mkdir -p /mnt
	yes | mkfs.ext4 "$root"
	mount "$root" /mnt

	if [ -n "$efi" ]; then
		mkdir -p /mnt/boot/efi
		mkfs.fat -F32 "$efi"
		mount "$efi" /mnt/boot/efi
	fi
	if [ -n "$swap" ]; then
		mkswap "$swap"
		swapon "$swap"
	fi
	if [ -n "$home" ]; then
		mkdir -p /mnt/home
		yes | mkfs.ext4 "$home"
		mount "$home" /mnt/home
	fi
	if [ -n "$var" ]; then
		mkdir -p /mnt/var
		yes | mkfs.ext4 "$var"
		mount "$var" /mnt/var
	fi
}

set_mirrorlist() {
	pacman --noconfirm -Sy reflector
	reflector --verbose --latest 200 --age 24 --sort rate --save /etc/pacman.d/mirrorlist
}

install_base() {
	pacstrap /mnt base linux linux-firmware base-devel
	pacstrap /mnt git grub
	genfstab -U /mnt >/mnt/etc/fstab
}

create_user() {
	name="$1"
	password="$2"
	useradd -m -G adm,systemd-journal,wheel,rfkill,games,network,video,audio,optical,floppy,storage,scanner,power,sys,disk "$name"
	printf "%s\n%s" "$password" "$password" | passwd "$name" >/dev/null 2>&1
}

unmount_filesystems() {
	swap=$(lsblk -nrp | awk '/SWAP/ {print $1}')
	[ -n "$swap" ] && swapoff "$swap"
	umount -R /mnt
}

#===========
# CONFIGURE
#===========
set_locale() {
	lang="$1"
	echo "${lang}.UTF-8 UTF-8" >/etc/locale.gen
	echo "LANG=${lang}.UTF-8" >/etc/locale.conf
	locale-gen
}

set_hostname() {
	hostname="$1"
	echo "$hostname" >/etc/hostname
}

set_hosts() {
	hostname="$1"
	hosts_file_type="$2"
	url="https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/$hosts_file_type/hosts"
	if curl --output /dev/null --silent --head --fail "$url"; then
		curl "$url" >/etc/hosts
	elif [ "$hosts_file_type" = "unified" ]; then
		curl "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts" >/etc/hosts
	else
		cat >/etc/hosts <<EOF
127.0.0.1 localhost.localdomain localhost $hostname
::1       localhost.localdomain localhost $hostname
EOF
	fi
}

set_keymap() {
	keymap="$1"
	cat >/etc/vconsole.conf <<EOF
KEYMAP=$keymap
FONT=Lat2-Terminus16.psfu.gz
FONT_MAP=8859-2
EOF
}

set_timezone() {
	timezone="$1"
	ln -sf /usr/share/zoneinfo/"$timezone" /etc/localtime
	hwclock --systohc

}

set_root_password() {
	root_password="$1"
	printf "%s\n%s" "$root_password" "$root_password" | passwd >/dev/null 2>&1
}

set_sudoers() {
	cat >/etc/sudoers <<EOF
# /etc/sudoers
#
# This file MUST be edited with the 'visudo' command as root.
#
# See the man page for details on how to write a sudoers file.
#

Defaults env_reset
Defaults pwfeedback
Defaults lecture="always"
Defaults lecture_file="/home/$USER_NAME/.local/share/sudoers.bee"

# Host alias specification

# User alias specification

# Cmnd alias specification

# User privilege specification
root   ALL=(ALL) ALL
%wheel ALL=(ALL) ALL
%wheel ALL=(ALL) NOPASSWD: /bin/makepkg , /bin/pacman
EOF
}

set_boot() {
	boot_type="$1"
	if [ -n "$boot_type" ]; then
		pacman -Sy --noconfirm efibootmgr
		grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
	else
		grub-install --target=i386-pc "$DRIVE"
	fi
	grub-mkconfig -o /boot/grub/grub.cfg
}

install_yay() {
	git clone https://aur.archlinux.org/yay.git /yay
	cd /yay
	chown $USER_NAME:$USER_NAME /yay
	sudo -u $USER_NAME makepkg -si --noconfirm
	cd ..
	rm -r /yay
}

update_pkgfile() {
	pkgfile -u
}

clean_packages() {
	yes | pacman -Scc
}

set_pacman() {
	cat >/etc/pacman.conf <<EOF
#
# /etc/pacman.conf
#
# See the pacman.conf(5) manpage for option and repository directives

[options]
#RootDir     = /
#DBPath      = /var/lib/pacman/
#CacheDir    = /var/cache/pacman/pkg/
#LogFile     = /var/log/pacman.log
#GPGDir      = /etc/pacman.d/gnupg/
#HookDir     = /etc/pacman.d/hooks/
HoldPkg     = pacman glibc
#XferCommand = /usr/bin/curl -L -C - -f -o %o %u
#XferCommand = /usr/bin/wget --passive-ftp -c -O %o %u
#CleanMethod = KeepInstalled
Architecture = auto

# Pacman won't upgrade packages listed in IgnorePkg and members of IgnoreGroup
#IgnorePkg   =
#IgnoreGroup =

#NoUpgrade   =
#NoExtract   =

# Misc options
#UseSyslog
Color
TotalDownload
CheckSpace
VerbosePkgLists
ILoveCandy

SigLevel    = Required DatabaseOptional
LocalFileSigLevel = Optional
#RemoteFileSigLevel = Required

#[testing]
#Include = /etc/pacman.d/mirrorlist

[core]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist

#[community-testing]
#Include = /etc/pacman.d/mirrorlist

[community]
Include = /etc/pacman.d/mirrorlist

#[multilib-testing]
#Include = /etc/pacman.d/mirrorlist

#[multilib]
#Include = /etc/pacman.d/mirrorlist
EOF
}

set_makepkg() {
	numberofcores
	numberofcores=$(grep -c ^processor /proc/cpuinfo)
	sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j$((numberofcores + 1))\"/g" /etc/makepkg.conf
	sed -i "s/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T $numberofcores -z -)/g" /etc/makepkg.conf
}

setup() {
	greeter

	echo "Setting network"
	network

	if [ -e "$DRIVE" ]; then
		printf "%s :: Are you sure? This disk will be formatted: [yes/no] " "$DRIVE"
		read -r choice
		[ ! "$choice" = "y" ] && exit
	else
		echo "$DRIVE :: Device doesn't exist!"
		exit 1
	fi

	mkdir -p /mnt

	BOOT_TYPE=$(ls /sys/firmware/efi/efivars 2>/dev/null)
	prepare_disk "$DRIVE" "$BOOT_TYPE" "$EFI_SIZE" "$SWAP_SIZE" "$HOME_SIZE" "$VAR_SIZE"

	echo "Setting mirrorlist"
	set_mirrorlist

	echo "Installing base package"
	install_base

	echo "Chrooting to new system"
	cp "$0" /mnt/setup.sh
	cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist
	arch-chroot /mnt bash -c "./setup.sh chroot $BOOT_TYPE"

	if [ -f /mnt/setup.sh ]; then
		echo 'ERROR: Something failed inside the chroot, not unmounting filesystems so you can investigate.'
		echo 'Make sure you unmount everything before you try to run this script again.'
	else
		echo 'Unmounting filesystems'
		unmount_filesystems
		echo 'Done! Reboot system.'
	fi
}

configure() {
	# EFI or LEGACY
	BOOT_TYPE="$1"

	echo "Setting locale"
	set_locale "$LANG"

	echo "Setting time zone"
	if [ -z "$TIMEZONE" ] || [ ! -f "/usr/share/zoneinfo/$TIMEZONE" ]; then
		TIMEZONE=$(tzselect)
	fi
	set_timezone "$TIMEZONE"

	echo "Setting hostname"
	if [ -z "$HOSTNAME" ]; then
		printf "Enter the hostname: "
		read -r HOSTNAME
	fi
	set_hostname "$HOSTNAME"

	echo "Setting hosts"
	set_hosts "$HOSTNAME" "$HOSTS_FILE_TYPE"

	echo "Setting keymap"
	set_keymap $KEYMAP

	echo 'Setting bootloader'
	set_boot "$BOOT_TYPE"

	echo 'Setting root password'
	if [ -z "$ROOT_PASSWORD" ]; then
		printf "Enter the root password: "
		read -r ROOT_PASSWORD
	fi
	set_root_password "$ROOT_PASSWORD"

	echo 'Creating initial user'
	if [ -z "$USER_NAME" ]; then
		printf "Enter the user name: "
		read -r USER_NAME
	fi
	if [ -z "$USER_PASSWORD" ]; then
		printf "Enter the password for user %s: " "$USER_NAME"
		read -r USER_PASSWORD
	fi
	create_user "$USER_NAME" "$USER_PASSWORD"

	echo 'Setting sudoers'
	set_sudoers

	echo "Setting pacman"
	set_pacman

	echo "Setting makepkg"
	set_makepkg

	echo 'Installing yay'
	install_yay

	echo 'Installing additional packages'
	install_packages

	echo 'Clearing package tarballs'
	clean_packages

	echo 'Updating pkgfile database'
	update_pkgfile

	rm /setup.sh
}

if [ "$1" = "chroot" ]; then
	configure "$2"
else
	setup
fi
