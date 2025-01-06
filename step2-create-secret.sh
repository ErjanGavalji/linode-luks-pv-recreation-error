#!/usr/bin/env bash

kubeConfig=$1
if [ -z "$kubeConfig" ]; then
	echo "Usage: $0 <kubeconfig>"
	exit 1
fi

export KUBECONFIG=${kubeConfig}

# Create a secret with the password

kubectl create secret generic my-luks-secret -n csi-encrypt-keys --from-env-file=./my-luks-secret
