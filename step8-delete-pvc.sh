#!/usr/bin/env bash

kubeConfig=$1
if [ -z "$kubeConfig" ]; then
	echo "Usage: $0 <kubeconfig>"
	exit 1
fi

export KUBECONFIG=${kubeConfig}

kubectl delete pvc my-pvc -n my-namespace
