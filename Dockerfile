FROM google/cloud-sdk

COPY entrypoint.sh /entrypoint.sh
COPY gitdiff.sh /gitdiff.sh

ENTRYPOINT ["bash", "/entrypoint.sh"]
