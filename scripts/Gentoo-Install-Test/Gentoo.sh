#!/bin/bash

set -e

echo "==== Gentoo Binary Install Script (BIOS, No Compile) ===="
echo "WARNING: This script will ERASE all data on the selected disk!"
echo "You MUST review and understand each step before proceeding."
echo

# Step 1: Choose the install disk
echo "Available Disks:"
lsblk -d -o NAME,SIZE,MODEL
read -rp "Enter the disk to install Gentoo on (e.g., sda): " INSTALL_DISK

# Step 2: Set hostname
read -rp "Enter your desired hostname: " HOSTNAME

# Step 3: Choose root password and create a user
read -rp "Enter your desired username: " USERNAME

# Step 4: Set locale and timezone
echo "Available timezones (partial list):"
ls /usr/share/zoneinfo | head -20
read -rp "Enter your desired timezone (e.g., Europe/Berlin): " TIMEZONE

read -rp "Enter your desired locale (e.g., en_US.UTF-8): " LOCALE

# Step 5: Partition the disk (BIOS, MBR)
echo "Partitioning /dev/$INSTALL_DISK..."
sgdisk --zap-all /dev/"$INSTALL_DISK"
parted /dev/"$INSTALL_DISK" -- mklabel msdos
parted /dev/"$INSTALL_DISK" -- mkpart primary ext4 2MiB 100%
parted /dev/"$INSTALL_DISK" -- set 1 boot on

# Step 6: Format and mount
mkfs.ext4 /dev/"$INSTALL_DISK"1
mount /dev/"$INSTALL_DISK"1 /mnt/gentoo

# Step 7: Extract your local stage3 tarball
cd /mnt/gentoo
echo "Extracting your local stage3 tarball..."
read -rp "Enter the full path to your local stage3 tarball (e.g., /home/user/stage3-amd64.tar.gz): " STAGE3_PATH
tar xpvf "$STAGE3_PATH" --xattrs-include='*.*' --numeric-owner

# Step 8: Mount necessary filesystems
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev

# Step 9: Copy DNS info
cp -L /etc/resolv.conf /mnt/gentoo/etc/

# Step 10: Enter chroot and configure
cat << 'EOF' > /mnt/gentoo/install-inside-chroot.sh
#!/bin/bash
set -e

echo "Setting hostname..."
echo "$HOSTNAME" > /etc/hostname

echo "Setting timezone..."
echo "$TIMEZONE" > /etc/timezone
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime

echo "Configuring locale..."
echo "LANG=$LOCALE" > /etc/locale.conf
echo "$LOCALE UTF-8" >> /etc/locale.gen
locale-gen

echo "Setting root password..."
passwd

echo "Creating user..."
useradd -m -G wheel,audio,video -s /bin/bash $USERNAME
passwd $USERNAME

echo "Configuring sudo (optionally)..."
emerge -q app-admin/sudo
echo '%wheel ALL=(ALL) ALL' > /etc/sudoers.d/wheel

echo "Updating package manager..."
emerge --sync
emerge -qv @system

echo "Setting up bootloader (GRUB, BIOS)..."
emerge -q sys-boot/grub
grub-install /dev/$INSTALL_DISK
grub-mkconfig -o /boot/grub/grub.cfg

echo "Enabling networking..."
rc-update add dhcpcd default
rc-service dhcpcd start

echo "Install complete! You can now exit chroot, unmount, and reboot."
EOF

chmod +x /mnt/gentoo/install-inside-chroot.sh

# Step 11: Chroot and run inside script
cp /etc/portage/make.conf /mnt/gentoo/etc/portage/make.conf || true
chroot /mnt/gentoo /bin/bash -c 'source /etc/profile; export PS1="(chroot) $PS1"; bash /install-inside-chroot.sh'

# Step 12: Cleanup and reboot
echo "Cleaning up..."
rm /mnt/gentoo/install-inside-chroot.sh
umount -l /mnt/gentoo/dev{/shm,/pts,}
umount -R /mnt/gentoo
reboot
