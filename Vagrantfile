#ode: ruby -*-
# vi: set ft=ruby :

BOX_NAME = "archlinux/archlinux"
# MASTER_IPS = ["192.168.56.10", "192.168.56.11", "192.168.56.12"]
# NODE_IPS = ["192.168.56.20", "192.168.56.21", "192.168.56.22"]

# 使用与宿主机相同网段的IP，使用public network进行配置
MASTER_IPS = ["192.168.2.100", "192.168.2.101", "192.168.2.102"]
NODE_IPS = ["192.168.2.200", "192.168.2.201", "192.168.2.202"]
BRIDGE_NIC = "eno1" # 使用public_network时，配置成宿主机的桥接网卡，一般为eth0，可以通过命令 `ip a s` 查看

 # IP address of your LAN's router e.g. 192.168.0.1
DEFAULT_ROUTER = "192.168.2.1"

DNS_NAME = "shizhz.me"
LB_DOMAIN_NAME = "k8s.shizhz.me"
# We use the first master node as LB server
LB_IP = "192.168.2.100"

CLUSTER_NAME="shizhz.me"
KUBE_VERSION="1.25.4"
CONTAINERD_VERSION="1.6.10-1"
# HTTP_PROXY="http://192.168.2.7:7890"
HTTP_PROXY=""
CALICO_VERSION="v3.24.1"
POD_CIDR="172.30.0.0/16"
SVC_CIDR="10.96.0.0/12"

def get_cert_sans
  return "  - \"" + LB_IP + "\"\n    - \"" + LB_DOMAIN_NAME + "\""
end

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

def get_no_proxy()
  if HTTP_PROXY.empty?
    return ""
  else
    proxy_ip = HTTP_PROXY.split(':')[1].split('/')[2]

    return proxy_ip + ",localhost,127.0.0.1," + MASTER_IPS.join(',') + "," + NODE_IPS.join(',')
  end
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

 # change/ensure the default route via the local network's WAN router, useful for public_network/bridged mode
 config.vm.provision :shell, run: "always", :inline => "ip route delete default && ip route add default via #{DEFAULT_ROUTER}"


  # Master Nodes
  MASTER_IPS.each_with_index do |ip, index|
    config.vm.define "k8s-master-#{index}" do |km|
      km.vm.box = BOX_NAME
      km.vm.synced_folder ".", "/vagrant", type: "virtualbox"
      km.vm.hostname = master_fqdn(index)
      # km.vm.network "private_network", ip: ip
      km.vm.network "public_network", ip: ip, bridge: "$BRIDGE_NIC"
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
      km.vm.provision "shell", path: "scripts/common.sh", env: {
                                                               "ADVERTISE_IP" => ip,
                                                               "KUBE_VERSION" => KUBE_VERSION,
                                                               "CONTAINERD_VERSION" => CONTAINERD_VERSION,
                                                               "HTTP_PROXY" => HTTP_PROXY,
                                                               "NO_PROXY" => get_no_proxy()
                                                               }
      km.vm.provision "shell", path: "scripts/master.sh", env: {
                                                                "ADVERTISE_IP" => ip,
                                                                "KUBE_VERSION" => KUBE_VERSION,
                                                                "CALICO_VERSION" => CALICO_VERSION,
                                                                "POD_CIDR" => POD_CIDR,
                                                                "SVC_CIDR" => SVC_CIDR,
                                                                "CLUSTER_NAME" => CLUSTER_NAME,
                                                                "CERT_SANS" => get_cert_sans(),
                                                                "CONTROL_PLANE_ENDPOINT" => LB_DOMAIN_NAME
                                                               }
    end
  end

  # Worker Nodes
  NODE_IPS.each_with_index do |ip, index|
    config.vm.define "k8s-node-#{index}" do |km|
      km.vm.box = BOX_NAME
      km.vm.synced_folder ".", "/vagrant", type: "virtualbox"
      km.vm.hostname = node_fqdn(index)
      # km.vm.network "private_network", ip: ip
      km.vm.network "public_network", ip: ip, bridge: "$BRIDGE_NIC"
      km.vm.provider "virtualbox" do |v|
        v.name = node_hostname(index)
        v.memory = 4096
        v.cpus = 3
      end

      km.vm.provision "shell", inline: <<-SHELL
      cp /vagrant/configs/mirrorlist /etc/pacman.d/
      mkdir /etc/containerd/
      cp /vagrant/configs/config.toml /etc/containerd/
      SHELL

      km.vm.provision "shell", path: "scripts/common.sh", env: {
                                                               "ADVERTISE_IP" => ip,
                                                               "KUBE_VERSION" => KUBE_VERSION,
                                                               "CONTAINERD_VERSION" => CONTAINERD_VERSION,
                                                               "HTTP_PROXY" => HTTP_PROXY,
                                                               "NO_PROXY" => get_no_proxy()
                                                               }
      km.vm.provision "shell", path: "scripts/node.sh"
    end
  end
end
