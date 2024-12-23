


## Requirements ==>   EKS ready cluster and this commands already set: AWS CLI, kubectl, eksctl, openssl, docker, helm, envsubst

### EKS Terraform deployed from the repository https://github.com/cirobessa/TF-EKS-DEPLOY

### BUILD SPINA APP

# Set variables
REPOSITORY_NAME="spina"
IMAGE_TAG="latest"
AWS_REGION="us-east-1"
# Retrieve AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
# Define the full ECR repository URI
ECR_REPOSITORY_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPOSITORY_NAME}"
ECR_IMAGE_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPOSITORY_NAME}:latest"
CLUSTER_NAME=$(aws eks list-clusters --region $AWS_REGION --query 'clusters[0]' --output text)
POLICY_NAME="AWSLoadBalancerControllerIAMPolicy"
POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}"
SERVICE_ACCOUNT_NAME="aws-load-balancer-controller"
NAMESPACE="kube-system"
export ECR_IMAGE_URI=$(aws ecr describe-images \
  --repository-name spina \
  --region us-east-1 \
  --query 'sort_by(imageDetails, &imagePushedAt)[-1].imageTags[0]' \
  --output text)

export DB_INSTANCE_IDENTIFIER=dbpg
export DB_HOST=$(aws rds describe-db-instances \
  --db-instance-identifier $DB_INSTANCE_IDENTIFIER \
  --region us-east-1 \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)
export DB_NAME=dbpg
export DB_USER=masteruser
export DB_PASSWORD=<get-in-the-DB-creation>


## POSTGRES
bash  create-rds.sh

#################################################
cd ..
# Create ECR repo
aws ecr create-repository --repository-name "${REPOSITORY_NAME}" --region "${AWS_REGION}"
# Authenticate Docker to the ECR registry
aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
# Build the Docker image
docker build -t "${REPOSITORY_NAME}:${IMAGE_TAG}" .
# Tag the Docker image with the ECR repository URI
docker tag "${REPOSITORY_NAME}:${IMAGE_TAG}" "${ECR_REPOSITORY_URI}:${IMAGE_TAG}"
# Push the Docker image to ECR
docker push "${ECR_REPOSITORY_URI}:${IMAGE_TAG}"

cd -
#########################################################################

## SET kubeConfig
aws eks update-kubeconfig --region us-east-1 --name $(aws eks list-clusters --region us-east-1 --query 'clusters[0]' --output text)

# Associate IAM OIDC provider with the EKS cluster to enable IAM roles for service accounts
eksctl utils associate-iam-oidc-provider  --region $REGION  --cluster $CLUSTER_NAME  --approve

# download policy and create user for the AWS ALB
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json
aws iam create-policy --policy-name $POLICY_NAME --policy-document file://iam_policy.json

# Create the IAM service account for the AWS Load Balancer Controller
eksctl create iamserviceaccount --cluster $CLUSTER_NAME --namespace $NAMESPACE --name $SERVICE_ACCOUNT_NAME \
  --attach-policy-arn $POLICY_ARN --approve

# Add the EKS Helm chart repository
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install the AWS Load Balancer Controller using Helm
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace $NAMESPACE \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=$SERVICE_ACCOUNT_NAME \
  --set region=$AWS_REGION \
  --set vpcId=$(aws ec2 describe-vpcs --region $AWS_REGION --filters "Name=isDefault,Values=true" --query "Vpcs[0].VpcId" --output text)

# Verify the deployment of the AWS Load Balancer Controller
kubectl get deployment -n $NAMESPACE aws-load-balancer-controller
# Apply the Ingress resource for the Spina application
kubectl apply -f spina-ingress.yaml
# Retrieve and display the Ingress resource details
kubectl get ingress spina-ingress
# Apply the Service resource for the Spina application
kubectl apply -f spina-service.yaml
# Retrieve and display the Service resource details
kubectl get service spina-service


#############################################################################
# verify access
kubectl get ingress spina-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'


## create deployment permission role
aws iam create-role --role-name spina-app-role --assume-role-policy-document file://trust-policy.json
aws iam put-role-policy --role-name spina-app-role --policy-name SpinaAppPolicy --policy-document file://permissions-policy.json

## create EKS service account
eksctl create iamserviceaccount \
  --name spina-service-account \
  --namespace default \
  --cluster $CLUSTER_NAME \
  --attach-role-arn arn:aws:iam::$AWS_ACCOUNT_ID:role/spina-app-role \
  --approve


## SPINA Deployment
envsubst < spina-deployment.yaml | kubectl apply -f -

### SPINA CONFIG
POD_NAME=$(kubectl get pod -l app=spina -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $POD_NAME -- rails db:create
kubectl exec -it $POD_NAME -- rails db:migrate


