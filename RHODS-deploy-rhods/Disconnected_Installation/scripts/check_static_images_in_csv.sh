#!/bin/bash

# Requirements:
# - yq version >= 4.30
# - Red Hat VPN connected
#
#  Usage: check_static_images_in_csv.sh ${rhods_version}
#  Ex) check_static_images_in_csv.sh 1.25


cd "$(dirname "$0")"

source utils.sh

log::str::print "${info}[INFO] Verifying if your system meets the pre-requirement for this script${clear}\n"

#Check if pre-requirements are met
check_requirement

rhods_version=$1
test_home=/tmp/check_images

if [[ ! -d ${test_home} ]]; then
  mkdir ${test_home}
fi

cd ${test_home}
if [[ ! -f ${test_home}/rhods-operator.clusterserviceversion.yml ]]; then
  echo "Download CSV from rhods-cpaas-midstream"
  wget -q https://gitlab.cee.redhat.com/data-hub/rhods-cpaas-midstream/-/raw/rhods-${rhods_version}-rhel-8/distgit/containers/odh-operator-bundle/bundle-template/manifests/rhods-operator.clusterserviceversion.yml >/dev/null
fi

if [[ ! -f ${test_home}/upstream_sources.yml ]]; then
  echo "Download upstream_resources.yaml from rhods-cpaas-midstream"
  wget -q https://gitlab.cee.redhat.com/data-hub/rhods-cpaas-midstream/-/raw/rhods-${rhods_version}-rhel-8/upstream_sources.yml >/dev/null
fi

echo 
echo "Clone all repositories for RHODS ${rhods_version} if it does not exist"
while read -r url && read -r branch; do
  name=$(basename ${url}|cut -d. -f1)
  if [ ! -d ${test_home}/${name} ]; then
    echo "Name: ${name}, URL: $url, Branch: $branch"
    git clone --quiet --branch $branch $url $name >/dev/null
  fi
done < <(yq eval '.git[] | [.url, .branch]' ${test_home}/upstream_sources.yml|sed 's/- //g')

echo
echo "[INFO] Start to check if the images in the CSV annotations are being used in any repositories"
not_being_used_images=()
for img in $(yq eval '.metadata.annotations | to_entries | map(select(.key | test("image"))) | .[].value' ./rhods-operator.clusterserviceversion.yml)
do
  echo -n "Checking.. ${img}"
  grep $img -wr ./ |grep -v rhods-operator.clusterserviceversion.yml >/dev/null
  if [[ $? == 1 ]]; then
    not_being_used_images+=(${img})
    echo "--> Fail"
  else
    echo "--> Pass"
  fi
done

echo
if [ ${#not_being_used_images[@]} -gt 0 ]; then
  echo "[ERROR: Detect some images in csv annotations are not being used in any repositories]"
  echo "[INFO: The following images are detected]"
  for element in "${not_being_used_images[@]}"
  do
    echo "- ${element}"
  done
else
  echo "[SUCCESS: All images in csv annotations are being used in RHODS repositories]"
fi

