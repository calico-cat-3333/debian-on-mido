export CROSS_COMPILE=aarch64-linux-gnu-
export ARCH=arm64
export CC=aarch64-linux-gnu-gcc

export rootfs_mp=test

function make_rootfs_img {
	if [ $UID -ne 0 ]; then
		echo -e "\\e[31mError: should run as root.\\e[0m"
		return 1
	fi
	if [ -f rootfs.img ]; then
		read -r -p "rootfs.img exists, overwrite it?[y/N]" overwrite_rootfs
		case $overwrite_rootfs in
			[yY])
				echo "overwrite rootfs.img";;
			*)
				return 1;;
		esac
		if findmnt -n -o TARGET --source "$(losetup -j rootfs.img | cut -d: -f1)" >/dev/null 2>&1; then
			echo -e "\\e[31mError: rootfs.img is currently mounted. Please unmount it first.\\e[0m"
			return 1
		fi
	fi
	dd if=/dev/zero of=rootfs.img bs=1G count=3
	mkfs.ext4 rootfs.img
	mkdir -p ./$rootfs_mp
	mount rootfs.img ./$rootfs_mp
	debootstrap --arch arm64 trixie ./$rootfs_mp https://mirrors.tuna.tsinghua.edu.cn/debian/
}

function mount_rootfs {
	if [ $UID -ne 0 ]; then
		echo -e "\\e[31mError: should run as root.\\e[0m"
		return 1
	fi
	if [ ! -f rootfs.img ]; then
		echo -e "\\e[31mError: rootfs.img not exist, run make_rootfs_img first.\\e[0m"
		return 1
	fi
	if [ ! -f bootfs.img ]; then
		echo -e "\\e[31mError: bootfs.img not exist, run make_bootfs_img first.\\e[0m"
		return 1
	fi
	mkdir -p ./$rootfs_mp
	mount rootfs.img ./$rootfs_mp
	mount --bind /proc ./$rootfs_mp/proc
	mount --bind /dev ./$rootfs_mp/dev
	mount --bind /dev/pts ./$rootfs_mp/dev/pts
	mount --bind /sys ./$rootfs_mp/sys
	mount bootfs.img ./$rootfs_mp/boot
}

function umount_rootfs {
	if [ $UID -ne 0 ]; then
		echo -e "\\e[31mError: should run as root.\\e[0m"
		return 1
	fi
	umount ./$rootfs_mp/proc
	umount ./$rootfs_mp/dev/pts
	umount ./$rootfs_mp/dev
	umount ./$rootfs_mp/sys
	umount ./$rootfs_mp/boot
	umount ./$rootfs_mp
	rmdir ./$rootfs_mp
}

function make_boot_img_old {
	mkdir -p ./tmpboot
	if [ ! -f ./$rootfs_mp/boot/initrd.img* ]; then
		echo -e "\\e[31mError: No initrd.img, should mount_rootfs and create initrd.img first.\\e[0m"
		return 1
	fi
	cp ./linux/arch/arm64/boot/dts/qcom/*mido*.dtb tmpboot/dtb
	cp ./linux/arch/arm64/boot/Image.gz tmpboot/
	cp ./$rootfs_mp/boot/initrd.img* tmpboot/initrd.img
	cat ./tmpboot/Image.gz ./tmpboot/dtb > ./tmpboot/kernel-dtb

	rootfs_uuid=`/sbin/blkid -p -o value -s UUID rootfs.img`

	mkbootimg --base 0x80000000 \
			--kernel_offset 0x00008000 \
			--ramdisk_offset 0x01000000 \
			--tags_offset 0x00000100 \
			--pagesize 2048 \
			--second_offset 0x00f00000 \
			--ramdisk ./tmpboot/initrd.img \
			--cmdline "console=tty0 root=UUID=$rootfs_uuid rw loglevel=3 splash"\
			--kernel ./tmpboot/kernel-dtb -o ./tmpboot/boot.img
	cp ./tmpboot/boot.img ./boot.img
}

function make_bootfs_img {
	if [ $UID -ne 0 ]; then
		echo -e "\\e[31mError: should run as root.\\e[0m"
		return 1
	fi
	if [ -f bootfs.img ]; then
		read -r -p "bootfs.img exists, overwrite it?[y/N]" overwrite_rootfs
		case $overwrite_rootfs in
			[yY])
				echo "overwrite bootfs.img";;
			*)
				return 1;;
		esac
		if findmnt -n -o TARGET --source "$(losetup -j bootfs.img | cut -d: -f1)" >/dev/null 2>&1; then
			echo -e "\\e[31mError: bootfs.img is currently mounted. Please unmount it first.\\e[0m"
			return 1
		fi
	fi
	dd if=/dev/zero of=bootfs.img bs=1G count=1
	mkfs.ext2 bootfs.img
}
