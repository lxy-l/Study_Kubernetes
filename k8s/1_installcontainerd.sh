sudo su 
#安装containerd
apt remove docker docker-engine docker.io containerd runc
rm -rf /var/lib/docker
rm -rf /var/lib/containerd

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

apt install -y containerd.io
systemctl enable containerd
systemctl status containerd