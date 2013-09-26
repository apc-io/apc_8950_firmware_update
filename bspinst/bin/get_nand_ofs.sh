#!/bin/sh
#
# Query mtd offset on NAND flash
#

if [ $# -lt 1 ]; then
	echo "usage: get_nand_ofs.sh [filesystem-NAND|mtd11]"
	exit 0
fi

bindir=$PWD/bin:$PWD/bspinst/bin:/mnt/mmcblk0p1/bspinst/bin:/mnt/sda1/bspinst/bin:/usr/bin

export PATH=$bindir:$PATH

source `which bspinst_api.sh`

nand0p1=
i=0


mtdinfo=`cat /proc/mtd | grep mtd$i`

ofs=0
complete=0
while [ ! -z "$mtdinfo" ]; do
	x=`echo $mtdinfo | grep "\-SF"`
	if [ -z "$x" ] && [ -z "$nand0p1" ]; then
		nand0p1=/dev/mtd$i
	fi
	if [ ! -z "$nand0p1" ]; then
	x=`echo $mtdinfo | grep "\"$1\""`
	if [ ! -z "$x" ]; then
		complete=1
		break;
	fi
		x=`cat /proc/mtd |grep mtd$i|cut -d\  -f4|tr -d \"`
		len=`get_mtd_len $x`
	let "ofs = ofs + $len"
	fi
	let 'i = i + 1'
	mtdinfo=`cat /proc/mtd | grep mtd$i`
done

if [ $complete -eq 1 ]; then
	ofs=`dec_to_hex $ofs`
	echo $ofs
fi
