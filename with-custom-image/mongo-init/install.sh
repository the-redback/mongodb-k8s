#!/usr/bin/env bash

WORKDIR_VOLUME="/work-dir"

for i in "$@"; do
    case "$i" in
        -w=*|--work-dir=*)
            WORKDIR_VOLUME="${i#*=}"
            shift
            ;;
        *)
            # unknown option
            ;;
    esac
done

echo Installing config scripts into "${WORKDIR_VOLUME}"

mkdir -p "${WORKDIR_VOLUME}"
cp /peer-finder "${WORKDIR_VOLUME}"/
cp /on-start.sh "${WORKDIR_VOLUME}"/

# Copy config and other files into related fields.
# ref: https://github.com/kubernetes/charts/blob/master/stable/mongodb-replicaset/templates/mongodb-statefulset.yaml#L45

if [ -f "/configdb-readonly/mongod.conf" ]; then
    cp /configdb-readonly/mongod.conf /data/configdb/mongod.conf
fi

if [ -f "/keydir-readonly/key.txt" ]; then
     cp /keydir-readonly/key.txt /data/configdb/key.txt
     chmod 600 /data/configdb/key.txt
fi
