#!/bin/sh

random() {
    tr </dev/urandom -dc A-Za-z0-9 | head -c5
    echo
}

array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)
gen64() {
    ip64() {
        echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
    }
    echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}

gen_3proxy() {
    cat <<EOF
nserver 8.8.8.8
nserver 8.8.4.4
nserver 2001:4860:4860::8888
nserver 2001:4860:4860::8844
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
log /var/log/3proxy.log
logformat "L%t|%n|%e|%a|%r|%T|%c|%C|%R|%D"
rotate 30

internal 207.148.64.221
external 2001:19f0:4400:5206::1

auth none
allow * * *

# Proxy and SOCKS ports range
for ((port=10000; port<=20000; port++)); do
    proxy -p$port
    socks -p$port
done
EOF
}

gen_proxy_file_for_user() {
    cat >proxy.txt <<EOF
$(awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' ${WORKDATA})
EOF
}

upload_proxy() {
    local PASS=$(random)
    zip --password $PASS proxy.zip proxy.txt
    echo "Proxy list:"
    cat proxy.txt

    echo "Proxy is ready! Format IP:PORT:LOGIN:PASS"
    echo "Password for zip file: ${PASS}"
}

gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "usr$(random)/pass$(random)/$IP4/$port/$(gen64 $IP6)"
    done
}

gen_iptables() {
    cat <<EOF
$(awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA})
EOF
}

gen_ifconfig() {
    cat <<EOF
$(awk -F "/" '{print "ifconfig eth0 inet6 add " $5 "/64"}' ${WORKDATA})
EOF
}

echo "installing apps"
yum -y install gcc net-tools bsdtar zip curl iptables-services make gcc-c++ zlib-devel openssl-devel pcre-devel >/dev/null

echo "working folder = /home/proxy-installer"
WORKDIR="/home/proxy-installer"
WORKDATA="${WORKDIR}/data.txt"
mkdir -p $WORKDIR && cd $_

IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "Internal ip = ${IP4}. External sub for ip6 = ${IP6}"

echo "How many proxy do you want to create? Example 500"
read COUNT

FIRST_PORT=10000
LAST_PORT=$(($FIRST_PORT + $COUNT))

gen_data >$WORKDIR/data.txt
gen_iptables >$WORKDIR/boot_iptables.sh
gen_ifconfig >$WORKDIR/boot_ifconfig.sh
chmod +x ${WORKDIR}/boot_*.sh

gen_3proxy >/etc/3proxy.cfg

sudo systemctl restart NetworkManager
sudo systemctl restart 3proxy

cat >/usr/lib/systemd/system/3proxy.service <<EOF
[Unit]
Description=3proxy Proxy Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/3proxy /etc/3proxy.cfg
ExecReload=/bin/kill -HUP \$MAINPID
ExecStop=/bin/kill -TERM \$MAINPID
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable 3proxy
systemctl start 3proxy

gen_proxy_file_for_user

upload_proxy
