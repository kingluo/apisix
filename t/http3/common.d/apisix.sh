ADMIN() {
    method=${1^^};
    resource=$2;
    shift 2;
    curl ${ADMIN_SCHEME:-http}://${ADMIN_IP:-127.0.0.1}:${ADMIN_PORT:-9180}/apisix/admin${resource} \
        -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' -X $method "$@"
    sleep 1
}

apisix_start() {
    if [[ ! -f ./logs/nginx.pid ]] && [[ -x ./bin/apisix ]]; then
        ./bin/apisix start
        sleep 3

        ADMIN put /ssls/1 -d '{
            "cert": "'"$(<${BURL_ROOT}/examples/server.crt)"'",
            "key": "'"$(<${BURL_ROOT}/examples/server.key)"'",
            "snis": [
                "localhost"
            ]
        }'
    fi
}
