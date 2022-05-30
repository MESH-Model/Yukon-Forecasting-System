#!/usr/local/bin/Rscript

#Script accounts for stations that do not have historical flow data such as 09DC006 so that the plots do not show min max historical values. It produces individual graphs with min max values except for 09DC006 and it produces an overview graph of all basins. The update for multiple gauges in a basin needs to be made. Date argument is in format yyyymmdd.

library(ggplot2)
library(scales)
library(gridExtra)
library(cowplot)
library(reshape2)

args <- commandArgs(TRUE)
dt <- args[1] #date is start date of forecast data
home_dir <- args[2]
go_back <- as.numeric(args[4]) + 0.5
nudged <- args[5]
dt
home_dir
go_back 
nudged 

setwd(paste(home_dir,"/outputs/Forecast_Plots", sep=''))

source(paste(home_dir,"/scripts/streamflow_minmax_daily.R",sep=''))

#date_today <- format(Sys.time(), "%Y%m%d")

date_yesterday <- as.POSIXct(dt, format = "%Y%m%d")
date_today <- as.POSIXct(date_yesterday + as.difftime(1, unit="days"))
start_date <- as.POSIXct(date_today - as.difftime(go_back, unit="days"))   
end_date <- as.POSIXct(date_today + as.difftime(10, unit="days"))

date_today <- format(date_today, "%Y%m%d")

#used in generating the minmax dataframe & hindcasts

print(start_date)
print(date_today)
print(end_date)
#print(date_today_2)

# ME 1/5/2020 create a daily folder to reduce clutter
dir.create(date_today)
setwd(date_today)

if ( go_back == 15.5 ) {
	report_file_name <- paste("Streamfow_Forecast_", args[3], "_", date_today, ".pdf", sep = "")
} else {
	report_file_name <- paste(paste("Streamfow_Forecast", args[3], date_today, "starting", format(start_date, "%Y%m%d"),sep = "_"), ".pdf", sep = "")
}
	
#nudging_report <- paste("Nudging_Report", date_today,".csv", sep = "")
#file.create("my.csv")
file <- paste(args[3], ".txt", sep="")
station_path <- file.path(home_dir, "scripts", file)
stations <- read.csv(station_path, header = TRUE, sep = ",", stringsAsFactors = FALSE)
stations
if (nudged == 0)  # Nudging is disabled globally
{
	stations[, 11] <- 0
}
# type_color <- c("black", "gray50", "magenta3", "magenta", "royalblue3", "royalblue", "orangered3", "orangered")

graphlist <- list()
j <- 0
station <- c('0')

for (i in 1:length(stations[, 1])) {
	New <- 0
	# Determine colors - this assigns colors based on model type consistently	
	if ( station != stations[i,2]) {		# This is a new station
		# type_color <- c("black", "gray50")
		type_color <- NULL
		New <- 1
	}
	if ( stations[i,10] == '10K-old' ) {
		type_color <- append(type_color, c("magenta3", "violet"))
	}
	if ( stations[i,10] == '5K' ) {
		type_color <- append(type_color, c("orangered3", "sienna1"))
	} 
	if ( stations[i,10] == '10K' ) {
		type_color <- append(type_color, c("royalblue3", "deepskyblue"))
	} 
	print(New)
	print(type_color)
	basin <- stations[i, 1]
	station <- stations[i, 2]
	station_name <- stations[i, 5]
	print(paste(basin,station, sep=" "))

	###############################################################################
	#Reading observed gauged short record (few days)	
	# Reading in the data from .csv file
	if ( New == 1 )
	{
		file_name <- paste("YT_", station, "_hourly_hydrometric_", date_today, ".csv", sep = "")
		file_name <- file.path(home_dir, "streamflow", station, file_name)
		#  o_path <- file.path("D:/Yukon_MESH_forecast/SHARE_MESH/test_ggplot", file_name1)
		gauged_s <- read.csv(file_name, skip=1, stringsAsFactors = FALSE)

		# Preparing variables to go into the data frame of the gauged data.
		dateF_s <- as.POSIXct(gauged_s[, 2], format = "%Y-%m-%dT%H:%M:%S-08:00", tz = "etc/GMT+8")
		level_s <- gauged_s[, 3]
		#If discharge column is empty, calculate discharge. I use a file containing the rating curves.
		discharge_s <- gauged_s[, 7]

		# print(basin)
		# print(discharge_s[1])
		non_NA<-which(!is.na(discharge_s))
		type_s <- "WSC real-time"
		#if the "WHOLE" gauged discharge column is empty, and rating curve is provided, calculate discharge
		if (length(non_NA) == 0 && !is.na(stations[i, 6]))     
		{
			type_s <- "Est real-time"
			if (stations[i, 6] == 0) { # 2nd degree polynomial (a * level ^ 2 + b * level + c)
				discharge_s <- stations[i, 7] * level_s ^ 2 + stations[i, 8] * level_s + stations[i, 9]
			} else {	# Power (a * (level - ho) ^ b + c (a, ho, b, c are coefficients)
				discharge_s <- (stations[i, 6] * (level_s + stations[i, 7]) ^ stations[i, 8]) - stations[i, 9]
			}
		}
		
		gauged_frame_s <- data.frame(type_s, station, dateF_s, level_s, discharge_s)
		names(gauged_frame_s) <- c("type", "station", "date", "level", "discharge")
		# omit data with missing levels or discharge (value = 99999)
		#gauged_frame_s <- subset(gauged_frame_s,level < 99999)
		#gauged_frame_s <- subset(gauged_frame_s,!is.na(level_s))
		gauged_frame_s <- subset(gauged_frame_s,!is.na(discharge))
		gauged_frame_s <- subset(gauged_frame_s,discharge < 99999)
		non_NA<-which(!is.na(gauged_frame_s$discharge))
		if (length(non_NA) > 0)
		{
			type_color <- append(c("gray50"), type_color)
		}

		# file_name6 <- paste("streamflow_hourly_", station, "_", date_today, ".csv", sep = "")
	    # m <- file.path(home_dir, "outputs/R_Data_Frames", file_name6)
		# write.csv(gauged_frame_s, m , row.names = FALSE)
		rm(gauged_s, type_s, dateF_s, level_s, discharge_s)
		#################################################################################
		# Reading observed gauged long record (archive from beginning of season)
		# Modified by Mohamed Elshamy on June 16, 2020
		# Reading in the data from .csv file
		input_file <- paste(paste("gauged_hydrometric_appended", station, "till", dt, sep='_'),".csv",sep='')
		input_file <- file.path(home_dir, "outputs/streamflow_archive", input_file)
		gauged_l <- read.csv(input_file, header=FALSE, stringsAsFactors = FALSE, sep=" ")
	#	names(gauged_l) <- c("station", "date_time", "level", "level-grade", "level-sysmbol", "level-QC", "discharge", "discharge-grade", "discharge-symbol", "discharge-QC")
		
		dateF_l <- as.POSIXct(gauged_l[, 1], format = "%Y-%m-%dT%H:%M:%S-08:00", tz = "etc/GMT+8")	
		# Preparing variables to go into the data frame of the gauged data.

		level_l <- gauged_l[, 2]
		discharge_l <- gauged_l[, 3]
		type_l <- "WSC near real-time"
		# print(discharge_l[1])
		non_NA<-which(!is.na(discharge_l))
		Rating <- ""
		#if the "WHOLE" gauged discharge column is empty, and rating curve is provided, calculate discharge
		if (length(non_NA) == 0 && !is.na(stations[i, 6])) 
		{
			type_l <- "Est near real-time"
			if (stations[i, 6] == 0) { # 2nd degree polynomial (a * level ^ 2 + b * level + c)
				discharge_l <- stations[i, 7] * level_l ^ 2 + stations[i, 8] * level_l + stations[i, 9]
				Rating <- paste("Q =", stations[i, 7], "h^2 +",stations[i, 8], "h +", stations[i, 9])
			} else {	# Power (a * (level - ho) ^ b + c (a, ho, b, c are coefficients)
				discharge_l <- (stations[i, 6] * (level_l + stations[i, 7]) ^ stations[i, 8]) - stations[i, 9]
				# Rating <- paste("Q = ", stations[i, 6], "h"
				if (stations[i,7] == 0) {
					Rating <- paste("Q = ", stations[i, 6], "h")
					}
				else if (stations[i,7] < 0) {
					Rating <- paste("Q = ", stations[i, 6], " ( h - ",-stations[i,7]," )",sep="")
				}
				else {
					Rating <- paste("Q = ", stations[i, 6], " ( h + ",stations[i,7]," )",sep="")
				}
				if (stations[i,8] != 1) {
					Rating <- paste(Rating, "^",stations[i,8])
				}
				if (stations[i, 9] != 0) {
					Rating <-paste(Rating, "-",stations[i, 9])
				}
			}
		}
				
		gauged_frame_l <- data.frame(type_l, station, dateF_l, level_l, discharge_l)
		names(gauged_frame_l) <- c("type", "station", "date", "level", "discharge")
		cond1 <- gauged_frame_l$date>=start_date
		gauged_frame_l <- gauged_frame_l[cond1,]
		#gauged_frame_l <- subset(gauged_frame_l,!is.na(level_l))
		gauged_frame_l <- subset(gauged_frame_l,!is.na(discharge))
		non_NA<-which(!is.na(gauged_frame_l$discharge))
		if (length(non_NA) > 0)
		{
			type_color <- append(c("black"), type_color)	
		}
		print(type_color)
		rm(gauged_l, cond1, type_l, dateF_l, level_l, discharge_l)
	}
	##################################################################################
	#Reading simulated streamflow (CaPA-RDPS hindcast)
	# Added by Mohamed Elshamy on May 26, 2020

	input_file <- paste(paste("hindcasted_streamflow_appended", basin, station, "till", dt, sep='_'),".csv",sep='')
	input_file <- file.path(home_dir, "outputs/streamflow_archive", input_file)
	model_hindcast <- read.csv(input_file, header = FALSE, stringsAsFactors = FALSE, sep=" ")

	#Format date and apply shift
	date1 <- as.POSIXct(model_hindcast[, 1], format = "%Y-%m-%d %H:%M:%S", tz = "etc/GMT+8")
	date1 <- date1 + as.difftime(stations[i,12], unit="days")
	# Apply shift
	date1 <- date1 + as.difftime(stations[i,12], unit="days")
	
	# Converting day of year date format into the working format for the model streamflow values.
	#dateF2 <- as.POSIXct(date2, format = "%Y %j %H %M", tz = "etc/GMT+8")

	# The following if statement deals with mesh model files that contain values from 2 stations (one watershed).
	# ME 1/5/2020 - stations info should have the column number for the station to remove all hard coded stations names 
	discharge1 <- model_hindcast[, 2]
	level1 <- model_hindcast[, 2]  #bogus column, just to create NA values.
	type1 <- paste("RDPS","-",stations[i,10],sep="")
	
	#  print(model_RDPS[1, 9])
	
	model_hindcast_frame <- data.frame(type1, station, date1, level1, discharge1)
	cond1 <- model_hindcast_frame$date>=start_date
	model_hindcast_frame <- model_hindcast_frame[cond1,]

	#Renaming RDPS data frame variables
	names(model_hindcast_frame) <- c("type", "station", "date", "level", "discharge")
	rm(model_hindcast, cond1, type1, date1, level1, discharge1)
	
	##################################################################################
	#Reading simulated streamflow (RDPS forecast)

	 m <- file.path(home_dir, "streamflow", basin, "MESH_output_streamflow_ts_RDPS.csv")
	file_name2 <- "MESH_output_streamflow_ts.csv"
	t = paste(dt,"16",sep='')
	#print(file_name2)
	m <- file.path(home_dir, "gem_forecasts", basin, t ,"RDPS/RESULTS", file_name2)
	model_RDPS <- read.csv(m, header = TRUE, stringsAsFactors = FALSE)

	# Read date	
	dateF2 <- paste(model_RDPS[, 1], model_RDPS[, 2], model_RDPS[, 3], model_RDPS[, 4])
	# Convert day of year date format into the working format for the model streamflow 
	dateF2 <- as.POSIXct(dateF2, format = "%Y %j %H %M", tz = "etc/GMT+8")
	# Apply shift
	dateF2 <- dateF2 + as.difftime(stations[i,12], unit="days")

	# The following if statement deals with mesh model files that contain values from 2 stations (one watershed).
	# ME 1/5/2020 - stations info should have the column number for the station to remove all hard coded stations names 
	discharge2 <- model_RDPS[, stations[i,4]*2+4]
	level2 <- model_RDPS[, 7]  #bogus column, just to create NA values.
	type2 <- paste("RDPS","-",stations[i,10],sep="")

	model_RDPS_frame <- data.frame(type2, station, dateF2, level2, discharge2)

	#Renaming RDPS data frame variables
	names(model_RDPS_frame) <- c("type", "station", "date", "level", "discharge")
	rm(model_RDPS, type2, dateF2, level2, discharge2)
	
	####################################################################################  
	#Reading simulated streamflow (GDPS forecast)

	 m <- file.path(home_dir, "streamflow", basin, "MESH_output_streamflow_ts_GDPS.csv")
	file_name3 <- "MESH_output_streamflow_ts.csv"
	# m <- file.path("/home/ec2-user/Yukon/streamflow", basin, filename2)
	m <- file.path(home_dir, "gem_forecasts", basin, t, "GDPS/RESULTS", file_name3)
	# m <- file.path("D:/Yukon_MESH_forecast/SHARE_MESH/test_ggplot", file_name2)
	model_GDPS <- read.csv(m, header = TRUE, stringsAsFactors = FALSE)

	# Read date	
	dateF3 <- paste(model_GDPS[, 1], model_GDPS[, 2], model_GDPS[, 3], model_GDPS[, 4])
	# Convert day of year date format into the working format for the model streamflow 
	dateF3 <- as.POSIXct(dateF3, format = "%Y %j %H %M", tz = "etc/GMT+8")
	# Apply shift
	dateF3 <- dateF3 + as.difftime(stations[i,12], unit="days")
	Xint <- dateF3[1]
	# print(Xint)
	# The following if statement deals with mesh model files that contain values from 2 stations (one watershed).

	discharge3 <- model_GDPS[, stations[i,4]*2+4]
	level3 <- model_GDPS[, 7]  #bogus column, just to create NA values.
	type3 <- paste("GDPS","-",stations[i,10],sep="")

	#Producing GDPS data frame with streamflow and level.
	model_GDPS_frame <- data.frame(type3, station, dateF3, level3, discharge3)
	names(model_GDPS_frame) <- c("type", "station", "date", "level", "discharge")
	rm(model_GDPS, type3,  dateF3, level3, discharge3)

	######################################################################################
	#Nudging

	#Finding the indices of the first occurence of model day 1 16:30 in gauged data.
	x1 <- match(model_RDPS_frame$date[1],gauged_frame_s$date)
	print(model_RDPS_frame$date[1])
	#print(gauged_frame_s$date)
	#print(x1)
	# if (i == 1) {
	# x1 <- 523
	# }
	# x2 is not ued?
	# x2 <- match(start_date, gauged_frame_l$date)
	print(x1)

	# Nudging the model values to have both curves start at same y value.
	if (is.na(gauged_frame_s$discharge[x1])) {
		#gauged_frame_s_noNA <- na.omit(gauged_frame_s$discharge)
		# print(gauged_frame_s$discharge)
		diff1 <- model_RDPS_frame$discharge[1] - tail(gauged_frame_s$discharge, n=1)
	    print(model_RDPS_frame$discharge[1])
		print(model_GDPS_frame$discharge[1])
		print(tail(gauged_frame_s$discharge, n=1))
		if (is.na(x1)) 
		{
			diff1 <- 0
			diff2 <- 0
			stations[i,11] <- 0
		} else {
			diff1 <- model_RDPS_frame$discharge[1] - tail(gauged_frame_s$discharge, n=1)
			diff2 <- model_GDPS_frame$discharge[1] - tail(gauged_frame_s$discharge, n=1)	
			print("is missing discharge measurements. The last entry was used.") 
			print(paste(diff1, diff2, sep=" "))
		}
		
	} else {
		diff1 <- model_RDPS_frame$discharge[1] - gauged_frame_s$discharge[x1]
		diff2 <- model_GDPS_frame$discharge[1] - gauged_frame_s$discharge[x1] 
		print(paste(diff1, diff2, sep=" "))
	}
	# ME May 7 2020 - check if diff1 or diff2 are NA to disable nudging 
	# as it results in NA for simulated flow and nothing gets plotted
	# if (is.na(diff1) || is.na(diff2))
	# {
		# diff1 <- 0
		# diff2 <- 0
		# #diff3 <- 0
		# stations[i,11] <- 0
	# }

	#ME May 4 2020 - Added a flag to disable nudging to be read from stations file
	if (stations[i,11]==1) {
		model_RDPS_frame$discharge <- model_RDPS_frame$discharge - diff1
		model_GDPS_frame$discharge <- model_GDPS_frame$discharge - diff2
		# Disable the next line to stop nudging hindcasts
		model_hindcast_frame$discharge <- model_hindcast_frame$discharge - diff1
	}
	#write.table(c(station, diff1, diff2, diff3), file = paste(home_dir, "/outputs/Forecast_Plots_v2/Nudging.csv"), append = TRUE, quote = TRUE, sep = " ", eol = "\n", na = "NA", dec = ".", row.names = TRUE, col.names = FALSE, qmethod = c("escape", "double"), fileEncoding = "")

	#######################################################################################
	# Combining data frames from one station and different setups
	if (New == 1) {
		flow_data <- rbind(gauged_frame_l,gauged_frame_s,model_hindcast_frame, model_RDPS_frame, model_GDPS_frame)
	} else {
		flow_data <- rbind(flow_data, model_hindcast_frame, model_RDPS_frame, model_GDPS_frame)
	}
	rm(gauged_frame_l,model_hindcast_frame, model_RDPS_frame, model_GDPS_frame)
	
	#Combining data frames from same station 
	# if (New == 1) {
	  # flow_data_all <- flow_data
	  # #print(flow_data$discharge)
	# } else {
	  # flow_data_all <- rbind(flow_data_all, flow_data)
	# }
	# rm(flow_data)
	
	# Writing the gauged and modelled streamflow data to a file to use it in RStudio
	# uncomment for debugging purposes
	# file_name6 <- paste("streamflow_dataframe_", station, "_", date_today, ".csv", sep = "")
	# m <- file.path(home_dir, "outputs/R_Data_Frames", file_name6)
	# write.csv(flow_data, m , row.names = FALSE)

	#############WATER BALANCE##############################################################
	# Reading Water Balance (WB) outputs from appended hindcast file
	#theme_update(plot.title = element_text(hjust = 0.3)) 
	if (stations[i, 13]==1) {
		input_file <- paste(paste("hindcasted_water_balance_appended", basin, station, "till", dt, sep='_'),".csv",sep='')
		input_file <- file.path(home_dir, "outputs/water_balance_archive", input_file)
		if (file.exists(input_file)) 
		{
			WB_h <- read.csv(input_file, header = FALSE, stringsAsFactors = FALSE, sep=" ")
			date <- as.POSIXct(WB_h[, 1], format = "%Y-%m-%d %H:%M:%S", tz = "etc/GMT+8")
			precip <-  WB_h[, 2]
			evap <-  WB_h[, 3]
			snow <- WB_h[, 4]
			soil_moisture_Total <- WB_h[, 5]
			type <- paste("RDPS","-",stations[i,10],sep="") 

			df_wb_h <- data.frame(type, basin, station, date, snow, soil_moisture_Total)
			df_P_ET_h <- data.frame(type, basin, station, date, precip, evap)
			
			#start_date_WB <- as.POSIXct(start_date - as.difftime(1, unit="days"))
			cond1 <- df_wb_h$date>=start_date
			df_wb_h <- df_wb_h[cond1,]
			cond2 <- df_P_ET_h$date>=start_date
			df_P_ET_h <- df_P_ET_h[cond2,]
			
			#Renaming data frame variables
			names(df_wb_h) <- c("type", "basin", "station", "date", "Snow accumulation (SWE)", "Total soil moisture")
			names(df_P_ET_h) <- c("type", "basin", "station", "date","Total precipitation", "Evapotranspiration")
			rm(WB_h,type, date, precip, evap, snow, soil_moisture_Total)
		}
		# Reading Water Balance GDPS Forecast (WB_f) 

		file_name <- paste(paste("water_balance_forecast_reworked", basin, station, date_today, sep = "_"), ".csv",sep="")
		file_name <- file.path(home_dir, "outputs/water_balance_forecast", file_name)
		WB_f <- read.csv(file_name, header = FALSE, stringsAsFactors = FALSE, sep=" ")
		date <- as.POSIXct(WB_f[, 1], format = "%Y-%m-%d %H:%M:%S", tz = "etc/GMT+8")
		precip <-  WB_f[, 2]
		evap <-  WB_f[, 3]
		snow <- WB_f[, 4]
		soil_moisture_Total <- WB_f[, 5]
		type <- paste("GDPS","-",stations[i,10],sep="")

		df_wb_f <- data.frame(type, basin, station, date, snow, soil_moisture_Total)
		df_P_ET_f <- data.frame(type, basin, station, date, precip, evap)
		
		# Renaming data frame variables
		names(df_wb_f) <- c("type", "basin", "station", "date", "Snow accumulation (SWE)", "Total soil moisture")
		names(df_P_ET_f) <- c("type", "basin", "station", "date","Total precipitation", "Evapotranspiration")
		rm(WB_f, type, date, precip, evap, snow, soil_moisture_Total)
		
		# Binding hindcast and forecast dataframes
		df_WB <- rbind(df_wb_h, df_wb_f)
		df_P_ET <- rbind(df_P_ET_h, df_P_ET_f)
		#rm(df_wb_h, df_P_ET_h)
		rm(df_wb_h, df_wb_f, df_P_ET_h, df_P_ET_f)

	#Combining data frames from all stations
	# if (i == 1) {
	  # df_WB_all <- df_WB
	  # #print(flow_data$discharge)
	# } else
	# {
	  # df_WB_all <- rbind(df_WB_all, df_WB)
	# }
	# rm(df_WB)
	
	# #df of precip plus other water balance variables and changing format to long
		df_P_ET <- melt(df_P_ET, id.vars=c("type", "basin", "station", "date")) #long format
		df_WB <- melt(df_WB, id.vars=c("type", "basin", "station", "date"))
	# db_wb_fl <- melt(db_wb_f, id.vars=c("type", "basin", "station", "date")) #long format
	# #only unacc. precip
	# cond <- df.wbl$variable=="Total precipitation" #unacc. precip in the dataframe 
	# df.wbl_var1 <- df.wbl[cond,]  
	# cond <- df.wbl$variable!="Total precipitation" #WB, excludes unacc. precip in the dataframe
	# df.wbl_var234 <- df.wbl[cond,] 

	# cond <- db_wb_fl$variable=="Total precipitation" #unacc. precip in the dataframe
	# db_wb_fl_var1 <- db_wb_fl[cond,]
	# cond <- db_wb_fl$variable!="Total precipitation" #WB, excludes unacc. precip in the dataframe
	# db_wb_fl_var234 <- db_wb_fl[cond,]


	# #Adding water balance forecast to the water balance hindcast data frame
	# #three variables
	# df.balance_combined <- rbind(df.wbl_var234, db_wb_fl_var234)
	# #unacc precipitation
	# df.precip_combined <- rbind(df.wbl_var1, db_wb_fl_var1)

	# Writing water balance data frame to a file to use it in RStudio
	# Uncomment for Debugging Purposes
	# file_name <- paste(paste("precipitation_dataframe", basin, station, date_today, sep = "_"), ".csv", sep="")
	# m <- file.path(home_dir, "outputs/R_Data_Frames", file_name)
	# write.csv(df_P, m , row.names = FALSE)	
	# file_name <- paste(paste("waterbalance_dataframe", basin, station, date_today,  sep = "_"), ".csv", sep="")
	# m <- file.path(home_dir, "outputs/R_Data_Frames", file_name)
	# write.csv(df_WB, m , row.names = FALSE)

	# #############################################################################################
	# #Graphs of water balance
		date_breaks <- paste(trunc(( go_back + 10 )/10),"days")
	# #Unaccumulated precip using facet_wrap and geol_col
	#    p3b <- ggplot(df.wbl_var1, aes(x=date, y=value)) +
		p3b <- ggplot(df_P_ET, aes(x=date, y=value)) +
		#geom_line() + 
		geom_col(color = "black") +
		facet_wrap(~variable, scales = "free_y", nrow = 2) +
		geom_vline(xintercept = Xint, linetype="dashed", color = "black", size=0.3) +
		xlab("") +
		ylab("Fluxes (mm/30min)") +
		scale_x_datetime(date_breaks = date_breaks, labels=date_format("%m/%d")) +
		theme_bw() +
		theme(legend.position="none")
	# file_name <- paste("Precip_", station, "_", date_today, ".png", sep="")
	# ggsave(file_name, width = 26, height = 10, units = "cm", type = "cairo")    

	# #SWE
	# # p4 <- ggplot(df.wb_short, aes(x=date, y="Snow accumulation (SWE)", colour=type)) +
	# # geom_line() +
	# # xlab("")  + ylab("SWE (mm)") +
	# # scale_x_datetime(date_breaks = date_breaks, labels=date_format("%m/%d")) +
	# # theme_bw() +
	# # theme(legend.position="none")
	# #file_name11 <- paste("SWE_", station, "_", date_today, ".png", sep="")
	# #ggsave(file_name11, width = 26, height = 10, units = "cm", type = "cairo") 

	# #Soil moisture
	# # p5 <- ggplot(df.wb_short, aes(x=date, y="Total soil moisture", colour=type)) +
	# # geom_line() +
	# # xlab("Date")  + ylab("Soil moisture (mm)") +
	# # scale_x_datetime(date_breaks = date_breaks, labels=date_format("%m/%d")) +
	# # theme_bw() +
	# # theme(legend.position="none")
	# #file_name12 <- paste("soil_moisture_", station, "_", date_today, ".png", sep="")
	# #ggsave(file_name12, width = 26, height = 10, units = "cm", type = "cairo")

	# #  }

	# #GRAPHS

	# #theme_bw()
	


	################ Setting streamflow chart title& data depending on options (nudging/shifting) and station ############# 
		if (stations[i,11]==1) {
		tmp <- " (nudged) "
		} else {
		tmp <- " (not nudged) "
		}
		if (stations[i,12] != 0) {
		tmp <- paste(tmp, "& (shifted by", stations[i,12], "days)", sep =" ")
		}
		graph_title <- paste(station, tmp, "\n", station_name)
		if (Rating != "") {
			graph_title <- paste(graph_title, "\n", Rating) 	
		}
		#Selecting streamflow data for one station
		# cond3 <- flow_data_all$station==station
		# df_flow <- flow_data_all[cond3,]
		# rm(cond3)
		# file_name6 <- paste(paste("streamflow_dataframe", station, date_today, sep="_"),".csv", sep = "")
		# m <- file.path(home_dir, "outputs/R_Data_Frames", file_name6)
		# write.csv(flow_data, m , row.names = FALSE)
	

	#The historical data is prepared to create a dataframe containing min and max historical streamflow values for one station.

	#Creating dataframe for gauged flow (level is commented - can be added if needed)
		file_name6 <- paste(station, "_Streamflow_Archive.csv", sep = "")
		m <- file.path(home_dir, "streamflow/streamflow_archive", file_name6)
		# m <- file.path("D:/R/Debugging", file_name6)
		min_max <- read.csv(m, skip=1, stringsAsFactors = FALSE)
		param <- min_max[, 2]
		date_ribbon <- min_max[, 3]
		date_ribbonF <- as.Date(date_ribbon, format = "%m/%d/%Y")
		flow_level_ribbon <- min_max[, 4]
		df_hist_flow_level <- data.frame(date_ribbonF, flow_level_ribbon, param)
		
		
		#Extracting streamflow and level data 
		cond2a <- df_hist_flow_level$param==1
		#cond2b <- df_hist_flow_level$param==2
		df_hist_flow <- df_hist_flow_level[cond2a,]	
		#df_hist_level <- df_hist_flow_level[cond2b,]


		# For debugging
		# file_name <- paste("streamflow_min_max_", date_today, "_", station, ".csv", sep = "")
		# m <- file.path(home_dir, "outputs/R_Data_Frames", file_name)
		# write.csv(df_hist_flow, m , row.names = TRUE)
		
		# Using the streamflow_minmax_daily.R function to find min max for each day of the year based on the historical record.
		# In absence of historical record
		if (length(df_hist_flow$flow_level_ribbon) == 0 ) 
		{  

			#p2 <- ggplot(df_flow, aes(x=date, y=discharge, colour=type)) +
			p2 <- ggplot(flow_data, aes(x=date, y=discharge, colour=type)) + 
			geom_line() +
			geom_vline(xintercept = Xint, linetype="dashed", color = "black", size=0.3) +
			xlab("") +
			ylab(bquote('Discharge ('*m^3~s^-1*')')) +
			ggtitle(graph_title) +
			scale_colour_manual(values=type_color) +
			#theme_bw() +
			theme(plot.title = element_text(hjust = 0.5)) +
			#coord_trans(y="log10") + 
			scale_x_datetime(date_breaks = date_breaks, labels=date_format("%m/%d")) +
			theme(legend.title=element_blank()) +
			theme(legend.position="bottom")
			# file_name <- paste("discharge_", station, "_", date_today, ".png", sep="")
			# ggsave(file_name, width = 26, height = 10, units = "cm", type = "cairo")
		}

		else {
			minmax <- streamflow_minmax_daily(df_hist_flow, station)
			minmax <- na.omit(minmax)

			# For Debugging
			# file_name <- paste("streamflow_min_max_p", date_today, "_", station, ".csv", sep = "")
			# m <- file.path(home_dir, "outputs/R_Data_Frames", file_name)
			# write.csv(minmax, m , row.names = FALSE)

			# minmax <- minmax[-c(60), ]
			# # For Debugging
			# file_name <- paste("streamflow_min_max_processed", date_today, "_", station, ".csv", sep = "")
			# m <- file.path(home_dir, "outputs/R_Data_Frames", file_name)
			# write.csv(minmax, m , row.names = FALSE)

			# Changing fake year to current year
			# to be changed to read the year dynamically from today's date or so
			date_try <- format(minmax$date, format = "2022-%m-%d 12:00:00")
			date_try_2 <- as.POSIXct(date_try, format = "%Y-%m-%d %H:%M:%S", tz = "etc/GMT+8")
			date_try_2 <- na.omit(date_try_2)
			minmax$date <- date_try_2

		#	go back one more day (because hindcast starts at 16:00)
			start_date_minmax <- as.POSIXct(start_date - as.difftime(0.5, unit="days")) 	
			cond4 <- minmax$date>=start_date_minmax & minmax$date<=end_date
			minmax_short <- minmax[cond4,]

			#Graphs

			#Individual streamflow plots with min max values.
			#p2 <- ggplot(df_flow, aes(x=date, y=discharge, colour=type)) +
			p2 <- ggplot(flow_data, aes(x=date, y=discharge, colour=type)) + 
			geom_smooth(data=minmax_short, aes(x=date, y=min), colour = "grey50", lty=2, lwd=0.5, se = FALSE, span = 0.3) +
			geom_smooth(data=minmax_short, aes(x=date, y=max), colour = "grey50", lty=2, lwd=0.5, se = FALSE, span = 0.3) +
			geom_smooth(data=minmax_short, aes(x=date, y=median), colour = "grey50", lty=3, lwd=0.5, se = FALSE, span = 0.3) +
			geom_line() +
			geom_vline(xintercept = Xint, linetype="dashed", color = "black", size=0.3) +
			xlab("") + 
			ylab(bquote('Discharge ('*m^3~s^-1*')')) +
			ggtitle(graph_title) +
			scale_colour_manual(values=type_color) +
			#theme_bw() +
			theme(plot.title = element_text(hjust = 0.5)) +
			scale_x_datetime(date_breaks = date_breaks, labels=date_format("%m/%d")) + 
			# scale_y_log10() +
			theme(legend.title=element_blank()) +
			theme(legend.position="bottom")
			# coord_trans(y="log10")
			# file_name <- paste("discharge_", station, "_", date_today, ".png", sep="")
			# ggsave(file_name, width = 26, height = 10, units = "cm", type = "cairo")
		}
		rm(date_ribbon, flow_level_ribbon, param)
		rm(minmax, minmax_short, df_hist_flow_level, df_hist_flow, cond2a, cond4)
		if (stations[i,13] == 2) { # Just streamflow for this station - 1/2 page
		j <- j + 1
		p3 <- plot_grid(p2, nrow = 2, align = 'v', axis = 'l', rel_heights = c(0.5), rel_widths = c(1.5))
		graphlist[[j]] <- p3
		}
	##################################################################################

	# Water balance plots, faceted.
	#if (stations[i,13] == 1)
	#{
		filename <- paste("waterbalance_", station, "_", date_today, ".png", sep="") 
		p12 <- ggplot(df_WB, aes(date, value)) +
		geom_line() + 
		facet_wrap(~variable, scales = "free_y", nrow = 2) +
		xlab("") + 
		geom_vline(xintercept = Xint, linetype="dashed", color = "black", size=0.3) +
		ylab("State Variables (mm)") +
		scale_x_datetime(date_breaks = date_breaks, labels=date_format("%m/%d")) +
		theme_bw() +
		#theme(legend.title=element_blank())
		theme(legend.position="none") 
		# filename <- paste("Water_Balance_", station, "_", date_today, ".png", sep="")
		# ggsave(filename, p12, width = 26, height = 15, units = "cm", type = "cairo")

		##################################################################################

		# Combining water balance plots with the individual streamflow plots
		p11 <-  plot_grid(p2, p3b, p12, nrow = 3, align = 'v', axis = 'l', rel_heights = c(1.5, 1, 1), rel_widths = c(1.5, 1.5, 1.5))
		# filename <- paste("Summary_", station, "_", date_today, ".png", sep="")
		# ggsave(filename, p11, width = 26, height = 35, units = "cm", type = "cairo")
	
		j <- j + 1
		graphlist[[j]] <- p11
	}

} #end of main loop


#Overview plot of forecasts w/o min max values.

# p1 <- ggplot(flow_data_all, aes(date, discharge, colour = factor(type, labels = c("2-day forecast", "9-day forecast", "Gauged long record", "Gauged short record")))) +
# geom_line() + facet_wrap(~station_name, scales = "free_y", nrow = 5) +
# xlab("Date") + ylab(bquote('Discharge ('*m^3~s^-1*')')) +
# scale_x_datetime(date_breaks = date_breaks, labels=date_format("%m/%d"))
# p1 + theme(legend.title=element_blank(), panel.grid.major.y=element_line(colour="grey", size = (0.5)), panel.grid.minor.y=element_line(colour="grey", size = (0.05), linetype="dotdash"), panel.grid.major.x=element_line(colour="grey", size = (0.05)))
# file_name8 <- paste("Forecast_discharge_", date_today, ".pdf", sep="")
# ggsave(file_name8, width = 25, height = 30, units = "cm", type = "cairo")

#Combining plots in one single pdf file
pdf(file=report_file_name, paper="letter",width=8,height=10.5)
graphlist
while (!is.null(dev.list())) dev.off()
