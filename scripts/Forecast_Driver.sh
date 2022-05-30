#!/bin/bash
# -e exports all variables - no need to send path or date variables or redefine them in other scripts unless when they are called indpendently
set -ae #x

#This script's purpose is to produce a streamflow forecast for the Liard, Stewart, Pelly and Ross rivers for the time period yesterday 16:00 (UTC-8) to tomorrow 16:00 (UTC-8). A forecast for past dates is not possible due to the lack of online access to GEM values.

#This script gets data, organizes the files to run Mesh, runs Mesh for given sub-basins of the Yukon river basin, which includes 4 stations: 09BC002, 09BA001, 09DC006 and 10AA001. The script to plot forecast graphs is called at the end.

# Yesterday's date
# For example if today is 20170606, the script will retrieve CaPA data from 2017060516 to 2017060616 UTC-8 and GEM values from 20170606 to 20170608.


dt=$(date --date='yesterday' -u +%Y%m%d)
today=$(date -u +%Y%m%d)
today_s=$(date -d $today -u +'%s')
start_s=$(date -d "20220401" -u +'%s')
(( go_back = (( $today_s - $start_s ) / ( 24 * 60 * 60 )) ))
echo $dt
echo $go_back

#Working directories
home_dir=/home/ec2-user/Yukon_Forecasting
scripts_file_path=$home_dir/scripts

output_log_file=$home_dir/outputs/logs/$today'.log'
if [ ! -f $output_log_file ]; then
	touch $output_log_file
fi

echo 'Forecast Driver stage' $1 'started at' `date` >> $output_log_file
stage=$1
# staging within the same script

# Stage 1: GDPS download and processing - GDPS z12 issue becomes available generally a bit before 18:00 UTC
# We need to download today's rather than yesterday's data if downloads start before mid-night
if [ $stage == '1' ];
then
	# Getting GDPS forecast files from yesterday 16:00 for 10 days
	$scripts_file_path/get_GDPS_forecast.sh $today $home_dir	
	$scripts_file_path/process_GDPS_forecast.sh $today $home_dir
	
	# $scripts_file_path/get_GDPS_forecast.sh $dt $home_dir
	# $scripts_file_path/process_GDPS_forecast.sh $dt $home_dir
	
	echo 'GDPS processing complete for all watersheds at' `date` >> $output_log_file
	echo 'Forecast Driver - stage' $stage 'successful at' `date` >> $output_log_file
	exit
fi

# stage 2: RDPS download and processing: RDPS z18 issue becomes available generally a bit before 22:00 UTC
# We need to download today's rather than yesterday's data if downloads start before mid-night
if [ $stage == '2' ]; 
then
	# Getting RDPS (the files contain only modelled values) from yesterday 16:00 until it ends. 
	# That represents 78 hours. 84 hours are available but we do not use first 6 hours
	# This was recently updated to 84 hours instead of 54 hours
	$scripts_file_path/get_RDPS_forecast.sh $dt $home_dir
	$scripts_file_path/process_RDPS_forecast.sh $dt $home_dir
	
	echo 'RDPS processing complete for all watersheds at' `date` >> $output_log_file
	echo 'Forecast Driver - stage' $stage 'successful at' `date` >> $output_log_file
	exit
fi

# stage 3: CaPA download and processing, running hindcasts & forecasts & plotting
# RDPA data for the last downloaded time step becomes available generally shortly afer 1:00 UTC 
if [ $stage == '3' ];
then
	# check that Stage 1 and Stage 2 were done
	if [ ! -f $home_dir'/GRIB/GDPS/GDPS-download.done' ]; then
		echo 'Re-iterating GDPS download and processing at' `date` >> $output_log_file
		$scripts_file_path/get_GDPS_forecast.sh $dt $home_dir
		$scripts_file_path/process_GDPS_forecast.sh $dt $home_dir
		echo 'GDPS processing complete for all watersheds at' `date` >> $output_log_file
	fi
	if [ ! -f $home_dir'/GRIB/RDPS/RDPS-download.done' ]; then
		echo 'Re-iterating RDPS download and processing at' `date` >> $output_log_file
		$scripts_file_path/get_RDPS_forecast.sh $dt $home_dir
		$scripts_file_path/process_RDPS_forecast.sh $dt $home_dir
		echo 'RDPS processing complete for all watersheds at' `date` >> $output_log_file
	fi	
	# Getting CaPA data (data that incorporate actual precip data with modelled values) from two days ago 16:00 until yesterday 16:00 local Yukon time.
	$scripts_file_path/get_capa.sh $dt $home_dir
	$scripts_file_path/process_capa.sh $dt $home_dir
	echo 'CaPA processing complete for all watersheds at' `date` >> $output_log_file
	
	# Setting up CaPA folders for all watersheds to produce state variable files. The saveresume and resume ~flags are set to 5
	$scripts_file_path/perform_capa_hindcast.sh $dt $home_dir
	echo 'RDPS-CaPA hindcast MESH runs complete for all watersheds at' `date` >> $output_log_file

	# Setting up RDPS folders for the 4 stations to produce forecast. The saveresume flag is set to 0 and the resume flag, to 5
	$scripts_file_path/perform_RDPS_forecast.sh $dt $home_dir
	echo 'RDPS forecast MESH runs complete for all watersheds at' `date` >> $output_log_file

	# Setting up GDPS folders for the 4 stations to produce forecast. The saveresume flag is set to 0 and the resume flag, to 5
	$scripts_file_path/perform_GDPS_forecast.sh $dt $home_dir
	echo 'GDPS forecast MESH runs complete for all watersheds at' `date` >> $output_log_file

	# Getting the observed streamflow data from 16:00 yesterday.
	$scripts_file_path/get_streamflow.sh $dt $home_dir
	echo 'Streamflow download complete at' `date` >> $output_log_file 

	echo 'Forecast Driver - stage' $stage 'successful at' `date` >> $output_log_file
	stage=4
	#-----------------------------------------------------------------------------------
fi

if [ $stage == '4' ];
then
	echo 'Forecast Driver stage' $stage 'started at' `date` >> $output_log_file
	stations='All_Stations'	
	back=15
	
	$scripts_file_path/append_streamflow_gauged_oneday.R $dt $home_dir $stations
	echo 'gauged streamflow preparation complete for' $stations 'at' `date` >> $output_log_file
	
	$scripts_file_path/append_streamflow_hindcast_oneday.R $dt $home_dir $stations
	echo 'streamflow hindcast preparation complete for' $stations 'at' `date` >> $output_log_file
	
	$scripts_file_path/append_water_balance_hindcast_oneday.R $dt $home_dir $stations
	echo 'WB hindcast preparation complete for' $stations 'at' `date` >> $output_log_file

	$scripts_file_path/extract_water_balance_forecast.R $dt $home_dir $stations
	echo 'WB forecast preparation complete for' $stations 'at' `date` >> $output_log_file
	
	lakes='6lakes'
	
	$scripts_file_path/append_level_gauged_oneday.R $dt $home_dir $lakes
	echo 'gauged level preparation complete for' $lakes 'at' `date` >> $output_log_file

	$scripts_file_path/append_level_hindcast_oneday.R $dt $home_dir $lakes
	echo 'level hindcast preparation complete for' $lakes 'at' `date` >> $output_log_file
	
	#*********
	#*R Plots*
	#*********
	
	$scripts_file_path/ggplot_streamflow_WB_forecast_hindcast.R $dt $home_dir $stations $back 1
	echo 'Forecast support charts plotting complete for' $stations 'at' `date` >> $output_log_file
	
	# stations='09EB001-WSCRating'	
	# $scripts_file_path/ggplot_streamflow_WB_forecast_hindcast.R $dt $home_dir $stations $back 1
	# echo 'Forecast support charts plotting complete for' $stations 'at' `date` >> $output_log_file
	
	lakes='6lakes'
	$scripts_file_path/ggplot_level_forecast_hindcast.R $dt $home_dir $lakes $back 1
	echo 'Forecast support charts plotting complete for' $lakes 'water level at' `date` >> $output_log_file	
	
	$scripts_file_path/email_forecast.sh $today $home_dir
	echo 'Email sent at' `date` >> $output_log_file	
	
	stations='All_Stations_NoNudging'	
	
	$scripts_file_path/ggplot_streamflow_WB_forecast_hindcast.R $dt $home_dir $stations $back 0
	echo 'Forecast support charts plotting complete for ' $stations ' at' `date` >> $output_log_file
	
	$scripts_file_path/ggplot_streamflow_WB_forecast_hindcast.R $dt $home_dir $stations $go_back 0	
	echo 'Long term plotting complete for ' $stations ' at' `date` >> $output_log_file	

	lakes='6lakes'	
	$scripts_file_path/ggplot_level_forecast_hindcast.R $dt $home_dir $lakes $go_back 0
	echo 'Long term plotting complete for ' $lakes ' water level at' `date` >> $output_log_file
	

	
	#**************
	# Clean-Up & Backup
	#++++++++++++++
	rsync -rltuvz ~/Yukon_Forecasting melshamy@graham.computecanada.ca:~/project
	
	# Remove GRIB files and forecasts that are 2 weeks old
	set +e
	deldt=$(date -d "$dt -11 day" -u +%Y%m%d)
	rm -f $home_dir/GRIB/GDPS/*$deldt*
	rm -f $home_dir/GRIB/RDPS/*$deldt*
	rm -f $home_dir/GRIB/*$deldt*
	rm -rf $home_dir/gem_forecasts/*/$deldt'16'
	rm -rf $home_dir/streamflow/*/*$deldt'.csv'
	rm -f $home_dir/outputs/water_balance_forecast/*$deldt'.csv'
	
	echo 'Backup to Graham and Clean up complete at' `date` >> $output_log_file
	
	echo 'Forecast Driver - stage' $stage 'successful at' `date` >> $output_log_file
fi
