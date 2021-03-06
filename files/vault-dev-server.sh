#!/bin/bash

set -e

export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_DEV_ROOT_TOKEN_ID=root-token
export VAULT_TOKEN=root-token


function server {
    exec ${VAULT_CMD} server -dev -dev-listen-address="0.0.0.0:8200"
}

function download {
    if [ ! -x /tmp/vault-dev-bin  ]; then
        curl -sL -o /tmp/vault-dev.zip https://releases.hashicorp.com/vault/0.7.2/vault_0.7.2_linux_amd64.zip
        unzip /tmp/vault-dev.zip -d /tmp
        mv /tmp/vault ${VAULT_CMD}
        chmod +x ${VAULT_CMD}
        rm -f /tmp/vault-dev.zip
    fi
}

function config {
    while true; do
        STATUS=$(curl -s -o /dev/null -w '%{http_code}' "${VAULT_ADDR}/v1/sys/health" || true)
        if [ "${STATUS}" -eq 200 ]; then
            break
        fi
        sleep 1
    done

    path="test-ca"
    description="Test CA"
    ${VAULT_CMD} mount -path "${path}" -description "${description}" pki
    ${VAULT_CMD} mount-tune -max-lease-ttl=87600h "${path}"
    ${VAULT_CMD} write "${path}/root/generate/internal" \
        common_name="${description}" \
        ttl=87600h
    ${VAULT_CMD} write "${path}/roles/client" \
        allow_any_name=true \
        max_ttl="720h" \
        server_flag=true \
        client_flag=true \
        use_csr_sans=false \
        use_csr_common_name=false
    ${VAULT_CMD} write "${path}/roles/server" \
        allow_any_name=true \
        max_ttl="720h" \
        server_flag=false \
        client_flag=true \
        use_csr_sans=false \
        use_csr_common_name=false

    for role in client server; do
        ${VAULT_CMD} policy-write "${path}-${role}" - <<EOF
path "${path}/sign/${role}" {
    capabilities = ["create","read","update"]
}
EOF
        token_role="auth/token/roles/${path}-${role}"
        ${VAULT_CMD} write "${token_role}" \
            period="720h" \
            orphan=true \
            allowed_policies="default,${path}-${role}" \
            path_suffix="${path}-${role}"
        ${VAULT_CMD} policy-write "${path}-${role}-creator" - <<EOF
path "auth/token/create/${path}-${role}" {
    capabilities = ["create","read","update"]
}
EOF
        ${VAULT_CMD} token-create \
            -id="init-token-${role}" \
            -display-name="${path}-${role}-creator" \
            -orphan \
            -ttl="8760h" \
            -period="8760h" \
            -policy="${path}-${role}-creator"
    done

}

case "$1" in
    download)
        download
        ;;
    config)
        config
        ;;
    server)
        server
        ;;
    *)
        echo "Usage: $0 {download|config|server}"
        exit 1
esac
