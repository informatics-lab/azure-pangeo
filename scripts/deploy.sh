#!/bin/bash
set -ex
echo "*** Deploy ***"

ENV=$1 # environment
RELEASE_NAME=$2 # helm chart release name.
NAMESPACE=$3 # kubernetes namespace to use.
if [[ "$4" == "--skip-helm-downgrade" ]]; then SKIP_HELM_DOWNGRADE="True"; fi
echo ENV=$1 RELEASE_NAME=$2

# Connect to the correct cluster
az aks get-credentials -g "$ENV" -n "$ENV" --overwrite-existing

# helm client version may differ from server version. Find out the server version and install that if different.

if [ "$SKIP_HELM_DOWNGRADE" != "True" ]
then
    echo "*** Downgrade helm if client version doesn't match server ***"
    HVERSION=$(helm version -s --short | cut -d ' '  -f 2 | cut -d '+' -f 1)
    sudo ./helm-install.sh --version $HVERSION
fi

# init helm
helm init


# Add upstream pangeo repo and update
helm repo add pangeo https://pangeo-data.github.io/helm-chart/
helm repo update

# Get deps
helm dependency update azure-pangeo

# Apply changes
helm upgrade --install $RELEASE_NAME azure-pangeo --namespace $NAMESPACE -f env/$ENV/values.yaml -f env/$ENV/secrets.yaml


echo "*** Deployed successfully ***"


echo "###*** Now deploy the blob fuse secret if not previously done ***###"
SECRET_NAME="blobfusecreds"
echo "kubectl create secret generic $SECRET_NAME -n $NAMESPACE --from-literal accountname=\"<storage account name>\" --from-literal accountkey=\"<storage account key>\" --type=\"azure/blobfuse\""