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

echo "Creating the namespaces..."
./step1-create-namespaces.sh $kubeConfig

echo "Creating the secret..."
./step2-create-secret.sh $kubeConfig
echo ""

echo "Creating the storage class..."
./step3-create-storage-class.sh $kubeConfig
echo ""

echo "Creating the namespace and initial pv..."
./step4-create-initial-pv.sh $kubeConfig
echo "Give the system some time to create the pv and pvc..."
show_progress 20 3
echo ""

VOLUME_DETAILS=$(./step5-get-volume-details.sh $kubeConfig)
# VOLUME_DETAILS has each item in a new line, having the label separated from the value by a colon:
pvName=$(echo "$VOLUME_DETAILS" | sed -n 's/^pvName://p')
volumeHandle=$(echo "$VOLUME_DETAILS" | sed -n 's/^volumeHandle://p')
echo "pvName: ${pvName}"
echo "volumeHandle: ${volumeHandle}"
echo ""

echo "Creating the real service..."
./step6-create-real-service.sh $kubeConfig
echo "Give the system some time to create the real service..."
show_progress 40 3
echo ""

echo "Deleting the real service..."
./step7-delete-real-service.sh $kubeConfig
echo "Give the system some time to delete the real service..."
show_progress 10 3
echo""

echo "Deleting the pvc..."
./step8-delete-pvc.sh $kubeConfig
echo "Give the system some time to delete the pvc..."
show_progress 10 3
echo ""

echo "Deleting the pv..."
./step9-delete-pv.sh $kubeConfig $pvName
echo "Give the system some time to delete the pv..."
show_progress 10 3
echo ""

./step10-recreate-pv.sh $kubeConfig $pvName $volumeHandle
echo "Give the system some time to recreate the pv..."
show_progress 20 3
echo ""

./step11-recreate-real-service.sh $kubeConfig
echo "Give the system some time to attempt recreating the real service..."
show_progress 10 3
echo ""

kubectl describe pv ${pvName}
