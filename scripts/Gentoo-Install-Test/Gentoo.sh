#!/bin/bash

# Gentoo Linux Installation Script (BIOS/MBR)
# Based on: https://wiki.gentoo.org/wiki/Handbook:AMD64
# Installation started by: Nixiews
# Date: 2025-06-27 21:23:22 UTC

# === Interactive Configuration ===
echo "Welcome to Gentoo Linux Installation Script"
echo "Installation started by: Nixiews"
echo "Date: 2025-06-27 21:23:22 UTC"
echo

# List available disks
echo "Available disks:"
lsblk -d -o NAME,SIZE,MODEL
echo
while true; do
    read -p "Enter target disk (e.g., sda, sdb): " disk_input
    if [[ -b "/dev/${disk_input}" ]]; then
        DISK="/dev/${disk_input}"
        echo "Selected disk: ${DISK}"
        break
    else
        echo "Error: Invalid disk. Please choose from the list above."
    fi
done

# Boot partition size
while true; do
    read -p "Enter boot partition size (default: 128M): " boot_input
    if [[ -z "$boot_input" ]]; then
        BOOT_SIZE="128M"
        break
    elif [[ $boot_input =~ ^[0-9]+[MGT]$ ]]; then
        BOOT_SIZE=$boot_input
        break
    else
        echo "Error: Please enter size in format like 128M, 1G, etc."
    fi
done

# Get system memory for swap recommendation
TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
RECOMMENDED_SWAP=$((TOTAL_MEM + (TOTAL_MEM/2))) # 1.5x RAM

# Swap partition size
echo "Recommended swap size for hibernation: ${RECOMMENDED_SWAP}G (1.5x your RAM)"
while true; do
    read -p "Enter swap partition size (default: ${RECOMMENDED_SWAP}G): " swap_input
    if [[ -z "$swap_input" ]]; then
        SWAP_SIZE="${RECOMMENDED_SWAP}G"
        break
    elif [[ $swap_input =~ ^[0-9]+[MGT]$ ]]; then
        SWAP_SIZE=$swap_input
        break
    else
        echo "Error: Please enter size in format like 4G, 8G, etc."
    fi
done

# Hostname
while true; do
    read -p "Enter hostname for your system (default: gentoo): " hostname_input
    if [[ -z "$hostname_input" ]]; then
        HOSTNAME="gentoo"
        break
    elif [[ $hostname_input =~ ^[a-zA-Z0-9-]+$ ]]; then
        HOSTNAME=$hostname_input
        break
    else
        echo "Error: Hostname can only contain letters, numbers, and hyphens."
    fi
done

# Root password
while true; do
    read -s -p "Enter root password: " pass1
    echo
    read -s -p "Confirm root password: " pass2
    echo
    if [[ "$pass1" == "$pass2" ]]; then
        if [[ ${#pass1} -ge 8 ]]; then
            ROOT_PASSWORD=$pass1
            break
        else
            echo "Error: Password must be at least 8 characters long."
        fi
    else
        echo "Error: Passwords do not match. Please try again."
    fi
done

# === Display configuration summary ===
echo
echo "=== Installation Configuration Summary ==="
echo "Target Disk: $DISK"
echo "Boot Size: $BOOT_SIZE"
echo "Swap Size: $SWAP_SIZE"
echo "Hostname: $HOSTNAME"
echo "Root password: [hidden]"
echo
read -p "Press Enter to continue with these settings (or Ctrl+C to abort)..."

# === 1. Disk Partitioning ===
echo "Creating partitions..."
# Wipe existing partition table
wipefs -a "${DISK}"

# Create new partition table and partitions
parted -a optimal "${DISK}" mklabel msdos
parted -a optimal "${DISK}" mkpart primary ext2 1MiB "${BOOT_SIZE}"
parted -a optimal "${DISK}" mkpart primary linux-swap "${BOOT_SIZE}" "$((${BOOT_SIZE%M} + ${SWAP_SIZE%G}*1024))M"
parted -a optimal "${DISK}" mkpart primary ext4 "$((${BOOT_SIZE%M} + ${SWAP_SIZE%G}*1024))M" 100%
parted "${DISK}" set 1 boot on

# === 2. Creating Filesystems ===
echo "Creating filesystems..."
mkfs.ext2 "${DISK}1"
mkswap "${DISK}2"
mkfs.ext4 "${DISK}3"

# === 3. Mount Filesystems ===
echo "Mounting filesystems..."
swapon "${DISK}2"
mount "${DISK}3" /mnt/gentoo
mkdir -p /mnt/gentoo/boot
mount "${DISK}1" /mnt/gentoo/boot

# === 4. Setting Date/Time ===
ntpd -q -g

# === 5. Downloading and Extracting Stage3 ===
echo "Downloading and extracting stage3..."
cd /mnt/gentoo

# Use specific stage3 file
STAGE3_URL="https://distfiles.gentoo.org/releases/amd64/autobuilds/20250622T165243Z/stage3-amd64-desktop-systemd-20250622T165243Z.tar.xz"
STAGE3_FILE="stage3-amd64-desktop-systemd-20250622T165243Z.tar.xz"

# Download with progress bar
echo "Downloading stage3..."
wget --show-progress "${STAGE3_URL}"

# Verify the download exists
if [ ! -f "${STAGE3_FILE}" ]; then
    echo "Error: Stage3 file not downloaded successfully!"
    exit 1
fi

# Extract with progress indicator
echo "Extracting stage3..."
tar xpf "${STAGE3_FILE}" --xattrs-include='*.*' --numeric-owner

# Verify extraction
if [ $? -ne 0 ]; then
    echo "Error: Stage3 extraction failed!"
    exit 1
fi

# Clean up the tarball
rm "${STAGE3_FILE}"

# === 6. Configuring make.conf ===
echo "Configuring make.conf..."
cat > /mnt/gentoo/etc/portage/make.conf << EOF
COMMON_FLAGS="-O2 -pipe"
CFLAGS="\${COMMON_FLAGS}"
CXXFLAGS="\${COMMON_FLAGS}"
FCFLAGS="\${COMMON_FLAGS}"
FFLAGS="\${COMMON_FLAGS}"

# Use all available CPU cores
MAKEOPTS="-j\$(nproc)"

# Use flags for systemd and binary packages
USE="systemd bindist"

# Accept binary packages
FEATURES="getbinpkg"

# Binary package host
PORTAGE_BINHOST="https://mirrors.gentoo.org/binpkg/amd64-systemd/"

# This sets the language of build output to English.
LC_MESSAGES=C.utf8

# Accept all licenses
ACCEPT_LICENSE="*"
EOF

# === 7. Configuring the Gentoo repository ===
mkdir -p /mnt/gentoo/etc/portage/repos.conf
cp /mnt/gentoo/usr/share/portage/config/repos.conf /mnt/gentoo/etc/portage/repos.conf/gentoo.conf

# === 8. Copy DNS info ===
cp -L /etc/resolv.conf /mnt/gentoo/etc/

# === 9. Mount necessary filesystems ===
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
mount --bind /run /mnt/gentoo/run
mount --make-slave /mnt/gentoo/run

# === 10. Chroot and System Configuration ===
cat > /mnt/gentoo/chroot-commands.sh << EOF
#!/bin/bash
set -e

# Source the profile
source /etc/profile
export PS1="(chroot) \${PS1}"

# Update repository
emerge-webrsync
emerge --sync

# Create a script to handle profile selection
cat > /root/select-profile.sh << 'INNERSCRIPT'
#!/bin/bash
# Get available profiles
profiles=\$(eselect profile list)
echo "Available profiles:"
echo "\$profiles"
echo

# Find systemd profile
profile_number=\$(echo "\$profiles" | grep -n "systemd" | grep -v "plasma" | head -n1 | cut -d':' -f1)
if [ -n "\$profile_number" ]; then
    echo "Selecting profile number \$profile_number..."
    eselect profile set "\$profile_number"
    echo "Selected profile:"
    eselect profile show
else
    echo "Error: No suitable systemd profile found!"
    exit 1
fi
INNERSCRIPT

chmod +x /root/select-profile.sh
/root/select-profile.sh

# Update @world set after profile selection
emerge --update --deep --newuse @world

# Configure timezone
echo "UTC" > /etc/timezone
emerge --config sys-libs/timezone-data

# Set hostname
echo "${HOSTNAME}" > /etc/hostname

# Set root password
echo "root:${ROOT_PASSWORD}" | chpasswd

# Install binary kernel package
echo "Installing binary kernel package..."
emerge --getbinpkg --usepkg sys-kernel/gentoo-kernel-bin

# Install binary GRUB package
echo "Installing GRUB..."
emerge --getbinpkg --usepkg sys-boot/grub:2

# Install and configure GRUB
grub-install ${DISK}
grub-mkconfig -o /boot/grub/grub.cfg

# Install essential system tools (binary packages where available)
emerge --getbinpkg --usepkg \
    sys-apps/systemd \
    net-misc/dhcpcd \
    net-misc/chrony

# Enable essential services
systemctl enable systemd-networkd
systemctl enable systemd-resolved
systemctl enable chronyd

echo "Base system installation complete!"
EOF

# Make the chroot script executable
chmod +x /mnt/gentoo/chroot-commands.sh

# Execute the chroot commands
echo "Entering chroot and installing base system..."
chroot /mnt/gentoo /bin/bash /chroot-commands.sh

if [ $? -ne 0 ]; then
    echo "Error: Chroot installation failed!"
    exit 1
fi

# === Final steps ===
echo "Installation completed successfully!"
echo
echo "Next steps:"
echo "1. Remove the installation media"
echo "2. Type 'reboot' to restart into your new Gentoo system"
echo "3. After reboot, log in as root with your chosen password"
echo "4. Run 'systemctl start systemd-networkd' to start networking"
echo "5. Create a regular user account"
echo
echo "Installation finished at: $(date -u '+%Y-%m-%d %H:%M:%S') UTC"
