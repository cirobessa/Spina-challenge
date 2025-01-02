#!/bin/bash

# Define vars
DB_INSTANCE_IDENTIFIER="dbpg"
DB_NAME="dbpg"
MASTER_USERNAME="masteruser" 
MASTER_PASSWORD=$(openssl rand -base64 12 | tr -d '/@\" ')
REGION="us-east-1"
DB_INSTANCE_CLASS="db.t3.micro"
ALLOCATED_STORAGE=20

# Get the default VPC ID
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query "Vpcs[0].VpcId" --output text --region "$REGION")

# Check if the RDS instance already exists
echo "Checking if RDS instance '$DB_INSTANCE_IDENTIFIER' exists..."
EXISTING_INSTANCE=$(aws rds describe-db-instances \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --query "DBInstances[0].DBInstanceIdentifier" \
  --output text --region "$REGION" 2>/dev/null)

if [ "$EXISTING_INSTANCE" == "$DB_INSTANCE_IDENTIFIER" ]; then
  echo "RDS instance '$DB_INSTANCE_IDENTIFIER' already exists. Skipping creation."
  exit 0
else
  echo "RDS instance '$DB_INSTANCE_IDENTIFIER' does not exist. Proceeding with creation."
fi

# Create Security Group
echo "Creating Security Group..."
SECURITY_GROUP_ID=$(aws ec2 create-security-group \
  --group-name "rds-public-sg" \
  --description "Security Group for public RDS access" \
  --vpc-id "$VPC_ID" \
  --query "GroupId" --output text --region "$REGION")

# Open port 5432 to the internet
echo "Opening port 5432 to the internet..."
aws ec2 authorize-security-group-ingress \
  --group-id "$SECURITY_GROUP_ID" \
  --protocol tcp \
  --port 5432 \
  --cidr 0.0.0.0/0 \
  --region "$REGION"

# Create RDS
echo "Creating RDS instance..."
aws rds create-db-instance \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --db-name "$DB_NAME" \
  --db-instance-class "$DB_INSTANCE_CLASS" \
  --engine postgres \
  --master-username "$MASTER_USERNAME" \
  --master-user-password "$MASTER_PASSWORD" \
  --allocated-storage "$ALLOCATED_STORAGE" \
  --publicly-accessible \
  --vpc-security-group-ids "$SECURITY_GROUP_ID" \
  --region "$REGION"

# Wait for RDS to be available
echo "Waiting for RDS instance to become available..."
aws rds wait db-instance-available --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" --region "$REGION"

# Obtain RDS endpoint
DB_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" --query 'DBInstances[0].Endpoint.Address' --output text --region "$REGION")

# Show RDS info
echo "Success!"
echo "Endpoint: $DB_ENDPOINT"
echo "DB NAME: $DB_NAME"
echo "User: $MASTER_USERNAME"
echo "Password: $MASTER_PASSWORD"
echo "$MASTER_PASSWORD" > /tmp/pgdb.txt


