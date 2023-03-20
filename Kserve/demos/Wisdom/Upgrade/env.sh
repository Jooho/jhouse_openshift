# Export demo home
export DEMO_HOME=/tmp/modelmesh

# Export common script
source ${DEMO_HOME}/jhouse_openshift/Kserve/demos/utils/common.sh

# Export ModelMesh Manifests
export MM_MANIFESTS_HOME=${DEMO_HOME}/jhouse_openshift/Kserve/docs/Modelmesh/manifests

# Export common manifests dir
export COMMON_MANIFESTS_HOME=${DEMO_HOME}/jhouse_openshift/Kserve/docs/Common/manifests

# Export ModelMesh Demo Scripts
export MM_UPGREAD_DEMO_HOME=${DEMO_HOME}/jhouse_openshift/Kserve/demos/Wisdom/Upgrade


export RHODS_OP_NS=redhat-ods-operator
export RHODS_APP_NS=redhat-ods-applications
export MINIO_NS=minio
export test_mm_ns=wisdom
