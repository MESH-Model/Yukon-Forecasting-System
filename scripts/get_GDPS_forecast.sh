#!/bin/bash

set -ax

# define paths and other variables
# use ABSOLUTE paths

# Dates
#Date to run is passed as argument $1
if [ -z "$1" ]; then
    echo 'MISSING argument $1 should equal date to run'
    exit 1
fi

dt=$(date -d $1 -u +%Y%m%d)
today=$(date --date='today' -u +%Y%m%d)
echo $dt, $today

home_dir=$2
scripts_file_path=$home_dir'/scripts/'
grib_file_path=$home_dir'/GRIB/GDPS/'
output_log_file=$home_dir/outputs/logs/$today'.log'
if [ ! -f $output_log_file ]; then
	touch $output_log_file
fi
if [ -f $grib_file_path'GDPS-download.done' ]; 
then
	rm $grib_file_path'GDPS-download.done'
fi

remote_location1='https://dd.meteo.gc.ca/model_gem_global/15km/grib2/lat_lon/'
remote_location2='http://hpfx.collab.science.gc.ca/'$dt'/WXO-DD/model_gem_global/15km/grib2/lat_lon/'
    run_time='12'
    minhours=009
    maxhours=240
    #interval=3

# Met Variables to process
eval $(cat $scripts_file_path/met_variables.txt)

#Number of files to be downloaded. Used in a condition to check whether all necessary GDPS files have been downloaded.
F=546

cd $grib_file_path
# Files were already downloaded, no need to redo it
F_down=`ls *glb*$dt* |wc -l`
if [ $F_down == $F ]; then
	echo 'All GDPS files were already downloaded' >> $output_log_file
	exit
fi

trial=1
remote_location=$remote_location2

while [[ $F_down -lt $F && $trial -lt 15 ]] 
do
# DOWNLOAD the GEM grib2 files from remote_location
	echo 'GDPS download source:' $remote_location >> $output_log_file
    for hour in `seq -f %03.0f $minhours 3 $maxhours`
    do
        for variable in ${!FILESS[*]}
        do
            fvariable=${FILESS[$variable]}
            wget --no-check-certificate -r -l1 --no-parent -c -nd -A $fvariable$dt'*.grib2' $remote_location'/'$run_time'/'$hour'/'
        done
        #echo "boo"
    done
    #Counting number of files downloaded and restarting download if files are missing. Pausing 15 minutes before start of download.    
    F_down=`ls *glb*$dt* |wc -l`
    if [ $F_down -lt $F ] ;
	then
		echo 'GDPS download for' $dt 'completed' $F_down 'out of' $F 'files at' `date` 'after' $trial 'trial(s)' >> $output_log_file
		# switch to the other source
		if [ $remote_location == $remote_location1 ]; then
			remote_location=$remote_location2
		else
			remote_location=$remote_location1
		fi
		let trial=$trial+1		
        #sleep 5m    
    fi
done
echo 'GDPS download for' $dt 'completed' $F_down 'out of' $F 'files at' `date` 'after' $trial 'trial(s)' >> $output_log_file
if [ $F_down == $F ]; 
then
	touch $grib_file_path'GDPS-download.done'
fi
