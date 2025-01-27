#!/usr/bin/env bash

kubeConfig=$1
if [ -z "$kubeConfig" ]; then
	echo "Usage: $0 <kubeconfig>"
	exit 1
fi

export KUBECONFIG=${kubeConfig}

pvName=$(kubectl get pvc mongodb-data-ze-mongodb-0 -n my-namespace -o jsonpath='{.spec.volumeName}')
volumeHandle=$(kubectl get pv ${pvName} -o jsonpath='{.spec.csi.volumeHandle}')
csiProvisionerIdentity=$(kubectl get pv ${pvName} -o jsonpath="{.spec.csi.volumeAttributes.storage\.kubernetes\.io/csiProvisionerIdentity}")

echo "pvName:${pvName}
volumeHandle:${volumeHandle}
csiProvisionerIdentity:${csiProvisionerIdentity}"

