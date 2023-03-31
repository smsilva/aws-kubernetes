#   aws-kubernetes

##  1. Install

[Installing or updating the latest version of the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

### 1.1. aws CLI

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version
```

### 1.2. eksctl CLI

```bash
curl \
  --silent \
  --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" \
| tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
eksctl version
eksctl get clusters
```

##  2. kubeconfig file

### 2.1. Creating or updating

```bash
aws eks update-kubeconfig \
  --name "CLUSTER_NAME_HERE"
```

[Reference](https://docs.aws.amazon.com/eks/latest/userguide/create-kubeconfig.html)

### 2.2. Create kubeconfig file manually

[Reference](https://docs.aws.amazon.com/eks/latest/userguide/create-kubeconfig.html#create-kubeconfig-manually)

##  3. External Secrets

### 3.1. Environment Variables

```bash
cat <<EOF > /tmp/eks.conf
export EKS_CLUSTER_ID="$(uuidgen)"
export EKS_CLUSTER_ID="\${EKS_CLUSTER_ID:0:4}"
export EKS_CLUSTER_NAME="wasp-sandbox-\${EKS_CLUSTER_ID?}"
export EKS_CLUSTER_REGION="\${AWS_DEFAULT_REGION-us-east-1}"
export IAM_POLICY_NAME="secretsmanager-docker-hub-read-only"
export IAM_POLICY_CREATION_FILE="/tmp/\${IAM_POLICY_NAME?}-creation.json"
export IAM_POLICY_DATA_FILE="/tmp/\${IAM_POLICY_NAME?}-data.json"
export IAM_ROLE_NAME="external-secrets-operator"
export K8S_SERVICE_ACCOUNT_NAME="secretsmanager-access"
export K8S_SERVICE_ACCOUNT_NAMESPACE="external-secrets"
export TF_VAR_cluster_name=\${EKS_CLUSTER_NAME?}

echo "EKS_CLUSTER_ID................: \${EKS_CLUSTER_ID}"
echo "EKS_CLUSTER_NAME..............: \${EKS_CLUSTER_NAME}"
echo "EKS_CLUSTER_REGION............: \${EKS_CLUSTER_REGION}"
echo "IAM_POLICY_NAME...............: \${IAM_POLICY_NAME}"
echo "IAM_POLICY_CREATION_FILE......: \${IAM_POLICY_CREATION_FILE}"
echo "IAM_POLICY_DATA_FILE..........: \${IAM_POLICY_DATA_FILE}"
echo "IAM_ROLE_NAME.................: \${IAM_ROLE_NAME}"
echo "K8S_SERVICE_ACCOUNT_NAME......: \${K8S_SERVICE_ACCOUNT_NAME}"
echo "K8S_SERVICE_ACCOUNT_NAMESPACE.: \${K8S_SERVICE_ACCOUNT_NAMESPACE}"
echo "TF_VAR_cluster_name...........: \${TF_VAR_cluster_name}"
EOF

source /tmp/eks.conf

eksctl create cluster \
  --name ${EKS_CLUSTER_NAME?} \
  --region ${EKS_CLUSTER_REGION?} \
  --zones "us-east-1a, us-east-1" \
  --with-oidc \
  --ssh-access \
  --ssh-public-key ~/.ssh/id_rsa.pub \
  --managed \
  --version "1.24" \
  --nodes-min 1 \
  --nodes-max 5

aws sts get-caller-identity

aws eks update-kubeconfig \
  --name "${EKS_CLUSTER_NAME?}"
```

### 3.2. Check IAM OIDC provider

[Documentation](https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html)

```bash
EKS_CLUSTER_OIDC_ID=$(aws eks describe-cluster \
  --name ${EKS_CLUSTER_NAME?} \
  --query "cluster.identity.oidc.issuer" \
  --output text \
| cut -d '/' -f 5)

aws iam list-open-id-connect-providers --output text \
| grep ${EKS_CLUSTER_OIDC_ID?} \
| cut -d "/" -f4
```

### 3.3. Configuring a Kubernetes service account to assume an IAM role

[Documentation](https://docs.aws.amazon.com/eks/latest/userguide/associate-service-account-role.html)

```bash
source /tmp/eks.conf

aws secretsmanager list-secrets \
| jq '.SecretList[] | select(.Name | contains("docker-hub-credentials"))' \
| jq -r .ARN

cat <<EOF > ${IAM_POLICY_CREATION_FILE?}
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetResourcePolicy",
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
        "secretsmanager:ListSecretVersionIds"
      ],
      "Resource": [
        "arn:aws:secretsmanager:us-east-1:221047292361:secret:docker-hub-*"
      ]
    }
  ]
}
EOF

aws iam create-policy \
  --policy-name ${IAM_POLICY_NAME?} \
  --policy-document file://${IAM_POLICY_CREATION_FILE?} \
| tee ${IAM_POLICY_DATA_FILE?}

IAM_POLICY_ARN=$(jq -r .Policy.Arn ${IAM_POLICY_DATA_FILE?})

kubectl create namespace ${K8S_SERVICE_ACCOUNT_NAMESPACE?}

eksctl create iamserviceaccount \
  --cluster ${EKS_CLUSTER_NAME?} \
  --name ${K8S_SERVICE_ACCOUNT_NAME?} \
  --namespace ${K8S_SERVICE_ACCOUNT_NAMESPACE?} \
  --attach-policy-arn ${IAM_POLICY_ARN?} \
  --role-name ${IAM_ROLE_NAME?} \
  --approve

aws iam get-role \
  --role-name ${IAM_ROLE_NAME?} \
  --query Role.Arn \
  --output text

aws iam get-role \
  --role-name ${IAM_ROLE_NAME?} \
  --query Role.AssumeRolePolicyDocument

aws iam list-attached-role-policies \
  --role-name ${IAM_ROLE_NAME?} \
  --query AttachedPolicies[].PolicyArn \
  --output text

aws iam get-policy \
  --policy-arn ${IAM_POLICY_ARN?}

aws iam get-policy-version \
  --policy-arn ${IAM_POLICY_ARN?} \
  --version-id v1

kubectl describe serviceaccount ${K8S_SERVICE_ACCOUNT_NAME?} \
  --namespace ${K8S_SERVICE_ACCOUNT_NAMESPACE?}

kubectl get serviceaccount ${K8S_SERVICE_ACCOUNT_NAME?} \
  --namespace ${K8S_SERVICE_ACCOUNT_NAMESPACE?} \
  --output yaml \
| kubectl-neat
```

### 3.4. Setup Cluster Secret Store

[EKS Service Account credentials
](https://external-secrets.io/v0.8.1/provider/aws-secrets-manager/#eks-service-account-credentials)

```bash
helm repo add external-secrets https://charts.external-secrets.io

helm repo update

helm search repo external-secrets/external-secrets

helm upgrade \
  --install \
  --namespace external-secrets \
  --create-namespace \
  external-secrets external-secrets/external-secrets \
  --wait

watch -n 5 'kubectl -n example get css,es; echo; kubectl -n example get secrets | egrep "NAME|docker"'

cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: aws-secrets-manager
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: ${K8S_SERVICE_ACCOUNT_NAME?}
            namespace: ${K8S_SERVICE_ACCOUNT_NAMESPACE?}
EOF

kubectl create namespace example

cat <<EOF | kubectl -n example apply -f -
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: docker-hub
spec:
  refreshInterval: 1h

  secretStoreRef:
    kind: ClusterSecretStore
    name: aws-secrets-manager

  target:
    name: docker-hub
    creationPolicy: Owner

  data:
    - secretKey: values
      remoteRef:
        key: docker-hub-credentials

    - secretKey: mypassword
      remoteRef:
        key: docker-hub-credentials
        property: password
  
  dataFrom:
    - extract:
        key: docker-hub-credentials
EOF
```

##  4. IAM

### 4.1. Commands

```bash
export EKS_CLUSTER_NAME=$(
  eksctl get clusters \
  --output json \
| jq -r '.[0].Name'
)

aws eks update-kubeconfig \
  --profile terraform \
  --name ${EKS_CLUSTER_NAME?}

export IAM_EKS_ADMIN_ROLE_ARN=$(
aws iam get-role \
  --role-name eks-admin \
  --query "Role.Arn" \
  --output text
)

aws sts assume-role \
  --role-arn ${IAM_EKS_ADMIN_ROLE_ARN?} \
  --role-session-name silvios-session \
  --profile default

aws eks update-kubeconfig \
  --profile default \
  --name ${EKS_CLUSTER_NAME?}

kubectl get configmap aws-auth \
  --namespace kube-system \
  --output yaml \
| kubectl neat

kubectl edit configmap aws-auth \
  --namespace kube-system

cat ~/.aws/config

cat <<EOF >> ~/.aws/config
[profile eks-admin]
role_arn = arn:aws:iam::221047292361:role/eks-admin
source_profile = default
EOF

apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - groups:
      - system:bootstrappers
      - system:nodes
      rolearn: arn:aws:iam::221047292361:role/green-eks-node-group-20230330162751518900000001
      username: system:node:{{EC2PrivateDNSName}}
    # new role:
    - rolearn: arn:aws:iam::221047292361:role/eks-admin
      username: eks-admin
      groups:
      - system:masters

aws eks update-kubeconfig \
  --region us-east-1 \
  --name ${EKS_CLUSTER_NAME?} \
  --profile eks-admin

kubectl auth can-i "*" "*"
```

##  5. Terraform Providers

### 5.1. Helm

```lua
provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.cluster.name, "--profile", "terraform"]
    }
  }
}
```

### 5.2. Kubernetes

```lua
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.cluster.name, "--profile", "terraform"]
  }
}
```
