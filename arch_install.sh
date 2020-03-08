#!/usr/bin/env sh

# Drives to install to.
DRIVE='/dev/sda'
DRIVE2='/dev/sdb' # set 0 if you have only one drive

# Partitions
# HOME (set 0 to not create home partition).
HOMEPARTSIZE='0' #GB (recommend 10GB)
# VAR (set 0 to not create var partition).
VARPARTSIZE='0' #GB (recommend 5GB)
# Drive for this additional partitions.
ADDPARTSONDRIVE='$DRIVE2'

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

# If it isn't initialized,
# will calculate the square root of memory for the swap size
SWAP_SIZE=''

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

# Dotfiles url
DOTFILES_URL='https://github.com/Cherrry9/Dotfiles'

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

# Customize to install your dotfiles
install_dotfiles() {
	url="$1"
	shift
	sudo -i -u $USER_NAME bash <<EOF
	# update directories
	xdg-user-dirs-update

	# clone repo && stow
	git clone $url /home/$USER_NAME/Dotfiles
	cd /home/$USER_NAME/Dotfiles
	git submodule update --init --recursive
	rm /home/$USER_NAME/.bashrc /home/$USER_NAME/.bash_profile
	stow --no-folding --dir /home/$USER_NAME/Dotfiles -Sv config -t /home/$USER_NAME

	# vim
	nvim --headless -c PlugInstall -c q -c q

	# dmenu
	cd /home/"$USER_NAME"/.config/dmenu/dmenu-4.9/
	echo "$USER_PASSWORD" | sudo -S make install

	cd /home/$USER_NAME/.config/dmenu/j4-dmenu-desktop
	cmake .
	make
	echo "$USER_PASSWORD" | sudo -S make install

	# cron
	(crontab -l 2>/dev/null; echo "0,30 * * * * export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus; export DISPLAY=:0; /home/$USER_NAME/.local/bin/cron/checkup") | crontab -
	(crontab -l 2>/dev/null; echo "*/5 * * * * export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus; export DISPLAY=:0; /home/$USER_NAME/.local/bin/cron/cronbat") | crontab -
EOF
	# issue
	cd /etc
	mv issue issue-old
	/home/$USER_NAME/.local/bin/utilities/makeissue
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

calc_swap() {
	mem_size=$(free -g | awk '/Mem/ {print $2}')
	if [ "$mem_size" -lt 1 ]; then
		SWAP_SIZE=1
	else
		SWAP_SIZE=$(echo "sqrt($mem_size)" | bc)
	fi
}

bios() {
	if [ "$ADDPARTSONDRIVE" != "$DRIVE" ]; then
		parted -s "$DRIVE2" mklabel msdos \
			$(if [ "$HOMEPARTSIZE" -gt 0 ]; then mkpart primary ext4 1 "${HOMEPARTSIZE}GiB"; fi) \
			$(if [ "$VARPARTSIZE" -gt 0 ]; then mkpart primary ext4 "${HOMEPARTSIZE}GiB" "${VARPARTSIZE}GiB"; fi)
		parted -s "$DRIVE" mklabel msdos \
			mkpart primary linux-swap 1 "${SWAP_SIZE}GiB" \
			mkpart primary ext4 "${SWAP_SIZE}GiB" 100% 
		mkswap "${DRIVE}1"
		swapon "${DRIVE}1"
		mkfs.ext4 "${DRIVE}2"
		mkfs.ext4 "${DRIVE2}1"
		mkfs.ext4 "${DRIVE2}2"
		mount "${DRIVE}2" /mnt
		mount "${DRIVE2}1" /mnt/home
		mount "${DRIVE2}2" /mnt/var

	elif [ "$ADDPARTSONDRIVE" -eq "$DRIVE" ]; then
		parted -s "$DRIVE" mklabel msdos \
			mkpart primary linux-swap 1 "${SWAP_SIZE}GiB" \
			$(if [ "$HOMEPARTSIZE" -gt 0 ]; then mkpart primary ext4 "${SWAP_SIZE}GiB" "${HOMEPARTSIZE}GiB"; fi) \
			$(if [ "$VARPARTSIZE" -gt 0 ]; then mkpart primary ext4 "${HOMEPARTSIZE}GiB" "${VARPARTSIZE}GiB"; fi) \
			mkpart primary ext4 "${VARPARTSIZE}GiB" 100%
		mkswap "${DRIVE}1"
		swapon "${DRIVE}1"
		mkfs.ext4 "${DRIVE}2"
		mkfs.ext4 "${DRIVE}3"
		mkfs.ext4 "${DRIVE}4"
	else
		parted -s "$DRIVE" mklabel msdos \
			mkpart primary linux-swap 1 "${SWAP_SIZE}GiB" \
			mkpart primary ext4 "${SWAP_SIZE}GiB" 100% 
		mkswap "${DRIVE}1"
		swapon "${DRIVE}1"
		mkfs.ext4 "${DRIVE}2"
		mount "${DRIVE}2" /mnt
	fi
}

efi() {
	SWAP_END="$(echo "$SWAP_SIZE * 1024 + 513" | bc)MiB"
	sudo parted -s "$DRIVE" mklabel gpt \
		mkpart primary fat32 1 513MiB \
		mkpart primary linux-swap 513MiB "$SWAP_END" \
		mkpart primary ext4 "$SWAP_END" 100%
	mkfs.fat -F32 "${DRIVE}1"
	mkswap "${DRIVE}2"
	swapon "${DRIVE}2"
	mkfs.ext4 "${DRIVE}3"
	mount "${DRIVE}3" /mnt
	mkdir -p /mnt/boot/efi
	mount "${DRIVE}1" /mnt/boot/efi
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
	shift
	password="$1"
	shift
	useradd -m -G adm,systemd-journal,wheel,rfkill,games,network,video,audio,optical,floppy,storage,scanner,power,sys,disk "$name"
	printf "%s\n%s" "$password" "$password" | passwd "$name" >/dev/null 2>&1
}

unmount_filesystems() {
	umount -R /mnt
	swap=$(lsblk -nrp | awk '/SWAP/ {print $1}')
	swapoff "$swap"
}

#===========
# CONFIGURE
#===========
set_locale() {
	lang="$1"
	shift
	echo "${lang}.UTF-8 UTF-8" >/etc/locale.gen
	echo "LANG=${lang}.UTF-8" >/etc/locale.conf
	locale-gen
}

set_hostname() {
	hostname="$1"
	shift
	echo "$hostname" >/etc/hostname
}

set_hosts() {
	hostname="$1"
	shift
	hosts_file_type="$1"
	shift
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
	shift
	cat >/etc/vconsole.conf <<EOF
KEYMAP=$keymap
FONT=Lat2-Terminus16.psfu.gz
FONT_MAP=8859-2
EOF
}

set_timezone() {
	timezone="$1"
	shift
	ln -sf /usr/share/zoneinfo/"$timezone" /etc/localtime
	hwclock --systohc

}

set_root_password() {
	root_password="$1"
	shift
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
	shift
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

	[ -z "$SWAP_SIZE" ] && calc_swap

	mkdir -p /mnt

	BOOT_TYPE=$(ls /sys/firmware/efi/efivars 2>/dev/null)
	if [ -n "$BOOT_TYPE" ]; then
		echo "Detected EFI boot"
		efi
	else
		echo "Detected legacy boot"
		bios
	fi

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
	shift

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

	echo 'Installing dotfiles'
	install_dotfiles "$DOTFILES_URL"

	rm /setup.sh
}

if [ "$1" = "chroot" ]; then
	configure "$2"
else
	setup
fi
