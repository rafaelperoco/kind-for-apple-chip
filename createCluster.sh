#!/bin/bash
## Get default network interface to fill up LOCAL_IP environment variable
KIND_DEFAULT_IF=$(route -n get default | grep -A 1 "interface" | head -1 | cut -d ':' -f 2 | cut -d ' ' -f 2)
## Get network IP
LOCAL_IP=$(ifconfig $KIND_DEFAULT_IF | grep -w inet | tail -1 | cut -d ':' -f 2 | cut -d ' ' -f 2)
## Generate random name for cluster
CLUSTER_NAME=cluster-$(openssl rand -hex 3)
## Specific image for ARM processors
IMAGE="rossgeorgiev/kind-node-arm64:v1.20.0"
kind create cluster --name $CLUSTER_NAME --config cluster/cluster.yaml --image $IMAGE
kubectl create ns ingress-nginx
sed "s/MY_NETWORK_IP_RANGE/$LOCAL_IP-$LOCAL_IP/g" templates/metallb-config.yaml > infra/02-metallb-config.yaml
kubectl apply -f infra/
kubectl wait --for condition=Available=True deploy/ingress-nginx-controller -n ingress-nginx --timeout -1s
kubectl wait --for condition=Available=True deploy/controller -n metallb-system --timeout -1s
kubectl wait --for condition=ready pod -l app.kubernetes.io/component=controller -n ingress-nginx --timeout -1s
kubectl wait --for condition=ready pod -l component=controller -n metallb-system --timeout -1s
kubectl create deploy podinfo --image=stefanprodan/podinfo --port 9898
kubectl expose deploy podinfo --target-port 9898 --port 80 --type LoadBalancer
kubectl apply -f apps/