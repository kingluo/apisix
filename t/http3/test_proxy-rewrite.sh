#!/usr/bin/env bash
set -euo pipefail
set -x

. $(dirname "$0")/common.sh

## TEST 1: test basic config of proxy-rewrite plugin

# configure apisix
ADMIN put /apisix/admin/routes/1 -s -d '{
    "uri": "/httpbin/*",
    "plugins": {
        "proxy-rewrite": {
          "headers": {
            "set": {
              "Accept-Encoding": "identity"
            }
          },
          "uri": "/httpbin/get",
          "host": "foo.bar"
        },                                                                                                                                                                      "serverless-pre-function": {                                                                                                                                                "phase": "access",                                                                                                                                                      "functions": [
                "return function(conf,ctx)
                    assert(ctx.var.http3 == \"h3\")
                end"
            ]
        }
    },
    "upstream": {
        "scheme": "https",
        "type": "roundrobin",
        "nodes": {
            "nghttp2.org": 1
        }
    }
}'

# send request
REQ /httpbin/anything --http3-only

# validate the response headers
GREP "HTTP/3 200"

# validate the response body, e.g. JSON body
JQ '.headers.Host=="foo.bar"'

## TEST 2: test others
## ...
