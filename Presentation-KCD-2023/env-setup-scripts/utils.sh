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

die() {
  color_red='\e[31m'
  color_yellow='\e[33m'
  color_reset='\e[0m'
  printf "${color_red}FATAL:${color_yellow} $*${color_reset}\n" 1>&2
  exit 10
}

info() {
  color_blue='\e[34m'
  color_reset='\e[0m'
  printf "${color_blue}$*${color_reset}\n" 1>&2
}

success() {
  color_green='\e[32m'
  color_reset='\e[0m'
  printf "${color_green}$*${color_reset}\n" 1>&2
}

function log::str::print(){
    logText=$1
    
    printf "%s $logText" "$(log::time)" 
}

function log::time() {
    currentDate=$(date +"%Y%m%d %H:%M:%S")
    printf "[${yellow}${currentDate}${clear}]"
}

function wait_pod_deleted(){
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
                log::str::print "${green}[SUCCESS] Pod(s) with label '${pod_label}' is(are) deleted!${clear}\n"
                break
            else 
                tempcount=$((tempcount+1))
                log::str::print "${info}[Deleting] Pod(s) with label '${pod_label}' is(are) being deleted: $tempcount times${clear}\n"
                log::str::print "${info}[Deleting] Wait for 10 seconds${clear}\n"

                sleep 10
            fi
            if [[ $ready != $desired ]] && [[ $checkcount == $tempcount ]]
            then
                log::str::print "${error}[ERROR] Pod(s) with label '${pod_label}' is(are) NOT deleted${clear}\n"
                exit 1
            fi
        fi
    done

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

check_pod_status() {
  local -r JSONPATH="{range .items[*]}{'\n'}{@.metadata.name}:{@.status.phase}:{range @.status.conditions[*]}{@.type}={@.status};{end}{end}"
  local -r pod_selector="$1"
  local -r pod_namespace="$2"
  local pod_status
  local pod_entry

  pod_status=$(oc get pods -l $pod_selector -n $pod_namespace -o jsonpath="$JSONPATH") 
  oc_exit_code=$? # capture the exit code instead of failing

  if [[ $oc_exit_code -ne 0 ]]; then
    # kubectl command failed. print the error then wait and retry
    echo "Error running kubectl command."
    echo $pod_status
    return 1
  elif [[ ${#pod_status} -eq 0 ]]; then
    echo -n "No pods found with selector $pod_selector in $pod_namespace. Pods may not be up yet."
    return 1
  else
    # split string by newline into array
    IFS=$'\n' read -r -d '' -a pod_status_array <<<"$pod_status"

    for pod_entry in "${pod_status_array[@]}"; do
      local pod=$(echo $pod_entry | cut -d ':' -f1)
      local phase=$(echo $pod_entry | cut -d ':' -f2)
      local conditions=$(echo $pod_entry | cut -d ':' -f3)
      if [ "$phase" != "Running" ] && [ "$phase" != "Succeeded" ]; then
        return 1
      fi
      if [[ $conditions != *"Ready=True"* ]]; then
        return 1
      fi
    done
  fi
  return 0
}

wait_for_pods_ready() {
  local -r JSONPATH="{.items[*]}"
  local -r pod_selector="$1"
  local -r pod_namespace=$2
  local wait_counter=0
  local oc_exit_code=0
  local pod_status

  while true; do
    pod_status=$(oc get pods -l $pod_selector -n $pod_namespace -o jsonpath="$JSONPATH") 
    oc_exit_code=$? # capture the exit code instead of failing
    
    if [[ $oc_exit_code -ne 0 ]]; then
      # kubectl command failed. print the error then wait and retry
      echo $pod_status
      echo -n "Error running kubectl command."
    elif [[ ${#pod_status} -eq 0 ]]; then
      echo -n "No pods found with selector '$pod_selector' -n '$pod_namespace'. Pods may not be up yet."
    elif check_pod_status "$pod_selector" "$pod_namespace"; then
      echo "All $pod_selector pods in '$pod_namespace' namespace are running and ready."
      return
    else
      echo -n "Pods found with selector '$pod_selector' in '$pod_namespace' namespace are not ready yet."
    fi

    if [[ $wait_counter -ge 60 ]]; then
      echo
      oc get pods -l $pod_selector -n $pod_namespace
      die "Timed out after $((10 * wait_counter / 60)) minutes waiting for pod with selector: $pod_selector"
    fi

    wait_counter=$((wait_counter + 1))
    echo " Waiting 10 secs ..."
    sleep 10
  done
}

function oc::wait::object::availability() {
    local cmd=$1 # Command whose output we require
    local interval=$2 # How many seconds to sleep between tries
    local iterations=$3 # How many times we attempt to run the command

    ii=0
    echo "[START] Wait for \"${cmd}\" "
    while [ $ii -le $iterations ]
    do

        token=$($cmd &>>/dev/null) && returncode=$? || returncode=$?
        echo "$cmd "|sh

        if [ $returncode -eq 0 ]; then
            break
        fi

        ((ii=ii+1))
        if [ $ii -eq 100 ]; then
            echo "${cmd} did not return a value$"
            exit 1
        fi
        sleep $interval
    done
    echo "[END] \"${cmd}\" is successfully done"
}
