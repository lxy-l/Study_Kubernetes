#导出默认containerd配置文件（修改SystemdCgroup = true）
containerd config default > /etc/containerd/config.toml

systemctl restart containerd