#!/bin/bash
#
# MIT License
#
# (C) Copyright 2022 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#

if [ $# -ne 1 ]; then
  echo "usage: $0 <cn-hostname>"
  exit 1
fi

CN_NAME=$1

# Make sure we can resolve the CN Name
if [ $(dig +short ${CN_NAME} | wc -l) -lt 1 ]; then
    echo "ERROR: Unknown CN ${CN_NAME}"
    exit 1
fi

# Make sure the cray, craysys, kubectl, and jq commands are available

craysys type get > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "ERROR: craysys command is not available"
  exit 1
fi

kubectl version > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "ERROR: kubectl command is not available"
  exit 1
fi

which jq > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "ERROR: jq command is not available"
  exit 1
fi

# Get the Base Directory
BASEDIR=$(dirname $0)

# Get the SYSTEM_DOMAIN from cloud-init 
SYSTEM_NAME=$(craysys metadata get system-name)
SITE_DOMAIN=$(craysys metadata get site-domain)
SYSTEM_DOMAIN=${SYSTEM_NAME}.${SITE_DOMAIN}
echo "System domain is ${SYSTEM_DOMAIN}"

# Get a token to talk to SLS
export TOKEN=$(curl -s -k -S -d grant_type=client_credentials -d client_id=admin-client -d client_secret=`kubectl get secrets admin-client-auth -o jsonpath='{.data.client-secret}' | base64 -d` https://api-gw-service-nmn.local/keycloak/realms/shasta/protocol/openid-connect/token | jq -r '.access_token')

# Get the USER_NETWORK from SLS
USER_NETWORK=$(curl -s -k -H "Authorization: Bearer ${TOKEN}" https://api-gw-service-nmn.local/apis/sls/v1/dumpstate | jq -r '.Networks.BICAN.ExtraProperties.SystemDefaultRoute' | tr '[:upper:]' '[:lower:]')
echo "User Network on ${SYSTEM_NAME} is ${USER_NETWORK}"

# Get the ADMIN_SECRET
ADMIN_SECRET=$(kubectl get secrets admin-client-auth -ojsonpath='{.data.client-secret}' | base64 -d)
if [[ -z ${ADMIN_SECRET} ]]; then
    echo "ERROR: Failed to retrieve admin client secret"
    exit 1
fi
echo "Got admin client secret"

# Prepare the run script
cat > /tmp/run-gateway-test-${CN_NAME}.sh <<EOF
#!/bin/bash
    
export ADMIN_CLIENT_SECRET=$ADMIN_SECRET

echo "Running gateway tests on the CN...(this may take 1-2 minutes)"
echo "/root/gateway-test.py ${SYSTEM_DOMAIN} cn ${USER_NETWORK}"
/root/gateway-test.py ${SYSTEM_DOMAIN} cn ${USER_NETWORK}
EOF

chmod a+x /tmp/run-gateway-test-${CN_NAME}.sh

# Copy files to the CN
printf "\nSending files to the CN\n"
scp /tmp/run-gateway-test-${CN_NAME}.sh ${BASEDIR}/gateway-test.py ${BASEDIR}/gateway-test-defn.yaml ${CN_NAME}:~

# Running tests on the CN and cleaning up 
printf "\nRunning tests on the CN\n"
ssh ${CN_NAME} "~/run-gateway-test-${CN_NAME}.sh;rm gateway-test.py gateway-test-defn.yaml run-gateway-test-${CN_NAME}.sh"

rm -f /tmp/run-gateway-test-${CN_NAME}.sh