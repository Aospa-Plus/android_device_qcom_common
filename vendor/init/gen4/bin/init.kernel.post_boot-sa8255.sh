#=============================================================================
# Copyright (c) 2020-2023 Qualcomm Technologies, Inc.
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#
# Copyright (c) 2009-2012, 2014-2019, The Linux Foundation. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of The Linux Foundation nor
#       the names of its contributors may be used to endorse or promote
#       products derived from this software without specific prior written
#       permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NON-INFRINGEMENT ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
# OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#=============================================================================

silver_cores_list=(0 1 2 3)
gold_cores_list=(4 5 6 7)

boot_core=`grep "OF_FULLNAME" /sys/devices/system/cpu/cpu0/uevent | grep -o [1-9]`
if [ -z "$boot_core" ]; then
	boot_core=0
fi
cpu_arr[0]=$boot_core

j=1
for i in $(seq 0 7);
do
	if [ $i -ne $boot_core ]; then
		cpu_arr[j]=$i
	fi
	j=`expr $j + 1`
done

function find_index_of() {
	i=0
	for cpu in "${cpu_arr[@]}";
	do
		if [ $1 -eq $cpu ]; then
			return $i
		fi
		i=`expr $i + 1`
	done
}

cpunum=`printf '%s\n' "${silver_cores_list[@]}" | awk '$1 < m || NR == 1 { m = $1 } END { print m }'`
find_index_of $cpunum
silver_core=$?
cpunum=`printf '%s\n' "${gold_cores_list[@]}" | awk '$1 < m || NR == 1 { m = $1 } END { print m }'`
find_index_of $cpunum
gold_core=$?

cpufreq_silver="/sys/devices/system/cpu/cpufreq/policy${silver_core}"
cpufreq_gold="/sys/devices/system/cpu/cpufreq/policy${gold_core}"

if [ ! -d $cpufreq_silver ]; then
	echo "Directory $cpufreq_silver does not exists."
fi
if [ ! -d $cpufreq_gold ]; then
	echo "Directory $cpufreq_gold does not exists."
fi

function configure_automotive_sku_parameters() {
    echo 1267200 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
    echo 1267200 > /sys/devices/system/cpu/cpu4/cpufreq/scaling_min_freq
    echo 2361600 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
    echo 2361600 > /sys/devices/system/cpu/cpu4/cpufreq/scaling_max_freq

}

# Configure RT parameters:
# Long running RT task detection is confined to consolidated builds.
# Set RT throttle runtime to 50ms more than long running RT
# task detection time.
# Set RT throttle period to 100ms more than RT throttle runtime.
long_running_rt_task_ms=1200
sched_rt_runtime_ms=`expr $long_running_rt_task_ms + 50`
sched_rt_runtime_us=`expr $sched_rt_runtime_ms \* 1000`
sched_rt_period_ms=`expr $sched_rt_runtime_ms + 100`
sched_rt_period_us=`expr $sched_rt_period_ms \* 1000`
if [ -d /sys/module/sched_walt_debug ]; then
        echo $long_running_rt_task_ms > /proc/sys/walt/sched_long_running_rt_task_ms
fi
echo $sched_rt_period_us > /proc/sys/kernel/sched_rt_period_us
echo $sched_rt_runtime_us > /proc/sys/kernel/sched_rt_runtime_us

	# Core control parameters for gold
	echo 2 > /sys/devices/system/cpu/cpu${gold_core}/core_ctl/min_cpus
	echo 60 > /sys/devices/system/cpu/cpu${gold_core}/core_ctl/busy_up_thres
	echo 30 > /sys/devices/system/cpu/cpu${gold_core}/core_ctl/busy_down_thres
	echo 100 > /sys/devices/system/cpu/cpu${gold_core}/core_ctl/offline_delay_ms
	echo 4 > /sys/devices/system/cpu/cpu${gold_core}/core_ctl/task_thres

	# Disable Core control on silver
	echo 0 > /sys/devices/system/cpu/cpu${silver_core}/core_ctl/enable

	# Setting b.L scheduler parameters
	echo 95 > /proc/sys/walt/sched_upmigrate
	echo 85 > /proc/sys/walt/sched_downmigrate
	echo 100 > /proc/sys/walt/sched_group_upmigrate
	echo 10 > /proc/sys/walt/sched_group_downmigrate

	# cpuset parameters
	echo 0-3 > /dev/cpuset/background/cpus
	echo 0-3 > /dev/cpuset/system-background/cpus

	# configure governor settings for silver cluster
	echo "walt" > $cpufreq_silver/scaling_governor
	echo 0 > $cpufreq_silver/walt/up_rate_limit_us
	echo 0 > $cpufreq_silver/walt/down_rate_limit_us
	echo 1632000 > $cpufreq_silver/walt/hispeed_freq
	echo 1 > $cpufreq_silver/walt/pl

	# configure governor settings for gold cluster
	echo "walt" > $cpufreq_gold/scaling_governor
	echo 0 > $cpufreq_gold/walt/up_rate_limit_us
	echo 0 > $cpufreq_gold/walt/down_rate_limit_us
	echo 1632000 > $cpufreq_gold/walt/hispeed_freq
	echo 1 > $cpufreq_gold/walt/pl

	# configure input boost settings
	echo "1536000" > /proc/sys/walt/input_boost/input_boost_freq
	echo 120 > /proc/sys/walt/input_boost/input_boost_ms

	# Disable wsf, beacause we are using efk.
	# wsf Range : 1..1000 So set to bare minimum value 1.
	echo 1 > /proc/sys/vm/watermark_scale_factor

	bus_dcvs="/sys/devices/system/cpu/bus_dcvs"
	for device in $bus_dcvs/*
	do
		cat $device/hw_min_freq > $device/boost_freq
	done

	for llccbw in $bus_dcvs/LLCC/*bwmon-llcc
	do
		echo "2288 4577 7110 9155 12298 14236 15258" > $llccbw/mbps_zones
		echo 4 > $llccbw/sample_ms
		echo 50 > $llccbw/io_percent
		echo 5 > $llccbw/hist_memory
		echo 10 > $llccbw/hyst_length
		echo 30 > $llccbw/down_thres
		echo 0 > $llccbw/guard_band_mbps
		echo 250 > $llccbw/up_scale
		echo 1600 > $llccbw/idle_mbps
		echo 14236 > $llccbw/max_freq
		echo 40 > $llccbw/window_ms
	done

	for ddrbw in $bus_dcvs/DDR/*bwmon-ddr
	do
		echo "1720 2929 3879 5931 6881 7980" > $ddrbw/mbps_zones
		echo 4 > $ddrbw/sample_ms
		echo 80 > $ddrbw/io_percent
		echo 7 > $ddrbw/hist_memory
		echo 10 > $ddrbw/hyst_length
		echo 30 > $ddrbw/down_thres
		echo 0 > $ddrbw/guard_band_mbps
		echo 250 > $ddrbw/up_scale
		echo 1600 > $ddrbw/idle_mbps
		echo 6881 > $ddrbw/max_freq
		echo 40 > $ddrbw/window_ms
	done

# Turn off scheduler boost at the end
echo 0 > /proc/sys/walt/sched_boost
echo 1 > /proc/sys/walt/sched_walt_rotate_big_tasks

setprop vendor.dcvs.prop 1
configure_automotive_sku_parameters
echo N > /sys/devices/system/cpu/qcom_lpm/parameters/sleep_disabled

# Let kernel know our image version/variant/crm_version
if [ -f /sys/devices/soc0/select_image ]; then
	image_version="10:"
	image_version+=`getprop ro.build.id`
	image_version+=":"
	image_version+=`getprop ro.build.version.incremental`
	image_variant=`getprop ro.product.name`
	image_variant+="-"
	image_variant+=`getprop ro.build.type`
	oem_version=`getprop ro.build.version.codename`
	echo 10 > /sys/devices/soc0/select_image
	echo $image_version > /sys/devices/soc0/image_version
	echo $image_variant > /sys/devices/soc0/image_variant
	echo $oem_version > /sys/devices/soc0/image_crm_version
fi

# Change console log level as per console config property
console_config=`getprop persist.vendor.console.silent.config`
case "$console_config" in
	"1")
		echo "Enable console config to $console_config"
		echo 0 > /proc/sys/kernel/printk
	;;
	*)
		echo "Enable console config to $console_config"
	;;
esac

setprop vendor.post_boot.parsed 1
