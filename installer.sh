#!/bin/bash

# Arch Linux Installation Script
# Run this script in the Arch Linux live environment
# WARNING: This script will format and erase data on the specified drive!

# Set variables
DISK="/dev/sdX"    # Replace with your disk, e.g., /dev/sda or /dev/nvme0n1
HOSTNAME="archlinux"
USERNAME="user"
PASSWORD="password"

# Check if script is run as root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Use sudo."
  exit 1
fi

# Update system clock
timedatectl set-ntp true

# Partition the disk
echo "Partitioning the disk..."
parted $DISK --script mklabel gpt
parted $DISK --script mkpart ESP fat32 1MiB 512MiB
parted $DISK --script set 1 boot on
parted $DISK --script mkpart primary ext4 512MiB 100%

# Format the partitions
echo "Formatting partitions..."
mkfs.fat -F32 "${DISK}1"
mkfs.ext4 "${DISK}2"

# Mount the partitions
echo "Mounting partitions..."
mount "${DISK}2" /mnt
mkdir -p /mnt/boot
mount "${DISK}1" /mnt/boot

# Install base system
echo "Installing base system..."
pacstrap /mnt base linux linux-firmware vim

# Generate fstab
echo "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Configure the system
echo "Configuring the system..."
arch-chroot /mnt /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/$(curl -s https://ipapi.co/timezone) /etc/localtime
hwclock --systohc

echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen

echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts

echo "Setting root password..."
echo "root:$PASSWORD" | chpasswd

echo "Creating user $USERNAME..."
useradd -m $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
usermod -aG wheel $USERNAME

echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

echo "Installing bootloader..."
pacman -S --noconfirm grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
EOF

# Unmount and reboot
echo "Unmounting partitions and rebooting..."
umount -R /mnt
reboot
