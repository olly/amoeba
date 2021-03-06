#!/bin/bash -ex
#
# Based on the Bashton CentOS AMI build script: https://github.com/BashtonLtd/centos7-ami/blob/master/build.sh

DEVICE="$1"
BUILD_DIRECTORY="$2"

ROOTFS="$BUILD_DIRECTORY/mount"

# 1. partition EBS volume
parted "${DEVICE}" < "${BUILD_DIRECTORY}/files/parted.conf"
# 2. format as XFS
mkfs.xfs -L root "${DEVICE}2"
mkdir "${ROOTFS}"
mount "${DEVICE}2" "${ROOTFS}"

# 3. install CentOS 7.4
rpm --root="${ROOTFS}" --initdb
rpm --root="${ROOTFS}" --install http://mirror.centos.org/centos/7/os/x86_64/Packages/centos-release-7-4.1708.el7.centos.x86_64.rpm

# 4. install packages
yum --installroot="${ROOTFS}" --assumeyes groupinstall core
yum --installroot="${ROOTFS}" --assumeyes install openssh-server grub2 acpid tuned kernel deltarpm
yum --installroot="${ROOTFS}" --assumeyes --cacheonly remove NetworkManager --setopt="clean_requirements_on_remove=1"

# 5. copy bash config for root
cp -a /etc/skel/.bash* "${ROOTFS}/root"

# 6. setup networking
cp "${BUILD_DIRECTORY}/files/hosts.conf" "${ROOTFS}/etc/hosts"
cp "${BUILD_DIRECTORY}/files/network.conf" "${ROOTFS}/etc/sysconfig/network"
cp "${BUILD_DIRECTORY}/files/ifcfg-eth0.conf" "${ROOTFS}/etc/sysconfig/network-scripts/ifcfg-eth0"
touch "${ROOTFS}/etc/resolv.conf"


# 7. configure timezone
cp /usr/share/zoneinfo/UTC "${ROOTFS}/etc/localtime"
echo 'ZONE="UTC"' > "${ROOTFS}/etc/sysconfig/clock"

# 8. install firstboot, fstab, and grub config
cp "${BUILD_DIRECTORY}/files/firstboot.conf" "${ROOTFS}/etc/sysconfig/firstboot"
cp "${BUILD_DIRECTORY}/files/fstab.conf" "${ROOTFS}/etc/fstab"
cp "${BUILD_DIRECTORY}/files/grub.conf" "${ROOTFS}/etc/default/grub"

# 9. bind directories from host into chroot
BINDMNTS="dev sys etc/hosts etc/resolv.conf"
for d in $BINDMNTS ; do
  mount --bind "/${d}" "${ROOTFS}/${d}"
done
mount -t proc none "${ROOTFS}/proc"

# 10. install grub2
chroot "${ROOTFS}" grub2-mkconfig -o /boot/grub2/grub.cfg
chroot "${ROOTFS}" grub2-install "${DEVICE}"

# 11. enable ssh
cp "${BUILD_DIRECTORY}/files/sshd_config.conf" "${ROOTFS}/etc/ssh/sshd_config"
mkdir "${ROOTFS}/etc/systemd/system/sshd.service.d"
cp "${BUILD_DIRECTORY}/files/10-update-ec2-public-keys.conf" "${ROOTFS}/etc/systemd/system/sshd.service.d/10-update-ec2-public-keys.conf"
cp "${BUILD_DIRECTORY}/files/update-ec2-public-keys.sh" "${ROOTFS}/usr/local/bin/update-ec2-public-keys"
chroot "${ROOTFS}" chmod +x /usr/local/bin/update-ec2-public-keys
chroot "${ROOTFS}" systemctl enable sshd.service

# 12. add 'silicon' user.
chroot "${ROOTFS}" useradd --home-dir /home/silicon --create-home --groups adm,systemd-journal,wheel --shell /bin/bash silicon
cp "${BUILD_DIRECTORY}/files/10-silicon.conf" "${ROOTFS}/etc/sudoers.d/10-silicon"

# 13. disable SELinux
sed -i -e 's/^\(SELINUX=\).*/SELINUX=disabled/' "${ROOTFS}/etc/selinux/config"

# 14. unmount binds to host
for d in $BINDMNTS ; do
  umount "${ROOTFS}/${d}"
done
umount "${ROOTFS}/proc"

# 15. unmount the volume
sync
umount --lazy "${ROOTFS}"
