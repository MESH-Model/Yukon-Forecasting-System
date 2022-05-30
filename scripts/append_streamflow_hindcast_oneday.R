#!/usr/local/bin/Rscript

#This R code appends 24-hour capa hindcast streamflow one station at a time.
#Keep in mind that today's date is today's date until 00:00:00 UTC-6 for CST.
#Careful, the data is appended to the file of yesterday, then yesterday's file is deleted

args <- commandArgs(TRUE)

dt <- args[1] #date is start date of forecast data

home_dir <- args[2]
setwd(paste(home_dir,"/outputs/streamflow_archive", sep=''))

date_yesterday <- as.POSIXct(dt, format = "%Y%m%d")
date_before_yesterday <- as.POSIXct(date_yesterday - as.difftime(1, unit="days"))

date_yesterday <- format(date_yesterday, "%Y%m%d")
date_before_yesterday <- format(date_before_yesterday, "%Y%m%d")

#Reading station information, including setup (or basin)
stations <- read.csv (paste(home_dir, "/scripts/", args[3], ".txt", sep=''), header=TRUE, sep=",")
#stations

 for (i in 1:length(stations[,1]))
 {
	basin <- as.character(stations[i,1]) 
	station <- as.character(stations[i,2]) 
	print(paste(basin,station, sep=" "))
	
	output_file <- paste(paste("hindcasted_streamflow_appended", basin, station, "till", date_yesterday, sep='_'),".csv",sep='')
	if (file.exists(output_file)) {	#data has already been processed - no need to do anything
		print(paste(output_file, "is already done, skipping", sep =" "))		
		next
	}
	
	# Read yesterday's file for the current station - which has all time series from all previous hindcasts
	input_file <- paste(paste("hindcasted_streamflow_appended", basin, station, "till", date_before_yesterday, sep='_'),".csv",sep='')

	flow_old <- data.frame(matrix(ncol = 2, nrow = 0))
    if (file.exists(input_file)) {
		flow_old <- read.csv(input_file, header=FALSE, stringsAsFactors = FALSE, sep=" ")
		print(input_file)
	}
    names(flow_old) <- c("date_time", "discharge")
	
	#Reading hindcasted streamflow for the most recent date
	dates <- paste(date_before_yesterday, "16_to_", date_yesterday, "16", sep='')
	input_file_capa <- paste("RESULTS/MESH_output_streamflow_ts.csv", sep='')
	f <- file.path(home_dir, "capa_hindcasts", basin, dates, input_file_capa)
	if (file.exists(f)) 
	{
		print(f)
		flow <- read.csv(f, header=TRUE, stringsAsFactors = FALSE)

		#Formatting the date from day of year to regular date format.
		flow_date <- paste(flow[, 1], flow[, 2], flow[, 3], flow[, 4])
		flow_dateF <- as.POSIXct(flow_date, format = "%Y %j %H %M", tz = "etc/GMT+8")
		flow_dateCh <- as.character(flow_dateF)

		flow_sim <- flow[, stations[i,4]*2+4]

		flow_new <- data.frame(flow_dateCh, flow_sim)
		names(flow_new) <- c("date_time", "discharge")
		
		# Bind the most recent hindcast with the old cumulative frame and write to a new file
		# One appended file for each basin/station combination
		flow_all <- rbind(flow_old, flow_new)
		# This guards for any repetition in case the script is called again for any reason
		date_time <- flow_all[,2]		
		flow_all <- subset(flow_all, !duplicated(date_time))
		
		write.table(flow_all, file = output_file, sep = " ", append = FALSE, quote = TRUE, eol = "\n", col.names = FALSE, row.names = FALSE)
		if (file.exists(input_file)) {
			file.remove(input_file)		# All info is included in today's file so we do not need yesterday's
		}
	} else {
			print(paste(f, "is not found, skipping", sep =" "))
	}
 }
 