#!/bin/bash

# Gentoo Linux Installation Script (BIOS/MBR)
# Based on: https://wiki.gentoo.org/wiki/Handbook:AMD64

# === Interactive Configuration ===
echo "Welcome to Gentoo Linux Installation Script"
echo "Please provide the following information:"
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

# Stage3 selection
echo "Available stage3 types:"
echo "1) openrc (default)"
echo "2) systemd"
echo "3) nomultilib"
echo "4) hardened-openrc"
while true; do
    read -p "Select stage3 type [1-4] (default: 1): " stage3_input
    case $stage3_input in
        "" | "1")
            STAGE3_URL="https://distfiles.gentoo.org/releases/amd64/autobuilds/latest-stage3-amd64-openrc.txt"
            break
            ;;
        "2")
            STAGE3_URL="https://distfiles.gentoo.org/releases/amd64/autobuilds/latest-stage3-amd64-systemd.txt"
            break
            ;;
        "3")
            STAGE3_URL="https://distfiles.gentoo.org/releases/amd64/autobuilds/latest-stage3-amd64-nomultilib.txt"
            break
            ;;
        "4")
            STAGE3_URL="https://distfiles.gentoo.org/releases/amd64/autobuilds/latest-stage3-amd64-hardened.txt"
            break
            ;;
        *)
            echo "Invalid selection. Please choose a number between 1 and 4."
            ;;
    esac
done

# Timezone selection
echo "Available timezones:"
ls -1 /usr/share/zoneinfo/
echo
while true; do
    read -p "Enter your continent (e.g., Europe, America): " continent
    if [[ -d "/usr/share/zoneinfo/${continent}" ]]; then
        echo "Available cities in ${continent}:"
        ls -1 "/usr/share/zoneinfo/${continent}"
        read -p "Enter your city: " city
        if [[ -f "/usr/share/zoneinfo/${continent}/${city}" ]]; then
            TIMEZONE="${continent}/${city}"
            break
        else
            echo "Invalid city. Please try again."
        fi
    else
        echo "Invalid continent. Please try again."
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

# Display configuration summary
echo
echo "=== Installation Configuration Summary ==="
echo "Target Disk: $DISK"
echo "Boot Size: $BOOT_SIZE"
echo "Swap Size: $SWAP_SIZE"
echo "Stage3 URL: $STAGE3_URL"
echo "Timezone: $TIMEZONE"
echo "Hostname: $HOSTNAME"
echo "Root password: [hidden]"
echo
read -p "Press Enter to continue with these settings (or Ctrl+C to abort)..."
