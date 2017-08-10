#!/bin/bash
if [ "x$NAMESPACE" == "x" ];then
  NAMESPACE="default"
fi

until kubectl get secret -n $NAMESPACE 2>/dev/null; do printf 'waiting on kubectl...\n'; sleep 5; done

AWS_ACCOUNT="493490470276"
AWS_REGION="cn-north-1"
if [ "x$SECRET_NAME" == "x" ]; then SECRET_NAME=aws-ecr-${AWS_REGION}; fi
TOKEN=`aws ecr --region=$AWS_REGION get-authorization-token --output text --query authorizationData[].authorizationToken | base64 -D | cut -f2 -d:`
DOCKER_CFG_SECRET=`printf '{"%s":{"username":"AWS","password":"%s"}}' "https://${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com.cn" "${TOKEN}" | base64 | tr -d '\n'`

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
data:
  .dockercfg: ${DOCKER_CFG_SECRET}
metadata:
  name: ${SECRET_NAME}
  namespace: ${NAMESPACE}
type: kubernetes.io/dockercfg
EOF
