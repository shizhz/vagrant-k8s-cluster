#!/bin/bash
#
# Common setup for all servers (Control Plane and Nodes)

set -euxo pipefail

KUBE_VERSION="1.25.0-1"
CONTAINERD_VERSION="1.6.8-1"
HTTP_PROXY="http://192.168.2.7:7890"
NO_PROXY="192.168.2.7,localhost,127.0.0.1,192.168.0.0/16,10.0.0.0/16,10.96.0.1,192.168.56.10,192.168.56.11,192.168.56.12"

# Keep everything up-to-date
sudo pacman -Sy

# disable swap permanently
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# keeps the swaf off during reboot
(crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab - || true

# Setup kernel modules, see https://kubernetes.io/docs/setup/production-environment/container-runtimes/#install-and-configure-prerequisites
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

sudo pacman --noconfirm -S jq

local_ip="$(ip --json a s | jq -r '.[] | if .ifname == "eth1" then .addr_info[] | if .family == "inet" then .local else empty end else empty end')"
sudo tee /etc/default/kubelet << EOF
KUBELET_EXTRA_ARGS=--node-ip=$local_ip
EOF

# Handle iptables conflict, remove iptables first and then install iptables-nft, otherwise the script will fail for some reason
sudo pacman --noconfirm -Rdd iptables
sudo pacman --noconfirm -S iptables-nft

# Install tools
sudo pacman --noconfirm -S bash-completion ca-certificates curl net-tools inetutils vim
# Install container runtime and kube tools
sudo pacman --noconfirm -S containerd=${CONTAINERD_VERSION} kubeadm=${KUBE_VERSION} kubectl=${KUBE_VERSION} kubelet=${KUBE_VERSION}

# Setup bash completion for kubectl
echo 'source /usr/share/bash-completion/bash_completion' >>~/.bashrc
echo 'source <(kubectl completion bash)' >>~/.bashrc


# Setup HTTP Proxy for containerd
if [ ! -z ${HTTP_PROXY} ]
then
    echo "Set up HTTP Proxy for containerd"
    sudo mkdir -p /etc/systemd/system/containerd.service.d/
    cat <<EOF | sudo tee /etc/systemd/system/containerd.service.d/http-proxy.conf > /dev/null
[Service]
Environment="HTTP_PROXY=${HTTP_PROXY}"
Environment="HTTPS_PROXY=${HTTP_PROXY}"
Environment="NO_PROXY=${NO_PROXY}"
EOF
else
    echo "No HTTP Proxy specified"
fi

# Config crictl, refer to: https://kubernetes.io/docs/tasks/debug/debug-cluster/crictl/
cat <<EOF | sudo tee /etc/crictl.yaml > /dev/null
runtime-endpoint: unix:///var/run/containerd/containerd.sock
image-endpoint: unix:///var/run/containerd/containerd.sock
timeout: 10
debug: false
EOF

# Start and enable containerd
sudo systemctl daemon-reload
sudo systemctl start containerd

sudo systemctl enable containerd
sudo systemctl enable kubelet
