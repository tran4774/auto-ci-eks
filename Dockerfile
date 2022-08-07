#STAGE 1. Build java lite jdk and preinstall aws-cli
FROM docker.io/library/ubuntu:focal AS builder
ARG DEBIAN_FRONTEND=noninteractive
WORKDIR /home

#1. Install sdkman
RUN \
  bash -c "apt-get update && apt-get install -y curl zip unzip \
  && curl -s "https://get.sdkman.io" | bash"

#2. Install aws cli
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
  && unzip awscliv2.zip \
  && ./aws/install --bin-dir /aws-cli-bin \
  && /aws-cli-bin/aws --version \
  && rm -rf /usr/local/aws-cli/v2/current/dist/aws_completer /usr/local/aws-cli/v2/current/dist/awscli/data/ac.index /usr/local/aws-cli/v2/current/dist/awscli/examples \
  && find /usr/local/aws-cli/v2/current/dist/awscli/botocore/data -name examples-1.json -delete

#3. Install specific java sdk version with SDK_IDENTIFIER and export lite jdk
ARG SDK_IDENTIFIER=11.0.16-amzn
RUN \
  bash -c " \
  source "$HOME/.sdkman/bin/sdkman-init.sh" \
  && sdk install java $SDK_IDENTIFIER" \
  && /root/.sdkman/candidates/java/current/bin/java --list-modules \
  | sed -E "s/@.+//g" | tr "\n" "," \
  | xargs -I {} /root/.sdkman/candidates/java/current/bin/jlink \
  --output jdk --compress=2 --no-header-files --no-man-pages --module-path ../jmods --add-modules {} \
  && ./jdk/bin/java --version

#STAGE 2. Build image Auto CI
FROM docker.io/library/ubuntu:focal

#1. Install JDK
COPY --from=builder /home/jdk/ /usr/lib/jdk/
ENV JAVA_HOME=/usr/lib/jdk
ENV PATH="${PATH}:$JAVA_HOME/bin"

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
COPY --from=builder /usr/local/aws-cli/ /usr/local/aws-cli/
COPY --from=builder /aws-cli-bin/ /usr/local/bin/
COPY setup.sh ./
RUN \
  apt-get update \
  && apt-get install -y curl \
  && chmod +x setup.sh \
  && /setup/setup.sh \
  && apt-get clean autoclean \
  && apt-get autoremove -y \
  && rm -rf /var/lib/{apt,dpkg,cache,log}/
COPY script.sh ./
RUN chmod +x script.sh
CMD ["/setup/script.sh"]