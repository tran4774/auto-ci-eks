
ARG ALPINE_VERSION=3.16
FROM docker.io/python:3.10.5-alpine${ALPINE_VERSION} as builder

ARG AWS_CLI_VERSION=2.7.20
RUN apk add --no-cache git unzip groff build-base libffi-dev cmake \
  && git clone --single-branch --depth 1 -b ${AWS_CLI_VERSION} https://github.com/aws/aws-cli.git \
  && cd aws-cli \
  && sed -i'' 's/PyInstaller.*/PyInstaller==5.2/g' requirements-build.txt \
  && python -m venv venv \
  && . venv/bin/activate \
  && scripts/installers/make-exe \
  && unzip -q dist/awscli-exe.zip \
  && aws/install --bin-dir /aws-cli-bin \
  && /aws-cli-bin/aws --version \
  # reduce image size: remove autocomplete and examples
  && rm -rf /usr/local/aws-cli/v2/current/dist/aws_completer /usr/local/aws-cli/v2/current/dist/awscli/data/ac.index /usr/local/aws-cli/v2/current/dist/awscli/examples \
  && find /usr/local/aws-cli/v2/current/dist/awscli/botocore/data -name examples-1.json -delete 

# #1. Install JDK
FROM docker.io/bellsoft/liberica-openjdk-alpine-musl:11.0.16
#2. Install Kaniko Excutor
#2.1. Copy Needed Files from Kaniko Image
COPY --from=gcr.io/kaniko-project/executor:debug /kaniko/executor /kaniko/executor
COPY --from=gcr.io/kaniko-project/executor:debug /kaniko/docker-credential-gcr /kaniko/docker-credential-gcr
COPY --from=gcr.io/kaniko-project/executor:debug /kaniko/docker-credential-ecr-login /kaniko/docker-credential-ecr-login
COPY --from=gcr.io/kaniko-project/executor:debug /kaniko/docker-credential-acr-env /kaniko/docker-credential-acr-env
COPY --from=gcr.io/kaniko-project/executor:debug /kaniko/ssl/certs/ /kaniko/ssl/certs/
COPY --from=gcr.io/kaniko-project/executor:debug /kaniko/.docker /kaniko/.docker
COPY --from=gcr.io/kaniko-project/executor:debug /etc/nsswitch.conf /etc/nsswitch.conf
#2.2. Setting Enviroment Variables for Kaniko
ENV HOME=/root USER=root PATH="${PATH}:$JAVA_HOME/bin:/kaniko" SSL_CERT_DIR=/kaniko/ssl/certs DOCKER_CONFIG=/kaniko/.docker/ DOCKER_CREDENTIAL_GCR_CONFIG=/kaniko/.config/gcloud/docker_credential_gcr_config.json

#3. Init Auto Deployment
WORKDIR /setup
# COPY aws/ /setup/aws/
COPY --from=builder /usr/local/aws-cli/ /usr/local/aws-cli/
COPY --from=builder /aws-cli-bin/ /usr/local/bin/
COPY setup.sh ./
RUN \
  apk add --no-cache curl openssl \
  && chmod +x setup.sh \
  && /setup/setup.sh
COPY script.sh ./
RUN chmod +x script.sh
CMD ["/setup/script.sh"]