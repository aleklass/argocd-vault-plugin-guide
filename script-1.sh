#!/bin/bash
#creating namespace
kubectl create ns argocd
#installing credentials deployment
kubectl apply -f argocd-vault-plugin-credentials.yaml -n argocd
#installing argocd
kubectl apply -f argocd.yaml -n argocd
#creating namespace
kubectl create ns vault
#installing vault using helm
helm install vault hashicorp/vault --set "server.ha.enabled=true" --namespace vault
#read -p "Pause Time 5 seconds" -t 180
read -p "Wait till Pods get ready" -t 180
#read -n 1 -s -r -p "Press any key to continue"
echo "Continuing ...."
#checking pods
kubectl get pods -l app.kubernetes.io/name=vault
#getting keys and token from vault
kubectl exec vault-0 -- vault operator init -key-shares=1 -key-threshold=1 -format=json > cluster-keys.json
cat cluster-keys.json | jq -r ".unseal_keys_b64[]"
VAULT_UNSEAL_KEY=$(cat cluster-keys.json | jq -r ".unseal_keys_b64[]")
kubectl exec vault-0 -- vault operator unseal $VAULT_UNSEAL_KEY
kubectl exec vault-1 -- vault operator unseal $VAULT_UNSEAL_KEY
kubectl exec vault-2 -- vault operator unseal $VAULT_UNSEAL_KEY
kubectl get pods -l app.kubernetes.io/name=vault
read -p "Vault pods should be running 1/1" -t 5
cat cluster-keys.json | jq -r ".root_token"
read -p "Token Key" -t 5
echo "Enter Vault Token Here"
kubectl exec -ti vault-0 -- vault login
kubectl exec -ti vault-0 -- vault auth enable kubernetes 
kubectl exec -ti vault-0 -- vault write auth/kubernetes/config \
        token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token \
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