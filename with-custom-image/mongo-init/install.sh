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