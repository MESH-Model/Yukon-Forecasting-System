#!/usr/local/bin/Rscript

#This R code reads in water balance forecast. Produces a file for each station.
#Keep in mind that today's date is today's date until 00:00:00 UTC-6 for CST.

args <- commandArgs(TRUE)
dt <-args[1] #date is start date of forecast data
home_dir <- args[2]

setwd(paste(home_dir,"/outputs/water_balance_forecast", sep=''))

date_yesterday <- as.POSIXct(dt, format = "%Y%m%d")
date_today<-as.POSIXct(date_yesterday + as.difftime(1, unit="days"))

date_yesterday <- format(date_yesterday, "%Y%m%d")
date_today <- format(date_today, "%Y%m%d")

print(date_yesterday)
print(date_today)

#Reading the names of stations.
# ME - 1/5/2020 - 3/5/3020
# Merged stations.txt and stations_RC.csv into stations_info.txt and updated the script to include basin as well as station
stations <- read.csv (paste(home_dir, "/scripts/", args[3], ".txt", sep=''), header=TRUE, sep=",")
stations

for (i in 1:length(stations[,1]))
{
	basin <- as.character(stations[i,1]) 
	station <- as.character(stations[i,2])
	print(paste(basin,station, sep=" "))
	
	# Reading in water balance GDPS forecast. Date in filepath is yesterday's date, dt.
	date <- paste(date_yesterday, "16", sep="")
	# Temporarily use the basin file because their is a bug in sub-basins ts files 
	input_file_GDPS <- paste("Basin_average_water_balance_ts_", station,".csv", sep='')
	# input_file_GDPS <- paste("Basin_average_water_balance_ts.csv", sep='')
	f <- file.path(home_dir, "gem_forecasts", basin, date, "GDPS/RESULTS", input_file_GDPS)
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
		#therefore, column number is read from file
		soil_m <- WB[, stations[i,3]] 

		df_WB <- data.frame(WB_dateCh, precip, evap, snow, soil_m)
		names(df_WB) <- c("date", "precip", "evap", "snow", "soil_moisture")

		#One appended file for each station.
		output_file <- paste("water_balance_forecast_reworked_", basin, "_", station, "_", date_today, ".csv", sep='')

		if (file.exists(output_file)) {
			file.remove(output_file)
		} else {
			file.create(output_file)
		}

		write.table(df_WB, file = output_file, sep = " ", append = FALSE, quote = TRUE, eol = "\n", na = "NA", col.names = FALSE, row.names = FALSE)
	} else {
			print(paste(f, "is not found, skipping", sep =" "))
	}
}



