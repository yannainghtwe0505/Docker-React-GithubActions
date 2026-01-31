#!/bin/sh
set -eu

# Fail fast if a required INPUT_* var is missing
require() {
  varname="$1"
  if [ -z "$(printenv "$varname" 2>/dev/null || true)" ]; then
    echo "Missing required input: $varname" >&2
    exit 1
  fi
}

require "INPUT_AWS_ACCESS_KEY"
require "INPUT_AWS_SECRET_KEY"
require "INPUT_REGION"
require "INPUT_DEPLOYMENT_PACKAGE"
require "INPUT_APPLICATION_NAME"
require "INPUT_ENVIRONMENT_NAME"
require "INPUT_EXISTING_BUCKET_NAME"
require "INPUT_VERSION_LABEL"

export AWS_ACCESS_KEY_ID="$INPUT_AWS_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$INPUT_AWS_SECRET_KEY"
export AWS_DEFAULT_REGION="$INPUT_REGION"

PACKAGE_PATH="/github/workspace/${INPUT_DEPLOYMENT_PACKAGE}"
if [ ! -f "$PACKAGE_PATH" ]; then
  echo "Deployment package not found: $PACKAGE_PATH" >&2
  exit 1
fi

S3_KEY="${INPUT_DEPLOYMENT_PACKAGE}-${INPUT_VERSION_LABEL}"

echo "Uploading $PACKAGE_PATH to s3://$INPUT_EXISTING_BUCKET_NAME/$S3_KEY"
aws s3 cp "$PACKAGE_PATH" "s3://$INPUT_EXISTING_BUCKET_NAME/$S3_KEY"

echo "Creating application version $INPUT_VERSION_LABEL for app $INPUT_APPLICATION_NAME"
# create-application-version may fail if version already exists; let it return non-zero without breaking the container
aws elasticbeanstalk create-application-version --application-name "$INPUT_APPLICATION_NAME" --version-label "$INPUT_VERSION_LABEL" --source-bundle S3Bucket="$INPUT_EXISTING_BUCKET_NAME",S3Key="$S3_KEY" || true

echo "Updating environment $INPUT_ENVIRONMENT_NAME to version $INPUT_VERSION_LABEL"
aws elasticbeanstalk update-environment --environment-name "$INPUT_ENVIRONMENT_NAME" --version-label "$INPUT_VERSION_LABEL"

echo "Deployment triggered successfully"
exit 0
