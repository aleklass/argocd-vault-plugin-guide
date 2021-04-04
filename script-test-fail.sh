kubectl get pods -l app.kubernetes.io/name=vault
kubectl exec -ti vault-0 -- vault operator init
read -p "Save these keys & Toke somewhere safe" -t 60
echo "Enter Key 1"
kubectl exec -ti vault-0 -- vault operator unseal # ... Unseal Key 1
echo "Enter Key 2"
kubectl exec -ti vault-0 -- vault operator unseal # ... Unseal Key 2
echo "Enter Key 3"
kubectl exec -ti vault-0 -- vault operator unseal # ... Unseal Key 3
kubectl get pods -l app.kubernetes.io/name=vault
kubectl cluster-info
echo "enter your cluster IP"
read clusterip
echo "Cluster IP $clusterip"


#kubectl exec -it --stdin=true --tty=true vault-0 -- /bin/sh
echo "Enter Token Here"
kubectl exec -it vault-0 -- vault login
kubectl exec -it vault-0 vault auth enable kubernetes 
kubectl exec -it vault-0 vault write auth/kubernetes/config \
     token_reviewer_jwt="$(/var/run/secrets/kubernetes.io/serviceaccount/token)" \
     kubernetes_host=https:$clusterip \
     kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

kubectl exec -it vault-0 vault write auth/kubernetes/role/argocd \
    bound_service_account_names=default \
    bound_service_account_namespaces=argocd \
    policies=argocd \
    ttl=1h

kubectl exec -it vault-0 vault secrets enable -path=avp kv-v2    

kubectl exec -it vault-0 vault policy write argocd - <<EOF
path "*" {
  capabilities = ["read"]
}
EOF

kubectl exec -it vault-0 vault kv put avp/data/test sample=secret

exit

