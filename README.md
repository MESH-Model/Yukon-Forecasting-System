# Yukon Forecasting System
The Yukon Forecasting System consists of a set of scripts and configruation files that run the MESH model for a set of model setups in forecast mode using meteorological forecast data downloaded from ECCC. The system runs daily in 4 stages that are scheduled for certain times during the day based on the availibility of ECCC data. This repo has three folders as follows:
scripts: contains the scripts used to run the Yukon Forecasting System on the AWS cloud (or any similar Linux System) and the configuration files
common: contains the static model setup files - only the 10Km Yukon@Eagle setup is included in a subfolder named after the outlet WSC gauge ID (09ED01) 
templates: contains semi-static model setup files: MESH_input_run_options.template.ini and MESH_input_parameters_CLASS.template.ini where these are edited at run time to specifiy the initial and final run times and start of forcing. Other options/parameters remain static.
