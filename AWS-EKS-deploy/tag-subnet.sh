#!/bin/bash

# Define variables
VPC_NAME="cirobessa-vpc"
REGION="us-east-1"

# Get the VPC ID
echo "Fetching VPC ID for VPC Name: $VPC_NAME..."
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=$VPC_NAME" \
  --query "Vpcs[0].VpcId" --output text --region "$REGION")

if [ -z "$VPC_ID" ] || [ "$VPC_ID" == "None" ]; then
  echo "Error: VPC with name $VPC_NAME not found."
  exit 1
fi

echo "VPC ID: $VPC_ID"

# Get the Subnets and their tags
echo "Fetching Subnets associated with VPC ID: $VPC_ID..."
SUBNETS=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "Subnets[].{ID:SubnetId,Name:Tags[?Key=='Name'].Value | [0]}" \
  --region "$REGION" --output json)

if [ -z "$SUBNETS" ]; then
  echo "Error: No subnets found for VPC ID: $VPC_ID."
  exit 1
fi

# Iterate over subnets and apply the appropriate tag
echo "$SUBNETS" | jq -c '.[]' | while read -r subnet; do
  SUBNET_ID=$(echo "$subnet" | jq -r '.ID')
  SUBNET_NAME=$(echo "$subnet" | jq -r '.Name')

  if [[ "$SUBNET_NAME" == *"public"* ]]; then
    TAG_KEY="kubernetes.io/role/elb"
    TAG_VALUE="1"
    echo "Tagging public Subnet: $SUBNET_ID with $TAG_KEY=$TAG_VALUE..."
  elif [[ "$SUBNET_NAME" == *"private"* ]]; then
    TAG_KEY="kubernetes.io/role/internal-elb"
    TAG_VALUE="1"
    echo "Tagging private Subnet: $SUBNET_ID with $TAG_KEY=$TAG_VALUE..."
  else
    echo "Skipping Subnet: $SUBNET_ID (unknown type)"
    continue
  fi

  aws ec2 create-tags \
    --resources "$SUBNET_ID" \
    --tags Key="$TAG_KEY",Value="$TAG_VALUE" --region "$REGION"

  if [ $? -eq 0 ]; then
    echo "Successfully tagged Subnet: $SUBNET_ID"
  else
    echo "Failed to tag Subnet: $SUBNET_ID"
  fi
done

echo "All applicable Subnets tagged successfully!"


