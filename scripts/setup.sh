#!/bin/bash
set -e

# Vars
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_DIR=$SCRIPT_DIR/..

# Install tools
echo "*** Install helm ***"
sudo apt-get install git -y
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > ./helm-install.sh
chmod +x ./helm-install.sh
sudo ./helm-install.sh

echo "*** Install kubectl ***"
sudo apt-get update && sudo apt-get install -y apt-transport-https
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo touch /etc/apt/sources.list.d/kubernetes.list
echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubectl

echo "*** Install Azure CLI ***"
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash 


# Set up ssh
echo "*** Install ssh keys ***"
mkdir -p ~/.ssh
cat << EOF > ~/.ssh/config
Host *
    StrictHostKeyChecking no

EOF

echo $SSH_KEY | base64 -d > ~/.ssh/id_rsa
chmod 400  ~/.ssh/id_rsa

# Link secrets
echo "*** Link in secrets ***"
cd $REPO_DIR/..
git clone $SECRETS_REPO secrets
cd $REPO_DIR
for dir in env/*; do
    env=${dir##*/}
    ln -s $(cd ..; pwd)/secrets/jade-pangeo/${env}/secrets.yaml ./env/${env}/secrets.yaml
done


# # Setup kubectl config
az login --service-principal --username ${AZ_USERNAME} --password ${AZ_PASSWORD} --tenant ${AZ_TENENT}


