ctr -n=k8s.io i pull registry.k8s.io/kube-apiserver:v1.26.1 &/
ctr -n=k8s.io i pull registry.k8s.io/kube-controller-manager:v1.26.1 &/
ctr -n=k8s.io i pull registry.k8s.io/kube-scheduler:v1.26.1 &/
ctr -n=k8s.io i pull registry.k8s.io/kube-proxy:v1.26.1 &/
ctr -n=k8s.io i pull registry.k8s.io/pause:3.9 &/
ctr -n=k8s.io i pull registry.k8s.io/pause:3.6 &/
ctr -n=k8s.io i pull registry.k8s.io/etcd:3.5.6-0 &/
ctr -n=k8s.io i pull registry.k8s.io/coredns/coredns:v1.9.3 &/
ctr -n=k8s.io i pull k8s.gcr.io/metrics-server/metrics-server:v0.6.2 &/ #这个是metrics-server的镜像
ctr -n=k8s.io images ls
