# Github Action for Google Cloud Run branch deployments

Authenticate with gcloud, build and push image to GCR and deploy as a new revision or branch preview to Cloud Run.

## Usage

Docker image

In your actions workflow, somewhere after the checkout step insert this:

```yaml
- name: Deploy service to Cloud Run
  uses: schliflo/action-cloud-run@2
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
    registry: eu.gcr.io
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
- name: Deploy service to Cloud Run
  uses: schliflo/action-cloud-run@2
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
