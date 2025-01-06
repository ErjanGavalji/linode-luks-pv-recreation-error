#!/usr/bin/env bash

kubeconfig=$1
if [ -z "$kubeconfig" ]; then
	echo "Usage: $0 <kubeconfig>"
	exit 1
fi

export KUBECONFIG=$kubeconfig

function show_progress() {
	total=$1
	if [ -z "$total" ]; then
		total=10
	fi
	time=$2
	if [ -z "$time" ]; then
		time=3
	fi
	for i in $(seq 1 ${total}); do
		dots=$(printf '.%.0s' $(seq 1 $i))
		echo -ne "\r${dots} ${i}/${total}"
		sleep 3
	done
	echo ""
}

echo "Deleting the real service..."
kubectl delete -f ./dbs.yml
echo "Give the system some time to delete the real service..."
show_progress 20 3
echo ""

echo "Deleting the pvc and pv..."
pvName=$(kubectl get pvc -n my-namespace my-pvc -o jsonpath='{.spec.volumeName}')
echo "pvName: ${pvName}"
kubectl delete pvc -n my-namespace my-pvc
kubectl delete pv ${pvName}
echo "Give the system some time to delete the pv and pvc..."
show_progress 10 3
echo ""

echo "Deleting the storage class..."
kubectl delete -f ./luks-storage-class.yml

echo "Deleting the secret..."
kubectl delete secret my-luks-secret -n csi-encrypt-keys

echo "Deleting the namespaces..."
kubectl delete -f ./namespaces.yml
