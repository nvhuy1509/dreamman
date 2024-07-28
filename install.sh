#!/bin/bash

# Địa chỉ IPv4 của máy chủ
IPv4_ADDR="207.148.64.221"

# Cấu hình ban đầu cho 3proxy
cat > /etc/3proxy.cfg << EOF
daemon
maxconn 100
nserver 1.1.1.1
nserver 8.8.8.8
nscache 65536
log /var/log/3proxy/3proxy.log D
logformat "L%d-%m-%Y %H:%M:%S %N.%p %E %U %C:%c %R:%r %O %I %h %T"
auth none
EOF

# Thêm các proxy
for i in {1..5}; do
    # Tạo subnet IPv6 ngẫu nhiên
    SUBNET="2001:db8:$(($RANDOM % 10000))::"

    # Thêm các proxy listener cho mỗi subnet
    echo "proxy -6 -n -a -p3128$i -i$IPv4_ADDR -e$SUBNET" >> /etc/3proxy.cfg
done

# Khởi động lại 3proxy
systemctl restart 3proxy
