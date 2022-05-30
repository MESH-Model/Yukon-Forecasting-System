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
	report_file_name <- paste("Water_Level_Forecast_", args[3], "_", date_today, ".pdf", sep = "")
} else {
	report_file_name <- paste(paste("Water_Level_Forecast", args[3], date_today, "starting", format(start_date, "%Y%m%d"),sep = "_"), ".pdf", sep = "")
}
	
#nudging_report <- paste("Nudging_Report", date_today,".csv", sep = "")
#file.create("my.csv")
file <- paste(args[3], ".txt", sep="")
station_path <- file.path(home_dir, "scripts", file)
lakes <- read.csv(station_path, header = TRUE, sep = ",", stringsAsFactors = FALSE)
#stations
if (nudged == 0)  # Nudging is disabled globally
{
	lakes[, 8] <- 0
}
# type_color <- c("black", "gray50", "magenta3", "magenta", "royalblue3", "royalblue", "orangered3", "orangered")

graphlist <- list()
j <- 0
station <- c('0')

for (i in 1:length(lakes[, 1])) {
	New <- 0
	# Determine colors - this assigns colors based on model type consistently	
	if ( station != lakes[i,2]) {		# This is a new lake
		type_color <- NULL
		New <- 1
	}
	if ( lakes[i,7] == '10K-old' ) {
		type_color <- append(type_color, c("magenta3", "violet"))
	}
	if ( lakes[i,7] == '5K' ) {
		type_color <- append(type_color, c("orangered3", "sienna1"))
	} 
	if ( lakes[i,7] == '10K' ) {
		type_color <- append(type_color, c("royalblue3", "deepskyblue"))
	} 
	print(type_color)
	basin <- lakes[i, 1]
	station <- lakes[i, 2]
	region <- lakes[i,3]
	lake <- lakes[i,4]
	station_name <- lakes[i, 5]	
	lake_area <- lakes[i,6]

	print(paste(basin,station, sep=" "))

	###############################################################################
	#Reading observed gauged short record (few days)	
	# Reading in the data from .csv file
	if ( New ==1 )
	{
		file_name <- paste(region, "_", station, "_hourly_hydrometric_", date_today, ".csv", sep = "")
		file_name <- file.path(home_dir, "streamflow", station, file_name)
		#  o_path <- file.path("D:/Yukon_MESH_forecast/SHARE_MESH/test_ggplot", file_name1)
		gauged_s <- read.csv(file_name, skip=1, stringsAsFactors = FALSE)

		# Preparing variables to go into the data frame of the gauged data.
		dateF_s <- as.POSIXct(gauged_s[, 2], format = "%Y-%m-%dT%H:%M:%S-08:00", tz = "etc/GMT+8")
		level_s <- gauged_s[, 3]
		type_s <- "WSC real-time"
		gauged_frame_s <- data.frame(type_s, station, dateF_s, level_s)
		names(gauged_frame_s) <- c("type", "station", "date", "level")
		# omit data with missing levels or discharge (value = 99999)
		gauged_frame_s <- subset(gauged_frame_s,!is.na(level))
		gauged_frame_s <- subset(gauged_frame_s,level < 99999)
		non_NA<-which(!is.na(gauged_frame_s$level))
		if (length(non_NA) > 0)
		{
			type_color <- type_color <- append(c("gray50"), type_color)
		}
		rm(gauged_s, type_s, dateF_s, level_s)
		
		#################################################################################
		# Reading observed gauged long record (archive from beginning of season)
		# Modified by Mohamed Elshamy on June 16, 2020
		# Reading in the data from .csv file
		input_file <- paste(paste("gauged_hydrometric_appended", station, "till", dt, sep='_'),".csv",sep='')
		input_file <- file.path(home_dir, "outputs/streamflow_archive", input_file)
		gauged_l <- read.csv(input_file, header=FALSE, stringsAsFactors = FALSE, sep=" ")
		
		dateF_l <- as.POSIXct(gauged_l[, 1], format = "%Y-%m-%dT%H:%M:%S-08:00", tz = "etc/GMT+8")
		level_l <- gauged_l[, 2]
		type_l <- "WSC near real-time"
		gauged_frame_l <- data.frame(type_l, station,  dateF_l, level_l)
		names(gauged_frame_l) <- c("type", "station", "date", "level")
		cond1 <- gauged_frame_l$date>=start_date
		gauged_frame_l <- gauged_frame_l[cond1,]
		gauged_frame_l <- subset(gauged_frame_l,!is.na(level))
		gauged_frame_l <- subset(gauged_frame_l,level < 99999)
		non_NA<-which(!is.na(gauged_frame_l$level))
		if (length(non_NA) > 0)
		{
			type_color <- type_color <- append(c("black"), type_color)
		}
		rm(gauged_l, cond1, type_l, dateF_l, level_l)
	}
	##################################################################################
	#Reading simulated level (CaPA-RDPS hindcast)
	# Added by Mohamed Elshamy on May 26, 2020

	input_file <- paste(paste("hindcasted_level_appended", basin, station, "till", dt, sep='_'),".csv",sep='')
	input_file <- file.path(home_dir, "outputs/streamflow_archive", input_file)
	model_hindcast <- read.csv(input_file, header = FALSE, stringsAsFactors = FALSE, sep=" ")

	#Format date and apply shift
	date1 <- as.POSIXct(model_hindcast[, 1], format = "%Y-%m-%d %H:%M:%S", tz = "etc/GMT+8")
	date1 <- date1 + as.difftime(lakes[i,9], unit="days")
	# Apply shift
	date1 <- date1 + as.difftime(lakes[i,9], unit="days")
	
	# Converting day of year date format into the working format for the model streamflow values.
	#dateF2 <- as.POSIXct(date2, format = "%Y %j %H %M", tz = "etc/GMT+8")

	# The following if statement deals with mesh model files that contain values from 2 stations (one watershed).
	# ME 1/5/2020 - stations info should have the column number for the station to remove all hard coded stations names 
	level1 <- model_hindcast[, 2]
	type1 <- paste("RDPS","-",lakes[i,7],sep="")
	
	#  print(model_RDPS[1, 9])
	
	model_hindcast_frame <- data.frame(type1, station, date1, level1)
	cond1 <- model_hindcast_frame$date>=start_date
	model_hindcast_frame <- model_hindcast_frame[cond1,]

	#Renaming RDPS data frame variables
	names(model_hindcast_frame) <- c("type", "station", "date", "level")
	rm(model_hindcast, cond1, type1, date1, level1)
	
	##################################################################################
	#Reading simulated level (RDPS forecast)

	#  m <- file.path(home_dir, "streamflow", basin, "MESH_output_streamflow_ts_RDPS.csv")
	file_name2 <- paste("MESH_output_reach",lake,"ts.csv",sep="_")
	t = paste(dt,"16",sep='')
	#print(file_name2)
	m <- file.path(home_dir, "gem_forecasts", basin, t ,"RDPS/RESULTS", file_name2)
	model_RDPS <- read.csv(m, header = TRUE, stringsAsFactors = FALSE)

	# Read date	
	dateF2 <- paste(model_RDPS[, 1], model_RDPS[, 2], model_RDPS[, 3], model_RDPS[, 4])
	# Convert day of year date format into the working format for the model streamflow 
	dateF2 <- as.POSIXct(dateF2, format = "%Y %j %H %M", tz = "etc/GMT+8")
	# Apply shift
	dateF2 <- dateF2 + as.difftime(lakes[i,9], unit="days")

	# The following if statement deals with mesh model files that contain values from 2 lakes (one watershed).
	# ME 1/5/2020 - lakes info should have the column number for the station to remove all hard coded lakes names 
	#discharge2 <- model_RDPS[, lakes[i,4]*2+4]
	level2 <- model_RDPS[, 6]/lake_area
	type2 <- paste("RDPS","-",lakes[i,7],sep="")

	model_RDPS_frame <- data.frame(type2, station, dateF2, level2)

	#Renaming RDPS data frame variables
	names(model_RDPS_frame) <- c("type", "station", "date", "level")
	rm(model_RDPS, type2, dateF2, level2)
	
	####################################################################################  
	#Reading simulated streamflow (GDPS forecast)

	#  m <- file.path(home_dir, "streamflow", basin, "MESH_output_streamflow_ts_GDPS.csv")
	file_name3 <- paste("MESH_output_reach",lake,"ts.csv",sep="_")
	# m <- file.path("/home/ec2-user/Yukon/streamflow", basin, filename2)
	m <- file.path(home_dir, "gem_forecasts", basin, t, "GDPS/RESULTS", file_name3)
	# m <- file.path("D:/Yukon_MESH_forecast/SHARE_MESH/test_ggplot", file_name2)
	model_GDPS <- read.csv(m, header = TRUE, stringsAsFactors = FALSE)

	# Read date	
	dateF3 <- paste(model_GDPS[, 1], model_GDPS[, 2], model_GDPS[, 3], model_GDPS[, 4])
	# Convert day of year date format into the working format for the model streamflow 
	dateF3 <- as.POSIXct(dateF3, format = "%Y %j %H %M", tz = "etc/GMT+8")
	# Apply shift
	dateF3 <- dateF3 + as.difftime(lakes[i,9], unit="days")
	Xint <- dateF3[1]
	print(Xint)
	#discharge3 <- model_GDPS[, lakes[i,4]*2+4]
	level3 <- model_GDPS[, 6]/lake_area
	type3 <- paste("GDPS","-",lakes[i,7],sep="")

	#Producing GDPS data frame with streamflow and level.
	model_GDPS_frame <- data.frame(type3, station, dateF3, level3)
	names(model_GDPS_frame) <- c("type", "station", "date", "level")
	rm(model_GDPS, type3,  dateF3, level3)

	######################################################################################
	#Nudging

	#Finding the indices of the first occurence of model day 1 16:30 in gauged data.
	x1 <- match(model_RDPS_frame$date[1],gauged_frame_s$date)
	# print(gauged_frame_s$date[x1])
	#print(x1)
	# if (i == 1) {
	# x1 <- 523
	# }
	# x2 is not ued?
	# x2 <- match(start_date, gauged_frame_l$date)
	print(x1)

	# Nudging the model values to have both curves start at same y value.
	if (is.na(gauged_frame_s$level[x1])) {
		#gauged_frame_s_noNA <- na.omit(gauged_frame_s$level)
		# print(gauged_frame_s$level)
		diff1 <- model_RDPS_frame$level[1] - tail(gauged_frame_s$level, n=1)
		#   print(tail(gauged_frame_s$level, n=1))
		diff2 <- model_GDPS_frame$level[1] - tail(gauged_frame_s$level, n=1)
		#diff3 <- tail(model_hindcast_frame$level, n=1) - tail(gauged_frame_s$level, n=1)		
		print("is missing level measurements. The last entry was used.") 
		print(paste(diff1, diff2, sep=" "))
		
	}
	else {

		diff1 <- model_RDPS_frame$level[1] - gauged_frame_s$level[x1]
		diff2 <- model_GDPS_frame$level[1] - gauged_frame_s$level[x1] 
		#diff3 <- tail(model_hindcast_frame$level,n=1) - gauged_frame_s$level[x1]	
		print(paste(diff1, diff2, sep=" "))
	}
	# ME May 7 2020 - check if diff1 or diff2 are NA to disable nudging 
	# as it results in NA for simulated flow and nothing gets plotted
	if (is.na(diff1) || is.na(diff2))
	{
		diff1 <- 0
		diff2 <- 0
		#diff3 <- 0
		lakes[i,8] <- 0
	}

	#ME May 4 2020 - Added a flag to disable nudging to be read from lakes_info.txt
	if (lakes[i,8]==1) {
		model_RDPS_frame$level <- model_RDPS_frame$level - diff1
		model_GDPS_frame$level <- model_GDPS_frame$level - diff2
		# Disable the next line to stop nudging hindcasts
		model_hindcast_frame$level <- model_hindcast_frame$level - diff1
	}
	#write.table(c(station, diff1, diff2, diff3), file = paste(home_dir, "/outputs/Forecast_Plots_v2/Nudging.csv"), append = TRUE, quote = TRUE, sep = " ", eol = "\n", na = "NA", dec = ".", row.names = TRUE, col.names = FALSE, qmethod = c("escape", "double"), fileEncoding = "")

	#######################################################################################
	# Combining data frames from one station
	if ( New == 1)
	{
		level_data <- rbind(gauged_frame_l,gauged_frame_s,model_hindcast_frame, model_RDPS_frame, model_GDPS_frame)
	} else {
		level_data <- rbind(level_data,model_hindcast_frame, model_RDPS_frame, model_GDPS_frame)
	}
	#Combining data frames from all lakes
	# if (i == 1) {
	  # level_data_all <- level_data
	  # #print(flow_data$discharge)
	# } else
	# {
	  # level_data_all <- rbind(level_data_all, level_data)
	# }
	# rm(level_data)
	
	# Writing the gauged and modelled streamflow data to a file to use it in RStudio
	# uncomment for debugging purposes
	# file_name6 <- paste("streamflow_dataframe_", date_today, ".csv", sep = "")
	# m <- file.path(home_dir, "outputs/R_Data_Frames", file_name6)
	# write.csv(flow_data_all, m , row.names = FALSE)

	################ Setting streamflow chart title& data depending on options (nudging/shifting) and station ############# 
	if (lakes[i, 10] == 2) 
	{
		if (lakes[i,8]==1)
		{
			tmp <- " (nudged) "
		} else {
			tmp <- " (not nudged) "
		}
		if (lakes[i,9] != 0) 
		{
			tmp <- paste(tmp, "& (shifted by", lakes[i,8], "days)", sep =" ")
		}
		graph_title <- paste(station, tmp, "\n", station_name) 	
	#print(graph_title)
	#Selecting streamflow data for one station
	# cond3 <- level_data_all$station==station
	# df_level <- level_data_all[cond3,]
	# rm(cond3)
	
	################ Simulated streamflow with historical max, min and median ##################### 

	#The historical data is prepared to create a dataframe containing min and max historical streamflow values for one station.

	#Creating dataframe for gauged flow (level is commented - can be added if needed)
		file_name6 <- paste(station, "_Streamflow_Archive.csv", sep = "")
		m <- file.path(home_dir, "streamflow/streamflow_archive", file_name6)
		min_max <- read.csv(m, skip=1, stringsAsFactors = FALSE)
		param <- min_max[, 2]
		date_ribbon <- min_max[, 3]
		date_ribbonF <- as.Date(date_ribbon, format = "%m/%d/%Y")
		flow_level_ribbon <- min_max[, 4]
		df_hist_flow_level <- data.frame(date_ribbonF, flow_level_ribbon, param)
		
		#Extracting streamflow and level data 
		#cond2a <- df_hist_flow_level$param==1
		cond2b <- df_hist_flow_level$param==2
		#df_hist_flow <- df_hist_flow_level[cond2a,]	
		df_hist_level <- df_hist_flow_level[cond2b,]

		# For debugging
		# file_name <- paste("streamflow_", date_today, "_", station, ".csv", sep = "")
		# m <- file.path(home_dir, "outputs/R_Data_Frames", file_name)
		# write.csv(df_level, m , row.names = TRUE)
		
		# Using the streamflow_minmax_daily.R function to find min max for each day of the year based on the historical record.
		# In absence of historical record
		date_breaks <- paste(trunc(( go_back + 10 )/10),"days")
		if (length(df_hist_level$flow_level_ribbon) == 0) 
		{  

		#p2 <- ggplot(df_flow, aes(x=date, y=discharge, colour=type)) +
		p2 <- ggplot(level_data, aes(x=date, y=level, colour=type)) + 
		geom_line() +
		geom_vline(xintercept = Xint, linetype="dashed", color = "black", size=0.3) +
		xlab("") +
		ylab("Water Level (m)") +
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
		minmax <- streamflow_minmax_daily(df_hist_level, station)
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

	#Individual water level plots with min max values.
	#p2 <- ggplot(df_flow, aes(x=date, y=discharge, colour=type)) +
		p2 <- ggplot(level_data, aes(x=date, y=level, colour=type)) + 
		geom_smooth(data=minmax_short, aes(x=date, y=min), colour = "grey50", lty=2, lwd=0.5, se = FALSE, span = 0.3) +
		geom_smooth(data=minmax_short, aes(x=date, y=max), colour = "grey50", lty=2, lwd=0.5, se = FALSE, span = 0.3) +
		geom_smooth(data=minmax_short, aes(x=date, y=median), colour = "grey50", lty=3, lwd=0.5, se = FALSE, span = 0.3) +
		geom_line() + 
		geom_vline(xintercept = Xint, linetype="dashed", color = "black", size=0.3) +
		xlab("") + 
		ylab("Water Level (m)") +
		ggtitle(graph_title) +
		scale_colour_manual(values=type_color) +
		#theme_bw() +
		theme(plot.title = element_text(hjust = 0.5)) +
		scale_x_datetime(date_breaks = date_breaks, labels=date_format("%m/%d")) + 
		# scale_y_log10() +
		theme(legend.title=element_blank()) +
		theme(legend.position="bottom")
		# coord_trans(y="log10")
		# file_name <- paste("level_", station, "_", date_today, ".png", sep="")
		# ggsave(file_name, width = 26, height = 10, units = "cm", type = "cairo")
		
		rm(date_ribbon, flow_level_ribbon, param)
		rm(minmax, minmax_short, df_hist_flow_level, df_hist_level, cond2b, cond4)	
		}
		j <- j + 1
		p3 <- plot_grid(p2, nrow = 2, align = 'v', axis = 'l', rel_heights = c(0.5), rel_widths = c(1.5))
		graphlist[[j]] <- p3
	}
	
} #end of main loop

#Combining plots in one single pdf file
pdf(file=report_file_name, paper="letter",width=8,height=10.5)
graphlist
while (!is.null(dev.list())) dev.off()
