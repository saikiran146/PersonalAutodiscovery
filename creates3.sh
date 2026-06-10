#!/bin/bash
set -e

# ─────────────────────────────────────────────
#  Terraform S3 Backend Setup Script
#  Project: Auto-Discovery Project Team 2
#  Run this ONCE before terraform init
# ─────────────────────────────────────────────

# ── CONFIG — change these if needed ──────────
BUCKET_NAME="pet-adoption-state-bucket-two2"
REGION="eu-west-3"
STATE_KEY="vault-jenkins/terraform.tfstate"
# ─────────────────────────────────────────────

echo ""
echo "================================================"
echo "  Terraform S3 Backend Setup"
echo "  Bucket : $BUCKET_NAME"
echo "  Region : $REGION"
echo "================================================"
echo ""

# ── Step 1: Verify AWS CLI is configured ─────
echo "[1/6] Verifying AWS credentials..."
IDENTITY=$(aws sts get-caller-identity --output json 2>&1)
if [ $? -ne 0 ]; then
  echo "ERROR: AWS CLI not configured. Run 'aws configure' first."
  exit 1
fi
ACCOUNT_ID=$(echo $IDENTITY | python3 -c "import sys,json; print(json.load(sys.stdin)['Account'])")
echo "      Account ID : $ACCOUNT_ID"
echo "      OK"
echo ""

# ── Step 2: Check if bucket already exists ───
echo "[2/6] Checking if bucket already exists..."
if aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$REGION" 2>/dev/null; then
  echo "      Bucket '$BUCKET_NAME' already exists — skipping creation."
else
  echo "      Creating bucket '$BUCKET_NAME' in $REGION..."
  if [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket \
      --bucket "$BUCKET_NAME" \
      --region "$REGION"
  else
    aws s3api create-bucket \
      --bucket "$BUCKET_NAME" \
      --region "$REGION" \
      --create-bucket-configuration LocationConstraint="$REGION"
  fi
  echo "      Bucket created."
fi
echo ""

# ── Step 3: Enable versioning ─────────────────
echo "[3/6] Enabling versioning..."
aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled \
  --region "$REGION"
echo "      Versioning enabled."
echo ""

# ── Step 4: Enable server-side encryption ────
echo "[4/6] Enabling AES-256 server-side encryption..."
aws s3api put-bucket-encryption \
  --bucket "$BUCKET_NAME" \
  --region "$REGION" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      },
      "BucketKeyEnabled": true
    }]
  }'
echo "      Encryption enabled."
echo ""

# ── Step 5: Block all public access ──────────
echo "[5/6] Blocking all public access..."
aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --region "$REGION" \
  --public-access-block-configuration '{
    "BlockPublicAcls": true,
    "IgnorePublicAcls": true,
    "BlockPublicPolicy": true,
    "RestrictPublicBuckets": true
  }'
echo "      Public access blocked."
echo ""

# ── Step 6: Verify all settings ──────────────
echo "[6/6] Verifying configuration..."
echo ""

VERSIONING=$(aws s3api get-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --region "$REGION" \
  --query "Status" --output text)
echo "      Versioning     : $VERSIONING"

ENCRYPTION=$(aws s3api get-bucket-encryption \
  --bucket "$BUCKET_NAME" \
  --region "$REGION" \
  --query "ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm" \
  --output text)
echo "      Encryption     : $ENCRYPTION"

PUBLIC_BLOCK=$(aws s3api get-public-access-block \
  --bucket "$BUCKET_NAME" \
  --region "$REGION" \
  --query "PublicAccessBlockConfiguration.BlockPublicPolicy" \
  --output text)
echo "      Public blocked : $PUBLIC_BLOCK"
echo ""

# ── Final summary ─────────────────────────────
echo "================================================"
echo "  SETUP COMPLETE"
echo "================================================"
echo ""
echo "  Your provider.tf backend block should be:"
echo ""
echo "  terraform {"
echo "    backend \"s3\" {"
echo "      bucket  = \"$BUCKET_NAME\""
echo "      key     = \"$STATE_KEY\""
echo "      region  = \"$REGION\""
echo "      encrypt = true"
echo "      profile = \"default\""
echo "    }"
echo "  }"
echo ""
echo "  Next steps:"
echo "  1. cd into your project folder"
echo "  2. terraform init"
echo "  3. terraform plan"
echo "  4. terraform apply"
echo ""
