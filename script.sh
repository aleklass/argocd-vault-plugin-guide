#!/bin/bash
#creating namespace
kubectl create ns argocd
#installing credentials deployment
kubectl apply -f argocd-vault-plugin-credentials.yaml -n argocd
#installing argocd
kubectl apply -f argocd.yaml -n argocd
#installing vault using helm
helm install vault hashicorp/vault
#read -p "Pause Time 5 seconds" -t 180
read -p "Wait 1 minute till Pods get ready" -t 60
echo "Continuing ...."
#checking pods
kubectl get pods -l app.kubernetes.io/name=vault
#getting keys and token from vault
kubectl exec -ti vault-0 -- vault operator init
read -p "Save these keys & Toke somewhere safe" -t 60
#enter the keys respectively
echo "Enter Key 1"
kubectl exec -ti vault-0 -- vault operator unseal # ... Unseal Key 1
echo "Enter Key 2"
kubectl exec -ti vault-0 -- vault operator unseal # ... Unseal Key 2
echo "Enter Key 3"
kubectl exec -ti vault-0 -- vault operator unseal # ... Unseal Key 3
#check the vault running 1/1
kubectl get pods -l app.kubernetes.io/name=vault
#get cluster-ip
kubectl cluster-info
echo "Enter your cluster IP"
read clusterip
echo "Cluster IP $clusterip"
#kubectl exec --stdin=true --tty=true vault-0 -- /bin/sh
kubectl exec -ti vault-0 -- vault login
echo "Enter Vault Token Here"
kubectl exec -ti vault-0 -- vault auth enable kubernetes 

kubectl exec -ti vault-0 -- vault write auth/kubernetes/config \
        token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
        kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
        kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

kubectl exec -ti vault-0 -- vault write auth/kubernetes/role/argocd \
    bound_service_account_names=default \
    bound_service_account_namespaces=argocd \
    policies=argocd \
    ttl=1h

kubectl exec -ti vault-0 -- vault policy write argocd - <<EOF
path "*" {
  capabilities = ["read"]
}
EOF

kubectl exec -ti vault-0 -- vault secrets enable -path=avp kv-v2    

kubectl exec -ti vault-0 -- vault kv put avp/data/test sample=secret

kubectl apply -f clusterrolebinding.yaml 