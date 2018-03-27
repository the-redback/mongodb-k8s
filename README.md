# MongoDB in Kubernetes

## Replica-Sets

### Create Secret for Key file

MongoDB will use this key to communicate internal cluster.

```console
$ openssl rand -base64 741 > ./replica-sets/key.txt

$ kubectl create secret generic shared-bootstrap-data --from-file=internal-auth-mongodb-keyfile=./replica-sets/key.txt
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

Run the following command to connect to the first container:

```console
$ kubectl exec -it mongod-0 -c mongod-container bash
```

This will place you into a command line shell directly in the container.

Connect to the local “mongod” process using the Mongo Shell and authorize the user

```console
$ mongo
```

In the shell run the following command to initiate the replica set (we can rely on the hostnames always being the same, due to having employed a StatefulSet):

```console
> rs.initiate({_id: "MainRepSet", version: 1, members: [
       { _id: 0, host : "mongod-0.mongodb-service.default.svc.cluster.local:27017" },
       { _id: 1, host : "mongod-1.mongodb-service.default.svc.cluster.local:27017" },
       { _id: 2, host : "mongod-2.mongodb-service.default.svc.cluster.local:27017" }
 ]});
```

Keep checking the status of the replica set, with the following command, until you see that the replica set is fully initialised and a primary and two secondaries are present:

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
$ kubectl apply -f ./replica-sets/mongodb-rc.yaml
$ kubectl get all
```

Recreate MongoDB

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