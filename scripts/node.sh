#!/bin/bash
#
# Common setup for all servers (Control Plane and Nodes)

set -euxo pipefail

sudo /bin/bash /vagrant/scripts/join_worker.sh -v

sudo mkdir -p $HOME/.kube
sudo cp -i /vagrant/configs/config $HOME/.kube/config

sudo systemctl restart systemd-resolved
sudo systemctl daemon-reload && sudo systemctl restart kubelet
