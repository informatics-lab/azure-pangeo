#!/bin/bash
set -e
echo "*** Test ***"

for dir in env/*; do
    env=${dir##*/}
    echo "*** Test ${env} ***"
    helm lint jadepangeo -f env/${env}/values.yaml -f env/${env}/secrets.yaml
done
