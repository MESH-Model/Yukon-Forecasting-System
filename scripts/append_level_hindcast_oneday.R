#!/usr/local/bin/Rscript

#This R code appends 24-hour capa hindcast water level one lake at a time.
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

#Reading lake information, including setup (or basin)
lakes <- read.csv (paste(home_dir, "/scripts/", args[3], ".txt",  sep=''), header=TRUE, sep=",")
#lakes

 for (i in 1:length(lakes[,1]))
 {
	basin <- as.character(lakes[i,1]) 
	lake <- as.character(lakes[i,2]) 
	lake_num <- lakes[i,4]
	lake_area <- lakes[i,6]
	print(paste(basin,lake, sep=" "))
	
	output_file <- paste(paste("hindcasted_level_appended", basin, lake, "till", date_yesterday, sep='_'),".csv",sep='')
	if (file.exists(output_file)) {	#data has already been processed - no need to do anything
		print(paste(output_file, "is already done, skipping", sep =" "))		
		next
	}
	
	# Read yesterday's file for the current lake - which has all time series from all previous hindcasts
	input_file <- paste(paste("hindcasted_level_appended", basin, lake, "till", date_before_yesterday, sep='_'),".csv",sep='')

	level_old <- data.frame(matrix(ncol = 2, nrow = 0))
    if (file.exists(input_file)) {
		level_old <- read.csv(input_file, header=FALSE, stringsAsFactors = FALSE, sep=" ")
		print(input_file)
	}
    names(level_old) <- c("date_time", "level")
	
	# Writing the gauged and modelled streamflow data to a file to use it in RStudio
	# uncomment for debugging purposes
	# file_name6 <- paste("old_level_dataframe_", date_yesterday, ".csv", sep = "")
	# m <- file.path(home_dir, "outputs/R_Data_Frames", file_name6)
	# write.csv(level_old, m , row.names = FALSE)
	
	
	#Reading hindcasted level for the most recent date
	dates <- paste(date_before_yesterday, "16_to_", date_yesterday, "16", sep='')
	input_file_capa <- paste("RESULTS/MESH_output_reach_",lake_num,"_ts.csv", sep='')
	f <- file.path(home_dir, "capa_hindcasts", basin, dates, input_file_capa)
	if (file.exists(f)) 
	{
		print(f)
		level <- read.csv(f, header=TRUE, stringsAsFactors = FALSE)

		#Formatting the date from day of year to regular date format.
		level_date <- paste(level[, 1], level[, 2], level[, 3], level[, 4])
		level_dateF <- as.POSIXct(level_date, format = "%Y %j %H %M", tz = "etc/GMT+8")
		level_dateCh <- as.character(level_dateF)

		level_sim <- level[, 6]/lake_area

		level_new <- data.frame(level_dateCh, level_sim)
		names(level_new) <- c("date_time", "level")
		# Writing the gauged and modelled streamflow data to a file to use it in RStudio
		# uncomment for debugging purposes
		# file_name6 <- paste("new_level_dataframe_", date_yesterday, ".csv", sep = "")
		# m <- file.path(home_dir, "outputs/R_Data_Frames", file_name6)
		# write.csv(level_new, m , row.names = FALSE)
	
		# Bind the most recent hindcast with the old cumulative frame and write to a new file
		# One appended file for each basin/lake combination
		level_all <- rbind(level_old, level_new)
		# This guards for any repetition in case the script is called again for any reason
		date_time <- level_all[,2]		
		level_all <- subset(level_all, !duplicated(date_time))
		
		write.table(level_all, file = output_file, sep = " ", append = FALSE, quote = TRUE, eol = "\n", col.names = FALSE, row.names = FALSE)
		if (file.exists(input_file)) {
			file.remove(input_file)		# All info is included in today's file so we do not need yesterday's
		}
	} else {
			print(paste(f, "is not found, skipping", sep =" "))
	}
 }
 