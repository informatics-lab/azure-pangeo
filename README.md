# Our Pangeo [![Build Status](https://travis-ci.com/informatics-lab/our-pangeo.svg?branch=master)](https://travis-ci.com/informatics-lab/our-pangeo)

We have joined forces with the [Pangeo community](https://pangeo-data.github.io/)! Pangeo is a curated stack of software and tools to empower big data processing in the atmostpheric, oceanographic and climate community. Much of the work we did in our previous [Jade](https://github.com/informatics-lab?utf8=%E2%9C%93&q=jade&type=&language=) project has been integreated into Pangeo.

This repository contains a [helm chart](https://github.com/kubernetes/helm/blob/master/docs/charts.md) which allows you to stand up our custom version of the Pangeo stack. This chart is mainly going to be a wrapper the [Pangeo chart](https://zero-to-jupyterhub.readthedocs.io/en/latest/) along with config to add our custom stuff.

## Usage

First off you need [helm](https://github.com/kubernetes/helm) if you don't have it already.

You'll also need to symlink the config from our [private-config](https://github.com/met-office-lab/private-config) repo.

_If you're not a member of the Informatics Lab and are looking to set this up yourself then check out the `values.yaml` file and the config for the other dependencies._

```shell
PATH_TO_PRIVATE_CONFIG=$(cd $(pwd)/../private-config; pwd) # set as necessary
ln -s $PATH_TO_PRIVATE_CONFIG/jade-pangeo/panzure/secrets.yaml env/panzure/secrets.yaml
ln -s $PATH_TO_PRIVATE_CONFIG/jade-pangeo/panzure-dev/secrets.yaml env/panzure-dev/secrets.yaml
```

Now you can go ahead and deploy

```shell
# Create or update
# prod
./scripts/deploy.sh --env panzure --release-name panzure --namespace panzure --skip-helm-downgrade
#dev
./scripts/deploy.sh --env panzure-dev --release-name panzure-dev --namespace panzure-dev --skip-helm-downgrade

# Delete
# prod
helm delete panzure.informaticslab.co.uk --purge
# dev
helm delete panzure-dev.informaticslab.co.uk --purge
```

## Troubleshooting

Here are some common problems we experience with our Pangeo and ways to resolve them.

### Install error "Error: Could not get apiVersions from Kubernetes: unable to retrieve the complete list of server APIs: metrics.k8s.io/v1beta1: the server is currently unable to handle the request"

This happens when one or more of the Kubernetes API services is not in a "Available" state. This can be checked by running the command `kubectl get apiservice`,  the service  `v1beta1.metrics.k8s.io` regularly fails to be available for up to an hour or perhaps longer when a new AKS cluster is created. Waiting for a hour or two usually resolves the issue if the cluster is new.


### 503 Errors when starting your notebook server

This happens for a range of reasons. The main ones are:
 - The notebook pod failing to start due to issues with the image. Often experienced after updating the docker image and upgrading to a new version. Roll back to the previous image to resolve.
 - AWS scaling being slow and Jupyter Hub (Kubespawner specifically) timing out. Attempting to start server again usually is successful.
 - User home directory being full. This causes a whole range of problems. Fix for this is to mount the home directory onto a separate pod and cleaning out some files ([see debugging persistent volume claims](https://medium.com/@jacobtomlinson/debugging-kubernetes-pvcs-a150f5efbe95)).


### Jupyter Hub failing to start after upgrade

Occasionally when upgrading the helm chart the hub fails to start and complains about a PVC attachment issue.

This happens because a new hub is created while the old hub is terminating. They both want to have the PVC (which in this case is an AWS EBS volume) but that can only be attached to one host at the same time. If the old and new pods are on different hosts they can get stuck.

This can also happen when AWS occasionally has problems mounting the EBS volume.

This will resolve itself with time, but due to backoff timouts this can be a while. To speed things along you can manually scale the hub down to one pod, then wait for all to temrinate, then scale back up.

```shell
# Scale down
kubectl -n jupyter scale deployment hub --replicas=0

# Scale up
kubectl -n jupyter scale deployment hub --replicas=1
```


### User home directory filling up

Frustratingly when a user's home directory fills up it can present itself in a myriad of ways, none of which are very descriptive of what is going on. Usually it results in repeated 400/500 errors in the browser.

No new kernels can be created as they require temporary files to be placed in the home directory. This means you cannot switch to the shell to tidy the files.

If a user logs out with a full home directory they may not be able to log back in.

If the user has an active kernel either in a notebook or shell they can try to clear out the files them selves. However the easiest way is for an admin with kubectl access to exec a bash session inside the user's pod and clean out the files.

```shell
kubectl -n jupyter exec -it jupyter-jacobtomlinson bash
```


### Kernels dying

When a kernel exceeds the memory limits specified in the `values.yaml` file it will be sent a `SIGKILL` by the Kubernetes kubelet. This causes the kernel to silently exit. When viewing this in the notebook the activity light will switch to 'restarting' then 'idle' but the cell will still appear to be executing and there will be no stderr output.

This is expected functionality but frustrating for users.


## Auto deployment

The auto deployment requires these environment variables to be set.

```shell
SECRETS_REPO # Git url of the private config repo.
SSH_KEY # Base 64 encode version of the private side of the github deploy key

# The azure service principal details.
AZ_PASSWORD
AZ_TENENT 
AZ_USERNAME
```

The service principal can be created like so. This will show the necessary values of the env vars above (note - username is the appId):

```shell
az ad sp create-for-rbac --name http://pangeo-travis-deploy

az role assignment create --role "Azure Kubernetes Service Cluster Admin Role" --assignee http://pangeo-travis-deploy
```

`SSH_KEY` is the private key to match the deploy key for the repo. Should be in base64 format.

You can create one like so.
```shell
ssh-keygen -f ./key
SSH_KEY=$(cat key |base64)
```

`$SSH_KEY` is the env var `key.pub` is the public deploy key for github.


### TODOS

Shared file storage on scratch across environments. Currently not doing with blob store but want to also do it with file store. Stopped as this as it was getting a little messy.

Would require (on deploy) creating the file-share if not exists:

```
# Create scratch files share if not exist
SCRATCH_FILE_SHARE_NAME="panzure-scratch"
SHARED_STORAGE_ACCOUNT_NAME="panzuredata"
az storage share create
if ! az storage share show --account-name $SHARED_STORAGE_ACCOUNT_NAME --name $SCRATCH_FILE_SHARE_NAME > /dev/null 2>&1; then
    echo "need to make it"
    az storage share create --name $SCRATCH_FILE_SHARE_NAME --quota 100 --account-name $SHARED_STORAGE_ACCOUNT_NAME
fi
```

Then creating a `PV`, I believe if the name was exactly the same as the name of the file share (and account the same) then it would 'connect' but not tested this.
In order to create the `PV` would need to create the secret for the `PV` to use as per here https://docs.microsoft.com/en-us/azure/aks/azure-files-volume this is currently
automatically done with the dynamic PVC provisioning but the automatically created one would not necessarily be available at the time that it was required.

The `scratch-pvc` would need to be set up to reference the new `PV`.
