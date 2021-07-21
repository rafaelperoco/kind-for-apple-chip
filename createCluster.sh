#!/bin/bash
## Get default network interface to fill up LOCAL_IP environment variable
KIND_DEFAULT_IF=$(route -n get default | grep -A 1 "interface" | head -1 | cut -d ':' -f 2 | cut -d ' ' -f 2)
LOCAL_IP=$(ifconfig $KIND_DEFAULT_IF | grep -w inet | tail -1 | cut -d ':' -f 2 | cut -d ' ' -f 2)
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
