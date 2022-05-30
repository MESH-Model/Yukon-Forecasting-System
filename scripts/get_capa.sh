#!/bin/bash
set -aex
#
# Script to extract CaPA data from Datamart and convert it to R2C format
# Provided the date 20170606 the script will retrieve data from 2017060516 to 2017060616 UTC-8
#
#   ********** FOR CaPA **********
#
# The date to run is passed as argument $1

# Working directories
# The home directory is an absolute path; other directories build from this path
# Dates
# Date to run is passed as argument $1
if [ -z "$1" ]; then
    echo 'MISSING argument $1 should equal date to run'
    exit 1
fi

# # Provided the date 20170606 the script will retrieve data from 2017060516 to 2017060616 UTC-8
#dt=$(date -d "$dt - 1 day" -u +%Y%m%d)
dt=$(date -d $1 -u +%Y%m%d)
today=$(date --date='today' -u +%Y%m%d)
echo $dt, $today

home_dir=$2
scripts_file_path=$home_dir/scripts
grib_file_path=$home_dir/GRIB
output_log_file=$home_dir/outputs/logs/$today'.log'
if [ ! -f $output_log_file ]; then
	touch $output_log_file
fi
# Remote paths
remote_location_CaPA=https://dd.weather.gc.ca/analysis/precip/rdpa/grib2/polar_stereographic/06

# Programs
bin_wgrib2=/home/ec2-user/grib2/wgrib2/wgrib2

# Variable names (to name output files)
namess[1]='rain' #(CaPA)

# Variables names (to match GRIB files)
FILESS[1]='APCP-006-0700'       # kg/m2 (6h period), (CaPA)

# Create a list of CaPA files to download from the remote location
# CaPA example filename date: 2017060706_000
set +x
date_list_CaPA=
    for hour in 06 12 18 ; do date_list_CaPA="$date_list_CaPA ${dt}${hour}_000" ; done
    for hour in 00 ; do date_list_CaPA="$date_list_CaPA $(date -d "$dt + 1 day" -u +%Y%m%d)${hour}_000"; done
set -x
date_list_CaPA=$date_list_CaPA

# 'cd' to the GRIB directory and download the files
cd $grib_file_path
for date in $date_list_CaPA
do
    for index in ${!FILESS[*]}
    do
        wget -r -l1 --no-parent -c -nd --no-check-certificate -A *${FILESS[$index]}*${date}*.grib2 $remote_location_CaPA/
    done
done

echo 'CaPA download complete at' `date` >> $output_log_file

