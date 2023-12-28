shopt -s expand_aliases

SET() {
    set +e
    read -r -d '' $1
    set -e
}

TEST() {
    echo ">>> $@"
}

CURL_TMP=$(mktemp)

REQ() {
    curl ${TEST_SCHEME:-https}://${TEST_HOST:-localhost}:${TEST_PORT:-443}"$@" \
        -k -s -S -v -o ${CURL_TMP}-body 2>&1 | tee ${CURL_TMP}
    grep -E '^< \w+' ${CURL_TMP} | \
        sed 's/< //g; s/ \r//g; s/\r//g' > ${CURL_TMP}-headers
}

HEADER() {
    grep "$@" ${CURL_TMP}-headers
}

BODY() {
    grep "$@" ${CURL_TMP}-body
}

JQ() {
    jq -e "$@" < ${CURL_TMP}-body
}

XMLTODICT='
import sys
import xmltodict
with open(sys.argv[1]) as fd:
    body=xmltodict.parse(fd.read())
exit(eval(sys.argv[2]))
'

XML() {
    set +e
    python3 -c "${XMLTODICT}" "${CURL_TMP}-body" "$@"
    local ret=$?
    set -e
    [[ $ret -eq 1 ]]
}

GC_FN_LIST=()

GC() {
    GC_FN_LIST+=("$@")
}

GC_CLEANUP() {
    set +e
    local tmp=()
    for ((i=${#GC_FN_LIST[@]}-1; i>=0; i--)); do
        eval "${GC_FN_LIST[$i]}"
    done
    set -e
}

GC "rm -f ${CURL_TMP}{,-headers,-body}"
trap GC_CLEANUP EXIT INT TERM

BURL() {
    BURL_EXT=$1
    local start_fn="${BURL_EXT}_start"
    if declare -F "${start_fn}" >/dev/null; then
        eval "${start_fn}"
    fi
}

BURL_STOP() {
    if [[ "${BURL_EXT:-}" != "" ]]; then
        local stop_fn="${BURL_EXT}_stop"
        if declare -F "${stop_fn}" >/dev/null; then
            eval "${stop_fn}"
        fi
    fi
    unset TEST_SCHEME TEST_HOST TEST_PORT BURL_EXT
}

for ext in ${BURL_ROOT}/common.d/*.sh; do
    . $ext
done
