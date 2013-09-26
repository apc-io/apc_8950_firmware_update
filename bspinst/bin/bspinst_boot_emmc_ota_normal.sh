#!/bin/sh

bindir=$PWD/bin:$PWD/bspinst/bin:/mnt/mmcblk0p1/bspinst/bin:/mnt/sda1/bspinst/bin:/usr/bin

export PATH=$bindir:$PATH

source `which bspinst_var.sh`
source `which bspinst_ui.sh`
source `which bspinst_api.sh`

srcdir=`get_src_dir`

echo srcdir = $srcdir

bspinst_start

# msg "Press [MENU] to install or [BACK] to quit"
# code=`catch_input_event`

# if [ "$code" == "0x9e" ]; then
#	rpc sys shutdown
#	exit 0
# fi

make_mbr ()
{
	# create device node
	mknod /dev/mmcblk1 b 179 8
	mknod /dev/mmcblk1p1 b 179 9
	mknod /dev/mmcblk1p2 b 179 10
	mknod /dev/mmcblk1p3 b 179 11
	mknod /dev/mmcblk1p4 b 179 12
	mknod /dev/mmcblk1p5 b 179 13
	mknod /dev/mmcblk1p6 b 179 14	
	mknod /dev/mmcblk1p7 b 179 15
	mknod /dev/mmcblk1p8 b 179 16	
	mknod /dev/mmcblk1p9 b 179 17	
	mknod /dev/mmcblk1p10 b 179 18	
	mknod /dev/mmcblk1p11 b 179 19	
	mknod /dev/mmcblk1p12 b 179 20	
	mknod /dev/mmcblk1p13 b 179 21	
	
	# kill udevd --daemon
	killall -9 udevd

	# kill /etc/udec/script/CARD_DET
	card_det=`ps|grep CARD_DET|sed 's/^ \+//g'|cut -d\  -f1|head -1`
	kill -9 $card_det

	ps

	umount /mnt/mmcblk1p1
	umount /mnt/mmcblk1p2
	umount /mnt/mmcblk1p3
	umount /mnt/mmcblk1p4
	umount /mnt/mmcblk1p5
	umount /mnt/mmcblk1p6
	umount /mnt/mmcblk1p7
	umount /mnt/mmcblk1p8
	umount /mnt/mmcblk1p9
	umount /mnt/mmcblk1p10
	umount /mnt/mmcblk1p11
	umount /mnt/mmcblk1p12
	umount /mnt/mmcblk1p13


	# fdisk commands
	# a   toggle a bootable flag
	# b   edit bsd disklabel
	# c   toggle the dos compatibility flag
	# d   delete a partition
	# l   list known partition types
	# m   print this menu
	# n   add a new partition
	# o   create a new empty DOS partition table
	# p   print the partition table
	# q   quit without saving changes
	# s   create a new empty Sun disklabel
	# t   change a partition's system id
	# u   change display/entry units
	# v   verify the partition table
	# w   write table to disk and exit
	# x   extra functionality (experts only)

	# /dev/sdx1	   system      256MB   ext4
	# /dev/sdx2	   boot        16MB    ext4
	# /dev/sdx3    recovery    16MB    ext4
	# /dev/sdx4    extended partition
	# /dev/sdx5    cache       128MB   ext4
	# /dev/sdx6    swap        128MB   vfat
	# /dev/sdx7    u-boot-logo 2MB     vfat
	# /dev/sdx8    kernel-logo 2MB     vfat
	# /dev/sdx9    misc        2MB     ext4
	# /dev/sdx10   efs         2MB     ext4
	# /dev/sdx11   radio       16MB    ext4
	# /dev/sdx12   keydata     2MB     ext4
	# /dev/sdx13   userdata	           ext4
                
	# create sdx1
	printf "o\np\nn\np\n1\n\n+256M\nt\n83\np\nw\n" | fdisk $1
	# create sdx2
	printf "p\nn\np\n2\n\n+16M\nt\n2\n83\np\nw\n" | fdisk $1
	# create sdx3
	printf "p\nn\np\n3\n\n+16M\nt\n3\n83\np\nw\n" | fdisk $1
	# create sdx4 for extended partition
	printf "p\nn\ne\n4\n\n\np\nw\n" | fdisk $1
	# create sdx5
    printf "p\nn\nl\n\n+128M\nt\n5\n83\np\nw\n" | fdisk $1
    # create sdx6
# tmp solution start    
    printf "p\nn\nl\n\n+128M\nt\n6\nb\np\nw\n" | fdisk $1
#    printf "p\nn\nl\n\n+128M\nt\n6\n82\np\nw\n" | fdisk $1
# tmp solution end
    # create sdx7 ~ sdx12
    printf "p\nn\nl\n\n+2M\nt\n7\nb\np\nw\n" | fdisk $1
    printf "p\nn\nl\n\n+2M\nt\n8\nb\np\nw\n" | fdisk $1
    printf "p\nn\nl\n\n+2M\nt\n9\n83\np\nw\n" | fdisk $1
    printf "p\nn\nl\n\n+2M\nt\n10\n83\np\nw\n" | fdisk $1
    printf "p\nn\nl\n\n+16M\nt\n11\n83\np\nw\n" | fdisk $1
    printf "p\nn\nl\n\n+2M\nt\n12\n83\np\nw\n" | fdisk $1
    # create sdx13
    printf "p\nn\nl\n\n\nt\n13\n83\nw\n" | fdisk $1
    
	# print the partition table
	printf "p\nq\n" | fdisk $1

	sync; sleep 1;

	# format partitions
	echo mkfs.ext4 -v -L system    "$1"p1
	mkfs.ext4      -v -L system    "$1"p1
#	echo mkfs.ext4 -v -L boot      "$1"p2
#	mkfs.ext4      -v -L boot      "$1"p2
#	echo mkfs.ext4 -v -L recovery  "$1"p3
#	mkfs.ext4      -v -L recovery  "$1"p3
	echo mkfs.ext4 -v -L cache     "$1"p5
	mkfs.ext4      -v -L cache     "$1"p5
# tmp solution start	
	echo mkdosfs   -v -n swap      "$1"p6
	mkdosfs        -v -n swap      "$1"p6
# tmp solution end	
	echo mkdosfs   -v -n u-boot-logo     "$1"p7
	mkdosfs        -v -n u-boot-logo     "$1"p7
	echo mkdosfs   -v -n kernel-logo     "$1"p8
	mkdosfs        -v -n kernel-logo     "$1"p8
#	echo mkfs.ext4 -v -L misc      "$1"p9
#	mkfs.ext4      -v -L misc      "$1"p9
	echo mkfs.ext4 -v -L efs       "$1"p10
	mkfs.ext4      -v -L efs       "$1"p10
#	echo mkfs.ext4 -v -L radio     "$1"p11
#	mkfs.ext4      -v -L radio     "$1"p11
	echo mkfs.ext4 -v -L keydata   "$1"p12
	mkfs.ext4      -v -L keydata   "$1"p12
	echo mkfs.ext4 -v -L userdata  "$1"p13
	mkfs.ext4      -v -L userdata  "$1"p13

	sync; sleep 1;
}

inst_filesystem_emmc ()
{
	local device=$1
	local mount_point=/tmp/mtd
	local prev_ratio=$g_ratio
	local _ratio=

	printf "Writing EMMC device... Please wait."

	if [ ! -e "${mount_point}" ]; then
		mkdir -p ${mount_point}
	fi

	if [ "$device" == "" ]; then
		device=/dev/mmcblk1p1
	fi

	umount -f /mnt/mmcblk1p[1-13]
	mount -t ext4 $device $mount_point

	local_cwd="$srcdir/packages"
	if [ -e "$local_cwd" ]; then
		packages=`find $local_cwd -name "*.tgz" | sort`
		pkglist=
		pkgtotal=0
		pkgcount=0
		echo
		for f in $packages ; do
			pkglist="$pkglist $f"
			let 'pkgtotal = pkgtotal + 1'
		done
		for f in $pkglist ; do
			let 'pkgcount = pkgcount + 1'
			_ratio=`expr $prev_ratio + \( 100 - $prev_ratio \) \* $pkgcount / $pkgtotal`
			ratio $_ratio
			msg "`base_name $local_cwd/ $f`"
			echo "Install $f ($pkgcount / $pkgtotal)"
			tar zxf $f -C ${mount_point} >/dev/null 
			sleep 1
		done
	fi

	sync
	umount -f ${mount_point}
	printf "\b\b\b\b\b\b\b\b\b\b\b\bdone.        \n"
}

ratio 0; msg "creating partition table"; make_mbr /dev/mmcblk1


mkdir -p /mnt/swap
mount -t vfat /dev/mmcblk1p6 /mnt/swap

ratio 5; msg "installing uzImage.bin"; cp `whereis uzImage.bin` /mnt/swap
ratio 10; msg "installing boot.img"; cp `whereis boot.img` /mnt/swap
ratio 15; msg "installing boot.img"; dd if=`whereis boot.img` of=/dev/mmcblk1p2
ratio 20; msg "installing recovery.img"; cp `whereis recovery.img` /mnt/swap
ratio 25; msg "installing recovery.img"; dd if=`whereis recovery.img` of=/dev/mmcblk1p3
ratio 30; msg "installing initrd.img"; cp `whereis initrd.img` /mnt/swap


mkdir -p /mnt/ubootlogo
mkdir -p /mnt/kernellogo
mount -t vfat /dev/mmcblk1p7 /mnt/ubootlogo
mount -t vfat /dev/mmcblk1p8 /mnt/kernellogo

ratio 40; msg "installing u-boot-logo.data"; cp `whereis u-boot-logo.data` /mnt/ubootlogo
ratio 45; msg "installing kernel-logo.data"; cp `whereis kernel-logo.data` /mnt/kernellog

sync; sleep 1;               

umount /mnt/swap
umount /mnt/ubootlogo
umount /mnt/kernellogo

ratio  50; msg "installing w-load.bin"; inst_wload_sf
ratio  60; msg "installing u-boot.bin"; inst_uboot_sf
ratio  70; msg "installing bspinst.cfg"; 
	bspinst_netcfg.sh $srcdir/bspinst.cfg
	bspinst_loadcfg.sh $srcdir/bspinst.cfg > /tmp/setenv.cfg
	setenv /tmp/setenv.cfg
ratio  80; msg "installing filesystem"; inst_filesystem_emmc

bspinst_stop
