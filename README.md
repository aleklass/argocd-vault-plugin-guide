# argocd-vault-plugin-guide
This guide is just for helping purposes

# references: 

- https://github.com/IBM/argocd-vault-plugin
- https://itnext.io/argocd-secret-management-with-argocd-vault-plugin-539f104aff05

# Install argocd

File name: argocd.yaml

$ kubectl create ns argocd

$ kubectl apply -f argocd.yaml -n argocd

$ kubectl apply -f argocd-vault-plugin-credentials.yaml -n argocd

Configure cluster, like changing password and integrate cluster with argo.

Ref: https://argoproj.github.io/argo-cd/getting_started/

---
# Install vault:

## Commands:

$ helm repo add hashicorp https://helm.releases.hashicorp.com

$ helm install vault hashicorp/vault

---
There are 3 modes choose, what is best for you.

STANDALONE MODE:                                       

$ helm install vault hashicorp/vault

HA MODE:

$ helm install vault hashicorp/vault \
    --set "server.ha.enabled=true"

---

$ helm install vault hashicorp/vault

$ kubectl get pods -l app.kubernetes.io/name=vault

$ kubectl exec -ti vault-0 -- vault operator init

### Unseal the first vault server until it reaches the key threshold

$ kubectl exec -ti vault-0 -- vault operator unseal # ... Unseal Key 1

$ kubectl exec -ti vault-0 -- vault operator unseal # ... Unseal Key 2

$ kubectl exec -ti vault-0 -- vault operator unseal # ... Unseal Key 3

kubectl get pods -l app.kubernetes.io/name=vault   

It should be running 1/1 after been unsealed.

---

## Enable Kubernetes Authentication

$ kubectl exec --stdin=true --tty=true vault-0 -- /bin/sh

$ vault login

$ vault auth enable kubernetes

---
$ vault write auth/kubernetes/config \
    token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
    kubernetes_host=(cluster-ip# kubectl cluster-info):<your TCP port or blank for 443> \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

- Wildcard can be used for path as well.

---

$ vault policy write argocd - <<EOF
path "avp/data/test" {
  capabilities = ["read"]
}
EOF

---

$ vault write auth/kubernetes/role/argocd \
    bound_service_account_names=default \
    bound_service_account_namespaces=argocd \
    policies=argocd \
    ttl=1h

---

$ vault secrets enable -path=avp kv-v2
$ vault kv put avp/data/test sample=secret
$ vault kv get avp/data/test

---

kubectl apply -f clusterrolebinding

---

While adding plugin in the argocd deployment use these 2 env variables.

AVP_TYPE: vault
AVP_VAULT_ADDR: http://vault.default.svc.cluster.local:8200


refrences:

https://www.vaultproject.io/docs/platform/k8s/helm/run
https://learn.hashicorp.com/tutorials/vault/kubernetes-minikube?in=vault/kubernetes
https://www.vaultproject.io/docs/auth/kubernetes
