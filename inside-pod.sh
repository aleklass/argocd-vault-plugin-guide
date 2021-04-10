#!/bin/bash
vault auth enable kubernetes 
vault write auth/kubernetes/config \
        token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
        kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
        kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

vault write auth/kubernetes/role/argocd \
    bound_service_account_names=default \
    bound_service_account_namespaces=argocd \
    policies=argocd \
    ttl=1h

vault -- vault policy write argocd - <<EOF
path "*" {
  capabilities = ["read"]
}
EOF

vault -- vault secrets enable -path=avp kv-v2    
vault -- vault kv put avp/data/test sample=secret
