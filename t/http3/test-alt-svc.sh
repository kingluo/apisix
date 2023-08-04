#!/usr/bin/env bash
set -euo pipefail
set -x

. $(dirname "$0")/common.sh

echo TEST 1: test if alt-svc works

# configure apisix
ADMIN put /routes/1 -s -d '{
    "uri": "/httpbin/*",
    "upstream": {
        "scheme": "https",
        "type": "roundrobin",
        "nodes": {
            "nghttp2.org": 1
        }
    }
}'

REQ /httpbin/get --alt-svc altsvc.cache
GREP -x "HTTP/1.1 200 OK"

REQ /httpbin/get --alt-svc altsvc.cache
GREP -x "HTTP/3 200"

rm -f altsvc.cache
