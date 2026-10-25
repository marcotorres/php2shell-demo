# Auditor de triaje: una imagen mínima con bash, curl y jq.
FROM alpine:3.20

RUN apk add --no-cache bash curl jq coreutils

COPY php2shell-triage.sh /triage.sh
RUN chmod +x /triage.sh

ENTRYPOINT ["bash", "/triage.sh"]
