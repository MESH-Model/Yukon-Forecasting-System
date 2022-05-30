#!/usr/local/bin/Rscript

#This R code appends 24-hour capa hindcast streamflow one station at a time.
#Keep in mind that today's date is today's date until 00:00:00 UTC-6 for CST.
#Careful, the data is appended to the file of yesterday, then yesterday's file is deleted

#library(dplyr)
args <- commandArgs(TRUE)

dt <- args[1] #date is start date of forecast data

home_dir <- args[2]
setwd(paste(home_dir,"/outputs/streamflow_archive", sep=''))

date_yesterday <- as.POSIXct(dt, format = "%Y%m%d")
date_before_yesterday <- as.POSIXct(date_yesterday - as.difftime(1, unit="days"))

date_yesterday <- format(date_yesterday, "%Y%m%d")
date_before_yesterday <- format(date_before_yesterday, "%Y%m%d")

print(date_yesterday)
print(date_before_yesterday)

#Reading station information, including setup (or basin)
lakes <- read.csv (paste(home_dir, "/scripts/", args[3], ".txt", sep=''), header=TRUE, sep=",")
#stations
# Only the list of station IDs are needed - unique ones
stations <- lakes[,2:3]
stations <- unique(stations)
stations
for (i in 1:length(stations[,1]))
{
	station <- as.character(stations[i,1]) 
	region <- as.character(stations[i,2]) 
	print(paste(station, region, sep =" "))
	
	output_file <- paste(paste("gauged_hydrometric_appended", station, "till", date_yesterday, sep='_'),".csv",sep='')

	if (file.exists(output_file)) {	#data has already been processed - no need to do anything
		print(paste(output_file, "is already done, skipping", sep =" "))
		next
	} 
	
	# Read yesterday's file for the current station - which has all time series from all previous hindcasts
	input_file <- paste(paste("gauged_hydrometric_appended", station, "till", date_before_yesterday, sep='_'),".csv",sep='')

	hydromet_old <- data.frame(matrix(ncol = 3, nrow = 0))
    if (file.exists(input_file)) {
		hydromet_old <- read.csv(input_file, header=FALSE, stringsAsFactors = FALSE, sep=" ")
		print(input_file)
	}
    names(hydromet_old) <- c("date_time", "level", "discharge")
	# hydromet_old <- hydromet_old[-c(1,4:6,8:10)]
	
	#Reading downloaded hydromet for today
	input_file_guaged <- paste(region, "_", station, "_daily_hydrometric_", date_yesterday, ".csv", sep = "")
	f <- file.path(home_dir, "streamflow", station, input_file_guaged)
	if (file.exists(f)) 
	{
		print(f)
		hydromet <- read.csv(f, header=TRUE, stringsAsFactors = FALSE)

		# hydromet_new <- data.frame(flow_dateCh, flow_sim)
		names(hydromet) <- c("station", "date_time", "level", "level-grade", "level-sysmbol", "level-QC", "discharge", "discharge-grade", "discharge-symbol", "discharge-QC")
		# omit non-necessary fields - keep only date_time, level and discharge
		hydromet <- hydromet[-c(1,4:6,8:10)]
		# omit data with missing levels or discharge (value = 99999)
		hydromet <- subset(hydromet,!is.na(level))
		hydromet <- subset(hydromet,level < 99999)
		#hydromet <- subset(hydromet,discharge < 99999)
		
		# Bind the most recent daily hydromet file with the old cumulative frame and write to a new file
		# One appended file for each station 
		hydromet_new <- rbind(hydromet_old, hydromet)
		# This guards for any repetition in case the script is called again for any reason
		date_time <- hydromet_new[,2]	
		hydromet_new2 <- subset(hydromet_new, !duplicated(date_time))

		write.table(hydromet_new2, file = output_file, sep = " ", append = FALSE, quote = TRUE, eol = "\n", col.names = FALSE, row.names = FALSE)
		if (file.exists(input_file)) {
			file.remove(input_file)		# All info is included in today's file so we do not need yesterday's
		}
	} else {	# No information to add
			print(paste(f, "is not found, skipping", sep =" "))
	}
}
