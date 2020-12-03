#!/bin/bash
BRANCH="BRANCH"
GITHUB_SHA="GITHUB___SHA"
GITHUB_TOKEN="GITHUB___TOKEN"
GITHUB_REPOSITORY="GITHUB___REPOSITORY"

#GITHUB_API="https://api.github.com/repos/$GITHUB_REPOSITORY/deployments"
#CURL_HEADERS="-H \"Accept: application/vnd.github.v3+json\" -H \"Authorization: token $GITHUB_TOKEN\""
#START="curl -d '{\"ref\": \"${GITHUB_SHA}\", \"required_contexts\": [], \"environment\": \"${BRANCH}\", \"transient_environment\": true}' ${CURL_HEADERS} -X POST ${GITHUB_API}"
#FULL=$(eval $START)
#echo $START
#echo $FULL

DEPLOY_API="https://api.github.com/repos/$GITHUB_REPOSITORY/deployments"
DEPLOY_CURL_HEADERS="-H \"Accept: application/vnd.github.v3+json\" -H \"Authorization: token $GITHUB_TOKEN\""
DEPLOY_CURL="curl -d '{\"ref\": \"$GITHUB_SHA\", \"required_contexts\": [], \"environment\": \"$BRANCH\", \"transient_environment\": true}' ${CURL_HEADERS} -X POST ${DEPLOY_API}"
echo $DEPLOY_CURL
DEPLOY_CREATE_JSON=$(eval $DEPLOY_CURL)
echo $DEPLOY_CREATE_JSON
DEPLOY_ID=$(echo $DEPLOY_CREATE_JSON | grep "\/deployments\/" | grep "\"url\"" | sed -E 's/^.*\/deployments\/(.*)",$/\1/g')
echo $DEPLOY_ID
