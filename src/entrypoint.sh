#!/bin/bash

if [ "$INPUT_HOOK_BEGIN" ]; then
  sh $INPUT_HOOK_BEGIN
fi

IMAGE_POSTFIX=""

if [ "$INPUT_WORKING_DIRECTORY" != "." ]; then
    IMAGE_POSTFIX="/${INPUT_WORKING_DIRECTORY}"
fi

set -e

if [ "$INPUT_HOOK_VARS_BEFORE" ]; then
  sh $INPUT_HOOK_VARS_BEFORE
fi

BRANCH=$(echo $GITHUB_REF | sed -E 's/^refs\/[^\/]+\/(.*)/\1/g')

if [ "$INPUT_ACTION" = "delete" ]; then
  BRANCH=$(cat "$GITHUB_EVENT_PATH" | grep "\"ref\": " | sed -E 's/^.*\"ref\": \"(.*)",$/\1/g')

    if [ -z "${BRANCH}" ]; then
      echo "Something ent wrong while trying to get the deleted branch/tag"
      exit 1
    fi
fi

BRANCH_SAFE=$(echo $BRANCH | tr '[:upper:]' '[:lower:]' | sed 's/[_\/#]/-/g')
REPO=$(echo $GITHUB_REPOSITORY | tr '[:upper:]' '[:lower:]')
GCR_IMAGE_NAME=${INPUT_REGION}-docker.pkg.dev/${INPUT_PROJECT}/${INPUT_REGISTRY}/${REPO}${IMAGE_POSTFIX}
SERVICE_NAME=$(echo "${INPUT_SERVICE_NAME}--${BRANCH_SAFE}")

if [ "$INPUT_HOOK_VARS_AFTER" ]; then
  sh $INPUT_HOOK_VARS_AFTER
fi

echo -e "\n\n-----------------------------------------------------------------------------\n\n"
echo "ACTION:         ${INPUT_ACTION}"
echo "BRANCH:         ${BRANCH}"
echo "GCR_IMAGE_NAME: ${GCR_IMAGE_NAME}"
echo "SERVICE_NAME:   ${SERVICE_NAME}"
echo -e "\n\n-----------------------------------------------------------------------------\n\n"

# service account key
echo "$INPUT_KEY" | base64 --decode > "$HOME"/gcloud.json

if [ "$INPUT_HOOK_SETUP_BEFORE" ]; then
  sh $INPUT_HOOK_SETUP_BEFORE
fi

echo -e "\nActivate service account..."
gcloud auth activate-service-account \
  --key-file="$HOME"/gcloud.json \
  --project "$INPUT_PROJECT"

echo -e "\nConfigure gcloud cli..."
gcloud config set disable_prompts true
gcloud config set project "${INPUT_PROJECT}"
gcloud config set run/region "${INPUT_REGION}"
gcloud config set run/platform "${INPUT_PLATFORM}"

if [ "$INPUT_ACTION" = "delete" ]; then
  echo -e "\nTrying to delete the service ${SERVICE_NAME}..."

  gcloud run services delete ${SERVICE_NAME} || :

  DEPLOY_ACTION="delete"
  . /github-deployment.sh

  echo -e "\n\n-----------------------------------------------------------------------------\n\n"
  echo "Successfully cleaned up service ${SERVICE_NAME} and deployments for environment ${BRANCH}"
  echo -e "\n\n-----------------------------------------------------------------------------\n\n"

  exit 0
fi

DEPLOY_ACTION="create"
. /github-deployment.sh

DEPLOY_ACTION="status_progress"
. /github-deployment.sh

echo -e "\nConfigure docker..."
gcloud auth configure-docker ${INPUT_REGION}-docker.pkg.dev --quiet

if [ "$INPUT_HOOK_SETUP_AFTER" ]; then
  sh $INPUT_HOOK_SETUP_AFTER
fi

cd ${GITHUB_WORKSPACE}/${INPUT_WORKING_DIRECTORY}

if [ "$INPUT_HOOK_BUILD_BEFORE" ]; then
  sh $INPUT_HOOK_BUILD_BEFORE
fi

echo -e "\nBuild image..."
docker build \
  -t ${GCR_IMAGE_NAME}:${GITHUB_SHA} \
  -t ${GCR_IMAGE_NAME}:${BRANCH_SAFE} \
  --build-arg IMAGE_NAME=${GCR_IMAGE_NAME} \
  --build-arg BRANCH_NAME=${BRANCH} \
  --build-arg REF_NAME=${GITHUB_REF_NAME} \
  --build-arg COMMIT_SHA=${GITHUB_SHA} \
  .

if [ "$INPUT_HOOK_BUILD_AFTER" ]; then
  sh $INPUT_HOOK_BUILD_AFTER
fi

if [ "$INPUT_HOOK_PUSH_BEFORE" ]; then
  sh $INPUT_HOOK_PUSH_BEFORE
fi

echo -e "\nPush image..."
docker push -a "$GCR_IMAGE_NAME"

if [ "$INPUT_HOOK_PUSH_AFTER" ]; then
  sh $INPUT_HOOK_PUSH_AFTER
fi

if [ "$INPUT_HOOK_DEPLOY_BEFORE" ]; then
  sh $INPUT_HOOK_DEPLOY_BEFORE
fi

echo -e "\nDeploy to cloud run..."
gcloud run deploy ${SERVICE_NAME} \
  --image "$GCR_IMAGE_NAME:$GITHUB_SHA" \
  ${INPUT_DEPLOY_FLAGS}


if [ "$INPUT_HOOK_DEPLOY_AFTER" ]; then
  sh $INPUT_HOOK_DEPLOY_AFTER
fi

echo -e "\nGet deployment URL"
DATA_JSON=$(gcloud run services describe ${SERVICE_NAME} --format=json)
URL=$(echo $DATA_JSON | jq --raw-output .status.url)
echo "::set-output name=cloud_run_service_data_json::$DATA_JSON"
echo "::set-output name=cloud_run_service_url::$URL"
echo "::set-output name=cloud_run_image::$GCR_IMAGE_NAME"
echo "::set-output name=cloud_run_image_sha::$GCR_IMAGE_NAME:$GITHUB_SHA"
echo "::set-output name=cloud_run_image_branch::$GCR_IMAGE_NAME:$BRANCH_SAFE"

if [ "$INPUT_HOOK_END" ]; then
  sh $INPUT_HOOK_END
fi

DEPLOY_ACTION="status_success"
. /github-deployment.sh

echo -e "\n\n-----------------------------------------------------------------------------\n\n"
echo "Successfully deployed ${SERVICE_NAME} to ${URL}"
echo -e "\n\n-----------------------------------------------------------------------------\n\n"
