#!/bin/bash
## Get default network interface to fill up LOCAL_IP environment variable
KIND_DEFAULT_IF=$(route -n get default | grep -A 1 "interface" | head -1 | cut -d ':' -f 2 | cut -d ' ' -f 2)
## Get network IP
LOCAL_IP=$(ifconfig $KIND_DEFAULT_IF | grep -w inet | tail -1 | cut -d ':' -f 2 | cut -d ' ' -f 2)
## Transform to hexadecimal
IP_HEX=$(echo $LOCAL_IP | awk -F '.' '{printf "%08x", ($1 * 2^24) + ($2 * 2^16) + ($3 * 2^8) + $4}')
## Generate random name for cluster
CLUSTER_NAME=cluster-$(openssl rand -hex 3)
## Specific image for ARM processors
IMAGE="rossgeorgiev/kind-node-arm64:v1.21"
kind create cluster --name $CLUSTER_NAME --config cluster/cluster.yaml --image $IMAGE
sed "s/MY_NETWORK_IP_RANGE/$LOCAL_IP\/32/g" templates/metallb-config.yaml > infra/metallb-values.yaml
sed "s/MY_HOST/$IP_HEX.nip.io/g" templates/ingress.yaml > apps/ingress.yaml
helm repo add projectcalico https://docs.projectcalico.org/charts
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add metallb https://metallb.github.io/metallb
helm repo update
helm install calico projectcalico/tigera-operator --namespace calico-system --create-namespace --version v3.20.0
kubectl wait --for condition=Available=True deploy/tigera-operator -n tigera-operator --timeout -1s
helm install metrics-server bitnami/metrics-server --set rbac.create=true --set extraArgs.kubelet-insecure-tls=true --set extraArgs.kubelet-preferred-address-types=InternalIP --set apiService.create=true
kubectl wait --for condition=Available=True deploy/metrics-server -n kube-system --timeout -1s
helm install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx  --create-namespace -f infra/ingress-nginx-values.yaml
kubectl wait --for condition=Available=True deploy/ingress-nginx-controller -n ingress-nginx --timeout -1s
helm install metallb metallb/metallb --namespace metallb-system  --create-namespace -f infra/metallb-values.yaml
kubectl wait --for condition=Available=True deploy/metallb-controller -n metallb-system --timeout -1s
kubectl wait --for condition=ready pod -l app.kubernetes.io/component=controller -n metallb-system --timeout -1s
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl create deploy podinfo -n default --image=stefanprodan/podinfo --port 9898
kubectl expose deploy podinfo -n default  --target-port 9898 --port 80 --type ClusterIP
kubectl apply -f apps/
