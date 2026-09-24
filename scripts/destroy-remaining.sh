#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AWS_REGION="eu-west-2"

PROJECT_NAME="ec2-to-ecs-migration"
LEGACY_PROJECT_NAME="legacy-api"

ECR_REPOSITORY="${PROJECT_NAME}-prod-app"
SSM_STATE_PARAMETER="/${PROJECT_NAME}/bootstrap/state-bucket"
HOSTED_ZONE_ID="Z0280982DGM72ZMRTH0P"

echo
echo "=================================================="
echo " EC2 to ECS Migration - Final Infrastructure Cleanup"
echo "=================================================="
echo

echo "This script will:"
echo "  1. Confirm ECS production has already been destroyed"
echo "  2. Destroy the legacy EC2 infrastructure"
echo "  3. Empty the bootstrap ECR repository"
echo "  4. Empty all versions from the Terraform state bucket"
echo "  5. Destroy the bootstrap infrastructure"
echo "  6. Verify remaining AWS resources"
echo
echo "ECS production must already have been destroyed"
echo "through the GitHub Actions destroy workflow."
echo

read -r -p "Type DESTROY to continue: " CONFIRMATION

if [[ "${CONFIRMATION}" != "DESTROY" ]]; then
  echo "Cleanup cancelled."
  exit 1
fi

# ---------------------------------------------------------------------------
# Prerequisite checks
# ---------------------------------------------------------------------------

echo
echo "=================================================="
echo " Prerequisite checks"
echo "=================================================="
echo

echo "Checking required commands..."

for COMMAND in aws terraform; do
  if ! command -v "${COMMAND}" >/dev/null 2>&1; then
    echo "Required command not found: ${COMMAND}"
    exit 1
  fi
done

echo "Required commands available."

echo
echo "Checking AWS identity..."

aws sts get-caller-identity

echo
echo "Checking that ECS production has already been destroyed..."

ECS_CLUSTERS=$(aws ecs list-clusters \
  --region "${AWS_REGION}" \
  --query "clusterArns[?contains(@, \`${PROJECT_NAME}\`)]" \
  --output text)

if [[ -n "${ECS_CLUSTERS}" ]]; then
  echo
  echo "ECS infrastructure still exists:"
  echo "${ECS_CLUSTERS}"
  echo
  echo "Run the Destroy ECS Production GitHub Actions workflow first."
  exit 1
fi

echo "No project ECS clusters found."
echo "Safe to continue with final cleanup."

# ---------------------------------------------------------------------------
# Legacy infrastructure
# ---------------------------------------------------------------------------

echo
echo "=================================================="
echo " Destroying legacy EC2 infrastructure"
echo "=================================================="
echo

cd "${ROOT_DIR}/legacy/terraform"

terraform init -input=false

terraform plan \
  -destroy \
  -input=false \
  -out=destroy.tfplan

echo
read -r -p "Type LEGACY to destroy the legacy infrastructure: " LEGACY_CONFIRM

if [[ "${LEGACY_CONFIRM}" != "LEGACY" ]]; then
  echo "Legacy destruction cancelled."
  rm -f destroy.tfplan
  exit 1
fi

terraform apply \
  -input=false \
  destroy.tfplan

rm -f destroy.tfplan

echo
echo "Legacy infrastructure destroyed."

# ---------------------------------------------------------------------------
# Discover bootstrap state bucket
# ---------------------------------------------------------------------------

echo
echo "=================================================="
echo " Discovering bootstrap resources"
echo "=================================================="
echo

STATE_BUCKET=$(aws ssm get-parameter \
  --name "${SSM_STATE_PARAMETER}" \
  --region "${AWS_REGION}" \
  --query 'Parameter.Value' \
  --output text)

echo "Terraform state bucket: ${STATE_BUCKET}"
echo "ECR repository: ${ECR_REPOSITORY}"

# ---------------------------------------------------------------------------
# Empty ECR repository
# ---------------------------------------------------------------------------

echo
echo "=================================================="
echo " Emptying ECR repository"
echo "=================================================="
echo

if aws ecr describe-repositories \
  --repository-names "${ECR_REPOSITORY}" \
  --region "${AWS_REGION}" \
  >/dev/null 2>&1; then

  IMAGE_IDS=$(aws ecr list-images \
    --repository-name "${ECR_REPOSITORY}" \
    --region "${AWS_REGION}" \
    --query 'imageIds' \
    --output json)

  if [[ "${IMAGE_IDS}" != "[]" && "${IMAGE_IDS}" != "null" ]]; then
    printf '%s\n' "${IMAGE_IDS}" > /tmp/ecr-images.json

    aws ecr batch-delete-image \
      --repository-name "${ECR_REPOSITORY}" \
      --region "${AWS_REGION}" \
      --image-ids file:///tmp/ecr-images.json

    rm -f /tmp/ecr-images.json

    echo
    echo "ECR images deleted."
  else
    echo "ECR repository is already empty."
  fi

else
  echo "ECR repository does not exist."
fi

# ---------------------------------------------------------------------------
# Empty versioned Terraform state bucket
# ---------------------------------------------------------------------------

echo
echo "=================================================="
echo " Emptying Terraform state bucket"
echo "=================================================="
echo

if aws s3api head-bucket \
  --bucket "${STATE_BUCKET}" \
  >/dev/null 2>&1; then

  echo "Deleting all S3 object versions..."

  VERSIONS=$(aws s3api list-object-versions \
    --bucket "${STATE_BUCKET}" \
    --query 'Versions[].{Key:Key,VersionId:VersionId}' \
    --output json)

  if [[ "${VERSIONS}" != "[]" && "${VERSIONS}" != "null" ]]; then
    printf '{"Objects":%s,"Quiet":true}\n' "${VERSIONS}" \
      > /tmp/s3-versions.json

    aws s3api delete-objects \
      --bucket "${STATE_BUCKET}" \
      --delete file:///tmp/s3-versions.json

    rm -f /tmp/s3-versions.json
  else
    echo "No S3 object versions found."
  fi

  echo
  echo "Deleting all S3 delete markers..."

  DELETE_MARKERS=$(aws s3api list-object-versions \
    --bucket "${STATE_BUCKET}" \
    --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' \
    --output json)

  if [[ "${DELETE_MARKERS}" != "[]" && "${DELETE_MARKERS}" != "null" ]]; then
    printf '{"Objects":%s,"Quiet":true}\n' "${DELETE_MARKERS}" \
      > /tmp/s3-delete-markers.json

    aws s3api delete-objects \
      --bucket "${STATE_BUCKET}" \
      --delete file:///tmp/s3-delete-markers.json

    rm -f /tmp/s3-delete-markers.json
  else
    echo "No S3 delete markers found."
  fi

  echo
  echo "Verifying state bucket is empty..."

  REMAINING_OBJECTS=$(aws s3api list-object-versions \
    --bucket "${STATE_BUCKET}" \
    --query 'length(Versions || `[]`) + length(DeleteMarkers || `[]`)' \
    --output text)

  if [[ "${REMAINING_OBJECTS}" != "0" ]]; then
    echo "State bucket still contains ${REMAINING_OBJECTS} versioned objects."
    echo "Bootstrap destruction will not continue."
    exit 1
  fi

  echo "Terraform state bucket is empty."

else
  echo "Terraform state bucket does not exist."
fi

# ---------------------------------------------------------------------------
# Bootstrap infrastructure
# ---------------------------------------------------------------------------

echo
echo "=================================================="
echo " Destroying bootstrap infrastructure"
echo "=================================================="
echo

cd "${ROOT_DIR}/ecs-platform/bootstrap"

terraform init -input=false

terraform plan \
  -destroy \
  -input=false \
  -out=destroy.tfplan

echo
echo "Bootstrap includes:"
echo "  - GitHub Actions OIDC role and policies"
echo "  - ECR repository"
echo "  - Terraform state bucket"
echo "  - SSM backend parameter"
echo

read -r -p "Type BOOTSTRAP to destroy bootstrap: " BOOTSTRAP_CONFIRM

if [[ "${BOOTSTRAP_CONFIRM}" != "BOOTSTRAP" ]]; then
  echo "Bootstrap destruction cancelled."
  rm -f destroy.tfplan
  exit 1
fi

terraform apply \
  -input=false \
  destroy.tfplan

rm -f destroy.tfplan

echo
echo "Bootstrap infrastructure destroyed."

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
  --filters \
    "Name=tag:Project,Values=${PROJECT_NAME},${LEGACY_PROJECT_NAME}" \
    "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[].Instances[].{ID:InstanceId,State:State.Name,Name:Tags[?Key==`Name`]|[0].Value}' \
  --output table || true

echo
echo "--- ECS clusters ---"

aws ecs list-clusters \
  --region "${AWS_REGION}" \
  --query "clusterArns[?contains(@, \`${PROJECT_NAME}\`)]" \
  --output table || true

echo
echo "--- Application Load Balancers ---"

aws elbv2 describe-load-balancers \
  --region "${AWS_REGION}" \
  --query "LoadBalancers[?contains(LoadBalancerName, \`${PROJECT_NAME}\`)].{Name:LoadBalancerName,DNS:DNSName}" \
  --output table || true

echo
echo "--- NAT Gateways ---"

aws ec2 describe-nat-gateways \
  --region "${AWS_REGION}" \
  --filter "Name=state,Values=available,pending,deleting" \
  --query "NatGateways[?Tags[?Key==\`Project\` && Value==\`${PROJECT_NAME}\`]].{ID:NatGatewayId,State:State}" \
  --output table || true

echo
echo "--- VPCs ---"

aws ec2 describe-vpcs \
  --region "${AWS_REGION}" \
  --filters "Name=tag:Project,Values=${PROJECT_NAME},${LEGACY_PROJECT_NAME}" \
  --query 'Vpcs[].{ID:VpcId,CIDR:CidrBlock}' \
  --output table || true

echo
echo "--- Elastic IPs ---"

aws ec2 describe-addresses \
  --region "${AWS_REGION}" \
  --query "Addresses[?Tags[?Key==\`Project\` && (Value==\`${PROJECT_NAME}\` || Value==\`${LEGACY_PROJECT_NAME}\`)]].{IP:PublicIp,AllocationId:AllocationId}" \
  --output table || true

echo
echo "--- ECR repositories ---"

aws ecr describe-repositories \
  --region "${AWS_REGION}" \
  --query "repositories[?contains(repositoryName, \`${PROJECT_NAME}\`)].repositoryName" \
  --output table 2>/dev/null || true

echo
echo "--- CloudWatch log groups ---"

aws logs describe-log-groups \
  --region "${AWS_REGION}" \
  --query "logGroups[?contains(logGroupName, \`${PROJECT_NAME}\`)].logGroupName" \
  --output table || true

echo
echo "--- CloudWatch alarms ---"

aws cloudwatch describe-alarms \
  --region "${AWS_REGION}" \
  --query "MetricAlarms[?contains(AlarmName, \`${PROJECT_NAME}\`)].AlarmName" \
  --output table || true

echo
echo "--- IAM roles ---"

aws iam list-roles \
  --query "Roles[?contains(RoleName, \`${PROJECT_NAME}\`) || contains(RoleName, \`${LEGACY_PROJECT_NAME}\`)].RoleName" \
  --output table || true

echo
echo "--- S3 buckets ---"

aws s3api list-buckets \
  --query "Buckets[?contains(Name, \`${PROJECT_NAME}\`) || contains(Name, \`${LEGACY_PROJECT_NAME}\`)].Name" \
  --output table || true

echo
echo "--- SSM parameters ---"

aws ssm describe-parameters \
  --region "${AWS_REGION}" \
  --query "Parameters[?contains(Name, \`${PROJECT_NAME}\`)].Name" \
  --output table || true

echo
echo "--- Route53 migration record ---"

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
echo "Empty results indicate that the Terraform-managed"
echo "migration infrastructure has been removed."