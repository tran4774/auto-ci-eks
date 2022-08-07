#!/bin/sh

curl -o "chart_repo.tar.gz" $CHART_GIT_ARCHIVED_URL && \
mkdir workspace && tar xzf chart_repo.tar.gz -C workspace --strip-components 1 && \
echo -e "[default]\naws_access_key_id = $AWS_ACCESS_KEY_ID \naws_secret_access_key = $AWS_SECRET_ACCESS_KEY\n" > /root/.aws/credentials && \
aws eks --region $AWS_DEFAULT_REGION --profile default update-kubeconfig --name $AWS_EKS_NAME

cd ./workspace
helm delete $SERVICE_NAME -n $NAME_SPACE
if [ -z "$CHART_VALUE_PATH" ]; then
  helm install $SERVICE_NAME $CHART_DIR -n $NAME_SPACE
else
  helm install $SERVICE_NAME $CHART_DIR -n $NAME_SPACE -f $CHART_VALUE_PATH
fi