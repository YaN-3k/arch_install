#!/usr/bin/env sh

# Drives to install to.
DRIVE='/dev/sda'

# Set partitioning method to auto/manual
PARTITIONING='auto'

# Set boot type on efi/legacy
# if blank automaticly detect
BOOT_TYPE=''

# Partitions (only in use if PARTITIONING is set to auto);
# HOME (set 0 or leave blank to not create home partition).
HOME_SIZE='10' #GB (recommend 10GB)

# VAR (set 0 or leave blank to not create var partition).
VAR_SIZE='5' #GB (recommend 5GB)

# SWAP (set 0 or leave blank to not create swap partition).
SWAP_SIZE='2' #GB (recommend square root of ram)

# EFI (set 0 or leave blank to not create efi partition).
# is used if the system is to be installed on "uefi"
EFI_SIZE='512' #MB (recommend (or if not set) 512MB)

# System language.
LANG='en_US'

# System timezone (leave blank to be prompted).
TIMEZONE='America/New_York'

# System hostname (leave blank to be prompted).
HOSTNAME='host'

# Root password (leave blank to be prompted).
ROOT_PASSWORD=''

# Main user to create (by default, added to wheel group, and others).
USER_NAME=''

# The main user's password (leave blank to be prompted).
USER_PASSWORD=''

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

detect_boot_type() {
	BOOT_TYPE=$(ls /sys/firmware/efi/efivars 2>/dev/null)
	[ "$BOOT_TYPE" ] &&
		BOOT_TYPE='efi' ||
		BOOT_TYPE='legacy'
}

format_and_mount() {
	# format && mount
	mkdir -p /mnt
	yes | mkfs.ext4 "$root"
	mount "$root" /mnt

	[ "$efi" ] && {
		mkdir -p /mnt/boot/efi
		mkfs.fat -F32 "$efi"
		mount "$efi" /mnt/boot/efi
	}

	[ "$swap" ] && {
		mkswap "$swap"
		swapon "$swap"
	}

	[ "$home" ] && {
		mkdir -p /mnt/home
		yes | mkfs.ext4 "$home"
		mount "$home" /mnt/home
	}

	[ "$var" ] && {
		mkdir -p /mnt/var
		yes | mkfs.ext4 "$var"
		mount "$var" /mnt/var
	}
}

auto_partition() {
	# calc end
	case $(echo "$EFI_SIZE > 0" | bc) in
	1) efi_end="$((EFI_SIZE + 1))" ;;
	*) efi_end=513 ;;
	esac

	case $(echo "$SWAP_SIZE > 0" | bc) in
	1)
		swap_end=$(echo "$SWAP_SIZE * 1024 + $efi_end" | bc)
		swap=0
		;;
	*) swap_end="$efi_end" ;;
	esac

	case $(echo "$HOME_SIZE > 0" | bc) in
	1)
		home_end=$(echo "$HOME_SIZE * 1024 + $swap_end" | bc)
		home=0
		;;
	*) home_end="$swap_end" ;;
	esac

	case $(echo "$VAR_SIZE > 0" | bc) in
	1)
		var_end=$(echo "$VAR_SIZE  * 1024 + $home_end" | bc)
		var=0
		;;
	*) var_end="$home_end" ;;
	esac

	# label mbr/gpt
	next_part=1
	if [ "$BOOT_TYPE" = 'efi' ]; then
		echo "Detected EFI boot"
		parted -s "$DRIVE" mklabel gpt
	else
		echo "Detected legacy boot"
		parted -s "$DRIVE" mklabel msdos
	fi

	# efi
	[ "$BOOT_TYPE" = 'efi' ] && {
		parted -s "$DRIVE" select "$DRIVE" mkpart primary fat32 1MiB "${efi_end}MiB"
		efi="${DRIVE}$next_part"
		next_part=$((next_part + 1))
	}

	# swap
	[ "$swap" ] && {
		parted -s "$DRIVE" select "$DRIVE" mkpart primary linux-swap "${efi_end}MiB" "${swap_end}MiB"
		swap="${DRIVE}$next_part"
		next_part=$((next_part + 1))
	}

	# home
	[ "$home" ] && {
		parted -s "$DRIVE" select "$DRIVE" mkpart primary ext4 "${swap_end}MiB" "${home_end}MiB"
		home="${DRIVE}$next_part"
		next_part=$((next_part + 1))
	}

	# var
	[ "$var" ] && {
		parted -s "$DRIVE" select "$DRIVE" mkpart primary ext4 "${home_end}MiB" "${var_end}MiB"
		var="${DRIVE}$next_part"
		next_part=$((next_part + 1))
	}

	# root
	parted -s "$DRIVE" select "$DRIVE" mkpart primary ext4 "${var_end}MiB" 100%
	root="${DRIVE}$next_part"
}

select_disk() {
	DISK=''
	SIZE=''
	type="$1"

	# pseudo select loop
	while [ ! "$DISK" ] && [ -s "$list" ]; do
		i=0
		echo
		while read -r line; do
			i=$((i + 1))
			echo "$i) $line"
		done <"$list"

		if [ "$type" != "root" ]; then
			i=$((i + 1))
			echo "$i) Don't create $type partitions."
			refuse="$i"
		fi

		printf "\nEnter disk number for %s: " "$type"
		read -r choice

		if [ "$refuse" ] && [ "$refuse" = "$choice" ]; then
			DISK=''
			break
		elif [ "$choice" ]; then
			DISK=$(sed -n "${choice}p" "$list" | awk '{print $1}')
			SIZE=$(sed -n "${choice}p" "$list" | awk '{print $2}')
			sed -i "${choice}d" "$list"
		fi
	done
}

manual_partition() {
	while [ ! "$next" ] || [ "$next" != "y" ]; do
		# part
		if [ "$BOOT_TYPE" = 'efi' ]; then
			cat <<EOF

Please create root partition (/) and efi partition (/boot/efi), optional home (/home), var (/var) or swap

Example:
# label
mklabel gpt
# swap
mkpart primary linux-swap 1MiB 2G
# home
mkpart primary ext4 2G 12G
# root
mkpart primary ext4 12G 100%

If finished, enter - "quit"

EOF
		else
			cat <<EOF

Please create root partition (/) and optional home (/home), var (/var) or swap

Example:
# label
mklabel msdos
# swap
mkpart primary linux-swap 1MiB 2G
# home
mkpart primary ext4 2G 12G
# root
mkpart primary ext4 12G 100%

If finished, enter - "quit"

EOF
		fi

		parted "$DRIVE"

		# select disks
		list="/disks.list"
		lsblk -nrp "$DRIVE" | awk '/part/ { print $1" "$4 }' >"$list"

		[ "$BOOT_TYPE" = 'efi' ] && {
			select_disk "efi"
			efi="$DISK"
			EFI_SIZE="$SIZE"
		}

		select_disk "root"
		root="$DISK"
		ROOT_SIZE="$SIZE"

		select_disk "home"
		home="$DISK"
		HOME_SIZE="$SIZE"

		select_disk "swap"
		swap="$DISK"
		SWAP_SIZE="$SIZE"

		select_disk "var"
		var="$DISK"
		VAR_SIZE="$SIZE"

		rm "$list"

		echo
		echo "root: $root $ROOT_SIZE"
		[ "$efi" ] && echo "efi: $efi $EFI_SIZE"
		[ "$home" ] && echo "home: $home $HOME_SIZE"
		[ "$swap" ] && echo "swap: $swap $SWAP_SIZE"
		[ "$var" ] && echo "var:  $var $VAR_SIZE"
		echo
		printf "Continue? [y/n] "
		read -r next
	done
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

unmount_filesystems() {
	swap=$(lsblk -nrp | awk '/SWAP/ {print $1}')
	[ "$swap" ] && swapoff "$swap"
	umount -R /mnt
}

arch_chroot() {
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

create_user() {
	name="$1"
	password="$2"
	useradd -m -G adm,systemd-journal,wheel,rfkill,games,network,video,audio,optical,floppy,storage,scanner,power,sys,disk "$name"
	printf "%s\n%s" "$password" "$password" | passwd "$name" >/dev/null 2>&1
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
	if [ "$boot_type" = 'efi' ]; then
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

disable_pc_speaker() {
	echo "blacklist pcspkr" >>/etc/modprobe.d/nobeep.conf
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

[multilib]
Include = /etc/pacman.d/mirrorlist
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
		printf "%s :: Are you sure? This disk will be formatted: [y/n] " "$DRIVE"
		read -r choice
		[ ! "$choice" = "y" ] && exit
	else
		echo "$DRIVE :: Device doesn't exist!"
		exit 1
	fi

	mkdir -p /mnt

	if [ ! "$BOOT_TYPE" ]; then
		detect_boot_type
	elif [ "$BOOT_TYPE" != 'efi' ] && [ "$BOOT_TYPE" != 'legacy' ]; then
		echo "Wrong boot type: $BOOT_TYPE"
		echo "Set to efi or legacy"
		exit
	fi

	if [ "$PARTITIONING" = auto ]; then
		auto_partition
	else
		manual_partition
	fi
	format_and_mount

	echo "Setting mirrorlist"
	set_mirrorlist

	echo "Installing base package"
	install_base

	echo "Chrooting to new system"
	arch_chroot
}

configure() {
	# efi or legacy
	BOOT_TYPE="$1"

	echo "Setting locale"
	set_locale "$LANG"

	echo "Setting time zone"
	[ ! -f "/usr/share/zoneinfo/$TIMEZONE" ] && TIMEZONE=$(tzselect)
	set_timezone "$TIMEZONE"

	echo "Setting hostname"
	[ ! "$HOSTNAME" ] && {
		printf "Enter the hostname: "
		read -r HOSTNAME
	}

	set_hostname "$HOSTNAME"

	echo "Setting hosts"
	set_hosts "$HOSTNAME" "$HOSTS_FILE_TYPE"

	echo "Setting keymap"
	set_keymap $KEYMAP

	echo 'Setting bootloader'
	set_boot "$BOOT_TYPE"

	echo 'Setting root password'
	[ ! "$ROOT_PASSWORD" ] && {
		printf "Enter the root password: "
		read -r ROOT_PASSWORD
	}
	set_root_password "$ROOT_PASSWORD"

	echo 'Creating initial user'
	[ ! "$USER_NAME" ] && {
		printf "Enter the user name: "
		read -r USER_NAME
	}
	[ ! "$USER_PASSWORD" ] && {
		printf "Enter the password for user %s: " "$USER_NAME"
		read -r USER_PASSWORD
	}
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

	echo 'Disabling PC speaker'
	disable_pc_speaker

	rm /setup.sh
}

if [ "$1" = "chroot" ]; then
	configure "$2"
else
	setup
fi
