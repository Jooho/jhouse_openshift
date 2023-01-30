
source common.sh
# ISTIO_DIR=istio
# ISTIO_BIN_DIR=$ISTIO_DIR/bin

# #Download istioctl
# exist=$(check_binary_exist ${ISTIO_DIR})

# if [[ ${exist}  == 0 ]]
# then
#   # curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.16.1 TARGET_ARCH=x86_64 sh -
#   echo "Download ISTIO binary"
#   curl -L https://istio.io/downloadIstio | sh -
#   mv $(ls -d |grep 1) ${ISTIO_DIR}
# else
#   echo "ISTIO directory exist"
# fi

# echo "Installalling Istio Operator"
# oc adm policy add-scc-to-group anyuid system:serviceaccounts:istio-system
# # $ISTIO_BIN_DIR/istioctl operator init --set profile=openshift
# $ISTIO_BIN_DIR/istioctl operator init 

oc create -f $manifest_dir/istio-sub.yaml
