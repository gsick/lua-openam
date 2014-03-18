#!/bin/sh
set -e

cd /tmp
wget https://github.com/pintsized/lua-resty-http/archive/v0.03.tar.gz
tar -zxvf v0.03.tar.gz
cd lua-resty-http-0.03
make PREFIX=/usr LUA_LIB_DIR=/usr/lib64/lua/5.1 install
cp /usr/lib64/lua/5.1/resty/http/http.lua /usr/lib64/lua/5.1/resty

cd /tmp
wget http://www.kyne.com.au/~mark/software/download/lua-cjson-2.1.0.tar.gz
tar -zxvf lua-cjson-2.1.0.tar.gz
cd lua-cjson-2.1.0
make
cp cjson.so /usr/lib64/lua/5.1

cd /tmp
git clone https://github.com/starwing/luautf8.git
cd luautf8
gcc -shared -fPIC -O3 lutf8lib.c -o utf8.so
cp utf8.so /usr/lib64/lua/5.1

