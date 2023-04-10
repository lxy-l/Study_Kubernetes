# Kubernetes 学习笔记
>创建Kubernetes集群
---
## 参考资料
* 使用 *[kubeadm](https://kubernetes.io/zh-cn/docs/setup/production-environment/tools/kubeadm/)* 安装kubernetes集群
* 安装 *[containerd](https://github.com/containerd/containerd/blob/main/docs/getting-started.md)* 容器
* 安装 *[istio](https://istio.io/latest/docs/setup/getting-started/)* 网关
* 安装 *[calico](https://docs.tigera.io/calico/3.25/about/)* CNI
* 安装 *[PureLB](https://purelb.gitlab.io/docs/install/install/)* 负载均衡器
* 安装 *[Dashboard](https://github.com/kubernetes/dashboard)* 面板
## 准备
1. Ubuntu22.10 服务器
2. 配置代理 
3. 临时关闭防火墙
4. 分配服务器固定IP

### 配置
> 搭建一个master两个node的学习环境  
> 端口开放：
> [Kubernetes](https://kubernetes.io/zh-cn/docs/reference/networking/ports-and-protocols/)
> [Calico](https://docs.tigera.io/calico/3.25/getting-started/kubernetes/requirements)
> [Istio](https://istio.io/latest/zh/docs/ops/deployment/requirements/#ports-used-by-Istio)
> 
 
| 节点名   | IP             |端口  |
| :-----  | :------------: | :-------: |
| master1 |  172.17.191.2  | 6443,53,8443,443,10250,15020,22,15014,2379,2376,2380,9099,9796,6783,10254,9443,80,15029,15021,179,4789,5473,7472 |
| node1   | 172.17.191.3   | 7934,53,15020,15014,443,8443,10250,22,15029,9090,9011,15012,15032,15030,15031,9411,3000,16685,9080,15021,179,4789,5473,6443,2379,7472 |
| node2   |  172.17.191.4  | 7934,8443,10250,15020,15014,22,15029,15012,15030,15032,15031,9411,3000,9080,15021,179,4789,5473,443,6443,2379,7472|

## 1. 安装

### 安装 *[containerd](https://containerd.io/)* 容器
>https://docs.docker.com/engine/install/ubuntu/
1. 执行下列命令安装对应模块
``` bash
apt update
apt install ca-certificates
apt install curl 
apt install gnupg
apt install lsb-release
mkdir -p /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update
```
2. 安装containerd
``` bash
apt install -y containerd.io
```
3. 生成默认配置并修改SystemdCgroup = true
``` bash
containerd config default > /etc/containerd/config.toml
```
4. 重启containerd
``` bash
systemctl restart containerd
```

## 2. 配置网络
>如果使用ipvs需要开启ipvs模块

### 基础配置
``` bash
# 设置加载br_netfilter模块
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# 开启bridge-nf-call-iptables ，设置所需的 sysctl 参数，参数在重新启动后保持不变
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# 应用 sysctl 参数而不重新启动
sudo sysctl --system
```
### 开启ipvs
```bash
modprobe ip_vs && modprobe ip_vs_rr && modprobe ip_vs_wrr && modprobe ip_vs_sh && modprobe nf_conntrack
```

### 关闭swap
``` bash
sed -ri 's/.*swap.*/#&/' /etc/fstab
swapoff -a && swapon -a
```


## 3. 安装kubeadm工具
>https://kubernetes.io/zh-cn/docs/setup/production-environment/tools/kubeadm/install-kubeadm/  

1. 安装
```bash
apt update
apt install -y apt-transport-https ca-certificates curl

curl -fsSLo /etc/apt/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

apt update

apt install -y kubelet kubeadm kubectl
```
2. 导出kubeadm默认配置文件
```
kubeadm config print init-defaults > kubeadm-config.yaml
```
3. 修改配置文件
``` YAML
apiVersion: kubeadm.k8s.io/v1beta3
bootstrapTokens:
- groups:
  - system:bootstrappers:kubeadm:default-node-token
  token: abcdef.0123456789abcdef
  ttl: 24h0m0s
  usages:
  - signing
  - authentication
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: 172.17.191.2 #这个是master服务器的ip
  bindPort: 6443 #默认配置
nodeRegistration:
  criSocket: unix:///var/run/containerd/containerd.sock
  imagePullPolicy: IfNotPresent
  name: node
  taints: null
---
apiServer:
  timeoutForControlPlane: 4m0s
apiVersion: kubeadm.k8s.io/v1beta3
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controllerManager: {}
dns: {}
etcd:
  local:
    dataDir: /var/lib/etcd
imageRepository: registry.k8s.io #默认镜像地址
kind: ClusterConfiguration
kubernetesVersion: 1.26.1
networking:
  dnsDomain: cluster.local
  serviceSubnet: 10.96.0.0/12 #需要配置
  podSubnet: 10.244.0.0/16    #需要配置
scheduler: {}
---
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
cgroupDriver: systemd #需要配置
---
#下面这个是启用ipvs（前提是开启了ipvs模块）
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs
```
4. 拉取容器镜像（需要代理，提前拉取）
```bash
ctr -n=k8s.io i pull registry.k8s.io/kube-apiserver:v1.26.1 &/
ctr -n=k8s.io i pull registry.k8s.io/kube-controller-manager:v1.26.1 &/
ctr -n=k8s.io i pull registry.k8s.io/kube-scheduler:v1.26.1 &/
ctr -n=k8s.io i pull registry.k8s.io/kube-proxy:v1.26.1 &/
ctr -n=k8s.io i pull registry.k8s.io/pause:3.9 &/
ctr -n=k8s.io i pull registry.k8s.io/pause:3.6 &/
ctr -n=k8s.io i pull registry.k8s.io/etcd:3.5.6-0 &/
ctr -n=k8s.io i pull registry.k8s.io/coredns/coredns:v1.9.3 &/
#这个是metrics-server的镜像
ctr -n=k8s.io i pull k8s.gcr.io/metrics-server/metrics-server:v0.6.2 &/ 
ctr -n=k8s.io images ls
```

## 4.部署master节点
>修改参数,拉取镜像成功后执行安装命令
```bash
#部署master节点
kubeadm init --config yaml/kubeadm-config.yaml --upload-certs --node-name master-1

#配置目录
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

#export KUBECONFIG=/etc/kubernetes/admin.conf
```


## 6.部署node节点

1. 按照`1~3`的步骤执行
2. 修改kubeadm对应的配置
3. 在master节点上生成jointoken
    ``` bash
    #在master节点上执行
    #永久有效的连接token
    kubeadm token create --ttl 0 --print-join-command
    ```
4. 加入master节点中
    ``` bash
    #在node节点上执行
    kubeadm join 172.17.191.2:6443 --token wbxv8d.uhvwicjhgw4phfmp --discovery-token-ca-cert-hash sha256:e16b1fd42dc7cbe365a6bdc82c79c335b6a47b90a2037c84e46f2a3b503927b0 --node-name node1
    ```

---

## 7.安装calico
>安装：https://docs.tigera.io/calico/3.25/getting-started/kubernetes/quickstart  
>疑难解答：https://docs.tigera.io/calico/3.25/operations/troubleshoot/troubleshooting#configure-networkmanager
1. 配置NetworkManager
    ```conf
    #/etc/NetworkManager/conf.d/calico.conf
    [keyfile]
    unmanaged-devices=interface-name:cali*;interface-name:tunl*;interface-name:vxlan.calico;interface-name:vxlan-v6.calico;interface-name:wireguard.cali;interface-name:wg-v6.cali
    ```
2. 安装
   ```
   #按照官方默认配置来就行了
   kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/tigera-operator.yaml
   ```
3. 配置custom-resources.yaml
   ```bash
   wget https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/custom-resources.yaml
   ```
   修改配置文件
   ```YAML
    # This section includes base Calico installation configuration.
    # For more information, see: https://projectcalico.docs.tigera.io/master/reference/installation/api#operator.tigera.io/v1.Installation
    apiVersion: operator.tigera.io/v1
    kind: Installation
    metadata:
    name: default
    spec:
    # Configures Calico networking.
    calicoNetwork:
        # Note: The ipPools section cannot be modified post-install.
        ipPools:
        - blockSize: 26
        cidr: 10.244.0.0/16 #这个地方改为kubeadm配置文件中配置的podSubnet
        encapsulation: VXLANCrossSubnet
        natOutgoing: Enabled
        nodeSelector: all()
        nodeAddressAutodetectionV4:
        interface: eth.* #如果是多网卡直接指定服务器ip网卡的名称
    ---

    # This section configures the Calico API server.
    # For more information, see: https://projectcalico.docs.tigera.io/master/reference/installation/api#operator.tigera.io/v1.APIServer
    apiVersion: operator.tigera.io/v1
    kind: APIServer 
    metadata: 
    name: default 
    spec: {}

   ```
4. 配置完后执行
   
   ```bash
   kubectl create -f custom-resources.yaml
   ```
5. 检查状态

   ```bash
   calicoctl node status 
   #INFO处于Established状态
   ```
   1. 所有节点处于Ready状态
   2. Pod全部处于Runing状态
   3. 执行命令所有节点IP正常


## 8.安装metrics-server
>https://github.com/kubernetes-sigs/metrics-server

1. 拉取镜像(之前已经拉取过了)
   
   ```
   ctr -n=k8s.io i pull k8s.gcr.io/metrics-server/metrics-server:v0.6.2 &/ 
   ```
2. 修改ApiServer配置文件
   ```YAML
   apiVersion: v1
    kind: Pod
    ......
    spec:
    containers:
    - command:
        - kube-apiserver
        ......
        - --enable-bootstrap-token-auth=true
        # 增加这行
        - --enable-aggregator-routing=true  
   ```
3. 下载配置文件(yaml文件夹内有配置好的文件)
   ```bash
   wget https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
   ```
   ```YAML
     template:
    metadata:
      labels:
        k8s-app: metrics-server
    spec:
      containers:
      - args:
        - --cert-dir=/tmp
        - --secure-port=4443
         # 修改这行，默认是InternalIP,ExternalIP,Hostname
        - --kubelet-preferred-address-types=InternalIP  
        - --kubelet-use-node-status-port
        - --metric-resolution=15s
        # 增加这行
        - --kubelet-insecure-tls  
   ```
4. 执行配置文件
   ```bash
   kubectl apply -f components.yaml
   ```
5. 验证
   ```
   #使用这个命令不报错无问题
   kubectl top nodes
   ```


## 9.安装PureLB
>https://purelb.gitlab.io/docs/install/install/

1. 配置
```bash
#前提开启ipvs

#配置apiserver
kubectl edit configmap kube-proxy -n kube-system
修改mode: "ipvs" #修改此处，原为空
修改strictARP: true #修改此处，原为false

#重启kube-proxy
kubectl rollout restart daemonset kube-proxy -n kube-system 

#配置sysctl
cat <<EOF | sudo tee /etc/sysctl.d/k8s_arp.conf
net.ipv4.conf.all.arp_ignore=1
net.ipv4.conf.all.arp_announce=2

EOF
sudo sysctl --system
```

2. 安装PureLB
```bash
kubectl apply -f https://gitlab.com/api/v4/projects/purelb%2Fpurelb/packages/generic/manifest/0.0.1/purelb-complete.yaml

kubectl get pods --namespace=purelb --output=wide

kubectl api-resources --api-group=purelb.io

kubectl describe --namespace=purelb lbnodeagent.purelb.io/default
```

3. 新增默认配置文件
```YAML
#00-installer-config.yaml
network:
  ethernets:
    eth0:
      dhcp4: true
    eth1:
      dhcp4: no
      addresses: [172.17.191.2/24] #这个是服务器固定IP
    eth2:
      dhcp4: no
      addresses: [172.32.100.2/24] #需要新增一个负载均衡的IP
  version: 2
#purelbserviceGroup.yaml
apiVersion: purelb.io/v1
kind: ServiceGroup
metadata:
  name: default
  namespace: purelb
spec:
  local:
    v4pool:
      aggregation: default
      pool: 172.32.100.225-172.32.100.229 #自定义范围
      subnet: 172.32.100.0/24 #配置为eth2网卡
```
4. 执行配置文件
```bash
kubectl apply -f purelbserviceGroup.yaml
```

5. 检查
```bash
#此时service类型为LoadBalancer的 EXTERNAL-IP已经被分配好了
kubectl get svc istio-ingressgateway -n istio-system
访问EXTERNAL-IP加端口正常
```

6. 重启服务器
```bash
#PEER ADDRESS 应该为服务器固定IP，如果不是，需要手动修改IP
#INFO处于Established状态
calicoctl node status

#观察caliconode
calicoctl get node node1 -o yaml

#调整
kubectl edit daem：qonset calico-node -n calico-system
 - name: IP
    value: autodetect
 - name: IP_AUTODETECTION_METHOD
    value: interface=eth1 #这个网卡名称不能错，否则IP分配会错误
```

## 10.安装Istio
>https://istio.io/latest/docs/setup/getting-started/
1. 下载istio安装包
```bash
curl -L https://istio.io/downloadIstio | sh -
cd istio-1.17.0
export PATH=$PWD/bin:$PATH
```
2. 安装istio
```bash
#安装demo示例
istioctl install --set profile=demo -y
#自动注入
kubectl label namespace default istio-injection=enabled
#网关服务
kubectl get svc istio-ingressgateway -n istio-system
```
3. 安装插件和bookinfo示例
```bash
#安装bookinfo示例
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml
#安装插件
kubectl apply -f samples/addons
#检查配置文件
istioctl analyze
```
4. 配置Gateway
```yaml
#grafana-gateway.yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: grafana-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 15031
      name: http-grafana
      protocol: HTTP
    hosts:
    - "*"
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: grafana-vs
  namespace: istio-system
spec:
  hosts:
  - "*"
  gateways:
  - grafana-gateway
  http:
  - match:
    - port: 15031
    route:
    - destination:
        host: grafana
        port:
          number: 3000
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: grafana
  namespace: istio-system
spec:
  host: grafana
  trafficPolicy:
    tls:
      mode: DISABLE
---
#kiali-gateway.yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: kiali-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 15029
      name: http-kiali
      protocol: HTTP
    hosts:
    - "*"
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: kiali-vs
  namespace: istio-system
spec:
  hosts:
  - "*"
  gateways:
  - kiali-gateway
  http:
  - match:
    - port: 15029
    route:
    - destination:
        host: kiali
        port:
          number: 20001
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: kiali
  namespace: istio-system
spec:
  host: kiali
  trafficPolicy:
    tls:
      mode: DISABLE
---
#prometheus-gateway.yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: prometheus-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 15030
      name: http-prom
      protocol: HTTP
    hosts:
    - "*"
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: prometheus-vs
  namespace: istio-system
spec:
  hosts:
  - "*"
  gateways:
  - prometheus-gateway
  http:
  - match:
    - port: 15030
    route:
    - destination:
        host: prometheus
        port:
          number: 9090
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: prometheus
  namespace: istio-system
spec:
  host: prometheus
  trafficPolicy:
    tls:
      mode: DISABLE
---
#tracing-gateway.yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: tracing-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 15032
      name: http-tracing
      protocol: HTTP
    hosts:
    - "*"
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: tracing-vs
  namespace: istio-system
spec:
  hosts:
  - "*"
  gateways:
  - tracing-gateway
  http:
  - match:
    - port: 15032
    route:
    - destination:
        host: tracing
        port:
          number: 80
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: tracing
  namespace: istio-system
spec:
  host: tracing
  trafficPolicy:
    tls:
      mode: DISABLE
---

#bookinfo-gateway.yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: bookinfo-gateway
spec:
  selector:
    istio: ingressgateway # use istio default controller
  servers:
  - port:
      number: 9080 #修改端口
      name: http
      protocol: HTTP
    hosts:
    - "*"
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: bookinfo
spec:
  hosts:
  - "*"
  gateways:
  - bookinfo-gateway
  http:
  - match:
    - uri:
        exact: /productpage
    - uri:
        prefix: /static
    - uri:
        exact: /login
    - uri:
        exact: /logout
    - uri:
        prefix: /api/v1/products
    route:
    - destination:
        host: productpage
        port:
          number: 9080
```
5. 执行配置文件
```bash
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml #需要自己调整
kubectl apply -f grafana-gateway.yaml
kubectl apply -f kiali-gateway.yaml
kubectl apply -f prometheus-gateway.yaml
kubectl apply -f tracing-gateway.yaml
```
6. 修改网关配置
```bash
kubectl edit svc istio-ingressgateway -n istio-system
```
调整端口
```YAML
apiVersion: v1
kind: Service
metadata:
  annotations:
    purelb.io/allocated-by: PureLB
    purelb.io/allocated-from: default
  creationTimestamp: "2023-02-02T09:25:59Z"
...
spec:
  allocateLoadBalancerNodePorts: false #不自动分配NodePort
  #调整port端口配置
  ports:
  - name: bookinfo
    port: 9080 #对外暴露端口
    protocol: TCP
    targetPort: 9080 #gateway端口
  - name: kiali
    port: 15029
    protocol: TCP
    targetPort: 15029
  - name: prometheus
    port: 15030
    protocol: TCP
    targetPort: 15030
  - name: grafana
    port: 15031
    protocol: TCP
    targetPort: 15031
  - name: trac
    port: 15032
    protocol: TCP
    targetPort: 15032
  selector:
    app: istio-ingressgateway
    istio: ingressgateway
  sessionAffinity: None
  type: LoadBalancer
status:
  loadBalancer:
    ingress:
    - ip: 172.32.100.227
```
7. 配置kiali
```bash
# 编辑kiali的配置文件
kubectl edit configmap -n istio-system kiali
```
修改配置文件
```YAML
external_services:
  prometheus: #添加
    in_cluster_url: "http://prometheus.istio-system:9090/"
  grafana: #添加
    in_cluster_url: "http://grafana.istio-system:3000"
    url: 'http://172.32.100.227:15031/'
  tracing: #添加
    auth:
      type: none
      enabled: true
    in_cluster_url: "http://tracing.istio-system:16685/jaeger"
    url: 'http://172.32.100.227:15032/jaeger/'
    use_grpc: true
  custom_dashboards:
    enabled: true
  istio:
    root_namespace: istio-system
```
```BASH
#删除Pod，重新构建
kubectl delete pod -n istio-system kiali-5c547b7b74-hg7dz
```
打开kiali网页，无报错就ok



## 11.安装dashboard
>kubernetes官方文档：https://kubernetes.io/zh-cn/docs/tasks/access-application-cluster/web-ui-dashboard/  
>GitHub文档：https://github.com/kubernetes/dashboard/blob/master/docs/user/access-control/creating-sample-user.md

1. 下载配置文件
```bash
wget https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
```
2. 修改配置文件
```yaml
kind: Service
apiVersion: v1
metadata:
  annotations:
   purelb.io/service-group: default #增加这行
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
spec:
  allocateLoadBalancerNodePorts: false
  ports:
    - port: 8443
      targetPort: 8443
  type: LoadBalancer #修改为LoadBalancer
  selector:
    k8s-app: kubernetes-dashboard
---
kind: Deployment
apiVersion: apps/v1
metadata:
  labels:
    k8s-app: dashboard-metrics-scraper
  name: dashboard-metrics-scraper
  namespace: kubernetes-dashboard
spec:
  replicas: 2 #修改为2
  ...
---
kind: Deployment
apiVersion: apps/v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
spec:
  replicas: 2 #修改为2
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      k8s-app: kubernetes-dashboard
      ...
```

3. 生成配置文件
```yaml
#dashboard-adminuser.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
#dashboard-ClusterRoleBinding.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
```

4. 执行配置文件
```bash
kubectl apply -f recommended.yaml
kubectl apply -f dashboard-adminuser.yaml
kubectl apply -f dashboard-ClusterRoleBinding.yaml
```

# 完成
1. 开启防火墙
2. 开启防火墙日志监控端口
3. 开放对应端口
---
# 总结
1. 需要在初始化集群之前手动翻墙拉取registry.k8s.io里面的相关镜像
2. registry.k8s.io/pause:3.6需要手动拉取，推荐的registry.k8s.io/pause:3.9使用不了，不然会报错
3. flannel.yml文件中的Network要与kubeadm-config.yaml文件中的podSubnet一致最好使用默认10.244.0.0/16
4. calico 需要开启179和5473端口，需要修改默认用户配置的pod network CIDR,需要配置/etc/NetworkManager/conf.d/calico.conf 
   https://projectcalico.docs.tigera.io/maintenance/troubleshoot/troubleshooting
5. istio 安装需要metrics-server,镜像需要代理拉取，此外需要关闭防火墙
   kube-apiserver.yaml 开启--enable-aggregator-routing=true，关闭env中的代理
6. 需要创建Gateway，VirtualService，DestinationRule等服务才能使用istio-ingressgateway
7. 安装PureLB后重启服务器可能会导致集群IP更改，是因为多网卡calico自己选择ip的规则是模糊的，建议手动指定网卡名称


# 常用命令
## kubeclt
>https://kubernetes.io/docs/reference/kubectl/kubectl/
1. kubectl create -f *.yaml #创建
2. kubectl delete ns name #删除命名空间
3. kubectl get namespaces --show-labels #获取命名空间
4. kubectl create deployment snowflake --image=registry.k8s.io/serve_hostname  -n=development --replicas=2 #创建一个副本个 数为 2 的 Deployment
5. kubectl delete -n dev deployment snowflake #删除deployment
6. kubectl describe node <节点名称> #查询节点详细信息
7. kubectl describe pods <Pod名称> #查询Pod详细信息
8. kubectl logs <Pod名称> -n <命名空间> #查询Pod日志

## calicoctl 
>https://docs.tigera.io/calico/3.25/operations/calicoctl/install
1. calicoctl node status #查询节点状态
2. calicoctl get ippool -o wide #查询IP池

## istioctl
>https://istio.io/latest/docs/reference/commands/istioctl/
1. istioctl analyze #检查配置文件
