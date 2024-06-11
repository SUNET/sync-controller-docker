#!/bin/bash
ttl=300
namespace="sync-jobs"
api="https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}/apis"
jobs_endpoint="batch/v1/namespaces/${namespace}/jobs"
curl="curl --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  --header \"Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)\""
while true; do
  for row in $(mysql -h ${DBHOST} -u ${DBUSER} -p${DBPASSWORD} ${DBNAME} -NB \
    -e "SELECT oc_ioidc_userconfig.access_token,oc_ioidc_userconfig.uid,oc_preferences.configvalue FROM oc_ioidc_userconfig LEFT JOIN oc_preferences ON oc_ioidc_userconfig.uid = oc_preferences.userid WHERE oc_preferences.configkey = 'email'" \
    | sed 's/\t/;/g'); do
      accesstoken=$(echo ${row} | awk -F';' '{print $1}')
      gmail=$(echo ${row} | awk -F';' '{print $2}')
      sunet=$(echo ${row} | awk -F';' '{print $3}')
      jobname=${sunet//[@.]/_}
      status_endpoint="batch/v1/namespaces/${namespace}/jobs/${jobname}/status"
      status=$(${curl} ${api}/${status_endpoint} | jq -rc '.status')
      if [[ -z ${status} ]]; then
        ${curl} ${api}/${jobs_endpoint} \  -X POST \
                  -H 'Content-Type: application/yaml' \
                  -d "---
apiVersion: batch/v1
kind: Job
metadata:
  name: ${jobname}
spec:
  ttlSecondsAfterFinished: ${ttl}
  template:
    spec:
      containers:
        - name: ${jobname}
          image: docker.sunet.se/mail/imapsync:2.229-1
          env:
            - name: IMAPSYNC_MODE
              value: from_gmail
            - name: IMAPSYNC_HOST2
              value: ${SUNET_MAILHOST}
            - name: IMAPSYNC_OAUTH_ACCESS_TOKEN1
              value: ${accesstoken}
            - name: IMAPSYNC_PASSWORD2
              value: ${SUNET_MASTERPASSWORD}
            - name: IMAPSYNC_USER1
              value: ${gmail}
            - name: IMAPSYNC_USER2
              value: ${sunet}
      restartPolicy: Never
  backoffLimit: 4
"
      fi
  done
  sleep ${ttl}
done
