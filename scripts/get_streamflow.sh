#!/bin/bash
set -ae #x
#
# Dates
# Date to run is passed as argument $1

dt=$1
if [ -z $1 ]; then
    echo 'MISSING argument $1 should equal date to run'
    exit 1
fi

dt=$(date -d $1 -u +%Y%m%d)
today=$(date --date='today' -u +%Y%m%d)
echo $dt, $today

home_dir=$2
strm_file_path=$home_dir/streamflow 
scripts_file_path=$home_dir/scripts

# DOWNLOAD Streamflow Observations csv files from remote_location_2 (2-3 days) and remote_location_3 (month)
    
# Stations
eval $(cat $scripts_file_path/stations.txt)

# Loop over stations
for i in ${!stations[*]}
do  
	station=${stations[$i]} 
	region=${region[$i]}  
	echo station, region
	
	remote_location_2='http://dd.weather.gc.ca/hydrometric/csv/'$region'/hourly'
	remote_location_3='http://dd.weather.gc.ca/hydrometric/csv/'$region'/daily'   
	cd $strm_file_path/${station}
   
	wget -r -l1 --no-parent -c -nd -A '*'$station'*' $remote_location_2
	wget -r -l1 --no-parent -c -nd -A '*'$station'*' $remote_location_3

	if [ ! -f $region'_'$station'_hourly_hydrometric.csv' ]; then 
		cp $region'_'$station'_hourly_hydrometric_'$dt'.csv' $region'_'$station'_hourly_hydrometric_'$today'.csv'
	else
		mv $region'_'$station'_hourly_hydrometric.csv' $region'_'$station'_hourly_hydrometric_'$today'.csv'
   fi
   if [ ! -f $region'_'$station'_daily_hydrometric.csv' ]; then 
		cp $region'_'$station'_daily_hydrometric_'$dt'.csv' $region'_'$station'_daily_hydrometric_'$today'.csv'
   else
		mv $region'_'$station'_daily_hydrometric.csv' $region'_'$station'_daily_hydrometric_'$today'.csv'
   fi
done

