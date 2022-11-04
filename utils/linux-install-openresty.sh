#!/usr/bin/env bash
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
set -euo pipefail

ARCH=${ARCH:-`(uname -m | tr '[:upper:]' '[:lower:]')`}
arch_path=""
if [[ $ARCH == "arm64" ]] || [[ $ARCH == "aarch64" ]]; then
    arch_path="arm64/"
fi

wget -qO - https://openresty.org/package/pubkey.gpg | sudo apt-key add -
sudo apt-get -y update --fix-missing
sudo apt-get -y install software-properties-common
sudo add-apt-repository -y "deb https://openresty.org/package/${arch_path}ubuntu $(lsb_release -sc) main"

sudo apt-get update

abt_branch=${abt_branch:="master"}

if [ "$OPENRESTY_VERSION" == "source" ]; then
    # openssl 3.0 with openresty patch and fips enabled
    sudo apt install -y build-essential
    git clone https://github.com/openssl/openssl
    cd openssl
    patch -p1 < ../openssl-3.0-sess_set_get_cb_yield.patch
    ./Configure enable-fips
    sudo make install
    sudo /usr/local/bin/openssl fipsinstall -out /usr/local/ssl/fipsmodule.cnf -module /usr/local/lib64/ossl-modules/fips.so
    sudo cp -a ../openssl.cnf /usr/local/ssl/
    sudo bash -c 'echo /usr/local/lib64 > /etc/ld.so.conf.d/lib64.conf'
    sudo ldconfig
    export cc_opt="-I/usr/local/include"
    export ld_opt="-L/usr/local/lib64 -Wl,-rpath,/usr/local/lib64"
    cd ..

    cd ..
    wget https://raw.githubusercontent.com/api7/apisix-build-tools/$abt_branch/build-apisix-base.sh
    chmod +x build-apisix-base.sh
    ./build-apisix-base.sh latest

    exit 0
fi

if [ "$OPENRESTY_VERSION" == "default" ]; then
    openresty='openresty-debug'
else
    openresty="openresty-debug=$OPENRESTY_VERSION*"
fi

sudo apt-get install "$openresty" openresty-openssl111-debug-dev libldap2-dev
