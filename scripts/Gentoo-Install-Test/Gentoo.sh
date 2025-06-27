#!/bin/bash
set -e

### --- User Input Section --- ###
echo "=== Gentoo Minimal Installer ==="
read -rp "Enter target disk (e.g., /dev/sda): " DISK
if [ ! -b "$DISK" ]; then
    echo "Error: $DISK is not a valid block device."
    exit 1
fi

read -rp "Enter hostname for this system: " HOSTNAME

read -rsp "Enter root password: " ROOT_PASSWORD
echo
read -rsp "Confirm root password: " CONFIRM_PASSWORD
echo
if [ "$ROOT_PASSWORD" != "$CONFIRM_PASSWORD" ]; then
    echo "Error: Passwords do not match."
    exit 1
fi

### --- Partitioning and Filesystems --- ###
echo "[*] Partitioning $DISK..."
parted -s "$DISK" mklabel msdos
parted -s "$DISK" mkpart primary ext4 1MiB 512MiB
parted -s "$DISK" mkpart primary ext4 512MiB 100%
parted -s "$DISK" set 1 boot on

mkfs.ext4 "${DISK}1"
mkfs.ext4 "${DISK}2"

mount "${DISK}2" /mnt/gentoo
mkdir -p /mnt/gentoo/boot
mount "${DISK}1" /mnt/gentoo/boot

### --- Download and Extract Stage3 --- ###
echo "[*] Downloading latest stage3 tarball..."
STAGE3_URL=$(curl -s https://gentoo.org/downloads/mirrors/ | grep -oP 'http.*stage3-amd64-[\d]{8}T\d{6}Z\.tar\.xz' | head -n 1)
wget "$STAGE3_URL" -O /mnt/gentoo/stage3.tar.xz

echo "[*] Extracting stage3..."
tar xpf /mnt/gentoo/stage3.tar.xz -C /mnt/gentoo --xattrs-include='*.*' --numeric-owner

### --- Prep for Chroot --- ###
cp -L /etc/resolv.conf /mnt/gentoo/etc/
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev

### --- Chroot Script --- ###
echo "[*] Entering chroot to install system..."

cat << EOF | chroot /mnt/gentoo /bin/bash
source /etc/profile
export PS1="(chroot) \$PS1"

emerge-webrsync
emerge --verbose gentoo-kernel-bin

echo "UTC" > /etc/timezone
emerge --config sys-libs/timezone-data

echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
locale-gen
eselect locale set en_US.utf8
env-update && source /etc/profile

echo "$HOSTNAME" > /etc/hostname

echo "[*] Setting root password..."
echo "root:$ROOT_PASSWORD" | chpasswd

emerge --noreplace syslog-ng dhcpcd grub

echo "[*] Configuring fstab..."
cat << FSTAB > /etc/fstab
/dev/sda1   /boot       ext4    defaults        0 2
/dev/sda2   /           ext4    noatime         0 1
FSTAB

echo "[*] Configuring networking..."
echo "config_eth0=\"dhcp\"" >> /etc/conf.d/net
ln -s /etc/init.d/net.lo /etc/init.d/net.eth0
rc-update add net.eth0 default

grub-install --target=i386-pc "$DISK"
grub-mkconfig -o /boot/grub/grub.cfg

rc-update add dhcpcd default
rc-update add syslog-ng default

exit
EOF

echo "[*] Cleaning up and unmounting..."
umount -l /mnt/gentoo/dev{/shm,/pts,}
umount -R /mnt/gentoo

echo "[✔] Gentoo installed! You can now reboot into your system."
