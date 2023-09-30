export BASE_DIR=/tmp/kserve
export BASE_CERT_DIR=${BASE_DIR}/certs
export TEST_NS=kserve-demo
export MINIO_NS=minio


getKserveNS() {
  if [[ ${TARGET_OPERATOR} == "odh" ]]
  then
    echo "opendatahub"
  else
    echo "redhat-ods-applications"
  fi
}

getOpType() {
  target_op=$1
  if [[ ${target_op} == "odh" ]]
  then
    echo "odh"
  else
    echo "rhods"
  fi
}

getOpNS() {
  target_op=$1
  if [[ ${target_op} == "odh" ]]
  then
    echo "openshift-operators"
  else
    echo "redhat-ods-operator"
  fi
}

export TARGET_OPERATOR=odh
export TARGET_OPERATOR_TYPE=$(getOpType $TARGET_OPERATOR)
export KSERVE_OPERATOR_NS=$(getKserveNS)
export TARGET_OPERATOR_NS=$(getOpNS ${TARGET_OPERATOR_TYPE})
