#!/bin/sh

curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && \
sed -i 's/#!\/usr\/bin\/env bash/#!\/usr\/bin\/env sh/' get_helm.sh && \
chmod +x get_helm.sh && \
./get_helm.sh && \
rm get_helm.sh && \

curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl && \
chmod +x ./kubectl &&\
mkdir -p $HOME/bin && mv ./kubectl /bin/kubectl &&\

mkdir /root/.aws &&\
touch /root/.aws/credentials
