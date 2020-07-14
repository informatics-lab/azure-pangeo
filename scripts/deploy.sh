#!/bin/bash
set -ex
echo "*** Deploy ***"


## Parse args
ENV=""
RELEASE_NAME=""
NAMESPACE=""
CLUSTER_NAME=""
RESOURCE_GROUP=""
SKIP_HELM_DOWNGRADE="False"

PARAMS=""
while (( "$#" )); do
  case "$1" in
    --skip-helm-downgrade)
      SKIP_HELM_DOWNGRADE="True"
      shift
      ;;
    -e|--env)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        ENV=$2
        shift 2
      else
        echo "Error: Argument for $1 is missing" >&2
        exit 1
      fi
      ;;
    -n|--namespace)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        NAMESPACE=$2
        shift 2
      else
        echo "Error: Argument for $1 is missing" >&2
        exit 1
      fi
      ;;
    -c|--cluster-name)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        CLUSTER_NAME=$2
        shift 2
      else
        echo "Error: Argument for $1 is missing" >&2
        exit 1
      fi
      ;;
    -r|--release-name)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        RELEASE_NAME=$2
        shift 2
      else
        echo "Error: Argument for $1 is missing" >&2
        exit 1
      fi
      ;;
    -g|--resource-group)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        RESOURCE_GROUP=$2
        shift 2
      else
        echo "Error: Argument for $1 is missing" >&2
        exit 1
      fi
      ;;
    -*|--*=) # unsupported flags
      echo "Error: Unsupported flag $1" >&2
      exit 1
      ;;
    *) # preserve positional arguments
      PARAMS="$PARAMS $1"
      shift
      ;;
  esac
done
# set positional arguments in their proper place
eval set -- "$PARAMS"


# Backwards compatability with old positional args form
[ -z "$ENV" ] && ENV=$1 # environment
[ -z "$RELEASE_NAME" ] && RELEASE_NAME=$2 # helm chart release name.
[ -z "$NAMESPACE" ] && NAMESPACE=$3 # kubernetes namespace to use.
[ -z "$CLUSTER_NAME" ] && CLUSTER_NAME=$ENV # default cluster name to release name
[ -z "$RESOURCE_GROUP" ] && RESOURCE_GROUP=$ENV # default resource group to release name

cat << END 
Args parsed:
    ENV=$ENV
    RELEASE_NAME=$RELEASE_NAME
    NAMESPACE=$NAMESPACE
    CLUSTER_NAME=$CLUSTER_NAME
    RESOURCE_GROUP=$RESOURCE_GROUP
    SKIP_HELM_DOWNGRADE=$SKIP_HELM_DOWNGRADE
END

# Connect to the correct cluster
az aks get-credentials -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --overwrite-existing

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