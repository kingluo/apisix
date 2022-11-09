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

COMPILE_OPENSSL3=${COMPILE_OPENSSL3-no}
USE_OPENSSL3=${USE_OPENSSL3-no}

if [ "$OPENRESTY_VERSION" == "source" ]; then
    if [ "$COMPILE_OPENSSL3" == "yes" ]; then
        sudo apt install -y build-essential
        git clone https://github.com/openssl/openssl
        cd openssl
        ./Configure --prefix=/usr/local/openssl-3.0 enable-fips
        sudo make install
        sudo bash -c 'echo /usr/local/openssl-3.0/lib64 > /etc/ld.so.conf.d/openssl3.conf'
        sudo ldconfig
        sudo /usr/local/openssl-3.0/bin/openssl fipsinstall -out /usr/local/openssl-3.0/ssl/fipsmodule.cnf -module /usr/local/openssl-3.0/lib64/ossl-modules/fips.so
        sudo sed -i 's@# .include fipsmodule.cnf@.include /usr/local/openssl-3.0/ssl/fipsmodule.cnf@g; s/# \(fips = fips_sect\)/\1\nbase = base_sect\n\n[base_sect]\nactivate=1\n/g' /usr/local/openssl-3.0/ssl/openssl.cnf
        cd ..
    fi

    if [ "$USE_OPENSSL3" == "yes" ]; then
        sudo bash -c 'echo /usr/local/openssl-3.0/lib64 > /etc/ld.so.conf.d/openssl3.conf'
        sudo ldconfig
        export cc_opt="-I/usr/local/openssl-3.0/include"
        export ld_opt="-L/usr/local/openssl-3.0/lib64 -Wl,-rpath,/usr/local/openssl-3.0/lib64"
    fi

    cd ..
    wget https://raw.githubusercontent.com/api7/apisix-build-tools/$abt_branch/build-apisix-base.sh
    chmod +x build-apisix-base.sh
    ./build-apisix-base.sh latest

    sudo apt-get install openresty-openssl111-debug-dev
    exit 0
fi

if [ "$OPENRESTY_VERSION" == "default" ]; then
    openresty='openresty-debug'
else
    openresty="openresty-debug=$OPENRESTY_VERSION*"
fi

sudo apt-get install "$openresty" openresty-openssl111-debug-dev libldap2-dev
