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

BRANCH=$(echo $GITHUB_REF | rev | cut -f 1 -d / | rev)
REPO=$(echo $GITHUB_REPOSITORY | tr '[:upper:]' '[:lower:]')
GCR_IMAGE_NAME=${INPUT_REGISTRY}/${INPUT_PROJECT}/${REPO}${IMAGE_POSTFIX}
SERVICE_NAME=$(echo "${INPUT_SERVICE_NAME}--${BRANCH}" | tr '[:upper:]' '[:lower:]' | sed 's/[_]/-/g')

if [ "$INPUT_HOOK_VARS_AFTER" ]; then
  sh $INPUT_HOOK_VARS_AFTER
fi

echo -e "\n\n-----------------------------------------------------------------------------\n\n"
echo "BRANCH = ${BRANCH}"
echo "GCR_IMAGE_NAME = ${GCR_IMAGE_NAME}"
echo "SERVICE_NAME = ${SERVICE_NAME}"
echo -e "\n\n-----------------------------------------------------------------------------\n\n"

if [ "$GITHUB_TOKEN" ]; then
  echo -e "\nCreate GitHub Deployment for $BRANCH ($GITHUB_SHA) at https://github.com/$GITHUB_REPOSITORY ..."
  DEPLOY_API="https://api.github.com/repos/$GITHUB_REPOSITORY/deployments"
  DEPLOY_CURL_HEADERS="-H \"Accept: application/vnd.github.v3+json\" -H \"Accept: application/vnd.github.ant-man-preview+json\" -H \"Authorization: token $GITHUB_TOKEN\""
  DEPLOY_CURL="curl -d '{\"ref\": \"$GITHUB_SHA\", \"required_contexts\": [], \"environment\": \"$BRANCH\", \"transient_environment\": true}' ${DEPLOY_CURL_HEADERS} -X POST ${DEPLOY_API}"
  echo "$DEPLOY_CURL"
  DEPLOY_CREATE_JSON=$(eval $DEPLOY_CURL)
  echo "$DEPLOY_CREATE_JSON"
  DEPLOY_ID=$(echo "$DEPLOY_CREATE_JSON" | grep "\/deployments\/" | grep "\"url\"" | sed -E 's/^.*\/deployments\/(.*)",$/\1/g')

  if [ -z "${DEPLOY_ID}" ]; then
      echo "Something ent wrong while trying to get the deployment id" ;
      exit 1;
  fi

  echo -e "\nUpdating GitHub Deployment $DEPLOY_ID..."
  DEPLOY_CURL="curl -d '{\"state\": \"in_progress\", \"environment\": \"$BRANCH\"}' ${DEPLOY_CURL_HEADERS} -X POST ${DEPLOY_API}/$DEPLOY_ID/statuses"
  echo "$DEPLOY_CURL"
  DEPLOY_UPDATE_JSON=$(eval $DEPLOY_CURL)
  echo "$DEPLOY_UPDATE_JSON"
fi

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

echo -e "\nConfigure docker..."
gcloud auth configure-docker --quiet

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

echo -e "\nPush image..."
docker push "$GCR_IMAGE_NAME"

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
URL=$(gcloud run services describe ${SERVICE_NAME} | grep Traffic | sed 's/Traffic: //')
echo "##[set-output name=cloud_run_service_url;]$URL"

if [ "$INPUT_HOOK_END" ]; then
  sh $INPUT_HOOK_END
fi

if [ "$GITHUB_TOKEN" ]; then
  echo -e "\nUpdating GitHub Deployment $DEPLOY_ID..."
  DEPLOY_CURL="curl -d '{\"state\": \"success\", \"environment\": \"$BRANCH\", \"environment_url\": \"$URL\"}' ${DEPLOY_CURL_HEADERS} -X POST ${DEPLOY_API}/$DEPLOY_ID/statuses"
  echo "$DEPLOY_CURL"
  DEPLOY_UPDATE_JSON=$(eval $DEPLOY_CURL)
  echo "$DEPLOY_UPDATE_JSON"
fi

echo -e "\n\n-----------------------------------------------------------------------------\n\n"
echo "Successfully deployed ${SERVICE_NAME} to ${URL}"
echo -e "\n\n-----------------------------------------------------------------------------\n\n"

