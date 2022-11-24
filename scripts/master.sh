#!/bin/bash
#
# Common setup for all servers (Control Plane and Nodes)

set -euxo pipefail

# https://github.com/techiescamp/vagrant-kubeadm-kubernetes/blob/main/scripts/master.sh
# echo "Pull all images kubeadm needs"
# sudo kubeadm config images pull --v=5

if [ "$HOSTNAME" = "k8s-master-0" ]; then
    echo "Render kubeadm-config.yaml"
    envsubst < /vagrant/configs/kubeadm-config.yaml.tmpl > /vagrant/configs/kubeadm-config.yaml
    echo "Using kubeadm-config.yaml"
    cat /vagrant/configs/kubeadm-config.yaml

    # kubeadm init --image-repository=registry.aliyuncs.com/google_containers --service-cidr=${SVC_CIDR} --apiserver-cert-extra-sans=${ADVERTISE_IP} --pod-network-cidr=${POD_CIDR} --apiserver-advertise-address=${ADVERTISE_IP} --control-plane-endpoint="k8s.shizhz.me" --upload-certs --certificate-key=${CERT_KEY} --ignore-preflight-errors Swap
    kubeadm init --config /vagrant/configs/kubeadm-config.yaml --upload-certs --ignore-preflight-errors Swap

    EXIT_CODE="$?"
    if [ "${EXIT_CODE}" != 0 ]; then
        echo "Failed to do 'kubeadm init', exit"
        exit "${EXIT_CODE}"
    fi

    # Config kubeconfig for current user
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
    sudo cp -i /etc/kubernetes/admin.conf /vagrant/configs/config

    echo "Install calico"
    kubectl apply -f /vagrant/configs/calico-${CALICO_VERSION}.yaml

    echo "Create a new certificate-key for joining"
    CERT_KEY=$(kubeadm init phase upload-certs --upload-certs | tail -n 1)

    echo $(kubeadm token create --certificate-key ${CERT_KEY} --print-join-command) '$@' | tee /vagrant/scripts/join_master.sh
    echo $(kubeadm token create --print-join-command) | tee /vagrant/scripts/join_worker.sh
    chmod a+x /vagrant/scripts/join_master.sh
    chmod a+x /vagrant/scripts/join_worker.sh
else
    echo "Do 'kubeadm join' on the rest master nodes, currently doing it at $HOSTNAME"
    sudo /bin/bash /vagrant/scripts/join_master.sh --apiserver-advertise-address=$ADVERTISE_IP
fi

# Setup kube config
sudo mkdir -p $HOME/.kube
sudo cp -i /vagrant/configs/config $HOME/.kube/config
