#!/bin/bash

set -ax

# define paths and other variables
# use ABSOLUTE paths

# Dates
# Date to run is passed as argument $1
if [ -z "$1" ]; then
    echo 'MISSING argument $1 should equal date to run'
    exit 1
fi

# Provided the date 20170606 the script will retrieve data from 2017060516 to 2017060616 UTC-8
dt=$(date -d $1 -u +%Y%m%d)
today=$(date --date='today' -u +%Y%m%d)
echo $dt, $today

home_dir=$2
scripts_file_path=$home_dir'/scripts/'
grib_file_path=$home_dir'/GRIB/RDPS/'
output_log_file=$home_dir/outputs/logs/$today'.log'
if [ ! -f $output_log_file ]; then
	touch $output_log_file
fi
if [ -f $grib_file_path'RDPS-download.done' ]; 
then
	rm $grib_file_path'RDPS-download.done'
fi

remote_location1='https://dd.meteo.gc.ca/model_gem_regional/10km/grib2'
remote_location2='http://hpfx.collab.science.gc.ca/'$dt'/WXO-DD/model_gem_regional/10km/grib2/'
    run_time='18'
    minhours=5
    maxhours=84

# Met Variables to process
eval $(cat $scripts_file_path/met_variables.txt)

let hours=$maxhours-$minhours+1
F=560 #number of files to be downloaded. Used in a condition to check whether all necessary RDPS files have been downloaded.

cd $grib_file_path
# Files were already downloaded, no need to redo it
F_down=`ls *reg*$dt* |wc -l`
if [ $F_down == $F ]; then
	echo 'All RDPS files were already downloaded' >> $output_log_file
	exit
fi

trial=1
remote_location=$remote_location2

while [[ $F_down -lt F && $trial -lt 15 ]] 
do
    # DOWNLOAD the GEM grib2 files from remote_location
    echo 'RDPS download source:' $remote_location >> $output_log_file
    for hour in `seq -f %03.0f $minhours 1 $maxhours`
    do
        for variable in ${!FILESS[*]}
        do
            fvariable=${FILESS[$variable]}
            wget --no-check-certificate -r -l1 --no-parent -c -nd -A $fvariable$dt'*.grib2' $remote_location'/'$run_time'/'$hour'/'
        done
    done
    
#Counting number of files downloaded and restarting download if files are missing. Pausing 1 minute before start of download.
    F_down=`ls *reg*$dt* |wc -l` 
   #if there were more than 4 download attempts, the information is temporarily written to this file and is overwritten the next day.
    if [ $F_down -lt $F ] ;
	then
		echo 'RDPS download for' $dt 'completed' $F_down 'out of' $F 'files at' `date` 'after' $trial 'trial(s)' >> $output_log_file
		# switch to the other source
		if [ $remote_location == $remote_location1 ]; then
			remote_location=$remote_location2
		else
			remote_location=$remote_location1
		fi
		let trial=$trial+1
        #sleep 15m
    fi
done

echo 'RDPS download for' $dt 'completed' $F_down 'out of' $F 'files at' `date` 'after' $trial 'trial(s)' >> $output_log_file
if [ $F_down == $F ]; 
then
	touch $grib_file_path'RDPS-download.done'
fi
