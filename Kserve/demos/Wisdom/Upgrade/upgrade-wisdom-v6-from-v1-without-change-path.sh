
source env.sh

export rhods_version=1.23.0
export wisdom_img_tag=wisdom-v1-v6  
export runtime_version=0.19.1

# Change Model
if [[ z${MODEL_UPDATE} == z ]];then
  oc exec pod/minio -n ${MINIO_NS} -- mv /data1/modelmesh-example-models/wisdom/aw_model /data1/modelmesh-example-models/wisdom/aw_model_v1/

  oc exec pod/minio -n ${MINIO_NS} -- mv /data1/modelmesh-example-models/wisdom/aw_model_v2 /data1/modelmesh-example-models/wisdom/aw_model/
  
  # Verify Model Version 6
  oc exec pod/minio -n ${MINIO_NS} -- ls /data1/modelmesh-example-models/wisdom/aw_model
fi

# Update Serving Runtime ConfigMap
if [[ z${SRT_CONFIG_UPDATE} == z ]];then
  oc -n ${RHODS_APP_NS} \
      patch configmap \
      servingruntimes-config \
      -p "$(cat ${COMMON_MANIFESTS_HOME}/wisdom-servingruntimes-configmap-${runtime_version}.yaml)"

  oc delete pod -l control-plane=modelmesh-controller --force -n ${RHODS_APP_NS}

  check_pod_ready app=model-mesh ${RHODS_APP_NS}
  check_pod_ready app=odh-model-controller ${RHODS_APP_NS}
fi

if [[ z${SRT_UPDATE} == z ]];then
  echo 
  echo "*****************************************************************"
  echo "please create Quay.io registry secret(custom-registry-secret) for runtime"
  echo "(Example)"
cat <<EOF
oc create -f ~/Downloads/jooholee-secret.yml --namespace=${test_mm_ns}

oc patch serviceaccount modelmesh-serving-sa -p '{"imagePullSecrets": [{"name": "custom-registry-secret"}]}'  -n ${test_mm_ns} 
EOF
  read createdSecret
  oc apply -f ${COMMON_MANIFESTS_HOME}/wisdom-servingruntime-${runtime_version}-configmap.yaml -n ${test_mm_ns}

  oc apply -f ${COMMON_MANIFESTS_HOME}/wisdom-servingruntime-${runtime_version}.yaml -n ${test_mm_ns}

  check_pod_ready name=modelmesh-serving-watson-runtime  ${test_mm_ns}
fi

if [[ z${CHECK_MODEL_SIZE} == z ]];then
  # Check Model size
  model_size=$(oc exec -it deploy/modelmesh-serving-watson-runtime -c puller -- du -h --max-depth=1 /models)
  echo 
  echo "Model Size: "
  echo $model_size
  echo

  model_size=$(echo $model_size|awk '{print $1}')
  while [[ $model_size == "0" ]]; 
  do
    echo "MODEL is not loaded well so restart one of the serving runtime pods"
    oc delete pod $(oc get pod --no-headers=true|head -1|awk '{print $1}')

    check_pod_ready name=modelmesh-serving-watson-runtime  ${test_mm_ns}
    model_size=$(oc exec -it deploy/modelmesh-serving-watson-runtime -c puller -- du -h --max-depth=1 /models)
  done
fi

if [[ z${PORT_FORWARD} == z ]];then
cat << EOF
Please copy & paste the following for test wisdom v1

cd ${DEMO_HOME}
cd ans-wis-model
git restore -- *
git checkout -b main origin/main

cd clientcalls
chmod 777 grpcurl.sh

MNAME=ansible-wisdom ./grpcurl.sh "install node on rhel" 
EOF

  oc port-forward --address 0.0.0.0 service/modelmesh-serving 8033 -n ${test_mm_ns}
fi