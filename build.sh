#!/bin/bash

debug=0
IMAGE_NAME="keepalived"
build_date=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
version="v1.0.2" #$(git describe --tags 2> /dev/null || echo "$SOURCE_BRANCH")
#vcs_ref=$(git rev-parse --short HEAD)

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -v|--version) version="$2"; shift ;;
        -d|--debug) debug=1 ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

#--build-arg VCS_REF="$vcs_ref"       \
docker build \
  --build-arg BUILD_DATE="$build_date" \
  --build-arg VERSION="$version"       \
  -t "$IMAGE_NAME" .
