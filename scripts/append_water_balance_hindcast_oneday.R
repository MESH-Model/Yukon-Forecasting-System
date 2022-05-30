#!/usr/local/bin/Rscript

#This R code appends 24-hour capa hindcast water balance data one basin at a time.
#Keep in mind that today's date is today's date until 00:00:00 UTC-6 for CST.
#Careful, the data is appended to the file if it exists already.

args <- commandArgs(TRUE)

dt <- args[1] #date is start date of forecast data
#print(dt)

home_dir <- args[2]
setwd(paste(home_dir,"/outputs/water_balance_archive", sep=''))

date_yesterday <- as.POSIXct(dt, format = "%Y%m%d")
date_before_yesterday <- as.POSIXct(date_yesterday - as.difftime(1, unit="days"))

date_yesterday <- format(date_yesterday, "%Y%m%d")
date_before_yesterday <- format(date_before_yesterday, "%Y%m%d")

print(date_yesterday)
print(date_before_yesterday)

#Reading station information, including setup (or basin)
stations <- read.csv (paste(home_dir, "/scripts/", args[3], ".txt", sep=''), header=TRUE, sep=",")
#stations

for (i in 1:length(stations[,1]))
{
    basin <- as.character(stations[i,1]) 
    station <- as.character(stations[i,2])
	print(paste(basin,station, sep=" "))
	
	output_file <- paste(paste("hindcasted_water_balance_appended", basin, station, "till", date_yesterday, sep='_'),".csv",sep='')
	if (file.exists(output_file)) {	#data has already been processed - no need to do anything
		print(paste(output_file, "is already done, skipping", sep =" "))
		next
	}
	
   	# Read yesterday's file for the current station - which has all time series from all previous hindcasts
	input_file <- paste(paste("hindcasted_water_balance_appended", basin, station, "till", date_before_yesterday, sep='_'),".csv",sep='')

	WB_old <- data.frame(matrix(ncol = 5, nrow = 0))
	if (file.exists(input_file)) {
		WB_old <- read.csv(input_file, header=FALSE, stringsAsFactors = FALSE, sep=" ")
		print(input_file)
	}
	names(WB_old) <- c("date_time", "precip", "evap", "snow", "soil_moisture")
	
	#Reading and appending hindcast water balance outputs.
	dates <- paste(date_before_yesterday, "16_to_", date_yesterday, "16", sep='')
    
	# Temporarily use the basin file because their is a bug in sub-basins ts files 
	input_file_capa <- paste("RESULTS/Basin_average_water_balance_ts_", station,".csv", sep='')
	#input_file_capa <- "RESULTS/Basin_average_water_balance_ts.csv"
	f <- file.path(home_dir, "capa_hindcasts", basin, dates, input_file_capa)
	if (file.exists(f)) 
	{
		print(f)
		WB <- read.csv(f, header=TRUE, stringsAsFactors = FALSE) 

		#Formatting the date from day of year to regular date format.
		WB_date <- paste(WB[, 1], WB[, 2], WB[, 3], WB[, 4])
		WB_dateF <- as.POSIXct(WB_date, format = "%Y %j %H %M", tz = "etc/GMT+8")
		WB_dateCh <- as.character(WB_dateF)

		# Extract only the necessary fields
		precip <- WB[, 12] #half-hourly precipitation, not accumulated (mm) 
		evap <- WB[, 13]
		snow <- WB[, 20] #SWE  (mm)
	   
		#average total soil moisture: liquid + frozen for all layers (mm) - depends on number of layers which varies by setup.
		#therefore, column number is read from station info file
		soil_m <- WB[, stations[i,3]] 

		WB_new <- data.frame(WB_dateCh, precip, evap, snow, soil_m)
		names(WB_new) <- c("date_time", "precip", "evap", "snow", "soil_moisture")

		# Bind the most recent hindcast with the old cumulative frame and write to a new file
		# One appended file for each basin/station combination
		df_WB <- rbind(WB_old, WB_new)
		# This guards for any repetition in case the script is called again for any reason
		date_time <- df_WB[,2]		
		df_WB <- subset(df_WB, !duplicated(date_time))
		
		write.table(df_WB, file = output_file, sep = " ", append = FALSE, quote = TRUE, eol = "\n", na = "NA", col.names = FALSE, row.names = FALSE)
		if (file.exists(input_file)) {
			file.remove(input_file)		# All info is included in today's file so we do not need yesterday's
	}
		} else {
			print(paste(f, "is not found, skipping", sep =" "))
	}
}
