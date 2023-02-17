ifconfig cni0 down &/
ip link delete cni0 &/
ifconfig flannel.1 down &/
ip link delete flannel.1 &/
ifconfig kube-ipvs0 down &/
ip link delete kube-ipvs0 &/
