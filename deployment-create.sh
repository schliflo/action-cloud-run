#!/bin/bash

curl \
  -v \
  -X POST \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/$REPO/deployments \
  -d "{'ref': '$BRANCH'}"
