. env.sh
current_prj_name=${PROJECT_NAME}
operator_prj_name=openshift-operators

isPodReady(){
  local pod_name=$1
  local prj_name=$2

  if [[ z${prj_name} == z ]]
  then 
    prj_name=${current_prj_name}
  fi

  ready_pod=$(oc get pod -n ${prj_name} |grep $pod_name  |awk '{print $2}' |cut -d/ -f1)
  desired_pod=$(oc get pod -n ${prj_name} | grep $pod_name |awk '{print $2}' |cut -d/ -f2)

  if [[ ${ready_pod} == ${desired_pod} ]]
  then 
	  echo "0" # READY
  else
      echo "1" # NOT READY
  fi
  sleep 5
}

waitForPodsReady(){
  local target_pod_label=$1
  local target_pod_count=$2
  local prj_name=$3
  
  echo "Expected ready pods count: $target_pod_count"

  if [[ z${prj_name} == z ]]
  then 
    prj_name=${current_prj_name}
  fi
  
  podsReady=1
  ready_pod_count=0
  while [[ ${podsReady} != 0 && ${ready_pod_count} != ${target_pod_count}  ]]
  do
    # sleep 5
    for pod in $(oc get pods --field-selector status.phase=Running -l deployment=my-microcksinstall -l $target_pod_label -o name)
    do
        echo $pod
        pod_name=$(echo $pod|cut -d'/' -f2)
        # echo $pod_name
        isPodReady pod_name
        podsReady=$?
        
        if [[ $podsReady != 0 ]]; then
          echo "Not Ready POD found. Rechecking"
          ready_pod_count=0
          break
        else 
          ((ready_pod_count = ready_pod_count + 1))
          if [[ ${ready_pod_count} == ${target_pod_count} ]]
          then
            echo "ALL POD READY: $ready_pod_count"
          else
            echo "READY POD Count: $ready_pod_count"
          fi
        fi 
    done
  done

}

waitForPodsReady  "app=my-microcksinstall" "5"
