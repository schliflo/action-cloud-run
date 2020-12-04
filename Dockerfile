FROM google/cloud-sdk

COPY src/ /

ENTRYPOINT ["/entrypoint.sh"]
