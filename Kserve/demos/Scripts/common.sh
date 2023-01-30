#!/bin/bash

export root_dir=/tmp/KServe
export install_dir=${root_dir}/Installation
export script_dir=${install_dir}/Scripts
export manifest_dir=${install_dir}/Manifests


# Check folder for each component 
check_binary_exist() {
  
  if [[ $(ls -d $1|wc -l) == 1 ]] 
  then
    echo 1     #1 is existing
  else
    echo 0
  fi
}