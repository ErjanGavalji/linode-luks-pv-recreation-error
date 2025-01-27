#!/usr/bin/env bash

kubeConfig=$1
if [ -z "$kubeConfig" ]; then
	echo "Usage: $0 <kubeconfig>"
	exit 1
fi

export KUBECONFIG=${kubeConfig}

kubectl delete pvc mongodb-data-ze-mongodb-0 -n my-namespace
