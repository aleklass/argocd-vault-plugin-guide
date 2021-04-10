#!/bin/bash
#creating namespace
kubectl create ns argocd
kubectl create ns vault
#installing credentials deployment
kubectl apply -f argocd-vault-plugin-credentials.yaml -n argocd
#installing argocd
kubectl apply -f argocd.yaml -n argocd
#installing vault using helm
helm install vault hashicorp/vault --namespace vault
read -p "Wait till Pods get ready" -t 180
# #read -n 1 -s -r -p "Press any key to continue"
echo "Continuing ...."
#checking pods
kubectl get pods -n argocd
read -n 1 -s -r -p "Press any key to continue"
kubectl get pods -l app.kubernetes.io/name=vault -n vault
read -n 1 -s -r -p "Press any key to continue"
#getting keys and token from vault
kubectl exec vault-0 -n vault -- vault operator init -key-shares=1 -key-threshold=1 -format=json > cluster-keys.json
cat cluster-keys.json
VAULT_UNSEAL_KEY=$(cat cluster-keys.json | jq -r ".unseal_keys_b64[]")
kubectl exec vault-0 -n vault -- vault operator unseal $VAULT_UNSEAL_KEY
# # kubectl exec vault-1 -n vault -- vault operator unseal $VAULT_UNSEAL_KEY
# # kubectl exec vault-2 -n vault -- vault operator unseal $VAULT_UNSEAL_KEY
# kubectl get pods -l app.kubernetes.io/name=vault -n vault
read -p "Vault pods should be running 1/1" -t 10
cat cluster-keys.json | jq -r ".root_token"
read -p "Copy Token Key" -t 10
echo "Enter Vault Token Here"
#kubectl exec --stdin=true --tty=true vault-0 -- /bin/sh
kubectl exec --stdin=true --tty=true vault-0 -n vault -- vault login
kubectl exec --stdin=true --tty=true vault-0 -n vault -- vault auth enable kubernetes 
kubectl exec --stdin=true --tty=true vault-0 -n vault -- vault write auth/kubernetes/config \
        token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token \
        kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
        kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

kubectl exec --stdin=true vault-0 -n vault -- vault write auth/kubernetes/role/argocd \
    bound_service_account_names=default \
    bound_service_account_namespaces=argocd \
    policies=argocd \
    ttl=1h

kubectl exec --stdin=true --tty=true vault-0 -n vault -- vault policy write argocd - <<EOF
path "*" {
  capabilities = ["read"]
}
EOF

kubectl exec --stdin=true --tty=true vault-0 -n vault -- vault secrets enable -path=avp kv-v2    

kubectl exec --stdin=true --tty=true vault-0 -n vault -- vault kv put avp/data/test sample=secret

kubectl apply -f clusterrolebinding.yaml 