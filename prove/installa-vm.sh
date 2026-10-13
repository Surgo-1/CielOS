#!/bin/bash
# Installa una Arch minima nella VM di prova (gira DENTRO la ISO live, come root, via ssh).
# Disco /dev/vda: GPT con bios_grub + btrfs (@, @home), GRUB BIOS, rete DHCP, sshd, un utente di prova in wheel.
# Pacchetti in più per il guardiano: polkit, python-gobject, pacman-contrib, ufw, snapper.
# Uso: installa-vm.sh UTENTE PASSWORD "CHIAVE_SSH_PUBBLICA"
set -euo pipefail
UTENTE=$1; PASSWORD=$2; CHIAVE=$3
DISCO=/dev/vda

sfdisk --wipe always "$DISCO" <<EOF
label: gpt
size=1MiB, type=21686148-6E6F-704E-6565-6449656E6946
type=0FC63DAF-8483-4772-8E79-3D69D8477DE4
EOF
mkfs.btrfs -f -L cielos "${DISCO}2"
mount "${DISCO}2" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
umount /mnt
mount -o subvol=@,compress=zstd "${DISCO}2" /mnt
mkdir -p /mnt/home
mount -o subvol=@home,compress=zstd "${DISCO}2" /mnt/home

pacstrap -K /mnt base linux btrfs-progs grub sudo polkit python python-gobject pacman-contrib ufw snapper \
    openssh iproute2
genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt /bin/bash -e <<EOF
ln -sf /usr/share/zoneinfo/Europe/Rome /etc/localtime
echo "it_IT.UTF-8 UTF-8" >> /etc/locale.gen; echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen; locale-gen
echo "LANG=it_IT.UTF-8" > /etc/locale.conf
echo cielos-vm > /etc/hostname
useradd -m -G wheel "$UTENTE"
echo "$UTENTE:$PASSWORD" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
install -d -m 700 -o "$UTENTE" -g "$UTENTE" /home/$UTENTE/.ssh
echo "$CHIAVE" > /home/$UTENTE/.ssh/authorized_keys
chown "$UTENTE:$UTENTE" /home/$UTENTE/.ssh/authorized_keys; chmod 600 /home/$UTENTE/.ssh/authorized_keys
install -d -m 700 /root/.ssh; echo "$CHIAVE" > /root/.ssh/authorized_keys; chmod 600 /root/.ssh/authorized_keys
printf '[Match]\nName=en*\n[Network]\nDHCP=yes\n' > /etc/systemd/network/20-rete.network
systemctl enable sshd systemd-networkd systemd-resolved
sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="console=ttyS0 loglevel=3"/; s/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' /etc/default/grub
grub-install --target=i386-pc "$DISCO"
grub-mkconfig -o /boot/grub/grub.cfg
EOF
ln -sf /run/systemd/resolve/stub-resolv.conf /mnt/etc/resolv.conf
umount -R /mnt
echo "INSTALLAZIONE FINITA"
