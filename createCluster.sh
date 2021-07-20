#!/bin/bash
#LOCAL_IP_ipv4=$(ifconfig | grep -A 1 "en0" | tail -1 | cut -d ':' -f 2 | cut -d ' ' -f 2)
LOCAL_IP=$(ifconfig | grep -A 5 "en0" | grep -A 1 "inet" | head -1 | cut -d ':' -f 2 | cut -d ' ' -f 2)
CLUSTER_NAME=cluster-$(openssl rand -hex 3)
IMAGE="rossgeorgiev/kind-node-arm64:v1.20.0"
kind create cluster --name $CLUSTER_NAME --config cluster/cluster.yaml --image $IMAGE
kubectl create ns ingress-nginx
sed "s/MY_NETWORK_IP_RANGE/$LOCAL_IP-$LOCAL_IP/g" templates/metallb-config.yaml > infra/02-metallb-config.yaml
kubectl apply -f infra/
echo "waiting resources get ready..."
sleep 200
kubectl create deploy podinfo --image=stefanprodan/podinfo --port 9898
kubectl expose deploy podinfo --target-port 9898 --port 80 --type LoadBalancer
kubectl apply -f apps/
