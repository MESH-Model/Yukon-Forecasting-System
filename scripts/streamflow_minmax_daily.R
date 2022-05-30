#' Finds min and max streamflow values for each day of the year
#' @return If unsuccessful, returns \code{FALSE}. If successful, returns a \pkg{ggplot2} object.
#' @author Dominique Richard

streamflow_minmax_daily <- function(obs="", obsName="") {
  
  obs$fakedate <- as.Date(format(obs$date_ribbonF, format = "2001-%m-%d"), format = "%Y-%m-%d")
  obs <- na.omit(obs)
  # aggregate
  dailymin <- aggregate(obs[,2], by = list(obs$fakedate), FUN = "min")
  dailymax <- aggregate(obs[,2], by = list(obs$fakedate), FUN = "max")
  dailymedian <- aggregate(obs[,2], by = list(obs$fakedate), FUN = "median")
  daily <- data.frame( dailymin, dailymax[,2], dailymedian[,2], obsName)
  names(daily) <- c("date", "min", "max", "median", "name")
  
  return(daily)
}