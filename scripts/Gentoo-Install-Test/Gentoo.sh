#!/bin/bash
set -e

### --- User Input --- ###
echo "=== Gentoo Minimal Installer (Local Stage3) ==="
read -rp "Enter full path to local stage3 tarball (e.g., /mnt/stage3-amd64.tar.gz): " STAGE3_PATH
if [[ ! -f "$STAGE3_PATH" ]]; then
    echo "Error: File not found at $STAGE3_PATH"
    exit 1
fi

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

### --- Partitioning --- ###
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

### --- Extract Stage3 --- ###
echo "[*] Extracting stage3 from $STAGE3_PATH..."
tar xpf "$STAGE3_PATH" -C /mnt/gentoo --xattrs-include='*.*' --numeric-owner

### --- Prepare for Chroot --- ###
cp -L /etc/resolv.conf /mnt/gentoo/etc/
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev

### --- Chroot Section --- ###
echo "[*] Entering chroot to complete install..."

cat << EOF | chroot /mnt/gentoo /bin/bash
source /etc/profile
export PS1="(chroot) \$PS1"

echo "[*] Syncing portage..."
emerge-webrsync

echo "[*] Installing gentoo-kernel-bin (precompiled kernel)..."
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

echo "[*] Installing basic tools..."
emerge --noreplace syslog-ng dhcpcd grub

echo "[*] Setting up fstab..."
cat << FSTAB > /etc/fstab
/dev/sda1   /boot       ext4    defaults        0 2
/dev/sda2   /           ext4    noatime         0 1
FSTAB

echo "[*] Setting up networking..."
echo "config_eth0=\"dhcp\"" >> /etc/conf.d/net
ln -s /etc/init.d/net.lo /etc/init.d/net.eth0
rc-update add net.eth0 default

echo "[*] Installing GRUB..."
grub-install --target=i386-pc "$DISK"
grub-mkconfig -o /boot/grub/grub.cfg

rc-update add dhcpcd default
rc-update add syslog-ng default

exit
EOF

echo "[*] Cleaning up and unmounting..."
umount -l /mnt/gentoo/dev{/shm,/pts,}
umount -R /mnt/gentoo

echo "[✔] Gentoo installed successfully! You may now reboot."
