# Copyright (c) 2008-2011 WonderMedia Technologies, Inc. All Rights Reserved.
#
# This PROPRIETARY SOFTWARE is the property of WonderMedia Technologies, Inc.
# and may contain trade secrets and/or other confidential information of
# WonderMedia Technologies, Inc. This file shall not be disclosed to any
# third party, in whole or in part, without prior written consent of
# WonderMedia.
#
# THIS PROPRIETARY SOFTWARE AND ANY RELATED DOCUMENTATION ARE PROVIDED
# AS IS, WITH ALL FAULTS, AND WITHOUT WARRANTY OF ANY KIND EITHER EXPRESS
# OR IMPLIED, AND WONDERMEDIA TECHNOLOGIES, INC. DISCLAIMS ALL EXPRESS
# OR IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE,
# quiet ENJOYMENT OR NON-INFRINGEMENT.

# BSP installation low level API

# quiet - do command in silence
# @command
quiet ()
{
	$@ 2>/dev/null >/dev/null
	#$@ >/dev/null

	return $?
}

# rpc_test
#
# Test if RPC service is ready
rpc_test ()
{
	local st=

	st=`rpc timer get_status | cut -d\  -f 3`

	if [ "$st" != "off" ] ; then
		return 127
	fi

	return 0
}

# wait_rpc_ready 
#
# Wait until RPC service is ready
wait_rpc_ready ()
{
	local st=
	while [ "$st" != "off" ] ; do
		st=`rpc timer get_status | cut -d\  -f 3`
	done
}

# regular_name - translate @name to reqular expression.
# @name
regular_name ()
{
	local name=$1
	echo -n $name | sed 's/\//\\\//g' | sed 's/\./\\\./g'
}

# base_name - extract filename from whole path name
# @path_name
# @full_name
base_name ()
{
	local path_name=$1
	local full_name=$2

	local reg_path_name=`regular_name $path_name`
	echo -n $full_name | sed "s/$reg_path_name//g"
}

# fsearch - search a file by pattern match
# @from		the searching directory
# @pattern	the file name pattern
# @result	the matched file name found
fsearch ()
{
	local from=$1
	local pattern=
	local result=

	eval "pattern=\$$2"

	if [ -z "$pattern" ]; then
		return 
	fi

	#printf "> Search for firmware ... "

	for i in `find $from -type f -name "$pattern" -follow | sort -r`
	do
		result=$i
		break
	done
	
	if [ ! -e "$result" ]; then
		#printf "Not found (%s) \n" $pattern
		printf "fsearch: file is not found (%s) \n" $pattern
	else
		#printf "Found \n%s\n" $result
		eval "$2=\"$result\""

		if [ $# == 3 ]; then
			eval "$3=\"$result\""
		fi
	fi
}

# fcheck - terminate program if the file doesn't exist
# @file		the name of the target file
fcheck ()
{
	local file=$1

	if [ ! -e "$file" ]; then
		printf "The required file is missing. ($file)\n"
		exit 0;
	fi
}

# get_mtd - get mtd device by name
# @name
get_mtd ()
{
	desc=`echo $1 | sed 's/\ /\\\ /g'`
	cat /proc/mtd | grep "\"$desc\"" | cut -d: -f1 | sed 's/mtd/\/dev\/mtd/g'
}

# get_mtdblock - get mtdblock device by name
# @name
get_mtdblock ()
{
	get_mtd "$1" | sed 's/mtd/mtdblock/g'
}

# get_mtd_len - get mtd length by name
# @name
get_mtd_len ()
{
	tmp=`cat /proc/mtd |grep "\"$1\""|cut -d\  -f 2`
	len=`printf "0x%x" 0x$tmp`

	echo $len
}

# get_mtd_ofs - get mtd ofs on NAND flash
get_mtd_ofs ()
{
	get_nand_ofs.sh $1
}

get_src_dir()
{
	if [ -e ./bspinst.cfg ]; then
		echo "$PWD"
	elif [ -e ./bspinst ]; then
		echo "$PWD/bspinst"
	elif [ -e /mnt/mmcblk0p1/bspinst ]; then
		echo "/mnt/mmcblk0p1/bspinst"
	elif [ -e /mnt/sda1/bspinst ]; then
		echo "/mnt/sda1/bspinst"
	fi
}

get_cfg()
{
	local srcdir=`get_src_dir`
	local val=`bspinst_loadcfg.sh $srcdir/bspinst.cfg $1 \
		|grep $2|cut -d\  -f 3`
	echo $val
}

os_type ()
{
	# if [ ! -e /proc/binder/state ]; then
	#	echo "Linux"
	# else
	#	echo "Android"
	# fi
	local os=`get_cfg senario bspinst.os`
	if [ ! -z "$os" ]; then
		echo $os
	else
		echo "Unknown"
	fi
}

# sf_inst - copy from a file onto SPI flash
# @name
# @file
#
# The default search path is the current folder
# if $src_dir is invalid.
sf_inst ()
{
	local name=$1
	local file=$2
	local srcdir=`get_src_dir`
	local mtd=

	mtd=`get_mtd "$name"`

	if [ -z "$mtd" ]; then
		echo "No MTD partition called $name."
		return 0
	fi

	quiet fsearch $srcdir file

	if [ -e "$file" ]; then
		printf "Update %s to %s ... " $file $mtd
		quiet flash_eraseall $mtd
		if [ -e /usr/sbin/flashcp ]; then
			quiet flashcp $file $mtd
		else
			cat $file > $mtd
		fi
		printf "done\n"
	fi
}

# nand_inst - copy from a file onto SPI flash
# @name
# @file
#
# The default search path is the current folder
# if $src_dir is invalid.
nand_inst ()
{
	local name=$1
	local file=$2
	local srcdir=`get_src_dir`
	local mtd=

	mtd=`get_mtd "$name"`

	if [ -z "$mtd" ]; then
		echo "No MTD partition called $name."
		return 0
	fi

	quiet fsearch $srcdir file

	if [ -e "$file" ]; then
		printf "Update %s to %s ... " $file $mtd
		quiet flash_eraseall $mtd
		if [ -e /usr/sbin/nandwrite ]; then
			if [ "$2" == "system.img" ]; then
				# yaffs2
				quiet nandwrite -a -o $mtd $file
			else
				# raw
			quiet nandwrite -p $mtd $file
			fi
		else
			cat $file > $mtd
		fi
		printf "done\n"
	fi
}

# getvers_a - get version from U-Boot, U-Load, and Kernel
# @Keyword
getvers_a ()
{
	local ver=

	case $1 in
	U-Boot*)
		f=`get_mtd "u-boot-SF"`
		ver=`strsearch $f "U-Boot Version" 3`
		;;
	W-Load*)
		f=`get_mtd "w-load-SF"`
		ver=`strsearch $f "W-Load Version" 2`
		;;
	Kernel*)
		f="/proc/version"
		ver=`strsearch $f "Kernel" 1`
		;;	
	esac

	if [ "$ver" == "" ]; then
		ver="0.00.00.00"
	fi

	echo $1 $ver
}

# getvers_b - get version from version file
# @Keyword
getvers_b ()
{
	local srcdir=`get_src_dir`
	local ret
	if [ -e "$srcdir/version" ]; then
		ret=`cat $srcdir/version | grep $1 | cut -d':' -f 2`
	fi
	if [ "$ret" ]; then
		echo "$ret"
	else
		echo " "
	fi
}

hex_to_dec ()
{
	printf "%u" $1
}

dec_to_hex ()
{
	printf "0x%x" $1
}

# envfix
#
# Remove duplicated settings
envfix ()
{
	local tmpfile=/tmp/envfix.tmp

	touch $tmpfile
	
	while read line; do
		echo "$line" >> $tmpfile
	done

	n=`cat $tmpfile | wc -l`

	while [ $n -gt 0 ]; do
		token=`head -1 $tmpfile | cut -d= -f1`
		#dupl=`cat $tmpfile | grep ^$token | wc -l`
		dupl=0
		list=`cat $tmpfile | cut -d= -f1`
		for x in $list; do
			if [ "$x" == "$token" ]; then
				let 'dupl = dupl + 1'
			fi
		done
		if [ $dupl -eq 1 ]; then
			head -1 $tmpfile
		else
			echo -n "(!) skip " >&2
			head -1 $tmpfile >&2
		fi
		sed '1d' -i $tmpfile
		let 'n = n - 1'
	done

	rm -f $tmpfile
}

# do_setenv_nand
# @uboot_env	U-boot script in plain text format
# @mtd		MTD device used by U-Boot env.
#
# Save uboot environment variables from u-boot plain text script
#
# Usage:
#     do_setenv_nand /mnt/mmcblk0p1/env/uboot_env_sf /dev/mtd7
do_setenv_nand ()
{
	local infile=$1
	local mtd=$2

	local outfile=/tmp/do_setenv_nand.raw
	local tmpfile=/tmp/do_setenv_nand.tmp

	dd if=/dev/zero of=${outfile} bs=1k count=64

	cat ${infile} | \
	tr '\n' '~' | sed 's/\\~//g' | tr '~' '\n' | \
	sed 's/\ \+/ /g' | \
	grep setenv | sed 's/setenv //' | sed 's/ /=/' | \
	sed 's/\\;/;/g' | grep -v \# | envfix | tr "\n" "\0" > ${tmpfile}

	dd if=${tmpfile} of=${outfile} bs=1 seek=4 count=65532 conv=notrunc

	crc32 -s 4 -x 1 ${outfile}
	crc32 -s 4 -r ${outfile} > ${tmpfile}
	dd if=${tmpfile} of=${outfile} bs=1 seek=0 count=4 conv=notrunc

	flash_eraseall $mtd
	nandwrite -p -s 0  $mtd ${outfile}

	rm -f ${tmpfile} ${outfile}
}

# setenv_nand
# @uboot_env	U-boot script in plain text format
#
# Save uboot environment variables from u-boot plain text script
#
# Usage:
#     setenv "uboot_env_nand"
setenv_nand ()
{
	local mtd_name=
	local mtd=

	mtd_name="u-boot env. cfg. 1-NAND"
	mtd=`get_mtd "${mtd_name}"`

	if [ ! -z "${mtd}" ]; then
		echo do_setenv_nand $1 ${mtd}
		do_setenv_nand $1 ${mtd}
	else
		echo "No MTD partition called ${mtd_name}."
	fi
}

# do_setenv
# @uboot_env	U-boot script in plain text format
# @mtd		MTD device used by U-Boot env.
# @flag		active flag
#
# Save uboot environment variables from u-boot plain text script
#
# Usage:
#     do_setenv /mnt/mmcblk0p1/env/uboot_env_sf /dev/mtd3 1
do_setenv ()
{
	local infile=$1
	local mtd=$2
	local flag=$3
	local outfile=/tmp/do_setenv.raw
	local tmpfile=/tmp/do_setenv.tmp

	dd if=/dev/zero of=${outfile} bs=1k count=64

	cat ${infile} | \
	tr '\n' '~' | sed 's/\\~//g' | tr '~' '\n' | \
	sed 's/\ \+/ /g' | \
	grep setenv | sed 's/setenv //' | sed 's/ /=/' | \
	sed 's/\\;/;/g' | grep -v \# | envfix | tr "\n" "\0" > ${tmpfile}

	dd if=${tmpfile} of=${outfile} bs=1 seek=5 count=65531 conv=notrunc

	crc32 -s 5 -x 1 ${outfile}
	crc32 -s 5 -r ${outfile} > ${tmpfile}
	printf "\x${flag}" >> ${tmpfile}
	dd if=${tmpfile} of=${outfile} bs=1 seek=0 count=5 conv=notrunc

	flash_eraseall $mtd
	cat ${outfile} > $mtd

#	rm -f ${tmpfile} ${outfile}
}

# setenv
# @uboot_env	U-boot script in plain text format
#
# Save uboot environment variables from u-boot plain text script
#
# Usage:
#     setenv "uboot_env_sf"
setenv ()
{
	local mtd_name=
	local mtd=
	local uboot_env=$1
	local tmpfile=/tmp/setenv.tmp

	cp $1 ${tmpfile}

	mtd_name="u-boot env. cfg. 1-SF"
	mtd=`get_mtd "${mtd_name}"`

	if [ ! -z "${mtd}" ]; then
		do_setenv ${tmpfile} ${mtd} 1
	else
		echo "No MTD partition called ${mtd_name}."
	fi

	mtd_name="u-boot env. cfg. 2-SF"
	mtd=`get_mtd "${mtd_name}"`

	if [ ! -z "${mtd}" ]; then
echo		do_setenv ${tmpfile} ${mtd} 0
	else
		echo "No MTD partition called ${mtd_name}."
	fi

	rm -f ${tmpfile}
}

# strsearch
# @file
# @string
# @offset
#
# Search a word at the offset of the specific string.
strsearch ()
{
	if [ $# -lt 3 ]; then
		return
	fi

	local match=0
	local ofs=$3
	local uniq_word=`echo $2 | sed 's/ /_/g'`
	local tokens=`strings $1 | sed "s/$2/$uniq_word/g" | tr -d ![]`
	local keyword=`strings $1 | grep "$2"`

	if [ "$keyword" == "" ]; then
		return
	fi

	for i in $tokens ; do
		if [ "$i" == "$uniq_word" ]; then
			match=1
		fi
		if [ $match == 1 ]; then
			if [ $ofs == 0 ]; then
				echo $i
				return
			else
				let "ofs = ofs - 1"
			fi
		fi
	done
}

#
# PLEASE DON'T MODIFY FUNCTIONS ABOVE THIS LINE.
# THOSE FUNCTIONS ARE THE HEART OF BSPINST2.
#

inst_wload_sf ()
{
	sf_inst "w-load-SF" "w-load.bin"
}

inst_uboot_sf ()
{
	sf_inst "u-boot-SF" "u-boot.bin"
}

inst_kernel_sf ()
{
	sf_inst "kernel-SF" "uzImage.bin"
}

inst_initrd_sf ()
{
	sf_inst "filesystem-SF" "initrd.img"
}

inst_filesystem_sf ()
{
	sf_inst "filesystem-SF" "rootfs*.img"
}

inst_filesystem_cramfs ()
{
       sf_inst "filesystem-SF" "rootfs*.img"
}

inst_wload_nand ()
{
	nand_inst "w-load-NAND" "w-load.bin"
}

inst_uboot_nand ()
{
	nand_inst "u-boot-NAND" "u-boot-nand.bin"
}

inst_kernel_nand ()
{
	# lagacy mode
	nand_inst "boot" "uzImage.bin"

	# OTA mode
	nand_inst "boot"     "boot.img"
	nand_inst "recovery" "recovery.img"

	setenv.sh "boot_blk" "`get_mtdblock "boot"`"
	setenv.sh "boot_ofs" "`get_mtd_ofs  "boot"`"
	setenv.sh "boot_len" "`get_mtd_len  "boot"`"

	setenv.sh "recovery_blk" "`get_mtdblock "recovery"`"
	setenv.sh "recovery_ofs" "`get_mtd_ofs  "recovery"`"
	setenv.sh "recovery_len" "`get_mtd_len  "recovery"`"

	setenv.sh "system_blk" "`get_mtdblock "system"`"
	setenv.sh "system_ofs" "`get_mtd_ofs  "system"`"
	setenv.sh "system_len" "`get_mtd_len  "system"`"
}

inst_initrd_nand ()
{
	nand_inst "initrd-NAND" "initrd.img"
}

inst_uboot_env_sf ()
{
	setenv /tmp/setenv.cfg
}

inst_uboot_env_nand ()
{
	setenv_nand /tmp/setenv.cfg
}

# inst_filesystem_nand
#
# Install software packages into NAND rootfs
#
# The default search path is the current folder
# if $src_dir is invalid.
inst_filesystem_nand ()
{
	local nand2=
	local nandblock2=
	local mount_point=/tmp/mtd
	local ret=
	local i=
	local prev_ratio=$g_ratio
	local srcdir=`get_src_dir`
	local x=

	nand2=`get_mtd "system"`
	nandblock2=`get_mtdblock "system"`

	pkg_dir="$srcdir/packages"
	if [ -e "$pkg_dir" ]; then
		x=`find $pkg_dir -name "*.tgz" | sort`
		i=0
		for f in $x ; do
			let 'i = i + 1'
		done
		if [ $i -eq 0 ]; then
			echo "No package was found. Skip!"
			return
		fi
	else
		echo "No package was found. Skip!"
		return	
	fi

	echo
	printf "Erasing MTD device (%s)... Please wait." $nand2

	if [ ! -e "${mount_point}" ]; then
		mkdir -p ${mount_point}
	fi

	sync
	umount ${mount_point} 2>/dev/null
	flash_eraseall $nand2 > /dev/null
	printf "\b\b\b\b\b\b\b\b\b\b\b\bdone.        \n"

	printf "Writing MTD device (%s)... Please wait." $nandblock2

	x=`cat $srcdir/bspinst.cfg |grep setenv|grep boot-method|cut -d\  -f3`
	if [ "$x" == "boot-nand-ubifs" ]; then
		ubiformat -y $nand2
		ubiattach -p $nand2
		ubimkvol /dev/ubi0 -N "system" -m
		mount -t ubifs ubi0:"system" ${mount_point}
	else
		nand_inst "system" "system.img"
		mount -t yaffs2 -o rw $nandblock2 ${mount_point}
	fi

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
			if [ $g_ui -eq 1 ]; then
#				i=`expr $prev_ratio + \( 100 - $prev_ratio \) \* $pkgcount / $pkgtotal`
                i=`expr $prev_ratio + \( 90 - $prev_ratio \) \* \( $pkgcount - 1 \) / $pkgtotal`
				ratio $i
				msg "`base_name $local_cwd/ $f`"
			fi
			echo "Install $f ($pkgcount / $pkgtotal)"
			tar zxf $f -C ${mount_point} >/dev/null 
			sleep 1
		done
	fi

	sync
	umount ${mount_point}

	x=`cat $srcdir/bspinst.cfg |grep setenv|grep boot-method|cut -d\  -f3`
	if [ "$x" == "boot-nand-ubifs" ]; then
		ubidetach -p $nand2
	fi
	printf "\b\b\b\b\b\b\b\b\b\b\b\bdone.        \n"
}

whereis ()
{
	local file=$1
	local srcdir=`get_src_dir`

	quiet fsearch $srcdir file

	echo $file
}

catch_input_event ()
{
	local handler=/usr/bin/input.sh
	local code=/tmp/catch_input_event.dat
	if [ ! -e $handler ]; then
		echo "#!/bin/sh" > $handler
		echo "echo \$1 > $code" >> $handler
		chmod +x $handler
		sync
	fi

	rm -f $code

	while [ ! -e $code ]; do
		sleep 1
	done

	cat $code
}

show_next_mac ()
{
	let "s = 0"
	for i in 1 2 3 4 5 6; do
		let "u$i = `echo $1|cut -d: -f$i|xargs printf "0x%s"|\
			xargs printf "%u"`"
		let "s = s * 256 + u$i"
	done

	let "s = s + 1"

	for i in 6 5 4 3 2 1; do
		let "u$i = `expr $s % 256`"
		let "s = s / 256 "
	done
	
	printf "%02x:%02x:%02x:%02x:%02x:%02x\n" $u1 $u2 $u3 $u4 $u5 $u6 |\
		tr [a-z] [A-Z]
}

edit_config ()
{
	if [ $# -lt 2 ]; then
		echo "Usage: edit_config config name [value]"
		return
	fi

	local config=$1
	local name=$2
	local value=$3
	local old_value=

	if [ -e "$config" ]; then
		old_value=`cat $config | grep ^$name | cut -d= -f2`
	fi

	if [ -z "$old_value" ]; then
		if [ ! -z "$value" ]; then
			# add
			echo "$name=$value" >> $config
			return
		fi
	else
		if [ ! -z "$value" ]; then
			# modify
			old_value=`regular_name $old_value`
			value=`regular_name $value`
			sed "s/^$name=$old_value/^$name=$value/g" -i $config
		else
			# delete
			old_value=`regular_name $old_value`
			sed "s/^$name=$old_value//g" -i $config
		fi
	fi
	sed "/^$/d" -i $config
}

# get_var - load environment variables 
# @args
get_var ()
{
	for exp in $@; do
		eval $exp
	done
}

rpc_start ()
{
	srcdir=`get_src_dir`
	fstype=`cat /proc/mounts |grep \/dev\/root|cut -d\  -f3| head -n 1`
	ini="/tmp/bspinst.ini"
	mdev -s
	get_var $@
	fbset > /etc/fb.modes
	mount -t proc none /proc
	mount -t tmpfs none /dev/shm

	if [ $g_ui -eq 0 ]; then
		return 1
	fi

	echo "[font1]" > $ini
	echo "size = $g_fs" >> $ini
	echo "file = $g_font1" >> $ini
	echo >> $ini
	echo "[signage]" >> $ini
	echo "blank = 1" >> $ini

	args="--dfb:bg-none,no-hardware"

	echo "fstype = $fstype"

	quiet rpc_test
	if [ $? -ne 0 ]; then
		cat /dev/zero >/dev/fb0 2>/dev/null
		bspinst2 -s -i 1 -f /tmp/bspinst.ini $args &
	fi
	wait_rpc_ready
}

render_main ()
{
	local os=`os_type`

	if [ $g_ui -eq 0 ]; then
		return 1
	fi

	set_color 0 0 255
	fillrect 0 0 $g_xres $g_yres

	set_font_color 255 255 255

	if [ "${os}" == "Linux" ]; then
		drawstr `fsmul 2` `bsmul 1`  "WonderMedia Linux BSP Installation"
		drawstr `fsmul 2` `bsmul 2`  `getvers_b _Linux_`
		drawstr `fsmul 2` `bsmul 4`  "----------------------------------"
	else
		drawstr `fsmul 2` `bsmul 1`  "APC System Software Installation"
		drawstr `fsmul 2` `bsmul 2`  `getvers_b _Android_`
		drawstr `fsmul 2` `bsmul 4`  "------------------------------------"
		drawstr `fsmul 2` `bsmul 16` "DO NOT POWER OFF"
	fi

	drawstr `fsmul 4` `bsmul 6`  `getvers_a W-Load`" ->"`getvers_b W-Load`
	drawstr `fsmul 4` `bsmul 7`  `getvers_a U-Boot`" ->"`getvers_b U-Boot`
	drawstr `fsmul 4` `bsmul 8`  `getvers_a Kernel`" ->"`getvers_b Kernel`
	drawstr `fsmul 4` `bsmul 9`  `getvers_b Base`
	drawstr `fsmul 4` `bsmul 10` `getvers_b Reference`
	drawstr `fsmul 4` `bsmul 11` `getvers_b OtherInfo`
	
	show_progress_bar `fsmul 4` `bsmul 13` `fsmul 15` `fsmul 1` 0
	# show_warnings_by_ticker
}

bspinst_start ()
{
	rpc_start
	render_main
	
}

bspinst_stop ()
{
	msg "Now remove the microSD card"

  

	# Wait until storage unplugged or ENTER pressed

	if [ -e /proc/mounts ]; then
		i=`cat /proc/mounts|wc -l`
		j=`cat /proc/mounts|wc -l`
		while [ $j == $i ]; do
			read -t 1 key
			if [ $? -eq 0 ]; then
				break
			fi
			j=`cat /proc/mounts|wc -l`
		done
	else
		while [ -e $0 ]; do
			read -t 1 key
			if [ $? -eq 0 ]; then
				break
			fi
		done
	fi

	sync
	stop_delay 3
	reboot -f -n
}

