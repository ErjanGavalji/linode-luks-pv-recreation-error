# Linode/Akamain Luks PV Recreation Error Demo

Demonstrates the inability to re-mount a LUKS-envrypted pv at Linode LKE once it
has been unattached and re-attached by a provided volumeHandle.

Yet, if the cluster is simply recycled however, the pv gets attached
automatically via the
[BlockStorage CSI Driver](https://github.com/linode/linode-blockstorage-csi-driver/)

For simplicity, the `all-steps.sh` script uses time-based waiting for the k8s
objects to initialize.

## Requirements

You need a simple k8s cluster in LKE, with a kubeconfig yaml file.

## Steps

### Create the namespaces

#### Yaml file

Create a yaml file, named `namespaces.yml` with the content of:

```
kind: Namespace
apiVersion: v1
metadata:
  name: my-namespace
  labels:
    name: my-namespace

---
kind: Namespace
apiVersion: v1
metadata:
  name: csi-encrypt-keys
  labels:
    name: csi-encrypt-keys

```

#### Creation

Create the namespaces via the command of `kubectl apply -f ./namespaces.yml`

### Create the secret

#### Yaml file

Create a text file, named my-luks-secret with the content of

```
luksKey=AVerySecretForLuksDiskEncryption
```

#### Creation

Create the secret via the command of
`kubectl create secret generic my-luks-secret -n csi-encrypt-keys --from-env-file=./my-luks-secret`

### Create the storage class:

#### Yaml file

Create a yaml file, named `luks-storage-class.yml` with the content of:

```
allowVolumeExpansion: true
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
  name: my-luks-storage-class
  namespace: kube-system
provisioner: linodebs.csi.linode.com
reclaimPolicy: Retain
parameters:
  linodebs.csi.linode.com/luks-encrypted: "true"
  linodebs.csi.linode.com/luks-cipher: "aes-xts-plain64"
  linodebs.csi.linode.com/luks-key-size: "512"
  csi.storage.k8s.io/node-stage-secret-namespace: csi-encrypt-keys
  csi.storage.k8s.io/node-stage-secret-name: my-luks-secret
```

#### Creation

Create the storage class via the command of
`kubectl apply -f ./luks-storage-class.yml`

### Create the initial PV (automatically, via a PVC declaration)

#### Yaml file

Create a yaml file, named `initial-pv.yml` with the content of:

```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
  namespace: my-namespace
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: my-luks-storage-class
```

#### Creation

Create the pv/pvc pair via the command of `kubectl apply -f ./initial-pv.yml`

### Get new volume details, persist for the recreation later

Run the commands

```
pvName=$(kubectl get pvc my-pvc -n my-namespace -o jsonpath='{.spec.volumeName}')
volumeHandle=$(kubectl get pv ${pvName} -o jsonpath='{.spec.csi.volumeHandle}')
csiProvisionerIdentity=$(kubectl get pv ${pvName} -o jsonpath="{.spec.csi.volumeAttributes.storage\.kubernetes\.io/csiProvisionerIdentity}")

echo "pvName: " + ${pvName}
echo "VolumeHandle: " + ${volumeHandle}
echo "csiProvisionerIdentity: " + ${csiProvisionerIdentity}
```

### Create a real service, using the pv and pvc

#### Yaml file

Create a yaml file, named `dbs.yml` with the content of:

```
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: my-sts
  namespace: my-namespace
spec:
  serviceName: "ze-mongodb"
  replicas: 1
  selector:
    matchLabels:
      app: ze-mongodb
  template:
    metadata:
      labels:
        app: ze-mongodb
    spec:
      containers:
      - name: mongodb-container
        image: mongo:5.0.11
        ports:
        - containerPort: 27017
        volumeMounts:
        - name: mongodb-data
          mountPath: /data/db
      volumes:
        - name: mongodb-data
          persistentVolumeClaim:
            claimName: my-pvc
---

apiVersion: v1
kind: Service
metadata:
  name: ze-mongodb-service
  namespace: my-namespace
spec:
  selector:
    app: ze-mongodb
  clusterIP: None
  ports:
    - port: 27017
      targetPort: 27017
```

#### Creation

Create the service and sts via the command of `kubectl apply -f ./dbs.yml`

#### Wait for the service to get initialized (a minute or two should suffice)

### Delete the real service

Run the command `kubectl delete -f ./dbs.yml`

### Delete the pvc

Run the command `kubectl delete pvc my-pvc -n my-namespace`

### Delete the pv

Run the command `kubectl delete pv PV-NAME-HERE`. Use the `pvName` from Step4.

### Recreate the pv and pvc:

#### Yaml file

Create a yaml file named `mypv-secondary.template.yml` with the content of:

```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: %#VOLUME_NAME#%
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: my-luks-storage-class
  volumeMode: Filesystem
  csi:
    driver: linodebs.csi.linode.com
    fsType: ext4
    nodeStageSecretRef:
      name: my-luks-secret
      namespace: csi-encrypt-keys
    volumeAttributes:
      linodebs.csi.linode.com/luks-cipher: aes-xts-plain64
      linodebs.csi.linode.com/luks-encrypted: "true"
      linodebs.csi.linode.com/luks-key-size: "512"
    volumeHandle: %#VOLUME_HANDLE#%

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: experimental-mongodb-pvc
  namespace: my-namespace
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: linode-block-storage-retain-experimental-mongodb-luks
  volumeName: %#VOLUME_NAME#%
```

#### Creation

Recreate the pv and pvc via the command

```
cat mypv-secondary.template.yml | \
	sed "s/%#VOLUME_HANDLE#%/${volumeHandle}/" | \
	sed "s/%#VOLUME_NAME#%/${pvName}/" | \
	kubectl apply -f -
```

### Try creating the real service again

Run the command `kubectl apply -f ./dbs.yml`

Checking the pv and pvc now list the unable to mount error.

## Run-all

Run the `all-steps.sh` script to run all the steps in one go.
