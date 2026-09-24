#!/usr/bin/env bash

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

AWS_REGION="eu-west-2"

PROJECT_NAME="ec2-to-ecs-migration"
LEGACY_PROJECT_NAME="legacy-api"

ECS_CLUSTER_NAME="${PROJECT_NAME}-prod-cluster"

ECR_REPOSITORY="${PROJECT_NAME}-prod-app"
SSM_STATE_PARAMETER="/${PROJECT_NAME}/bootstrap/state-bucket"

CONTAINER_INSIGHTS_LOG_GROUP="/aws/ecs/containerinsights/${ECS_CLUSTER_NAME}/performance"

HOSTED_ZONE_ID="Z0280982DGM72ZMRTH0P"
MIGRATION_RECORD="migration.twrz.co.uk."

# Temporary files used during cleanup.
ECR_IMAGE_FILE="/tmp/ec2-to-ecs-ecr-images.json"
S3_VERSION_FILE="/tmp/ec2-to-ecs-s3-versions.json"
S3_MARKER_FILE="/tmp/ec2-to-ecs-s3-delete-markers.json"

# ---------------------------------------------------------------------------
# Cleanup temporary files on exit
# ---------------------------------------------------------------------------

cleanup_temp_files() {
  rm -f \
    "${ECR_IMAGE_FILE}" \
    "${S3_VERSION_FILE}" \
    "${S3_MARKER_FILE}"
}

trap cleanup_temp_files EXIT

# ---------------------------------------------------------------------------
# Header
# ---------------------------------------------------------------------------

echo
echo "=================================================="
echo " EC2 to ECS Migration - Final Infrastructure Cleanup"
echo "=================================================="
echo

echo "This script will:"
echo "  1. Confirm ECS production has already been destroyed"
echo "  2. Destroy legacy EC2 infrastructure if it still exists"
echo "  3. Empty the bootstrap ECR repository if it still exists"
echo "  4. Empty the versioned Terraform state bucket if it still exists"
echo "  5. Destroy bootstrap infrastructure if it still exists"
echo "  6. Remove remaining Container Insights logs"
echo "  7. Verify remaining AWS resources"
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
    echo "ERROR: Required command not found: ${COMMAND}"
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
  echo "ERROR: ECS infrastructure still exists:"
  echo "${ECS_CLUSTERS}"
  echo
  echo "Run the Destroy ECS Production GitHub Actions workflow first."
  echo "This script will not destroy legacy or bootstrap resources"
  echo "while ECS production still exists."
  exit 1
fi

echo "No project ECS clusters found."
echo "Safe to continue with final cleanup."

# ---------------------------------------------------------------------------
# Legacy infrastructure
# ---------------------------------------------------------------------------

echo
echo "=================================================="
echo " Legacy EC2 infrastructure"
echo "=================================================="
echo

cd "${ROOT_DIR}/legacy/terraform"

terraform init -input=false

LEGACY_STATE=$(terraform state list || true)

if [[ -z "${LEGACY_STATE}" ]]; then
  echo "Legacy Terraform state is empty."
  echo "Legacy infrastructure is already destroyed."
else
  echo "Legacy Terraform resources found:"
  echo
  echo "${LEGACY_STATE}"
  echo

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
fi

# ---------------------------------------------------------------------------
# Discover bootstrap resources
# ---------------------------------------------------------------------------

echo
echo "=================================================="
echo " Discovering bootstrap resources"
echo "=================================================="
echo

STATE_BUCKET=""

if STATE_BUCKET=$(aws ssm get-parameter \
  --name "${SSM_STATE_PARAMETER}" \
  --region "${AWS_REGION}" \
  --query 'Parameter.Value' \
  --output text 2>/dev/null); then

  echo "Terraform state bucket: ${STATE_BUCKET}"
else
  STATE_BUCKET=""

  echo "Bootstrap SSM state parameter does not exist."
  echo "Bootstrap infrastructure may already be destroyed."
fi

echo "ECR repository: ${ECR_REPOSITORY}"

# ---------------------------------------------------------------------------
# Empty ECR repository
# ---------------------------------------------------------------------------

echo
echo "=================================================="
echo " ECR repository cleanup"
echo "=================================================="
echo

if aws ecr describe-repositories \
  --repository-names "${ECR_REPOSITORY}" \
  --region "${AWS_REGION}" \
  >/dev/null 2>&1; then

  echo "ECR repository exists."

  while true; do
    IMAGE_IDS=$(aws ecr list-images \
      --repository-name "${ECR_REPOSITORY}" \
      --region "${AWS_REGION}" \
      --max-items 100 \
      --query 'imageIds' \
      --output json)

    if [[ "${IMAGE_IDS}" == "[]" || "${IMAGE_IDS}" == "null" ]]; then
      break
    fi

    printf '%s\n' "${IMAGE_IDS}" > "${ECR_IMAGE_FILE}"

    aws ecr batch-delete-image \
      --repository-name "${ECR_REPOSITORY}" \
      --region "${AWS_REGION}" \
      --image-ids "file://${ECR_IMAGE_FILE}" \
      >/dev/null

    echo "Deleted ECR image batch."
  done

  echo "ECR repository is empty."

else
  echo "ECR repository does not exist."
  echo "Skipping ECR cleanup."
fi

# ---------------------------------------------------------------------------
# Empty versioned Terraform state bucket
# ---------------------------------------------------------------------------

echo
echo "=================================================="
echo " Terraform state bucket cleanup"
echo "=================================================="
echo

if [[ -z "${STATE_BUCKET}" ]]; then

  echo "No Terraform state bucket was discovered from SSM."
  echo "Skipping S3 state cleanup."

elif ! aws s3api head-bucket \
  --bucket "${STATE_BUCKET}" \
  >/dev/null 2>&1; then

  echo "Terraform state bucket does not exist."
  echo "Skipping S3 state cleanup."

else

  echo "State bucket exists: ${STATE_BUCKET}"

  # -------------------------------------------------------------------------
  # Delete object versions
  # -------------------------------------------------------------------------

  echo
  echo "Deleting S3 object versions..."

  while true; do

    VERSIONS=$(aws s3api list-object-versions \
      --bucket "${STATE_BUCKET}" \
      --max-items 1000 \
      --query 'Versions[].{Key:Key,VersionId:VersionId}' \
      --output json)

    if [[ "${VERSIONS}" == "[]" || "${VERSIONS}" == "null" ]]; then
      break
    fi

    printf '{"Objects":%s,"Quiet":true}\n' "${VERSIONS}" \
      > "${S3_VERSION_FILE}"

    aws s3api delete-objects \
      --bucket "${STATE_BUCKET}" \
      --delete "file://${S3_VERSION_FILE}" \
      >/dev/null

    echo "Deleted S3 object version batch."

  done

  echo "No S3 object versions remain."

  # -------------------------------------------------------------------------
  # Delete delete markers
  # -------------------------------------------------------------------------

  echo
  echo "Deleting S3 delete markers..."

  while true; do

    DELETE_MARKERS=$(aws s3api list-object-versions \
      --bucket "${STATE_BUCKET}" \
      --max-items 1000 \
      --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' \
      --output json)

    if [[ "${DELETE_MARKERS}" == "[]" || "${DELETE_MARKERS}" == "null" ]]; then
      break
    fi

    printf '{"Objects":%s,"Quiet":true}\n' "${DELETE_MARKERS}" \
      > "${S3_MARKER_FILE}"

    aws s3api delete-objects \
      --bucket "${STATE_BUCKET}" \
      --delete "file://${S3_MARKER_FILE}" \
      >/dev/null

    echo "Deleted S3 delete marker batch."

  done

  echo "No S3 delete markers remain."

  # -------------------------------------------------------------------------
  # Verify bucket is empty
  # -------------------------------------------------------------------------

  echo
  echo "Verifying Terraform state bucket..."

  REMAINING_VERSIONS=$(aws s3api list-object-versions \
    --bucket "${STATE_BUCKET}" \
    --query 'length(Versions || `[]`)' \
    --output text)

  REMAINING_MARKERS=$(aws s3api list-object-versions \
    --bucket "${STATE_BUCKET}" \
    --query 'length(DeleteMarkers || `[]`)' \
    --output text)

  if [[ "${REMAINING_VERSIONS}" != "0" || "${REMAINING_MARKERS}" != "0" ]]; then
    echo
    echo "ERROR: Terraform state bucket is not empty."
    echo "Remaining versions: ${REMAINING_VERSIONS}"
    echo "Remaining delete markers: ${REMAINING_MARKERS}"
    echo
    echo "Bootstrap destruction will not continue."
    exit 1
  fi

  echo "Terraform state bucket is empty."
fi

# ---------------------------------------------------------------------------
# Bootstrap infrastructure
# ---------------------------------------------------------------------------

echo
echo "=================================================="
echo " Bootstrap infrastructure"
echo "=================================================="
echo

cd "${ROOT_DIR}/ecs-platform/bootstrap"

terraform init -input=false

BOOTSTRAP_STATE=$(terraform state list || true)

if [[ -z "${BOOTSTRAP_STATE}" ]]; then

  echo "Bootstrap Terraform state is empty."
  echo "Bootstrap infrastructure is already destroyed."

else

  echo "Bootstrap Terraform resources found:"
  echo
  echo "${BOOTSTRAP_STATE}"
  echo

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
fi

# ---------------------------------------------------------------------------
# Container Insights cleanup
# ---------------------------------------------------------------------------

echo
echo "=================================================="
echo " Container Insights cleanup"
echo "=================================================="
echo

CONTAINER_INSIGHTS_EXISTS=$(aws logs describe-log-groups \
  --region "${AWS_REGION}" \
  --log-group-name-prefix "${CONTAINER_INSIGHTS_LOG_GROUP}" \
  --query "logGroups[?logGroupName==\`${CONTAINER_INSIGHTS_LOG_GROUP}\`].logGroupName" \
  --output text)

if [[ -n "${CONTAINER_INSIGHTS_EXISTS}" ]]; then

  echo "Found Container Insights log group:"
  echo "${CONTAINER_INSIGHTS_LOG_GROUP}"
  echo
  echo "Deleting Container Insights log group..."

  aws logs delete-log-group \
    --log-group-name "${CONTAINER_INSIGHTS_LOG_GROUP}" \
    --region "${AWS_REGION}"

  echo "Container Insights log group deleted."

else
  echo "Container Insights log group does not exist."
  echo "Skipping Container Insights cleanup."
fi

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
echo "--- ECS services ---"

for CLUSTER in $(aws ecs list-clusters \
  --region "${AWS_REGION}" \
  --query 'clusterArns[]' \
  --output text 2>/dev/null); do

  aws ecs list-services \
    --cluster "${CLUSTER}" \
    --region "${AWS_REGION}" \
    --query "serviceArns[?contains(@, \`${PROJECT_NAME}\`)]" \
    --output table || true
done

echo
echo "--- Application Load Balancers ---"

aws elbv2 describe-load-balancers \
  --region "${AWS_REGION}" \
  --query "LoadBalancers[?contains(LoadBalancerName, \`${PROJECT_NAME}\`)].{Name:LoadBalancerName,DNS:DNSName}" \
  --output table || true

echo
echo "--- Target Groups ---"

aws elbv2 describe-target-groups \
  --region "${AWS_REGION}" \
  --query "TargetGroups[?contains(TargetGroupName, \`${PROJECT_NAME}\`)].TargetGroupName" \
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
  --filters \
    "Name=tag:Project,Values=${PROJECT_NAME},${LEGACY_PROJECT_NAME}" \
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
echo "--- IAM policies ---"

aws iam list-policies \
  --scope Local \
  --query "Policies[?contains(PolicyName, \`${PROJECT_NAME}\`) || contains(PolicyName, \`${LEGACY_PROJECT_NAME}\`)].PolicyName" \
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
  --query "ResourceRecordSets[?Name==\`${MIGRATION_RECORD}\`]" \
  --output table || true

# ---------------------------------------------------------------------------
# Complete
# ---------------------------------------------------------------------------

echo
echo "=================================================="
echo " Verification complete"
echo "=================================================="
echo
echo "Any project resources shown above should be reviewed."
echo
echo "If the project-specific results are empty, the"
echo "Terraform-managed migration infrastructure and"
echo "known AWS-created supporting resources have been removed."
echo
echo "Cleanup script completed successfully."