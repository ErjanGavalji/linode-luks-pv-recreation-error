#!/usr/bin/env bash

kubeConfig=$1
if [ -z "$kubeConfig" ]; then
	echo "Usage: $0 <kubeconfig>"
	exit 1
fi

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

export KUBECONFIG=${kubeConfig}

echo "Creating the namespaces..."
./step1-create-namespaces.sh $kubeConfig

echo "Creating the secret..."
./step2-create-secret.sh $kubeConfig
echo ""

echo "Creating the storage class..."
./step3-create-storage-class.sh $kubeConfig
echo ""

#echo "Creating the initial pv..."
#./step4-create-initial-pv.sh $kubeConfig
#echo "Give the system some time to create the pv and pvc..."
#show_progress 60 3
#echo ""

echo "Creating the real service..."
./step4-create-real-service.sh $kubeConfig
echo "Give the system some time to create the real service..."
show_progress 60 3
echo ""

echo ""
echo ""
echo ""
echo ""
echo ""
echo "================================================================================"
kubectl describe pvc mongodb-data-ze-mongodb-0 -n my-namespace
echo ""
echo ""
echo ""
echo ""
echo "================================================================================"
kubectl describe pods -n my-namespace ze-mongodb-0
