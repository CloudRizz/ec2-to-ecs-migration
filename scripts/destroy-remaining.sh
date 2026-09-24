#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AWS_REGION="eu-west-2"

echo
echo "=================================================="
echo " EC2 to ECS Migration - Final Infrastructure Cleanup"
echo "=================================================="
echo

echo "This script will destroy:"
echo "  1. Legacy EC2 infrastructure"
echo "  2. Bootstrap infrastructure"
echo "  3. Verify remaining AWS resources"
echo
echo "ECS production must already have been destroyed"
echo "through the GitHub Actions destroy workflow."
echo

read -r -p "Type DESTROY to continue: " CONFIRMATION

if [[ "${CONFIRMATION}" != "DESTROY" ]]; then
  echo "Cleanup cancelled."
  exit 1
fi

echo
echo "Checking AWS identity..."
aws sts get-caller-identity

# ---------------------------------------------------------------------------
# Legacy infrastructure
# ---------------------------------------------------------------------------

echo
echo "=================================================="
echo " Destroying legacy EC2 infrastructure"
echo "=================================================="

cd "${ROOT_DIR}/legacy/terraform"

terraform init -input=false

terraform plan -destroy -input=false -out=destroy.tfplan

echo
read -r -p "Type LEGACY to destroy the legacy infrastructure: " LEGACY_CONFIRM

if [[ "${LEGACY_CONFIRM}" != "LEGACY" ]]; then
  echo "Legacy destruction cancelled."
  exit 1
fi

terraform apply -input=false destroy.tfplan

rm -f destroy.tfplan

echo
echo "Legacy infrastructure destroyed."

# ---------------------------------------------------------------------------
# Bootstrap infrastructure
# ---------------------------------------------------------------------------

echo
echo "=================================================="
echo " Destroying bootstrap infrastructure"
echo "=================================================="

cd "${ROOT_DIR}/ecs-platform/bootstrap"

terraform init -input=false

terraform plan -destroy -input=false -out=destroy.tfplan

echo
echo "Bootstrap includes:"
echo "  - GitHub Actions OIDC role/policies"
echo "  - ECR repository"
echo "  - Terraform state bucket"
echo "  - SSM backend parameter"
echo

read -r -p "Type BOOTSTRAP to destroy bootstrap: " BOOTSTRAP_CONFIRM

if [[ "${BOOTSTRAP_CONFIRM}" != "BOOTSTRAP" ]]; then
  echo "Bootstrap destruction cancelled."
  exit 1
fi

terraform apply -input=false destroy.tfplan

rm -f destroy.tfplan

echo
echo "Bootstrap destruction completed."

# ---------------------------------------------------------------------------
# AWS verification
# ---------------------------------------------------------------------------

echo
echo "=================================================="
echo " AWS resource verification"
echo "=================================================="
echo

echo "--- EC2 instances ---"
aws ec2 describe-instances \
  --region "${AWS_REGION}" \
  --filters "Name=tag:Project,Values=ec2-to-ecs-migration,legacy-api" \
  "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[].Instances[].{ID:InstanceId,State:State.Name,Name:Tags[?Key==`Name`]|[0].Value}' \
  --output table || true

echo
echo "--- ECS clusters ---"
aws ecs list-clusters \
  --region "${AWS_REGION}" \
  --query 'clusterArns[?contains(@, `ec2-to-ecs-migration`)]' \
  --output table || true

echo
echo "--- Application Load Balancers ---"
aws elbv2 describe-load-balancers \
  --region "${AWS_REGION}" \
  --query 'LoadBalancers[?contains(LoadBalancerName, `ec2-to-ecs-migration`)].{Name:LoadBalancerName,DNS:DNSName}' \
  --output table || true

echo
echo "--- NAT Gateways ---"
aws ec2 describe-nat-gateways \
  --region "${AWS_REGION}" \
  --filter "Name=state,Values=available,pending,deleting" \
  --query 'NatGateways[?Tags[?Key==`Project` && Value==`ec2-to-ecs-migration`]].{ID:NatGatewayId,State:State}' \
  --output table || true

echo
echo "--- VPCs ---"
aws ec2 describe-vpcs \
  --region "${AWS_REGION}" \
  --filters "Name=tag:Project,Values=ec2-to-ecs-migration,legacy-api" \
  --query 'Vpcs[].{ID:VpcId,CIDR:CidrBlock}' \
  --output table || true

echo
echo "--- ECR repositories ---"
aws ecr describe-repositories \
  --region "${AWS_REGION}" \
  --query 'repositories[?contains(repositoryName, `ec2-to-ecs-migration`)].repositoryName' \
  --output table 2>/dev/null || true

echo
echo "--- CloudWatch log groups ---"
aws logs describe-log-groups \
  --region "${AWS_REGION}" \
  --query 'logGroups[?contains(logGroupName, `ec2-to-ecs-migration`)].logGroupName' \
  --output table || true

echo
echo "--- CloudWatch alarms ---"
aws cloudwatch describe-alarms \
  --region "${AWS_REGION}" \
  --query 'MetricAlarms[?contains(AlarmName, `ec2-to-ecs-migration`)].AlarmName' \
  --output table || true

echo
echo "--- IAM roles ---"
aws iam list-roles \
  --query 'Roles[?contains(RoleName, `ec2-to-ecs-migration`) || contains(RoleName, `legacy-api`)].RoleName' \
  --output table || true

echo
echo "--- S3 buckets ---"
aws s3api list-buckets \
  --query 'Buckets[?contains(Name, `ec2-to-ecs-migration`) || contains(Name, `legacy-api`)].Name' \
  --output table || true

echo
echo "--- SSM parameters ---"
aws ssm describe-parameters \
  --region "${AWS_REGION}" \
  --query 'Parameters[?contains(Name, `ec2-to-ecs-migration`)].Name' \
  --output table || true

echo
echo "--- Route53 migration record ---"
HOSTED_ZONE_ID="Z0280982DGM72ZMRTH0P"

aws route53 list-resource-record-sets \
  --hosted-zone-id "${HOSTED_ZONE_ID}" \
  --query 'ResourceRecordSets[?Name==`migration.twrz.co.uk.`]' \
  --output table || true

echo
echo "=================================================="
echo " Verification complete"
echo "=================================================="
echo
echo "Any resources shown above should be reviewed."
echo "An empty result for the project resources means the"
echo "Terraform-managed migration infrastructure has been removed."
