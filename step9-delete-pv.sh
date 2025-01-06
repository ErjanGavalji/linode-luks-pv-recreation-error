#!/usr/bin/env bash

kubeConfig=$1
pvName=$2
if [ -z "$kubeConfig" ] || [ -z "$pvName" ]; then
	echo "Usage: $0 <kubeconfig> <pv-name>"
	exit 1
fi

export KUBECONFIG=${kubeConfig}

kubectl delete pv ${pvName}
