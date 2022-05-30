#!/bin/bash
set -ae #x
#
# Script to manage the files for the next gem forecast
# Provided the date 20170606 the script will retrieve data from 2017060516 to 2017060616 UTC-8
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

# Provided the date 20170606 the script will retrieve data from 2017060516 to 2017060616 UTC-8
dt=$(date -d $1 -u +%Y%m%d)
today=$(date --date='today' -u +%Y%m%d)
echo $dt, $today

home_dir=$2
scripts_file_path=$home_dir/scripts
run_file_path_capa=$home_dir/capa_hindcasts
run_file_path_gem=$home_dir/gem_forecasts
output_log_file=$home_dir/outputs/logs/$today'.log'

# Watersheds
eval $(cat $scripts_file_path/watersheds.txt)
# for basin in ${!watersheds[*]}
# do
	# echo ${watersheds[$basin]}
# done

# Loop over the basins/watersheds
for basin in ${!watersheds[*]}
# for basin in `seq 1 1`
do
	echo ${watersheds[$basin]}
    # Assign the output file path
    watershed=${watersheds[$basin]}
	mesh_exe='/home/ec2-user/MESH_source_files/'${EXE[$basin]}
	
    input_file_path_capa="${run_file_path_capa}/${watershed}/$(date -d "$dt - 1 day" -u +%Y%m%d)16_to_${dt}16"
    #input_file_path_gem="${run_file_path_gem}/${watershed}/$(date -d "$dt - 1 day" -u +%Y%m%d)16"
    output_file_path_gem="${run_file_path_gem}/${watershed}/${dt}16/GDPS"

	cd $output_file_path_gem
    # Obtain other mesh files that are unchanged from the common folder
    for file in `ls $home_dir/common/$watershed/MESH*`
    do
		ln -sf $file ./
    done

    # Copy template files.
    #DAN 2018-11-29: Dan added this.
    for file in `ls $home_dir/template_files/$watershed/*`
    do
		cp $file ./
    done
   
    cd $input_file_path_capa
    # Obtain mesh state files from the today's capa run
    for file in `ls int_statVariables*_${dt}16*`
    do
		ln -sf  $input_file_path_capa/$file $output_file_path_gem/${file%_"$dt"16}
    done

######################
#GDEPS 10-day Forecast#
######################
   
    #Run MESH (Forecast using GEM input model data)  
	cd $output_file_path_gem
    cp MESH_input_run_options_template.ini MESH_input_run_options.ini
	#DAN 2018-11-29: Dan added this.
	# Update HOURLYFLAG and simulation start/stop dates in run_options.ini.
		sed -i "s/OPT_HLYFLG/180/g" MESH_input_run_options.ini
		sed -i "s/_SRF/0/g" MESH_input_run_options.ini
		sed -i "s/SRYR/`echo $(date -d $dt  -u +%Y)`/g" MESH_input_run_options.ini
		sed -i "s/SRD/`echo $(date -d $dt -u +%j)`/g" MESH_input_run_options.ini
		sed -i "s/SPYR/   0/g" MESH_input_run_options.ini
		sed -i "s/SPD/  0/g" MESH_input_run_options.ini
	rm MESH_input_run_options_template.ini
	
	# Copy parameter files.
	cp MESH_parameters_CLASS_template.ini MESH_parameters_CLASS.ini
        # Update 'met' start date.
        sed -i "s/MET_YEAR/    `echo $(date -d $dt -u +%Y)`/g" MESH_parameters_CLASS.ini
        sed -i "s/MET_JDAY/     `echo $(date -d $dt -u +%j)`/g" MESH_parameters_CLASS.ini
	rm MESH_parameters_CLASS_template.ini
	
	# rename resume files.
    # for file in `ls $int_statVariables*_"$dt"16`
	# do
		# mv $file 
	# done
		
	mkdir -p RESULTS
	$mesh_exe
    echo 'GDPS forecast MESH run complete for '$watershed' at' `date` >> $output_log_file
done

