#!/bin/bash

set +e

if [ "$GITHUB_TOKEN" ]; then
  DEPLOY_API="$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/deployments"
  CURL_HEADERS="-H \"Accept: application/vnd.github.v3+json\" -H \"Authorization: token $GITHUB_TOKEN\""

  case "$DEPLOY_ACTION" in
  create)
    echo -e "\nCreate GitHub Deployment for $BRANCH ($GITHUB_SHA) at https://github.com/$GITHUB_REPOSITORY ..."
    CURL_COMMAND="curl -d '{\"ref\": \"$GITHUB_SHA\", \"required_contexts\": [], \"environment\": \"$BRANCH\", \"auto_merge\": false, \"transient_environment\": true}' ${CURL_HEADERS} -X POST ${DEPLOY_API}"
    ;;

  status_progress)
    echo -e "\nUpdating GitHub Deployment $DEPLOY_ID..."
    CURL_COMMAND="curl -d '{\"state\": \"in_progress\", \"environment\": \"$BRANCH\"}' ${CURL_HEADERS} -X POST ${DEPLOY_API}/$DEPLOY_ID/statuses"
    ;;

  status_success)
    echo -e "\nUpdating GitHub Deployment $DEPLOY_ID..."
    CURL_COMMAND="curl -d '{\"state\": \"success\", \"environment\": \"$BRANCH\", \"environment_url\": \"$URL\"}' ${CURL_HEADERS} -X POST ${DEPLOY_API}/$DEPLOY_ID/statuses"
    ;;

  delete)
    echo -e "\nDeleting GitHub Deployments for environment  $BRANCH..."

    CURL_COMMAND="curl ${CURL_HEADERS} $DEPLOY_API\?environment\=$BRANCH"
    . /curl-helper.sh

    for id in $(echo $CURL_COMMAND_JSON | jq ".[].id"); do
      echo -e "\nSetting GitHub Deployment $id to inactive..."
      CURL_COMMAND="curl -d '{\"state\": \"inactive\", \"environment\": \"$BRANCH\"}' ${CURL_HEADERS} -X POST ${DEPLOY_API}/$id/statuses"
      . /curl-helper.sh

      echo -e "\nDeleting GitHub Deployment $id..."
      CURL_COMMAND="curl ${CURL_HEADERS} -X DELETE ${DEPLOY_API}/$id"
      . /curl-helper.sh
    done
    ;;

  *)
    echo $"Error: \$DEPLOY_ACTION has to be one of: {create|status_progress|status_success|delete}"
    exit 1
    ;;
  esac

  if [ "$DEPLOY_ACTION" != "delete" ]; then
      . /curl-helper.sh
  fi

  if [ "$DEPLOY_ACTION" = "create" ]; then
    DEPLOY_ID=$(echo "$CURL_COMMAND_JSON" | grep "\/deployments\/" | grep "\"url\"" | sed -E 's/^.*\/deployments\/(.*)",$/\1/g')

    if [ -z "${DEPLOY_ID}" ]; then
      echo "Something ent wrong while trying to get the deployment id"
      exit 1
    fi
  fi
fi

set -e
