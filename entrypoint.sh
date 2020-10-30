#!/bin/sh

if [ "$INPUT_HOOK_BEGIN" ]; then
  sh $INPUT_HOOK_BEGIN
fi

HAS_CHANGED=true
IMAGE_POSTFIX=""

if [ "$INPUT_WORKING_DIRECTORY" != "." ]; then
    IMAGE_POSTFIX="/${INPUT_WORKING_DIRECTORY}"
fi

if [ "$INPUT_CHECK_IF_CHANGED" ]; then
    HAS_CHANGED=$(/gitdiff.sh ${INPUT_WORKING_DIRECTORY})
fi

if [ $HAS_CHANGED = false ]; then
    exit 0;
fi

set -e

if [ "$INPUT_HOOK_VARS_BEFORE" ]; then
  sh $INPUT_HOOK_VARS_BEFORE
fi

BRANCH=$(echo $GITHUB_REF | rev | cut -f 1 -d / | rev)
REPO=$(echo $GITHUB_REPOSITORY | tr '[:upper:]' '[:lower:]')
GCR_IMAGE_NAME=${INPUT_REGISTRY}/${INPUT_PROJECT}/${REPO}${IMAGE_POSTFIX}
SERVICE_NAME=$(echo "${INPUT_SERVICE_NAME}--${BRANCH}" | tr '[:upper:]' '[:lower:]' | sed 's/[_]/-/g')

if [ "$INPUT_HOOK_VARS_AFTER" ]; then
  sh $INPUT_HOOK_VARS_AFTER
fi

echo "\n\n-----------------------------------------------------------------------------\n\n"
echo "BRANCH = ${BRANCH}"
echo "GCR_IMAGE_NAME = ${GCR_IMAGE_NAME}"
echo "SERVICE_NAME = ${SERVICE_NAME}"
echo "\n\n-----------------------------------------------------------------------------\n\n"

echo "\nCreate GitHub Deployment for $BRANCH ($GITHUB_SHA) at https://github.com/$GITHUB_REPOSITORY ..."
curl \
  -v \
  -X POST \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/$GITHUB_REPOSITORY/deployments \
  -d "{\"ref\": \"$GITHUB_SHA\", \"required_contexts\": [], \"environment\": \"$BRANCH\", \"transient_environment\": true}"

# service key

echo "$INPUT_KEY" | base64 --decode > "$HOME"/gcloud.json

# Prepare env vars if `env` is set to file

if [ "$INPUT_ENV" ]; then
    ENVS=$(cat "$INPUT_ENV" | xargs | sed 's/ /,/g')
fi

if [ "$ENVS" ]; then
    ENV_FLAG="--set-env-vars $ENVS"
fi

# run

if [ "$INPUT_HOOK_SETUP_BEFORE" ]; then
  sh $INPUT_HOOK_SETUP_BEFORE
fi

echo "\nActivate service account..."
gcloud auth activate-service-account \
  --key-file="$HOME"/gcloud.json \
  --project "$INPUT_PROJECT"

echo "\nConfigure gcloud cli..."
gcloud config set disable_prompts true
gcloud config set project "${INPUT_PROJECT}"
gcloud config set run/region "${INPUT_REGION}"
gcloud config set run/platform managed

echo "\nConfigure docker..."
gcloud auth configure-docker --quiet

if [ "$INPUT_HOOK_SETUP_AFTER" ]; then
  sh $INPUT_HOOK_SETUP_AFTER
fi

cd ${GITHUB_WORKSPACE}/${INPUT_WORKING_DIRECTORY}

if [ "$INPUT_HOOK_BUILD_BEFORE" ]; then
  sh $INPUT_HOOK_BUILD_BEFORE
fi

echo "\nBuild image..."
docker build \
  -t ${GCR_IMAGE_NAME}:${GITHUB_SHA} \
  -t ${GCR_IMAGE_NAME}:${BRANCH} \
  --build-arg IMAGE_NAME=${GCR_IMAGE_NAME} \
  --build-arg BRANCH_NAME=${BRANCH} \
  .

if [ "$INPUT_HOOK_BUILD_AFTER" ]; then
  sh $INPUT_HOOK_BUILD_AFTER
fi

if [ "$INPUT_HOOK_PUSH_BEFORE" ]; then
  sh $INPUT_HOOK_PUSH_BEFORE
fi

echo "\nPush image..."
docker push "$GCR_IMAGE_NAME"

if [ "$INPUT_HOOK_PUSH_AFTER" ]; then
  sh $INPUT_HOOK_PUSH_AFTER
fi

if [ "$INPUT_HOOK_DEPLOY_BEFORE" ]; then
  sh $INPUT_HOOK_DEPLOY_BEFORE
fi

echo "\nDeploy to cloud run..."
gcloud beta run deploy ${SERVICE_NAME} \
  --image "$GCR_IMAGE_NAME:$GITHUB_SHA" \
  --region "$INPUT_REGION" \
  --platform managed \
  --allow-unauthenticated \
  ${ENV_FLAG}


if [ "$INPUT_HOOK_DEPLOY_AFTER" ]; then
  sh $INPUT_HOOK_DEPLOY_AFTER
fi

echo "\nGet deployment URL"
URL=$(gcloud run services describe ${SERVICE_NAME} | grep Traffic | sed 's/Traffic: //')
echo "##[set-output name=cloud_run_service_url;]$URL"

if [ "$INPUT_HOOK_END" ]; then
  sh $INPUT_HOOK_END
fi

echo "\n\n-----------------------------------------------------------------------------\n\n"
echo "Successfully deployed ${SERVICE_NAME} to ${URL}"
echo "\n\n-----------------------------------------------------------------------------\n\n"

