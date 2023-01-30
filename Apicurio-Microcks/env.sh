# Customize Part
export PROJECT_NAME=apicurio-demo-3
export MICROCKS_CR_NAME=microks
export DOMAIN=apps.isvdemoprd.tqxf.p1.openshiftapps.com
export STORAGE_CLASS_NAME=nfs
export MICROCKS_KC_USER=jlee
export MICROCKS_KC_PW=1234

# Do not update
export KEYCLOAK_URL=${MICROCKS_CR_NAME}-keycloak-${PROJECT_NAME}.${DOMAIN}
export DB_PW=apicurio_12345
export DB_ROOT_PW=apicurio_root_12345
export DB_USER=apicurio
export APICURIO_URL=apicurio-studio-ui-${PROJECT_NAME}.${DOMAIN}
export APICURIO_API_URL=apicurio-studio-api-${PROJECT_NAME}.${DOMAIN}
export APICURIO_WS_URL=apicurio-studio-ws-${PROJECT_NAME}.${DOMAIN}
export APICURIO_KC_REALM=microcks
export APICURIO_KC_CLIENT_ID=apicurio-studio
export APICURIO_KC_CLIENT_SECRET=57b682ce-d764-4e8e-a546-fb758204a899
export MICROCKS_URL=${MICROCKS_CR_NAME}-${PROJECT_NAME}.${DOMAIN}
export MICROCKS_KC_CLIENT_ID=microcks-serviceaccount
export MICROCKS_KC_CLIENT_SECRET=ab54d329-e435-41ae-a900-ec6b3fe15c54
export current_prj_name=${PROJECT_NAME}
export operator_prj_name=openshift-operators
export microcks_dir=${PWD}/microcks
export apicurio_dir=${PWD}/apicurio