FROM google/cloud-sdk:alpine

RUN apk add --no-cache \
    jq \
    && gcloud components install \
    docker-credential-gcr

COPY src/ /

ENTRYPOINT ["/entrypoint.sh"]
