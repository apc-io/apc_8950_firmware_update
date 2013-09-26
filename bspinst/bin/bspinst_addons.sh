#!/bin/sh
#
# Add-ons for user-defined installation
#

clear_userdata=yes

printf "\nExecute bspinst_addons.sh\n\n"

bindir=$PWD/bin:$PWD/bspinst/bin:/mnt/mmcblk0p1/bspinst/bin:/mnt/sda1/bspinst/bin:/usr/bin

export PATH=$bindir:$PATH

source `which bspinst_api.sh`

inst_localdisk_nand ()
{
	mtdblock=`get_mtdblock "LocalDisk"`
	mtd_len=`get_mtd_len "LocalDisk"`
	mtd_lendec=`echo $(($mtd_len))`
	mtd_full_reserve=$(( $mtd_lendec + 1073741824 ))
	mtd_full_reserve=$(( $mtd_full_reserve * 5 ))
	mtd_full_reserve=$(( $mtd_full_reserve / 100 ))
	mtd_small_reserve=$(( $mtd_lendec * 5 ))
	mtd_small_reserve=$(( $mtd_small_reserve / 100 ))
	mtd_reserve=$(( $mtd_lendec - $mtd_full_reserve ))	
	mtd_min=10485760
	if [ "$(($mtd_reserve))" -le "$(($mtd_min))" ]; then
		mtd_lendec=$(( $mtd_lendec - $mtd_small_reserve ))
	else
		mtd_lendec=$(( $mtd_lendec - $mtd_full_reserve ))
	fi
	udc_dir=/mnt/localdisk
	udc_file=${udc_dir}/backfile.vfat
	udc_mount_point=/LocalDisk
	udc_loop_dev=/dev/block/loop0

	flash_eraseall `get_mtd "LocalDisk"`

	echo -n "Creating UDC udc_file...\n"
	/bin/mkdir -p ${udc_dir}
	/bin/mount -t yaffs2 -o rw ${mtdblock} ${udc_dir}
	dd bs=1 seek=$mtd_lendec count=1 if=/dev/zero of=${udc_file}
	mkdosfs ${udc_file}
	sync
	/bin/umount ${mtdblock}
	echo "done"
}

inst_android_data_nand ()
{
	flash_eraseall `get_mtd "userdata"`
}

inst_android_cache_nand()
{
	flash_eraseall `get_mtd "cache"`
}

android_data_init ()
{
	mtdblock_data=`get_mtdblock "userdata"`
	data_mnt="/mnt/mtd_data"

	/bin/mkdir -p ${data_mnt}
	/bin/mount -t yaffs2 -o rw ${mtdblock_data}  ${data_mnt}
	# extract patch packages to Android data partition
	echo "update data package to data partition..."
	/bin/find $srcdir/packages/wmt_initial/tgzdata/ -name "*.tgzdata" -exec echo {} \;
	/bin/find $srcdir/packages/wmt_initial/tgzdata/ -name "*.tgzdata" -exec tar zxf {} -C ${data_mnt} \;
	/bin/find $srcdir/packages/wmt_initial/data/ -name "*" -exec echo {} \;
	/bin/cp -arf $srcdir/packages/wmt_initial/data/* ${data_mnt}
	sync
	/bin/umount ${data_mnt}
}

srcdir=`get_src_dir`
os=`os_type`
bm=`cat $srcdir/bspinst.cfg |grep setenv|grep boot-method|cut -d\  -f3`

if [ "$os" == "Android" ]; then
    if [ "$clear_userdata" == "yes" ]; then
		inst_android_data_nand
		fi
		inst_android_cache_nand
		inst_localdisk_nand

		nand_inst "u-boot-logo" "u-boot-logo.data"
		nand_inst "kernel-logo" "kernel-logo.data"

		setenv.sh "wmt.nfc.mtd.u-boot-logo" "`get_nand_ofs.sh u-boot-logo`"
		setenv.sh "wmt.nfc.mtd.kernel-logo" "`get_nand_ofs.sh kernel-logo`"

		android_data_init

fi

printf "\nExecute bspinst_addons.sh done. \n\n"

