#!/bin/bash

set -aex

# This needs heirloom-mailx

dt=$1
if [ -z $1 ]; then
    echo 'MISSING argument $1 should equal date to run'
    exit 1
fi
dt=$(date -d $1 -u +%Y%m%d)
dt1=$(date -d $1 -u "+%B %d, %Y")

home_dir=$2
scripts_file_path=$home_dir/scripts

eval $(cat $scripts_file_path/smtp.txt)

subject="Forecast Support Charts - "$dt1
body=$scripts_file_path"/message.ME.txt"

#declare -a attachment
attachment1="/home/ec2-user/Yukon_Forecasting/outputs/Forecast_Plots/"$dt"/Streamfow_Forecast_All_Stations_"$dt".pdf"
#attachment2="/home/ec2-user/Yukon_Forecasting/outputs/Forecast_Plots/"$dt"/Streamfow_Forecast_09EB001-WSCRating_"$dt".pdf"
attachment3="/home/ec2-user/Yukon_Forecasting/outputs/Forecast_Plots/"$dt"/Water_Level_Forecast_6lakes_"$dt".pdf"
 
mailx -v -s "$subject" -r "$from" -c "$cc" -q $body -a $attachment1 -a $attachment3 -S smtp=$smtpserver \
                              -S smtp-use-starttls \
                              -S smtp-auth=login \
                              -S smtp-auth-user=$user \
                              -S smtp-auth-password=$password \
                              -S ssl-verify=ignore \
                              -S nss-config-dir=/etc/pki/nssdb/ \
                              -S sendwait \
                               "$to" <<< ""