#!/bin/bash

# https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version

curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
eksctl version

# https://docs.aws.amazon.com/pt_br/eks/latest/userguide/create-kubeconfig.html
aws eks update-kubeconfig \
  --region us-east-1 \
  --name my-cluster

ecksctl get clusters
