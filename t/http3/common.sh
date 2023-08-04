#!/usr/bin/env bash
set -euo pipefail
set -x

ADMIN() {
    method=${1^^};
    resource=$2;
    shift 2;
    curl ${ADMIN_SCHEME:-http}://${ADMIN_IP:-127.0.0.1}:${ADMIN_PORT:-9180}/apisix/admin${resource} \
        -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' -X $method "$@"
}

GREP() {
    grep "$@" ${tmpfile}-1
}

GREP_BODY() {
    grep "$@" ${tmpfile}-2
}

JQ() {
    jq -e "$@" < ${tmpfile}-2
}

cleanup() {
    eval rm -f "${tmpfile}*"
}

REQ() {
    eval rm -f "${tmpfile}*"
    curl -s -i -k https://localhost:9443"$@" &>${tmpfile}
    err=$?
    if [[ $err != 0 ]]; then
        if [[ $1 == "retry" ]]; then
            curl -s -v -k https://localhost:9443"$@"
        fi
        return $err
    fi

    # split the response into headers and body
    path=${tmpfile}-1
    while read -r line; do
        echo $line | sed 's/ \r//g' | sed 's/\r//g' >> $path
        if [[ "$line" == $'\r' ]]; then
            path=${tmpfile}-2
        fi
    done < ${tmpfile}
    #cat ${tmpfile}-1 ${tmpfile}-2
}

if [[ ! -f ./logs/nginx.pid ]]; then
    ./bin/apisix start
fi

tmpfile=$(mktemp)
trap cleanup EXIT INT TERM

ADMIN put /ssls/1 -d '{
    "cert": "'"$(<$(dirname "$0")/server.crt)"'",
    "key": "'"$(<$(dirname "$0")/server.key)"'",
    "snis": [
        "localhost"
    ]
}'

