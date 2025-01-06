# Linode/Akamain Luks PV Recreation Error Demo

1. Create the namespaces: 1.1. Create a yaml file, named `namespaces.yml` with
   the content of:

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

1.2. Create the namespaces via the command of ``

1. Create the secret:

- create a text file, named my-luks-secret with the content of
  'luksKey=AVerySecretForLuksDiskEncryption'

- create the secret via the command of
  `kubectl create secret generic my-luks-secret -n csi-encrypt-keys --from-env-file=./my-luks-secret`

2. Create the storage class:

- Create a yaml file, named `luks-storage-class.yml` with the content of:

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

- Create the storage class via the command of
  `kubectl apply -f ./luks-storage-class.yml`

3. Create the initial PV (automatically, via a PVC declaration)

- Create a yaml file, named `initial-pv.yml` with the content of:

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

- Create the pv/pvc pair via the command of `kubectl apply -f ./initial-pv.yml`

4. Get the details of the newly created volume, needed for the recreation later.
   Save them somewhere. Run the commands:

```
pvName=$(kubectl get pvc my-pvc -n my-namespace -o jsonpath='{.spec.volumeName}')
volumeHandle=$(kubectl get pv ${pvName} -o jsonpath='{.spec.csi.volumeHandle}')
csiProvisionerIdentity=$(kubectl get pv ${pvName} -o jsonpath="{.spec.csi.volumeAttributes.storage\.kubernetes\.io/csiProvisionerIdentity}")

echo "pvName: " + ${pvName}
echo "VolumeHandle: " + ${volumeHandle}
echo "csiProvisionerIdentity: " + ${csiProvisionerIdentity}
```

5. Create a real service, using the pv and pvc: 5.1. Create a yaml file, named
   `dbs.yml` with the content of:

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

5.2. Create the service and sts via the command of `kubectl apply -f ./dbs.yml`

5.3. Wait for the service to get initialized (a minute or two should suffice)

6. Delete the real service via the command of `kubectl delete -f ./dbs.yml`

7. Delete the pvc via the command of `kubectl delete pvc my-pvc -n my-namespace`

8. Delete the pv via the command of `kubectl delete pv PV-NAME-HERE`. Use the
   `pvName` from Step4.

9. Recreate the pv and pvc:

9.1. Create a yaml file named `mypv-secondary.template.yml` with the content of:

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
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: healeeDesignation
          operator: In
          values:
            - load2

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

9.2. Recreate the pv and pvc via the command of

```
cat mypv-secondary.template.yml | \
	sed "s/%#VOLUME_HANDLE#%/${volumeHandle}/" | \
	sed "s/%#VOLUME_NAME#%/${pvName}/" | \
	kubectl apply -f -
```

10. Try creating the real service again, via the command of
    `kubectl apply -f ./dbs.yml`

Checking the pv now lists the unable to mount error.
