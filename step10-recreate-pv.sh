#!/usr/bin/env bash

kubeConfig=$1
pvName=$2
volumeHandle=$3

if [ -z "$kubeConfig" ] || [ -z "$pvName" ] || [ -z "$volumeHandle" ]; then
	echo "Usage: $0 <kubeconfig> <pv-name> <volume-handle>"
	exit 1
fi

export KUBECONFIG=${kubeConfig}

cat mypv-secondary.template.yml | \
	sed "s/%#VOLUME_HANDLE#%/${volumeHandle}/" | \
	sed "s/%#VOLUME_NAME#%/${pvName}/" | \
	kubectl apply -f -
