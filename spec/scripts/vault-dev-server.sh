#!/bin/bash

set -e
# set -x

export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_DEV_ROOT_TOKEN_ID=root-token
export VAULT_TOKEN=root-token

{
sleep 2
path="test-ca"
description="Test CA"
vault mount -path "${path}" -description "${description}" pki
vault mount-tune -max-lease-ttl=87600h "${path}"
vault write "${path}/root/generate/internal" \
    common_name="${description}" \
    ttl=87600h
vault write "${path}/roles/client" \
    allow_any_name=true \
    max_ttl="720h" \
    server_flag=true \
    client_flag=true
vault write "${path}/roles/server" \
    allow_any_name=true \
    max_ttl="720h" \
    server_flag=false \
    client_flag=true

for role in client server; do
    vault policy-write "${path}-${role}" - <<EOF
path "${path}/sign/${role}" {
    capabilities = ["create","read","update"]
}
EOF
    token_role="auth/token/roles/${path}-${role}"
    vault write "${token_role}" \
        period="720h" \
        orphan=true \
        allowed_policies="default,${path}-${role}" \
        path_suffix="${path}-${role}"
    vault policy-write "${path}-${role}-creator" - <<EOF
path "auth/token/create/${path}-${role}" {
    capabilities = ["create","read","update"]
}
EOF
    vault token-create \
        -id="init-token-${role}" \
        -display-name="${path}-${role}-creator" \
        -orphan \
        -ttl="8760h" \
        -period="8760h" \
        -policy="${path}-${role}-creator"
done

}&

exec vault server -dev
