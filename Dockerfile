FROM google/cloud-sdk:alpine

RUN apk add --no-cache --update \
    coreutils \
    jq \
    && gcloud components install \
    docker-credential-gcr

COPY src/ /

ENTRYPOINT ["/entrypoint.sh"]
