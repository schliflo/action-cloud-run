#!/bin/bash

if [ "$GITHUB_TOKEN" ]; then
  DEPLOY_API="https://api.github.com/repos/$GITHUB_REPOSITORY/deployments"
  DEPLOY_CURL_HEADERS="-H \"Accept: application/vnd.github.v3+json\" -H \"Accept: application/vnd.github.flash-preview+json\" -H \"Accept: application/vnd.github.ant-man-preview+json\" -H \"Authorization: token $GITHUB_TOKEN\""

  case "$DEPLOY_ACTION" in
  create)
    echo -e "\nCreate GitHub Deployment for $BRANCH ($GITHUB_SHA) at https://github.com/$GITHUB_REPOSITORY ..."
    DEPLOY_CURL="curl -d '{\"ref\": \"$GITHUB_SHA\", \"required_contexts\": [], \"environment\": \"$BRANCH\", \"transient_environment\": true}' ${DEPLOY_CURL_HEADERS} -X POST ${DEPLOY_API}"
    ;;

  status_progress)
    echo -e "\nUpdating GitHub Deployment $DEPLOY_ID..."
    DEPLOY_CURL="curl -d '{\"state\": \"in_progress\", \"environment\": \"$BRANCH\"}' ${DEPLOY_CURL_HEADERS} -X POST ${DEPLOY_API}/$DEPLOY_ID/statuses"
    ;;

  status_success)
    echo -e "\nUpdating GitHub Deployment $DEPLOY_ID..."
    DEPLOY_CURL="curl -d '{\"state\": \"success\", \"environment\": \"$BRANCH\", \"environment_url\": \"$URL\"}' ${DEPLOY_CURL_HEADERS} -X POST ${DEPLOY_API}/$DEPLOY_ID/statuses"
    ;;

  delete)
    echo -e "\nDeleting GitHub Deployment $DEPLOY_ID..."
    DEPLOY_CURL="curl ${DEPLOY_CURL_HEADERS} -X DELETE ${DEPLOY_API}/$DEPLOY_ID"
    ;;

  *)
    echo $"Error: \$DEPLOY_ACTION has to be one of: {create|status_progress|status_success|delete}"
    exit 1
    ;;
  esac

  echo "$DEPLOY_CURL"
  DEPLOY_COMMAND_JSON=$(eval $DEPLOY_CURL)
  echo "$DEPLOY_COMMAND_JSON"

  if [ "$DEPLOY_ACTION" = "create" ]; then
    DEPLOY_ID=$(echo "$DEPLOY_COMMAND_JSON" | grep "\/deployments\/" | grep "\"url\"" | sed -E 's/^.*\/deployments\/(.*)",$/\1/g')

    if [ -z "${DEPLOY_ID}" ]; then
      echo "Something ent wrong while trying to get the deployment id"
      exit 1
    fi
  fi
fi
