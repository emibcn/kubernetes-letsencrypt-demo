#!/bin/bash -e

if [[ -z ${EMAIL} || -z ${DOMAINS} || -z ${SECRET} || -z ${MODE} ]]
then
    echo "EMAIL, DOMAINS, SECRET and MODE env vars required"
    env
    exit 1
fi

echo "Inputs:"
echo " - EMAIL: ${EMAIL}"
echo " - DOMAINS: ${DOMAINS}"
echo " - SECRET: ${SECRET}"
echo " - MODE: ${MODE}"

DRY_RUN=""
if [ "${MODE}" = "dry-run" ]
then
    DRY_RUN="--dry-run"
fi


NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)
echo "Current Kubernetes namespce: ${NAMESPACE}"

echo "Starting HTTP server..."
pushd "${HOME}"
python -m SimpleHTTPServer 80 &
PID=$!

echo "Wait a little so that service will see us"
sleep 20

echo "Starting certbot..."
certbot certonly --webroot -w "${HOME}" -n --agree-tos --email "${EMAIL}" --no-self-upgrade -d "${DOMAINS}" "${DRY_RUN}"

echo "Certbot finished. Killing http server..."
kill ${PID}

echo "Finiding certs. Exiting if certs are not found ..."
CERTPATH_BASE="/etc/letsencrypt/live"
CERTPATH="${CERTPATH_BASE}/$( echo $DOMAINS | cut -f1 -d',' )"
ls -l "${CERTPATH}" || (ls -l "${CERTPATH_BASE}" && echo "Sleeping 2m..." && sleep 2m && exit 1 )

echo "Creating update for secret..."
cat /secret-patch-template.json | \
	sed "s/NAMESPACE/${NAMESPACE}/" | \
	sed "s/NAME/${SECRET}/" | \
	sed "s/TLSCERT/$(cat ${CERTPATH}/fullchain.pem | base64 | tr -d '\n')/" | \
	sed "s/TLSKEY/$(cat ${CERTPATH}/privkey.pem |  base64 | tr -d '\n')/" \
	> /secret-patch.json

echo "Checking json file exists. Exiting if not found..."
ls /secret-patch.json || exit 1

echo "Updating secret..."
curl \
  --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
  -XPATCH \
  -H "Accept: application/json, */*" \
  -H "Content-Type: application/strategic-merge-patch+json" \
  -d @/secret-patch.json https://kubernetes/api/v1/namespaces/${NAMESPACE}/secrets/${SECRET} \
  -k -v

echo "Sleeping 6m..."
sleep 6m

echo "Done"
