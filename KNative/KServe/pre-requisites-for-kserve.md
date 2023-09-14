# KServe ServerlessDeployment with RHODS on ROSA

*Environment*
 - [ROSA](https://aws.amazon.com/rosa/)

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
export DEMO_HOME=/tmp/kserve
mkdir -p $DEMO_HOME
cd $DEMO_HOME

# Clone jhouse repository
git clone https://github.com/Jooho/jhouse_openshift.git

# Export common script
source ${DEMO_HOME}/jhouse_openshift/Kserve/demos/utils/common.sh

# Export ModelMesh Manifests
export MM_MANIFESTS_HOME=${DEMO_HOME}/jhouse_openshift/Kserve/docs/ServerlessDeployment/manifests

# Export common manifests dir
export COMMON_MANIFESTS_HOME=${DEMO_HOME}/jhouse_openshift/Kserve/docs/Common/manifests

export RHODS_OP_NS=redhat-ods-operator
export RHODS_APP_NS=redhat-ods-applications
export MINIO_NS=minio
export test_ns=kserve-demo
~~~


## Installation

**Install Pre-requisites(Serverless, Service Mesh) and KServe**
~~~
git clone git@github.com:Jooho/openshift-ai-serving-test.git
cd openshift-ai-serving-test

./commands/kserve-rhods-install.sh
~~~

## Clean up
~~~
./commands/kserve-dependencies-clean.sh
~~~
