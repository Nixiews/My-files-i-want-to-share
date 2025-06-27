# ... (previous interactive configuration remains the same)

# === 5. Downloading and Extracting Stage3 ===
echo "Downloading and extracting stage3..."
cd /mnt/gentoo
STAGE3_LATEST=$(curl -s "${STAGE3_URL}" | head -n 1)
STAGE3_PATH=$(echo "${STAGE3_LATEST}" | cut -d " " -f 1)
STAGE3_FILE=$(basename "${STAGE3_PATH}")

# Download with progress bar
wget --show-progress "https://distfiles.gentoo.org/releases/amd64/autobuilds/${STAGE3_PATH}"

# Verify the download exists
if [ ! -f "${STAGE3_FILE}" ]; then
    echo "Error: Stage3 file not downloaded successfully!"
    exit 1
fi

# Extract with progress indicator
echo "Extracting stage3 (this may take a while)..."
tar xpf "${STAGE3_FILE}" --xattrs-include='*.*' --numeric-owner --strip-components=1

# Verify extraction
if [ $? -ne 0 ]; then
    echo "Error: Stage3 extraction failed!"
    exit 1
fi

# Clean up the tarball to save space
rm "${STAGE3_FILE}"

# === 6. Configuring make.conf ===
echo "Configuring make.conf..."
cat > /mnt/gentoo/etc/portage/make.conf << EOF
# These settings were set by the catalyst build script that automatically
# built this stage.
COMMON_FLAGS="-O2 -pipe -march=native"
CFLAGS="\${COMMON_FLAGS}"
CXXFLAGS="\${COMMON_FLAGS}"
FCFLAGS="\${COMMON_FLAGS}"
FFLAGS="\${COMMON_FLAGS}"

# Use all available CPU cores for compilation
MAKEOPTS="-j\$(nproc)"

# NOTE: This stage was built with the bindist Use flag enabled
USE="bindist"

# This sets the language of build output to English.
LC_MESSAGES=C.utf8

# Turn on logging for portage
PORTAGE_ELOG_CLASSES="warn error info log qa"
PORTAGE_ELOG_SYSTEM="save"

# Accept all licenses
ACCEPT_LICENSE="*"

# Package-specific USE flags can be added here
EOF

# === 7. Configuring the Gentoo ebuild repository ===
echo "Configuring Gentoo repository..."
mkdir -p /mnt/gentoo/etc/portage/repos.conf
cp /mnt/gentoo/usr/share/portage/config/repos.conf /mnt/gentoo/etc/portage/repos.conf/gentoo.conf

# === 8. Copy DNS info ===
cp -L /etc/resolv.conf /mnt/gentoo/etc/

# === 9. Mount necessary filesystems ===
echo "Mounting necessary filesystems..."
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
mount --bind /run /mnt/gentoo/run
mount --make-slave /mnt/gentoo/run

# === 10. Entering the new environment ===
echo "Preparing chroot environment..."
cat > /mnt/gentoo/chroot-commands.sh << 'EOF'
#!/bin/bash
set -e  # Exit on error

# Source profile
source /etc/profile
export PS1="(chroot) \${PS1}"

# Update repository
echo "Syncing repository..."
emerge-webrsync
emerge --sync

# Select profile
eselect profile set default/linux/amd64/17.1

# Update @world set
echo "Updating world set (this will take a while)..."
emerge --verbose --update --deep --newuse @world

# Install kernel sources and firmware
echo "Installing kernel sources and firmware..."
emerge sys-kernel/gentoo-sources
emerge sys-kernel/linux-firmware
emerge sys-kernel/genkernel

# Configure and build kernel
echo "Building kernel (this will take a while)..."
genkernel all

# Install and configure GRUB
echo "Installing GRUB..."
emerge sys-boot/grub:2
grub-install ${DISK}
grub-mkconfig -o /boot/grub/grub.cfg

# Install essential system tools
echo "Installing system tools..."
emerge app-admin/sysklogd
emerge net-misc/dhcpcd
emerge net-misc/chrony

# Configure services
rc-update add sysklogd default
rc-update add chronyd default
rc-update add sshd default

echo "Base system installation complete!"
EOF

# Make the chroot script executable
chmod +x /mnt/gentoo/chroot-commands.sh

# Execute the chroot commands
echo "Entering chroot and installing base system (this will take a long time)..."
chroot /mnt/gentoo /bin/bash /chroot-commands.sh

if [ $? -ne 0 ]; then
    echo "Error: Chroot installation failed!"
    exit 1
fi

# === Final steps ===
echo "Installation completed successfully!"
echo "You can now:"
echo "1. Remove the installation media"
echo "2. Type 'reboot' to restart into your new Gentoo system"
echo "3. After reboot, log in as root with your chosen password"
echo "4. Configure your network settings if not using DHCP"
echo "5. Create a regular user account"
