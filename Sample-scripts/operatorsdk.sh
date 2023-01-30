function usage(){
cat <<EOF
Usage :
       ./operatorsdk.sh [op|bundle|index] [build|push|deploy|undeploy] {options}

        options:
           --help
           --version=0.0.1    Set version, it will overwrite VERSION parameter
           --new              Set this, if it is the first time to create an index image

        Before you execute this command, please update base information editing the opeeratorsdk.sh.
        Such as IMG
EOF
}

# Customization Part
export BUILD_TOOL=podman 
export VERSION=0.0.8-test 
export OLD_VERSION=0.0.7 
export BASE_REPO=quay.io/jooholee 
export BASE_IMG=${BASE_REPO}/pachyderm-operator 
export BASE_BUNDLE_IMG=${BASE_REPO}/pachyderm-bundle 
export BASE_INDEX_IMG=${BASE_REPO}/pachyderm-index 

# Do not change these
export IMG=${BASE_IMG}:latest 
export VERSION_IMG=${BASE_IMG}:${VERSION} 
export BUNDLE_IMG=${BASE_BUNDLE_IMG}:${VERSION} 
export INDEX_IMG=${BASE_INDEX_IMG}:${VERSION} 
export OLD_INDEX_IMG=${BASE_INDEX_IMG}:${OLD_VERSION}


for iii in $1 $2 $3 
do
        if ( echo $iii | grep "\--version" &> /dev/null )
        then
                c_version=`echo $iii | awk -F "=" '{print $2}'`
                if [[ z$c_version == z ]]; then
                        echo usage : --version=0.0.7
                        exit 1
                else
                        VERSION=$c_version
                fi
        fi
        if ( echo $iii | grep "\--new" &> /dev/null )
        then
            NEW=True
        fi

        if ( echo $iii | grep "\help" &> /dev/null )
        then
           usage
           exit 0
        fi
done

# Verify command parameters
if [[ $1 != 'op' &&  $1 != 'bundle' && $1 != 'index' ]]
then
   echo "Error: Wrong command line: $1 is not expected first parameter"
   echo ""
   usage
   exit 1
fi

if [[ $2 != 'build' &&  $2 != 'push' && $2 != 'deploy' && $2 != 'undeploy' ]]
then
   echo "Error: Wrong command line: $2 is not expected second parameter"
   echo ""
   usage
   exit 1
fi

if [[ $2 == 'build' ]]
then

  if [[ $1 == 'op' ]]
  then
    make docker-build
    ${BUILD_TOOL} tag $IMG ${VERSION_IMG}
  fi

  if [[ $1 == 'bundle' ]]
  then
    make bundle-build
  fi

  if [[ $1 == 'index' ]]
  then
     if [[ z${NEW} == z ]]
     then
        echo "index"
        opm index add --bundles ${BUNDEL_IMG} --from-index ${OLD_INDEX_IMG} -t ${INDEX_IMG} -u ${BUILD_TOOL}
     else
        echo "new index"
        opm index add --bundles ${BUNDLE_IMG} --tag ${INDEX_IMG} -u ${BUILD_TOOL}
     fi
  fi
fi


if [[ $2 == 'push' ]]
then
  if [[ $1 == 'op' ]]
  then
    ${BUILD_TOOL} push ${IMG}
    ${BUILD_TOOL} push ${VERSION_IMG} 
  fi

  if [[ $1 == 'bundle' ]]
  then
    make bundle-push
  fi

  if [[ $1 == 'index' ]]
  then
    ${BUILD_TOOL} push ${INDEX_IMG}
  fi
fi

if [[ $2 == 'deploy' ]]
then 
   if [[ $1 == 'op' || $1 == 'bundel' ]]
   then
      echo "deploy is only for index"
   else
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: pachyderm-catalog
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: ${INDEX_IMG}
EOF
   fi
fi

if [[ $2 == 'undeploy' ]]
then 
   if [[ $1 == 'op' || $1 == 'bundel' ]]
   then
      echo "deploy is only for index"
   else
      oc delete catalogsource pachyderm-catalog -n openshift-marketplace 
   fi
fi
