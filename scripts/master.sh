sudo kubeadm init --pod-network-cidr=10.69.0.0/16 --token k8s-join-token.abcdef1234567890
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | \
openssl rsa -pubin -outform DER 2>/dev/null | \
sha256sum | \
awk '{print $1}' > hash

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config