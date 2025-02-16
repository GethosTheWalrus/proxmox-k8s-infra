#exit root as normal user
exit
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
#to verify, if kubectl is working or not, run the following command.
kubectl get pod -A