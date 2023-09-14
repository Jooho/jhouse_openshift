# Showcase (Hello World) 

## [Install pre-requisite](./pre-requisites-for-kserve.md)

**Pre-resuisite steps & check**
~~~
# Check yq version
yq --version
yq (https://github.com/mikefarah/yq/) version v4.30.8

# Check jq version
jq --version
jq-1.6

# Check grpcurl version
grpcurl --version
grpcurl v1.8.7

# Export demo home
export DEMO_HOME=/tmp/knative
mkdir -p $DEMO_HOME
cd $DEMO_HOME

# Clone jhouse repository
git clone https://github.com/Jooho/jhouse_openshift.git

# Export common script
source ${DEMO_HOME}/jhouse_openshift/Kserve/demos/utils/common.sh

# Export ModelMesh Manifests
export MM_MANIFESTS_HOME=${DEMO_HOME}/jhouse_openshift/Knative/Kserve/manifests

# Export common manifests dir
export COMMON_MANIFESTS_HOME=${DEMO_HOME}/jhouse_openshift/Knative/Common/manifests

export test_ns=knative-demo
~~~

## Deploy Showcase
~~~
oc new-projcet $test_ns
oc create -f ${MM_MANIFESTS_HOME}/showcase.yaml
~~~

## Test
~~~
KSVC_URL=$(oc get ksvc showcase -ojsonpath='{.status.url}')

curl -k ${KSVC_URL}
~~~
