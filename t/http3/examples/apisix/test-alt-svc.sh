#!/usr/bin/env burl

# configure apisix
BURL apisix

TEST_PORT=9443

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



TEST 1: check if alt-svc works

altsvc_cache=$(mktemp)
GC "rm -f ${altsvc_cache}"

REQ /httpbin/get -k --alt-svc ${altsvc_cache}
HEADER -x "HTTP/1.1 200 OK"

REQ /httpbin/get -k --alt-svc ${altsvc_cache}
HEADER -x "HTTP/3 200"
