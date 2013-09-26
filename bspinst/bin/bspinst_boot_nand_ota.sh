#!/bin/sh

bindir=$PWD/bin:$PWD/bspinst/bin:/mnt/mmcblk0p1/bspinst/bin:/mnt/sda1/bspinst/bin:/usr/bin

export PATH=$bindir:$PATH

source `which bspinst_var.sh`
source `which bspinst_ui.sh`
source `which bspinst_api.sh`

srcdir=`get_src_dir`

echo srcdir = $srcdir

bspinst_start

interactive=`get_cfg senario bspinst.interactive`

if [ "$interactive" == "yes" ]; then
	msg "Press [MENU] to install or [BACK] to quit"
	code=`catch_input_event`

	if [ "$code" == "0x9e" ]; then
		rpc ticker stop
		set_color 0 0 0
		fillrect 0 0 $g_xres $g_yres
		sleep 1
		rpc sys shutdown
		exit 0
	fi
fi

ratio   0; msg "installing w-load.bin"; inst_wload_sf
ratio  10; msg "installing u-boot.bin"; inst_uboot_sf
ratio  20; msg "installing bspinst.cfg"; 
	bspinst_netcfg.sh $srcdir/bspinst.cfg
	bspinst_loadcfg.sh $srcdir/bspinst.cfg > /tmp/setenv.cfg
	setenv /tmp/setenv.cfg
ratio  30; msg "installing kernel"; inst_kernel_nand
ratio  40; msg "installing filesystem"; inst_filesystem_nand
ratio  90; msg "installing addons"; `which bspinst_addons.sh`
ratio 100;

bspinst_stop
