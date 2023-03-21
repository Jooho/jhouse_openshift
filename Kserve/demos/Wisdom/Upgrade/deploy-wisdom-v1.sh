source env.sh

# mkdir -p $DEMO_HOME
cd $DEMO_HOME

export rhods_version=1.23.0
export wisdom_img_tag=wisdom-v1-v6  
export runtime_version=0.0.3


if [[ z${RHODS_INSTALL} == z ]];then
  oc new-project ${RHODS_OP_NS}
  oc create -f ${COMMON_MANIFESTS_HOME}/subs-rhods-operator-latest.yaml -n ${RHODS_OP_NS}
  check_pod_ready name=rhods-operator ${RHODS_OP_NS}

  #(Optional) If you want to deploy ModelMesh only, execute the following command when RHODS installation done.
  ## Remove other components except Model Mesh
  #  oc delete kfdef rhods-anaconda rhods-dashboard rhods-nbc rhods-notebooks -n ${RHODS_APP_NS}

  check_pod_ready app=model-mesh ${RHODS_APP_NS}
  check_pod_ready app=odh-model-controller ${RHODS_APP_NS}

  oc -n ${RHODS_APP_NS} \
      patch configmap \
      servingruntimes-config \
      -p "$(cat ${COMMON_MANIFESTS_HOME}/wisdom-servingruntimes-configmap-${runtime_version}.yaml)"

  oc delete pod -l control-plane=modelmesh-controller --force  -n ${RHODS_APP_NS}
  
  check_pod_ready app=model-mesh ${RHODS_APP_NS}
  check_pod_ready app=odh-model-controller ${RHODS_APP_NS}
fi


# Deploy Minio
if [[ z${MINIO_INSTALL} == z ]];then
  ACCESS_KEY_ID=THEACCESSKEY
  SECRET_ACCESS_KEY=$(openssl rand -hex 32)

  oc new-project ${MINIO_NS}

  #Please ask jooho about the secret file
  sed 's/jooholee-pull-secret/custom-registry-secret/g' -i  ~/Downloads/jooholee-secret.yml 
  oc create -f ~/Downloads/jooholee-secret.yml --namespace=${MINIO_NS}

  oc patch serviceaccount default -p '{"imagePullSecrets": [{"name": "custom-registry-secret"}]}' -n ${MINIO_NS}

  sed "s/<accesskey>/$ACCESS_KEY_ID/g"  ${COMMON_MANIFESTS_HOME}/minio.yaml | sed "s+<secretkey>+$SECRET_ACCESS_KEY+g" | sed "s+quay.io/opendatahub/modelmesh-minio-examples:v0.8.0+quay.io/jooholee/modelmesh-minio-examples:${wisdom_img_tag}+g" |tee ./minio-current.yaml | oc -n ${MINIO_NS} apply -f -

  sed "s/<accesskey>/$ACCESS_KEY_ID/g" ${COMMON_MANIFESTS_HOME}/minio-secret.yaml | sed "s+<secretkey>+$SECRET_ACCESS_KEY+g" |sed 's+http://minio.modelmesh-serving.svc:9000+http://minio.minio.svc:9000+g'  | tee ./minio-secret-current.yaml | oc -n ${MINIO_NS} apply -f - 
  
  check_pod_ready app=minio ${MINIO_NS}
fi

#Setup Namespace for Wisdom runtime
if [[ z${WISDOM_INSTALL} == z ]];then
  oc new-project ${test_mm_ns}
  oc label namespace ${test_mm_ns} modelmesh-enabled=true --overwrite=true
  oc label namespace ${test_mm_ns} opendatahub.io/dashboard=true --overwrite=true

  echo "please create IBM registry secret"
  read createdSecret

  # Minio secret
  oc apply -f ./minio-secret-current.yaml -n ${test_mm_ns}
  oc apply -f  ${COMMON_MANIFESTS_HOME}/sa_user.yaml -n ${test_mm_ns}

  # Create servingRuntime in the test ns
  oc apply -f ${COMMON_MANIFESTS_HOME}/wisdom-servingruntime-${runtime_version}.yaml -n ${test_mm_ns}

  # Create inferenceService
cat <<EOF |oc apply -f - 
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: ansible-wisdom
  annotations:
    serving.kserve.io/deploymentMode: ModelMesh
spec:
  predictor:
    model:
      modelFormat:
        name: watson
      runtime: watson-runtime
      storage:
        key: localMinIO
        path: wisdom/aw_model/
EOF

  sleep 2

  oc patch serviceaccount modelmesh-serving-sa -p '{"imagePullSecrets": [{"name": "ibm-registry-secret"}]}'    

  oc delete pod --all --force

  check_pod_ready modelmesh-service=modelmesh-serving  ${test_mm_ns}
fi

if [[ z${PORT_FORWARD} == z ]];then
cat << EOF
Please copy & paste the following for test wisdom v1

cd ${DEMO_HOME}

git clone --branch v0-15 git@github.com:rh-aiservices-pilot/ans-wis-model.git

cd ans-wis-model/clientcalls
chmod 777 grpcurl.sh

sed 's/gpu-version-inference-service-v05/ansible-wisdom/g' -i ./grpcurl.sh

./grpcurl.sh "install node on rhel" 
EOF

  oc port-forward --address 0.0.0.0 service/modelmesh-serving 8033 -n ${test_mm_ns}
fi