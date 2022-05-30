#!/bin/bash
set -ae #x
#
# Script to manage the files for the next capa hindcast 
# Provided the date 20170606 the script will retrieve data from 2017060516 to 2017060616 UTC-8
#
# The date to run is passed as argument $1
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

# Working directories
# The home directory is an absolute path; other directories build from this path
#DAN 2018-11-29: Changed to pass 'home_dir' as argument from calling script.
home_dir=$2
run_file_path_capa=$home_dir'/capa_hindcasts'
run_file_path_gem=$home_dir'/gem_forecasts'
scripts_file_path=$home_dir'/scripts'
output_log_file=$home_dir/outputs/logs/$today'.log'

# Watershed characteristics
eval $(cat $scripts_file_path/'watersheds.txt')
for basin in ${!watersheds[*]}
do
	echo ${watersheds[$basin]}
done

# Loop over the basins/watersheds
#DAN 2018-11-29: Updated paths to pull from 'common' files where possible.
#DAN 2018-11-29: Updated to use parameter ensemble files and to add parameter ensemble folder structure.
for basin in ${!watersheds[*]}
# for basin in `seq 1 1`
do
    # Assign the input and output file paths
    watershed=${watersheds[$basin]}
	mesh_exe='/home/ec2-user/MESH_source_files/'${EXE[$basin]}
	
    input_file_path_capa="${run_file_path_capa}/${watershed}/$(date -d "$dt - 2 day" -u +%Y%m%d)16_to_$(date -d "$dt - 1 day" -u +%Y%m%d)16"
    input_file_path_gem="${run_file_path_gem}/${watershed}/$(date -d "$dt - 1 day" -u +%Y%m%d)16"
    output_file_path_capa="${run_file_path_capa}/${watershed}/$(date -d "$dt - 1 day" -u +%Y%m%d)16_to_${dt}16"
	
   cd $output_file_path_capa
   if [ `ls int* |wc -l` -gt 0 ]; then rm int* ; fi
   #exit
   # Obtain the other (non-precip) forcing files for this capa run (same files as for the previous gem forecast run)
   for variable in humidity longwave pres shortwave temperature wind
   do
      ln -sf ${input_file_path_gem}/RDPS/basin_$variable.r2c ${output_file_path_capa}
   done

   # Obtain other mesh files that are unchanged from the common folder
   for file in `ls $home_dir/common/$watershed/MESH*`
   do
      ln -sf $file ${output_file_path_capa}
   done

   # Copy template files.
   #DAN 2018-11-29: Dan added this.
   for file in `ls $home_dir/template_files/$watershed/*`
   do
      cp $file ${output_file_path_capa}
   done

   #for file in `ls $home_dir/template_files/*`
   #do
   #   cp $file ${output_file_path_capa}
   #done
   
   # Obtain mesh state files from the previous capa run
   for file in `ls $input_file_path_capa/int_statVariables*_$(date -d "$dt - 1 day" -u +%Y%m%d)16*`
   do
      cp $file ${output_file_path_capa}
   done

# ###############
# #CaPA Hindcast#
# ###############    
    
    #Run MESH (Hindcast using CaPA deterministic data)
    

    #DAN 2018-11-29: Copy 'hindcast' template (difference is SAVERESUMEFLAG); already copied to folder from 'template_files' above.
	#ME 2020-04-17: Added SAVERESUMEFLAG as _SRF to further unify the template
    cp MESH_input_run_options_template.ini MESH_input_run_options.ini
	#DAN 2018-11-29: Dan added this.
	# Update HOURLYFLAG and simulation start/stop dates in run_options.ini.
		sed -i "s/OPT_HLYFLG/60/g" MESH_input_run_options.ini
		sed -i "s/_SRF/5/g" MESH_input_run_options.ini
		sed -i "s/SRYR/`echo $(date -d "$dt - 1 day" -u +%Y)`/g" MESH_input_run_options.ini
		sed -i "s/SRD/`echo $(date -d "$dt - 1 day" -u +%j)`/g" MESH_input_run_options.ini
		sed -i "s/SPYR/   0/g" MESH_input_run_options.ini
		sed -i "s/SPD/  0/g" MESH_input_run_options.ini
	rm MESH_input_run_options_template.ini
	
	# Copy parameter files.
	cp MESH_parameters_CLASS_template.ini MESH_parameters_CLASS.ini
        # Update 'met' start date.
        sed -i "s/MET_YEAR/    `echo $(date -d "$dt - 1 day" -u +%Y)`/g" MESH_parameters_CLASS.ini
        sed -i "s/MET_JDAY/     `echo $(date -d "$dt - 1 day" -u +%j)`/g" MESH_parameters_CLASS.ini
	rm MESH_parameters_CLASS_template.ini
	
    # rename resume files.
    for file in `ls $int_statVariables*_$(date -d "$dt - 1 day" -u +%Y%m%d)16`
	do
		mv $file ${file%_$(date -d "$dt - 1 day" -u +%Y%m%d)16}
	done
	
	mkdir -p RESULTS
	$mesh_exe

    # rename the new resume files
    for file in `ls int_statVariables*`
	do
	   mv $file $file'_'${dt}'16'
	done
	
    #Zip the newly created results folder and append date to name
	#gzip -r RESULTS 
	#mv RESULTS RESULTS_$(date -d "$dt" -u +%Y%m%d)16
	echo 'RDPS-CaPA hindcast MESH run complete for '$watershed' at' `date` >> $output_log_file
done

