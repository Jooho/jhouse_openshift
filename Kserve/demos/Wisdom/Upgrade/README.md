# Wisdom Upgrade Demo

## Setup
`./setup.sh`

**Steps**
~~~
./setup.sh
cd /tmp/modelmesh
~~~

## Install V1 Ansible Wisdom 
./deploy-wisdom-v1.sh

**Environmental variables**
- RHODS_INSTALL
- MINIO_INSTALL
- WISDOM_INSTALL
- PORT_FORWARD

**Steps**
~~~
source ./env.sh

# Install RHODS
MINIO_INSTALL=false WISDOM_INSTALL=false PORT_FORWARD=false ./deploy-wisdom-v1.sh

# Install MINIO
RHODS_INSTALL=false WISDOM_INSTALL=false PORT_FORWARD=false ./deploy-wisdom-v1.sh

# Deploy Wisdom
RHODS_INSTALL=false MINIO_INSTALL=false PORT_FORWARD=false ./deploy-wisdom-v1.sh

# Test
RHODS_INSTALL=false MINIO_INSTALL=false WISDOM_INSTALL=false ./deploy-wisdom-v1.sh
~~~

## Upgrade to V6

### Replace model files with the same path. 
`./upgrade-wisdom-v6-from-v1-without-change-path.sh`

**Environmental variables**
- MODEL_UPDATE=false 
- SRT_UPDATE=false 
- SRT_CONFIG_UPDATE=false 
- CHECK_MODEL_SIZE=false 
- PORT_FORWARD=false

~~~
source ./env.sh

# Update Model
PORT_FORWARD=false CHECK_MODEL_SIZE=false SRT_CONFIG_UPDATE=false SRT_UPDATE=false ./upgrade-wisdom-v6-from-v1-without-change-path.sh

# Update ServingRuntime Configmap 
PORT_FORWARD=false CHECK_MODEL_SIZE=false SRT_UPDATE=false MODEL_UPDATE=false ./upgrade-wisdom-v6-from-v1-without-change-path.sh

# Update ServingRuntime in a namespace
PORT_FORWARD=false CHECK_MODEL_SIZE=false SRT_CONFIG_UPDATE=false MODEL_UPDATE=false ./upgrade-wisdom-v6-from-v1-without-change-path.sh

# Test
CHECK_MODEL_SIZE=false SRT_CONFIG_UPDATE=false SRT_UPDATE=false MODEL_UPDATE=false ./upgrade-wisdom-v6-from-v1-without-change-path.sh


# If test failed, check Model size
oc exec -it deploy/modelmesh-serving-watson-runtime -c puller -- du -h --max-depth=1 /models

# Check modelsize
PORT_FORWARD=false SRT_CONFIG_UPDATE=false SRT_UPDATE=false MODEL_UPDATE=false ./upgrade-wisdom-v6-from-v1-without-change-path.sh

~~~


### Replace model files with the different path. 
`./upgrade-wisdom-v6-from-v1-with-change-path.sh`

**Environmental variables**
- MODEL_UPDATE=false 
- SRT_UPDATE=false 
- SRT_CONFIG_UPDATE=false 
- CHECK_MODEL_SIZE=false 
- PORT_FORWARD=false

~~~
source ./env.sh

# Update Model
PORT_FORWARD=false CHECK_MODEL_SIZE=false SRT_CONFIG_UPDATE=false SRT_UPDATE=false ./upgrade-wisdom-v6-from-v1-with-change-path.sh

# Update ServingRuntime Configmap 
PORT_FORWARD=false CHECK_MODEL_SIZE=false SRT_UPDATE=false MODEL_UPDATE=false ./upgrade-wisdom-v6-from-v1-with-change-path.sh

# Update ServingRuntime in a namespace
PORT_FORWARD=false CHECK_MODEL_SIZE=false SRT_CONFIG_UPDATE=false MODEL_UPDATE=false ./upgrade-wisdom-v6-from-v1-with-change-path.sh

# Test
CHECK_MODEL_SIZE=false SRT_CONFIG_UPDATE=false SRT_UPDATE=false MODEL_UPDATE=false ./upgrade-wisdom-v6-from-v1-with-change-path.sh


# If test failed, check Model size
oc exec -it deploy/modelmesh-serving-watson-runtime -c puller -- du -h --max-depth=1 /models

# Check modelsize
PORT_FORWARD=false SRT_CONFIG_UPDATE=false SRT_UPDATE=false MODEL_UPDATE=false ./upgrade-wisdom-v6-from-v1-with-change-path.sh

~~~




## Cleanup
~~~
./cleanup.sh
~~~
