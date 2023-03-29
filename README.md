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

[Creating or updating a kubeconfig file for an Amazon EKS cluster](https://docs.aws.amazon.com/eks/latest/userguide/create-kubeconfig.html)

```bash
aws eks update-kubeconfig \
  --region "us-east-1" \
  --name "wasp-sandbox-uhb631"
```

### 2.2. Create kubeconfig file manually

[Create kubeconfig file manually]https://docs.aws.amazon.com/eks/latest/userguide/create-kubeconfig.html#create-kubeconfig-manually)

```bash
export region_code=region-code
export cluster_name=my-cluster
export account_id=111122223333

cluster_endpoint=$(aws eks describe-cluster \
  --region $region_code \
  --name $cluster_name \
  --query "cluster.endpoint" \
  --output text)

certificate_data=$(aws eks describe-cluster \
  --region $region_code \
  --name $cluster_name \
  --query "cluster.certificateAuthority.data" \
  --output text)

mkdir -p ~/.kube

#!/bin/bash
read -r -d '' KUBECONFIG <<EOF
apiVersion: v1
kind: Config

preferences: {}

clusters:
  - cluster:
      certificate-authority-data: $certificate_data
      server: $cluster_endpoint
    name: arn:aws:eks:$region_code:$account_id:cluster/$cluster_name

contexts:
  - context:
      cluster: arn:aws:eks:$region_code:$account_id:cluster/$cluster_name
      user: arn:aws:eks:$region_code:$account_id:cluster/$cluster_name
    name: arn:aws:eks:$region_code:$account_id:cluster/$cluster_name

current-context: arn:aws:eks:$region_code:$account_id:cluster/$cluster_name

users:
  - name: arn:aws:eks:$region_code:$account_id:cluster/$cluster_name
    user:
      exec:
        apiVersion: client.authentication.k8s.io/v1beta1
        command: aws
        args:
          - --region
          - $region_code
          - eks
          - get-token
          - --cluster-name
          - $cluster_name
          # - "- --role-arn"
          # - "arn:aws:iam::$account_id:role/my-role"
        # env:
          # - name: "AWS_PROFILE"
          #   value: "aws-profile"
EOF
echo "${KUBECONFIG}" > ~/.kube/config
```

##  3. External Secrets

### 3.1. Environment Variables

```bash
cat <<EOF > /tmp/eks.conf
export EKS_CLUSTER_ID="$(uuidgen)"
export EKS_CLUSTER_ID="\${EKS_CLUSTER_ID:0:6}"
export EKS_CLUSTER_NAME="wasp-sandbox-\${EKS_CLUSTER_ID?}"
export IAM_POLICY_NAME="secretsmanager-docker-hub-read-only"
export IAM_POLICY_CREATION_FILE="/tmp/\${IAM_POLICY_NAME?}-creation.json"
export IAM_POLICY_DATA_FILE="/tmp/\${IAM_POLICY_NAME?}-data.json"
export IAM_ROLE_NAME="external-secrets-operator"
export K8S_SERVICE_ACCOUNT_NAME="secretsmanager-access"
export K8S_SERVICE_ACCOUNT_NAMESPACE="external-secrets"

echo "EKS_CLUSTER_ID................: \${EKS_CLUSTER_ID}"
echo "EKS_CLUSTER_NAME..............: \${EKS_CLUSTER_NAME}"
echo "IAM_POLICY_NAME...............: \${IAM_POLICY_NAME}"
echo "IAM_POLICY_CREATION_FILE......: \${IAM_POLICY_CREATION_FILE}"
echo "IAM_POLICY_DATA_FILE..........: \${IAM_POLICY_DATA_FILE}"
echo "IAM_ROLE_NAME.................: \${IAM_ROLE_NAME}"
echo "K8S_SERVICE_ACCOUNT_NAME......: \${K8S_SERVICE_ACCOUNT_NAME}"
echo "K8S_SERVICE_ACCOUNT_NAMESPACE.: \${K8S_SERVICE_ACCOUNT_NAMESPACE}"
EOF

source /tmp/eks.conf

aws sts get-caller-identity

aws eks update-kubeconfig \
  --region "us-east-1" \
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
  name: docker-hub-credentials
spec:
  refreshInterval: 1h

  secretStoreRef:
    kind: ClusterSecretStore
    name: aws-secrets-manager

  target:
    name: docker-hub-credentials
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
