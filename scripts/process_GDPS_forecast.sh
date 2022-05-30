#!/bin/bash

set -aex

# Dates
#Date to run is passed as argument $1
if [ -z "$1" ]; then
    echo 'MISSING argument $1 should equal date to run'
    exit 1
fi
dt=$(date -d $1 -u +%Y%m%d)
today=$(date --date='today' -u +%Y%m%d)
echo $dt, $today

# define paths and other variables
# use ABSOLUTE paths
home_dir=$2
scripts_file_path=$home_dir'/scripts/'
grib_file_path=$home_dir'/GRIB/GDPS/'
temp_file_path=$home_dir'/TempFiles/GDPS/'
run_file_path=$home_dir'/gem_forecasts/'
output_log_file=$home_dir/outputs/logs/$today'.log'
if [ ! -f $output_log_file ]; then
	touch $output_log_file
fi
# Programs
bin_wgrib2=/home/ec2-user/grib2/wgrib2/wgrib2

minhours=9
maxhours=240
run_time='12'

# Met Variables to process
eval $(cat $scripts_file_path/met_variables.txt)

# Watershed characteristics
eval $(cat $scripts_file_path/watersheds.txt)
for basin in ${!watersheds[*]}
do
	echo ${watersheds[$basin]}
done

# LOOP over the basins/watersheds
for basin in ${!watersheds[*]}
#for basin in `seq 3 4`
do

    # Remove temporary files if they exist
    rm $temp_file_path/*.* -f

    # ASSIGN paths for Stored Files and Working folder
    watershed=${watersheds[$basin]}
    station=${stations[$basin]}

    # Create run directory
    mkdir -p $run_file_path$watershed'/'$dt'16/GDPS/'

    output_file_path=$run_file_path$watershed'/'$dt'16/GDPS/'

    lat=${lats[$basin]}
    lon=${lons[$basin]}
    ycount=${ycounts[$basin]}
    xcount=${xcounts[$basin]}
    ydelta=${ydelta[$basin]}
    xdelta=${xdelta[$basin]}
	
  # ------------------- GEM -------------------------------
    # LOOP over each variable on the saved grib2 files to create the GEM forcing files
    for index in ${!namess[*]}
    do

        # CREATE the forcing file header
        names=${namess[$index]}
        FILES=${FILESS[$index]}
      #  touch $scripts_file_path'header_info.txt'
        echo "$watershed,$names,$lat,$lon,$xcount,$ycount,$xdelta,$ydelta" > $temp_file_path$'header_info.txt'
        gawk -f $scripts_file_path'R2C_header.awk' $temp_file_path$'header_info.txt' > $temp_file_path$'basin_'$names'.r2c'

        # LOOP over each time-step on the grib2 files
        for hour in `seq -f %03.0f $minhours 3 $maxhours`
        do

           # CLIP the grib2 to a basin-size rectangle and CONVERT the clipped file into a csv file
           f=$grib_file_path$FILES'latlon*'$dt$run_time'_P'$hour'*.grib2'

           $bin_wgrib2 $f -new_grid_interpolation neighbor -new_grid_winds earth -new_grid latlon $lon:$xcount:$xdelta $lat:$ycount:$ydelta $temp_file_path$names$hour'.tmp'

           $bin_wgrib2 $temp_file_path$names$hour'.tmp' -csv $temp_file_path$names$hour'.csv'

           # Restructure the data in the csv files into a single-line-per-timestep file, and append all time-steps into another file
           gawk 'BEGIN { FS = "," }; { print $2, $3, $NF }' $temp_file_path$names$hour'.csv' > $temp_file_path$names$hour'_2.csv'

           gawk -f $scripts_file_path'MESH_2.awk' $temp_file_path$names$hour'_2.csv' >> $temp_file_path$names'_3.csv'

        done

        # FORMAT the data into a matrix configuration as per r2c format
        gawk '{ print $0 }' $temp_file_path$'header_info.txt' > $temp_file_path$names'_4.csv'
        gawk '{ print $0 }' $temp_file_path$names'_3.csv' >> $temp_file_path$names'_4.csv'
        gawk -f $scripts_file_path$'MESH_3_3Hourly.awk' $temp_file_path$names'_4.csv' > $temp_file_path$names'_5.csv'

        # APPEND the r2c body into the forcing file header
        gawk '{ print $0 }' $temp_file_path$names'_5.csv' >> $temp_file_path$'basin_'$names'.r2c'


 # MOVE the newly created forcing files into the run folder
        mv $temp_file_path$'basin_'$names'.r2c' $output_file_path

    done
    rm $temp_file_path/*.* -f
	echo 'GDPS processing complete for '$watershed' at' `date` >> $output_log_file
#	sleep 300
done
