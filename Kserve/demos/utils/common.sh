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


function log::str::print(){
    logText=$1
    
    printf "%s $logText" "$(log::time)" 
}

function log::time() {
    currentDate=$(date +"%Y%m%d %H:%M:%S")
    printf "[${yellow}${currentDate}${clear}]"
}


function check_pod_ready(){
    pod_label=$1
    namespace=$2
    checkcount=20
    tempcount=0
    while true; do
        pod_exist=$(oc get pod -l ${pod_label} -n ${namespace} --ignore-not-found)

        if [[ ${pod_exist} != '' ]]
        then
            ready=$(oc get pod -l ${pod_label} -n ${namespace} --no-headers|head -1|awk '{print $2}'|cut -d/ -f1)
            desired=$(oc get pod -l ${pod_label} -n ${namespace} --no-headers|head -1|awk '{print $2}'|cut -d/ -f2)

            if [[ $ready == $desired ]]
            then
                log::str::print "${green}[SUCCESS] Pod(s) with label '${pod_label}' is(are) Ready!${clear}\n"
                break
            else 
                tempcount=$((tempcount+1))
                log::str::print "${pending}[PENDING] Pod(s) with label '${pod_label}' is(are) ${red}NOT${clear}${pending} Ready yet: $tempcount times${clear}\n"
                log::str::print "${pending}[PENDING] Wait for 10 seconds${clear}\n"

                sleep 10
            fi
            if [[ $ready != $desired ]] && [[ $checkcount == $tempcount ]]
            then
                log::str::print "${error}[ERROR] Pod(s) with label '${pod_label}' is(are) NOT Ready${clear}\n"
                exit 1
            fi
        else 
            log::str::print "${pending}[PENDING] Pod is NOT created yet${clear}\n"
            sleep 10
        fi
    done
}


function oc::wait::object::availability() {
    local cmd=$1 # Command whose output we require
    local interval=$2 # How many seconds to sleep between tries
    local iterations=$3 # How many times we attempt to run the command

    ii=0

    while [ $ii -le $iterations ]
    do

        token=$($cmd &>>/dev/null) && returncode=$? || returncode=$?
        echo "$cmd ${only_log_file_options}"|sh

        if [ $returncode -eq 0 ]; then
            break
        fi

        ((ii=ii+1))
        if [ $ii -eq 100 ]; then
            log::str::print "${error}${cmd} did not return a value${clear}"
            exit 1
        fi
        sleep $interval
    done
}