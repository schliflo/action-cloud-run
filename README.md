# Github Action for Google Cloud Run branch deployments

Authenticate with gcloud, build and push image to GCR and deploy as a new revision or branch preview to Cloud Run.

## Features

- Sets `cloud_run_service_url` with the URL of your service as output.
- Optionally uses GitHub Deployments and environments to show active Instances:

  **Pull Requests**

  ![Pull Requests](https://github.com/schliflo/action-cloud-run/blob/master/img/pr.png?raw=true)

  **Environments**
  
  ![Environments](https://github.com/schliflo/action-cloud-run/blob/master/img/env_all.png?raw=true)
  
  ![Environments](https://github.com/schliflo/action-cloud-run/blob/master/img/env.png?raw=true)

## Usage

In your actions workflow, somewhere after the checkout step insert this:

```yaml
- name: "Cloud Run: Deploy Service"
  uses: schliflo/action-cloud-run@3.0.0
  env:
    # if set github deployments will be used
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  with:
    # required
    project: your-project-id
    service_name: your-service-name
    key: ${{ secrets.GCP_CLOUD_RUN_SERVICE_KEY }}
    # optional settings
    action: 'deploy'
    registry: docker
    region: europe-west1
    platform: managed
    working_directory: .
    deploy_flags: '--allow-unauthenticated --port=80'
    # hooks (all optional)
    hook_begin: your/script.sh
    hook_vars_before: your/script.sh
    hook_vars_after: your/script.sh
    hook_setup_before: your/script.sh
    hook_setup_after: your/script.sh
    hook_build_before: your/script.sh
    hook_build_after: your/script.sh
    hook_push_before: your/script.sh
    hook_push_after: your/script.sh
    hook_deploy_before: your/script.sh
    hook_deploy_after: your/script.sh
    hook_end: your/script.sh
```

Your `GCP_CLOUD_RUN_SERVICE_KEY` secret (or whatever you name it) must be a base64 encoded
gcloud service key with the following permissions:

- Service Account User
- Cloud Run Admin
- Storage Admin


You can also delete the service after branch deletion:

```yaml
- name: "Cloud Run: Delete Service"
  uses: schliflo/action-cloud-run@3.0.0
  env: 
    # if set github deployments will be used
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  with:
    # required
    project: your-project-id
    service_name: your-service-name
    key: ${{ secrets.GCP_CLOUD_RUN_SERVICE_KEY }}
    # optional settings
    action: 'delete'
    # all the other from above settings still apply
    # ...
```

### Full example

`deploy-cloud-run.yml`
```yaml
name: "Cloud Run: Deploy Service"

on:
  workflow_dispatch:
  push:

jobs:
  deploy:
    name: Deploy
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      - name: "Cloud Run: Deploy Service"
        uses: schliflo/action-cloud-run@3.0.0
        with:
          project: ${{ secrets.GCP_PROJECT }}
          service_name: your-service-name
          key: ${{ secrets.GCP_SA_KEY }}
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

`delete-cloud-run.yml`
```yaml
name: "Cloud Run: Delete Service"

on:
  workflow_dispatch:
  delete:

jobs:
  delete:
    name: Delete
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      - name: "Cloud Run: Delete Service"
        uses: schliflo/action-cloud-run@3.0.0
        with:
          project: ${{ secrets.GCP_PROJECT }}
          service_name: your-service-name
          key: ${{ secrets.GCP_SA_KEY }}
          action: 'delete'
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```
