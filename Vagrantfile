#ode: ruby -*-
# vi: set ft=ruby :

BOX_NAME = "archlinux/archlinux"
# MASTER_IPS = ["192.168.56.10", "192.168.56.11", "192.168.56.12"]
MASTER_IPS = ["192.168.56.10"]
NODE_IPS = ["192.168.56.20", "192.168.56.21", "192.168.56.22"]
DNS_NAME = "shizhz.me"
LB_DOMAIN_NAME = "k8s.shizhz.me"
# We use the first master node as LB server
LB_IP = "192.168.56.10"

def host_fqdn (hostname)
  return "#{hostname}.#{DNS_NAME}"
end

def hostname (prefix, index)
  return "#{prefix}-#{index}"
end

def master_hostname (index)
  return hostname("k8s-master", index)
end

def master_fqdn (index)
  return host_fqdn(master_hostname(index))
end

def node_hostname (index)
  return hostname("k8s-node", index)
end

def node_fqdn (index)
  return host_fqdn(node_hostname(index))
end

def gen_hosts()
  hosts = ""

  MASTER_IPS.each_with_index do |ip, index|
    mname = master_hostname(index)
    mfqdn = master_fqdn(index)
    hosts += "#{ip} #{mname}\n"
    hosts += "#{ip} #{mfqdn}\n"
  end

  NODE_IPS.each_with_index do |ip, index|
    nname = node_hostname(index)
    nfqdn = node_fqdn(index)
    hosts += "#{ip} #{nname}\n"
    hosts += "#{ip} #{nfqdn}\n"
  end

  # Simply point LB name to the first master node
  # TODO: Remove this entry if you've setup a seperated LB and configured DNS resolution
  hosts += "#{LB_IP} #{LB_DOMAIN_NAME}"

  return hosts
end

Vagrant.configure("2") do |config|
  config.ssh.insert_key = false
  config.vm.box = BOX_NAME

  config.vm.provision "shell", env: {"HOSTS" => gen_hosts()}, inline: <<-SHELL
      echo "$HOSTS" >> /etc/hosts
      timedatectl set-timezone Asia/Shanghai
  SHELL

  # Master Nodes
  MASTER_IPS.each_with_index do |ip, index|
    config.vm.define "k8s-master-#{index}" do |km|
      km.vm.box = BOX_NAME
      km.vm.synced_folder ".", "/vagrant", type: "virtualbox"
      km.vm.hostname = master_fqdn(index)
      km.vm.network "private_network", ip: ip, bridge: "eth0"
      km.vm.provider "virtualbox" do |v|
        v.name = master_hostname(index)
        v.memory = 2048
        v.cpus = 2
      end

      km.vm.provision "shell", inline: <<-SHELL
      cp /vagrant/configs/mirrorlist /etc/pacman.d/
      mkdir /etc/containerd/
      cp /vagrant/configs/config.toml /etc/containerd/
      SHELL
      km.vm.provision "shell", path: "scripts/common.sh"
      km.vm.provision "shell", path: "scripts/master.sh"
    end
  end

  # Worker Nodes
  NODE_IPS.each_with_index do |ip, index|
    config.vm.define "k8s-node-#{index}" do |km|
      km.vm.box = BOX_NAME
      km.vm.synced_folder ".", "/vagrant", type: "virtualbox"
      km.vm.hostname = node_fqdn(index)
      km.vm.network "private_network", ip: ip, bridge: "eth0"
      km.vm.provider "virtualbox" do |v|
        v.name = node_hostname(index)
        v.memory = 4096
        v.cpus = 3
      end

      km.vm.provision "shell", inline: <<-SHELL
      cp /vagrant/configs/mirrorlist /etc/pacman.d/
      SHELL
      km.vm.provision "shell", path: "scripts/common.sh"
      # km.vm.provision "shell", path: "scripts/node.sh"
    end
  end
end
