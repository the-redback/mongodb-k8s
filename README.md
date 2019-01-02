# MongoDB in Kubernetes

## Replica-Sets

### Create Secret for Key file

MongoDB will use this key to communicate internal cluster.

```console
$ openssl rand -base64 741 > ./replica-sets/key.txt

$ kubectl create secret generic shared-bootstrap-data -n demo --from-file=internal-auth-mongodb-keyfile=./replica-sets/key.txt
secret "shared-bootstrap-data" created
```

### Deploy MongoDB Replica-Sets YAML

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mongodb-service
  labels:
    name: mongo
spec:
  ports:
  - port: 27017
    targetPort: 27017
  clusterIP: None
  selector:
    role: mongo
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongod
spec:
  serviceName: mongodb-service
  replicas: 3
  selector:
    matchLabels:
      role: mongo
      environment: test
      replicaset: MainRepSet
  template:
    metadata:
      labels:
        role: mongo
        environment: test
        replicaset: MainRepSet
    spec:
      containers:
      - name: mongod-container
        image: mongo:3.4
        command:
        - "numactl"
        - "--interleave=all"
        - "mongod"
        - "--bind_ip"
        - "0.0.0.0"
        - "--replSet"
        - "MainRepSet"
        - "--auth"
        - "--clusterAuthMode"
        - "keyFile"
        - "--keyFile"
        - "/etc/secrets-volume/internal-auth-mongodb-keyfile"
        - "--setParameter"
        - "authenticationMechanisms=SCRAM-SHA-1"
        resources:
          requests:
            cpu: 0.2
            memory: 200Mi
        ports:
        - containerPort: 27017
        volumeMounts:
        - name: secrets-volume
          readOnly: true
          mountPath: /etc/secrets-volume
        - name: mongodb-persistent-storage-claim
          mountPath: /data/db
      volumes:
      - name: secrets-volume
        secret:
          secretName: shared-bootstrap-data
          defaultMode: 256
  volumeClaimTemplates:
  - metadata:
      name: mongodb-persistent-storage-claim
      annotations:
        volume.beta.kubernetes.io/storage-class: "standard"
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 1Gi
```

Now Deploy the Yaml

```console
$ kc create -f ./replica-sets/mongodb-rc.yaml 
service "mongodb-service" created
statefulset "mongod" created
```

### Wait for Pod running and PVC

```console
$ kubectl get all
NAME                  DESIRED   CURRENT   AGE
statefulsets/mongod   3         3         2m

NAME          READY     STATUS    RESTARTS   AGE
po/mongod-0   1/1       Running   0          2m
po/mongod-1   1/1       Running   0          2m
po/mongod-2   1/1       Running   0          2m

$ kubectl get pvc
NAME                                        STATUS    VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
mongodb-persistent-storage-claim-mongod-0   Bound     pvc-ba24dc66-319a-11e8-8dd9-080027779e8d   1Gi        RWO            standard       1h
mongodb-persistent-storage-claim-mongod-1   Bound     pvc-bf2e51a5-319a-11e8-8dd9-080027779e8d   1Gi        RWO            standard       1h
mongodb-persistent-storage-claim-mongod-2   Bound     pvc-c7948f87-319a-11e8-8dd9-080027779e8d   1Gi        RWO            standard       1h
```

### Setup ReplicaSet Configuration

Finally, we need to connect to one of the “mongod” container processes to configure the replica set.

Run the following command to connect to the first container. In the shell initiate the replica set (we can rely on the hostnames always being the same, due to having employed a StatefulSet):

```console
$ kubectl exec -it mongod-0 -c mongod-container bash
$ mongo
> rs.initiate({_id: "MainRepSet", version: 1, members: [
       { _id: 0, host : "mongod-0.mongodb-service.default.svc.cluster.local:27017" },
       { _id: 1, host : "mongod-1.mongodb-service.default.svc.cluster.local:27017" },
       { _id: 2, host : "mongod-2.mongodb-service.default.svc.cluster.local:27017" }
 ]});
```

Keep checking the status of the replica set, with the following command, until the replica set is fully initialised and a primary and two secondaries are present:

```console
> rs.status();

# output similar to:
{
	"set" : "MainRepSet",
	"date" : ISODate("2018-03-27T12:11:31.577Z"),
	"myState" : 2,
	"term" : NumberLong(1),
	"syncingTo" : "mongod-2.mongodb-service.default.svc.cluster.local:27017",
	"heartbeatIntervalMillis" : NumberLong(2000),
	"optimes" : {
		"lastCommittedOpTime" : {
			"ts" : Timestamp(1522152676, 1),
			"t" : NumberLong(1)
		},
		"appliedOpTime" : {
			"ts" : Timestamp(1522152686, 1),
			"t" : NumberLong(1)
		},
		"durableOpTime" : {
			"ts" : Timestamp(1522152686, 1),
			"t" : NumberLong(1)
		}
	},
	"members" : [
		{
			"_id" : 0,
			"name" : "mongod-0.mongodb-service.default.svc.cluster.local:27017",
			"health" : 1,
			"state" : 1,
			"stateStr" : "PRIMARY",
			"uptime" : 399,
			"optime" : {
				"ts" : Timestamp(1522152686, 1),
				"t" : NumberLong(1)
			},
			"optimeDurable" : {
				"ts" : Timestamp(1522152686, 1),
				"t" : NumberLong(1)
			},
			"optimeDate" : ISODate("2018-03-27T12:11:26Z"),
			"optimeDurableDate" : ISODate("2018-03-27T12:11:26Z"),
			"lastHeartbeat" : ISODate("2018-03-27T12:11:30.360Z"),
			"lastHeartbeatRecv" : ISODate("2018-03-27T12:11:30.697Z"),
			"pingMs" : NumberLong(0),
			"electionTime" : Timestamp(1522152306, 1),
			"electionDate" : ISODate("2018-03-27T12:05:06Z"),
			"configVersion" : 1
		},
		{
			"_id" : 1,
			"name" : "mongod-1.mongodb-service.default.svc.cluster.local:27017",
			"health" : 1,
			"state" : 2,
			"stateStr" : "SECONDARY",
			"uptime" : 505,
			"optime" : {
				"ts" : Timestamp(1522152686, 1),
				"t" : NumberLong(1)
			},
			"optimeDate" : ISODate("2018-03-27T12:11:26Z"),
			"syncingTo" : "mongod-2.mongodb-service.default.svc.cluster.local:27017",
			"configVersion" : 1,
			"self" : true
		},
		{
			"_id" : 2,
			"name" : "mongod-2.mongodb-service.default.svc.cluster.local:27017",
			"health" : 1,
			"state" : 2,
			"stateStr" : "SECONDARY",
			"uptime" : 399,
			"optime" : {
				"ts" : Timestamp(1522152686, 1),
				"t" : NumberLong(1)
			},
			"optimeDurable" : {
				"ts" : Timestamp(1522152686, 1),
				"t" : NumberLong(1)
			},
			"optimeDate" : ISODate("2018-03-27T12:11:26Z"),
			"optimeDurableDate" : ISODate("2018-03-27T12:11:26Z"),
			"lastHeartbeat" : ISODate("2018-03-27T12:11:30.360Z"),
			"lastHeartbeatRecv" : ISODate("2018-03-27T12:11:29.915Z"),
			"pingMs" : NumberLong(0),
			"syncingTo" : "mongod-0.mongodb-service.default.svc.cluster.local:27017",
			"configVersion" : 1
		}
	],
	"ok" : 1
}
```

`mongodb-0` has become `Primary` and Others two `Secondary` Nodes.

Then run the following command to configure an “admin” user (performing this action results in the “localhost exception” being automatically and permanently disabled):

```console
> db.getSiblingDB("admin").createUser({
      user : "main_admin",
      pwd  : "abc123",
      roles: [ { role: "root", db: "admin" } ]
 });
```

### Insert Data

Insert Data into `mongod-0` pod.

```console
> db.getSiblingDB('admin').auth("main_admin", "abc123");
> use test;
> db.testcoll.insert({a:1});
> db.testcoll.insert({b:2});
> db.testcoll.find();
```

### Verify Cluster Data

`exec` into Secondary Pod (here, mongo-1)

```console
$ kubectl exec -it mongod-1 -c mongod-container bash
$ mongo
> db.getSiblingDB('admin').auth("main_admin", "abc123");
> db.getMongo().setSlaveOk()
> use test;
> db.testcoll.find();
```

### Verify PVC

```console
$ kubectl delete -f ./replica-sets/mongodb-rc.yaml
$ kubectl get all
$ kubectl get persistentvolumes
```

Recreate MongoDB

```console
$ kubectl apply -f ./replica-sets/mongodb-rc.yaml
$ kubectl get all
```

Verify Data:

```console
$ kubectl exec -it mongod-0 -c mongod-container bash
$ mongo
> db.getSiblingDB('admin').auth("main_admin", "abc123");
> use test;
> db.testcoll.find();
```

As PVC was not deleted, We will still have existing Data.

### Verify Clusterization

Delete `mongod-0` Pod and keep cheking `rs.status()`, eventually another node of the remaining two will become `Primary` Node.


## Using Helm

Add repo

```console
$ helm repo add stable https://kubernetes-charts.storage.googleapis.com/
$ helm install --name my-release --namespace demo --set auth.enabled=true --set auth.key="asdasdasdasdasdasd" --set auth.adminUser=root --set auth.adminPassword=pass stable/mongodb-replicaset
$ helm install --name my-release --namespace demo --set tls.enabled=true --set replicas=5 --set tls.cacert=LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURCRENDQWV5Z0F3SUJBZ0lKQUpxeWhoaGZGa2luTUEwR0NTcUdTSWIzRFFFQkN3VUFNQmN4RlRBVEJnTlYKQkFNTURHMTVaRzl0WVdsdUxtTnZiVEFlRncweE9UQXhNREl4TVRNd05USmFGdzAwTmpBMU1qQXhNVE13TlRKYQpNQmN4RlRBVEJnTlZCQU1NREcxNVpHOXRZV2x1TG1OdmJUQ0NBU0l3RFFZSktvWklodmNOQVFFQkJRQURnZ0VQCkFEQ0NBUW9DZ2dFQkFNTnZvYjE5clJxWTRBdFRRbi9KSlgrSEkwZTAvRjVtVE1Kc0dlRTUzZFg3K1dqUHYzWTAKL2RVMS9YdFFzNUp4a0k5TjVhMjc5cHJ6RmQ1bFY2R0UxeThaL1l3U1dYSlhSK2xuTWVSZ3hzVVZMYXVWTHZ5bApSN2Fabkl4aWg5Uy9lRXg2S0pweVNJMDNGRXQvYURITUUzcndiSXVTMDlWSmV3TDZVd3QwOGdncjJkdkZVM1htCnFpNkJqSTZPWS9abXBmRmhkdjFNNHdXUVRldTNIUjc4bEdMMnBHZGszT2l2N3FaQnB4SEZkb2tmTHBuN1lLUVcKWUFoZlcrYUFSUHJPcXNaV2kyazRLZkpoeUlOcWJuVHdFZ0k5S1Y3WjZWeUtyM2lHb0pTVG8wbmRibTE4WVRsSQpHNXI1Ny9kazRhejRRaXhEN3E1S3ZPUzhFMTZHWjJNNy9XOENBd0VBQWFOVE1GRXdIUVlEVlIwT0JCWUVGT0VMClZFSkV4ZUJydlJmME5SVllYV3BjNEd3N01COEdBMVVkSXdRWU1CYUFGT0VMVkVKRXhlQnJ2UmYwTlJWWVhXcGMKNEd3N01BOEdBMVVkRXdFQi93UUZNQU1CQWY4d0RRWUpLb1pJaHZjTkFRRUxCUUFEZ2dFQkFCbURuL3R1ZmxzSAp6NUtRdUVVemoyR1FmMzZ1bXl0eEt4ZkJDMkV1U1VSTTJUQUlEK2hQUVlTSUxqb3lnNlk0ME80MmZRTCtOQmNjCklmQmFxM1RhZXp6blphellIcHhhY3REL2hCdEpzbFRtZ3N6eWwyT0k5VG5WNExYbFhRcjh1TFFSbTBWOEgvK1UKL2J5ZUFGYnNHZFYvcVBSaVI2NW9SdklsWC8zbGRsVzNnMUNQOWJReXE1QlVoeng3ZW5PRElQQ1lyN0htUVZEdQpEQklaYzNKcXZ2WndKWmxZNXk5a1AyQWwrQmJkSkRGZWJzVjk5bTREMCs3TGRyL001UzhqRjFUeUMxMCtSZmxJCnZwbnNkSUNEWkNkaEU2dlZJalFqcUQ5NVFDRGdkUURXWkZlWDJGVWU4UVlTdVkydTJYVjMwQWFqd2M3RUNYdUgKTUh5RjROeUh3S2M9Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K --set tls.cakey=LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlFb3dJQkFBS0NBUUVBdzIraHZYMnRHcGpnQzFOQ2Y4a2xmNGNqUjdUOFhtWk13bXdaNFRuZDFmdjVhTSsvCmRqVDkxVFg5ZTFDemtuR1FqMDNscmJ2Mm12TVYzbVZYb1lUWEx4bjlqQkpaY2xkSDZXY3g1R0RHeFJVdHE1VXUKL0tWSHRwbWNqR0tIMUw5NFRIb29tbkpJalRjVVMzOW9NY3dUZXZCc2k1TFQxVWw3QXZwVEMzVHlDQ3ZaMjhWVApkZWFxTG9HTWpvNWo5bWFsOFdGMi9VempCWkJONjdjZEh2eVVZdmFrWjJUYzZLL3Vwa0duRWNWMmlSOHVtZnRnCnBCWmdDRjliNW9CRStzNnF4bGFMYVRncDhtSElnMnB1ZFBBU0FqMHBYdG5wWElxdmVJYWdsSk9qU2QxdWJYeGgKT1VnYm12bnY5MlRoclBoQ0xFUHVya3E4NUx3VFhvWm5ZenY5YndJREFRQUJBb0lCQURhU2FWdDhTR1h3NGo3SApWUDVSc0lMWHZXWThoMnZrclBKdE5SekxCOExFeFhRYTdwK1hWSG5BeGJNMWFhOHV2dXNGR1dsVjN4cU5Ya0huCmtueXJsMXF6cXpUOXVyUk80dW10d3lTK1VVS2ZFMDJpTHFpbGprelN3QUFEVTJKNHhLSzJTYmcyeVVPRmFjbGIKSGtFcGR4Y1JJMzRsMWJqczk4aHhGZGRSSkhSYkxQWnM5T3E4QldXQVRyWVNxcWtOZ3VESlZMS2VocG5qdG9VWApraXROblhnaHRkT1k3Rk04QzNkVVNvMFBDSVlIT2pIN25EQ0VMQ0M2OGcvbjJHNUdjc0IrNmVWazVRdGFQTHF2CkZiWUpnQUw3Vmhac2MxZkVCdmZlMHhMRFBvN0dhclZveHpyR1NXWEN0S2MxOXcxekFERFZsK0xCVTNVOUp0akMKS3htZVpnRUNnWUVBOHV2KzF3b2svalovb2hzeXlwWktDbVM4dEUwMzJSamlwREF0UXBvNzE3YnFicUJYYzdZaQoyV1JEMFlXQ0Ntb1Qwb3JYYU5jQ2V6TkdSWVBPZzQ4cithNUcyZWMyakVzemJtYlFxVERLR3B0S3dna0tJdCszClcrMklhbWoyeTVEL3FZeWEwU3prTGtHMURJMkxXZVJyK1dnVjdqSUF1SlB1VEZFUkVFMFpzQzhDZ1lFQXpmVXQKSG5tQ055cXVGeUJhK1Mwd2FzZUJ0Z3JhcU1kU3VuUEY5Z0pFRGp0Yys4bmVJUUw3cTd1azFsNU5GS1dSRjQwOQpueHZObXBEWUk1dDJtdVNTbmpJT3c3N0tzRWgxQmcxd2FkRmttOW5Wa2pxakowbjRWTWFCWTA0TW4vWWY4ZEJUClFjV1ZuU21tRzBsNGFpSi9PVFo1TW5NWWFKd0FJeEx0aVVnLzlzRUNnWUJENHhYdDdLVFg4azBLOVlUbFBzamsKVExDN3hwU2o5Q05xZFJoQTg2OWpvbmV6Z05YUHZZZlJyd2FRNkRtbVJXelN1d0JtQ1NobFc3ZjR0MVFnU2dPbApIRUlxcFVZR1FRSFhpWjRvbWp6dzRKTXMxSy9qZlJmVjlmVFlvQXJRYXU0MzZOWmZQS2RzRWVyUjNrQ2lWNGFoClJhaFRUK0FKdFRXMFdEZG5rZFJxK3dLQmdGazZkRTYwbzlhVXRoR3M0ZHo4Vi9LYTlyWlFvNFRsdmhDclljT0EKSGMzd3FBc3AzUU4rVUZ5SmtoT1JqV0Y1alkrZmtHZmpXc014SjRMZHNwZk9tVHJTUXhWSkRuVXJIdy85T0l1UAp2VC9NTXp3RURYVlRGYlJjditldkE4YzFrWWRwRXZqMnlpZnB5RjRnQ1h3cDcrWndsRGRvSjlZQ2FBaktCWUVwCmZSVEJBb0dCQU5YRWU4TU9ueW9CcHBuaVpNNEMwa1NTVE9oSUZqV05JMWlkaXhMWTM5eFpqbTlJVDJMMjFGbDgKN0xXdEl6ZDlzVzVpRUFKTTBBczJPM094NUhQa2lYMENxUkJYM1EyeTl5QWJERVhDS2JLV05RVmRYRzlSV2lVcApWRTgrT0xmWGxxVUNheVhPQ1dCZGlrNUQ3Z2RFYllVbzBqNUR0T3EwL3ZTS3Jyc1VHNG0wCi0tLS0tRU5EIFJTQSBQUklWQVRFIEtFWS0tLS0tCg== stable/mongodb-replicaset
```

### mongodump

Hosts:

- my-release-mongodb-replicaset-0.my-release-mongodb-replicaset.demo.svc.cluster.local:27017
- my-release-mongodb-replicaset-1.my-release-mongodb-replicaset.demo.svc.cluster.local:27017
- my-release-mongodb-replicaset-2.my-release-mongodb-replicaset.demo.svc.cluster.local:27017

```console
$ mongodump --host "rs0/my-release-mongodb-replicaset-0.my-release-mongodb-replicaset.demo.svc.cluster.local:27017,my-release-mongodb-replicaset-1.my-release-mongodb-replicaset.demo.svc.cluster.local:27017,my-release-mongodb-replicaset-2.my-release-mongodb-replicaset.demo.svc.cluster.local:27017" --username "root" --password "pass" --out "/tmp/dump" --readPreference secondary

# If namespace is same,
$ mongodump --host "rs0/my-release-mongodb-replicaset-0:27017,my-release-mongodb-replicaset-1:27017,my-release-mongodb-replicaset-2:27017" --username "root" --password "pass" --out "/tmp/dump" --readPreference secondary 

# with just service name and without read preference
$ mongodump --host "rs0/my-release-mongodb-replicaset" --port 27017 --username "root" --password "pass" --out "/tmp/dump"

```
