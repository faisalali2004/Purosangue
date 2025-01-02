#!/bin/bash

# Arch Linux Installation Script with System Checks
# WARNING: This script will erase all data on the selected drive!

# Variables
DISK="/dev/sdX"    # Replace with your disk, e.g., /dev/sda or /dev/nvme0n1
HOSTNAME="archlinux"
USERNAME="user"
PASSWORD="password"

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Use sudo."
  exit 1
fi

# Check Internet Connection
echo "Checking internet connection..."
if ! ping -c 1 archlinux.org &>/dev/null; then
  echo "Internet connection is required. Please check your network settings."
  exit 1
fi

# Check System Requirements
echo "Checking system requirements..."
if ! grep -q "x86_64" /proc/cpuinfo; then
  echo "Arch Linux requires a 64-bit CPU. Your system does not meet this requirement."
  exit 1
fi

# Prompt for confirmation before proceeding
echo "WARNING: This script will format and erase all data on $DISK."
read -p "Are you sure you want to continue? (yes/no): " CONFIRM
if [[ $CONFIRM != "yes" ]]; then
  echo "Installation aborted."
  exit 0
fi

# Update system clock
echo "Updating system clock..."
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

# Verify installation
echo "Verifying installation..."
if [ ! -d "/mnt/boot" ]; then
  echo "Something went wrong during the installation. Please check the logs."
  exit 1
fi

# Unmount and reboot
echo "Unmounting partitions and rebooting..."
umount -R /mnt
reboot
