#!/usr/bin/env burl

# Configure apisix, nginx or any other proxy
#ADMIN put /routes/1 -s -d '{
#    "uri": "/httpbin/*",
#    "upstream": {
#        "scheme": "https",
#        "type": "roundrobin",
#        "nodes": {
#            "nghttp2.org": 1
#        }
#    }
#}'

# Or, request to the server directly
TEST_HOST=nghttp2.org



TEST 1: simple GET

REQ /httpbin/get --http3-only

HEADER "HTTP/3 200"
BODY '"Host": "nghttp2.org",'
JQ '.headers["Host"] == "nghttp2.org"'



#TEST 2: another test
#...
