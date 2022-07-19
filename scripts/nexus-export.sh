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

set -exo pipefail

if [[ "Bound" != $(kubectl get pvc -n nexus nexus-bak -o jsonpath='{.status.phase}') ]]; then
cat << EOF | kubectl -n nexus create -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nexus-bak
spec:
  storageClassName: k8s-block-replicated
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1000Gi
EOF
fi

kubectl -n nexus scale deployment nexus --replicas=0;

cat << EOF | kubectl -n nexus apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: nexus-backup
  namespace: nexus
spec:
  template:
    spec:
      containers:
      - name: backup-container
        image: artifactory.algol60.net/csm-docker/stable/docker.io/library/alpine:3.15
        command: [ "/bin/sh", "-c" ]
        args:
        - >-
            cd /nexus-data && tar cvzf /nexus-bak/nexus-data.tgz *;
        volumeMounts:
        - mountPath: /nexus-data
          name: nexus-data
        - mountPath: /nexus-bak
          name: nexus-bak
      restartPolicy: Never
      volumes:
      - name: nexus-data
        persistentVolumeClaim:
          claimName: nexus-data
      - name: nexus-bak
        persistentVolumeClaim:
          claimName: nexus-bak
EOF

while [[ -z $(kubectl get job nexus-backup -n nexus -o jsonpath='{.status.succeeded}') ]]; do
    echo  "Waiting for the backup to finish for another 10 seconds."
    sleep 10
done

kubectl -n nexus scale deployment nexus --replicas=1;