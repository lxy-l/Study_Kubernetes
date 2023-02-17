#kubectl proxy --disable-filter=true --address='0.0.0.0' --port=8001
kubectl port-forward -n kubernetes-dashboard --address 0.0.0.0 service/kubernetes-dashboard 8001:443
