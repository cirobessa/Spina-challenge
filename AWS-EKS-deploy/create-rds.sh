#!/bin/bash

# Define  vars
DB_INSTANCE_IDENTIFIER="dbpg"
DB_NAME="dbpg"
MASTER_USERNAME="masteruser" 
MASTER_PASSWORD=$(openssl rand -base64 12)
REGION="us-east-1"
DB_INSTANCE_CLASS="db.t3.micro"
ALLOCATED_STORAGE=20

# Create RDS
aws rds create-db-instance \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --db-name "$DB_NAME" \
  --db-instance-class "$DB_INSTANCE_CLASS" \
  --engine postgres \
  --master-username "$MASTER_USERNAME" \
  --master-user-password "$MASTER_PASSWORD" \
  --allocated-storage "$ALLOCATED_STORAGE" \
  --no-publicly-accessible \
  --region "$REGION"

# wait creation RDS
echo "Aguardando a criação da instância do RDS..."
aws rds wait db-instance-available --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" --region "$REGION"

# Obtain RDS endpoint 
DB_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" --query 'DBInstances[0].Endpoint.Address' --output text --region "$REGION")

# Show RDS info
echo "Sucess!"
echo "Endpoint: $DB_ENDPOINT"
echo "DB NAME: $DB_NAME"
echo "User: $MASTER_USERNAME"
echo "Password: $MASTER_PASSWORD"

