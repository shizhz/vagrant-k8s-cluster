#!/usr/bin/env bash

# Get images by command: kubeadm config images list
images=(
"kube-apiserver:v1.24.4"
"kube-controller-manager:v1.24.4"
"kube-scheduler:v1.24.4"
"kube-proxy:v1.24.4"
"pause:3.7"
"etcd:3.5.3-0"
"coredns/coredns:v1.8.6"
)

pre_registry="k8s.gcr.io"
des_registry="shizhz"

for img in ${images[*]}
do 
    ori_img=${pre_registry}/${img}
    des_img=${des_registry}/${img}
    docker pull ${ori_img}
    docker tag ${ori_img} ${des_img}
    docker push ${des_img}
done

docker pull k8s.gcr.io/coredns/coredns:v1.8.6
docker tag k8s.gcr.io/coredns/coredns:v1.8.6 shizhz/coredns:v1.8.6
docker push shizhz/coredns:v1.8.6
