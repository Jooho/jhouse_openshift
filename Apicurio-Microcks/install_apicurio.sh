source ./env.sh
source ./scripts/utils.sh

# Create a project if it does not exist.
createNS ${PROJECT_NAME}

# Setup Keycloak for Apicurio
# Get token from Keycloak
RESULT=`curl -k --data "username=admin&password=microcks123&grant_type=password&client_id=admin-cli" https://${MICROCKS_CR_NAME}-keycloak-${PROJECT_NAME}.${DOMAIN}/auth/realms/${APICURIO_KC_REALM}/protocol/openid-connect/token
`
TOKEN=`echo $RESULT | sed 's/.*access_token":"//g' | sed 's/".*//g'`
echo ${TOKEN}
# curl -k -X POST -d "{ \"clientId\": \"apicurio-studio\", \"redirectUris\": [\"https:\/\/${APICURIO_URL}/*\"], \"secret\": \"${APICURIO_KC_CLIENT_SECRET}\", \"directAccessGrantsEnabled\":\"true\", \"webOrigins\": [\"+\"]  }"  -H "Content-Type:application/json" -H "Authorization: bearer ${TOKEN}"  https://${MICROCKS_CR_NAME}-keycloak-${PROJECT_NAME}.${DOMAIN}/auth/realms/${APICURIO_KC_REALM}/clients-registrations/default

# Create client
curl -k -X POST -d "{ \"clientId\": \"apicurio-studio\", \"redirectUris\": [\"https:\/\/${APICURIO_URL}/*\"], \"publicClient\": true, \"directAccessGrantsEnabled\":\"true\", \"webOrigins\": [\"+\"]  }"  -H "Content-Type:application/json" -H "Authorization: bearer ${TOKEN}"  https://${MICROCKS_CR_NAME}-keycloak-${PROJECT_NAME}.${DOMAIN}/auth/realms/${APICURIO_KC_REALM}/clients-registrations/default

# Create user
curl -sk -X POST -d "{\"firstName\":\"Jooho\",\"lastName\":\"Lee\", \"email\":\"jlee@redhat.com\", \"enabled\":\"true\", \"username\":\"${MICROCKS_KC_USER}\", \"credentials\":[{\"type\":\"password\",\"value\":\"${MICROCKS_KC_PW}\",\"temporary\":false}]}" -H "Content-Type:application/json" -H "Authorization: bearer ${TOKEN}" https://${MICROCKS_CR_NAME}-keycloak-${PROJECT_NAME}.${DOMAIN}/auth/admin/realms/${APICURIO_KC_REALM}/users


# Create pvc.yaml
envsubst <${apicurio_dir}/pvc.yaml|oc create -f -

# Create configmap.yaml
envsubst <${apicurio_dir}/configmap.yaml|oc create -f -

# Create secret.yaml
envsubst < ${apicurio_dir}/secrets.yaml|oc create -f -

# Create services.yaml
oc create -f ${apicurio_dir}/services.yaml

# Expose routes for apicurio
oc create route edge --service=apicurio-studio-ui --insecure-policy=Redirect
oc create route edge --service=apicurio-studio-api --insecure-policy=Redirect
oc create route edge --service=apicurio-studio-ws --insecure-policy=Redirect

# Deploy apicurio-studio-db-deployment
oc create -f ${apicurio_dir}/apicurio-studio-db-deployment.yaml
waitForPodsReady "module=apicurio-studio-db" "1"

# Deploy apicurio-studio-api-deployment
oc create -f ${apicurio_dir}/apicurio-studio-api-deployment.yaml

# Deploy apicurio-studio-ws-deployment
oc create -f ${apicurio_dir}/apicurio-studio-ws-deployment.yaml

# Deploy apicurio-studio-ui-deployment
oc create -f ${apicurio_dir}/apicurio-studio-ui-deployment.yaml

waitForPodsReady "app=apicurio-studio" "4"

echo ""
echo "Successfully Apicurio Studio Installed."

