#!/bin/bash

# Set the color variable
red='\033[0;31m'
light_red='\033[0;91m'
cyan='\033[0;36m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
light_blue='\033[0;94m'
# Clear the color after that
clear='\033[0m'

# Set the color for log level
info=$cyan
warning=$yellow
error=$red
pending=$light_blue

export only_log_file_options="2>&1 > /dev/null"

function log::str::print(){
    logText=$1
    
    printf "%s $logText" "$(log::time)" 
}

function log::time() {
    currentDate=$(date +"%Y%m%d %H:%M:%S")
    printf "[${yellow}${currentDate}${clear}]"
}

check_requirement(){
  echo " yq --version ${only_log_file_options}"| sh 
 
  if [[ $? != 0 ]]; then
    log::str::print "${error}yq is not installed${clear}"
    exit 1
  fi
 yq_version=$(yq --version | grep -oE '[0-9]+\.[0-9]+')

  if [ $(echo "${yq_version} < 4.9" | bc -l) != 1 ]; then
    log::str::print "${error}yq version(${yq_version}) is too old${clear}"
    exit 1
 fi

  echo "curl -s https://gitlab.cee.redhat.com ${only_log_file_options}"| sh 
  if [[ $? != 0 ]];then
    log::str::print "${error}Red Hat VPN is required${clear}"
    exit 1
  fi
}