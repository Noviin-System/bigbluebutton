#!/bin/bash

# Check args
if [ "$#" -lt 4 ]; then
    echo "Usage: $0 <NEW_DOMAIN> <NEW_IP/CIDR> <GATEWAY> <DNS_SERVERS_SPACE_SEPARATED>"
    echo "Example: $0 sy101.limsclass.ir 78.110.122.163/29 172.27.3.133 \"217.218.127.127 217.218.155.155\""
    exit 1
fi

NEW_DOMAIN=$1
NEW_IP_CIDR=$2
GATEWAY=$3
DNS_SERVERS=$4

# Machine to replace (Master VM)
OLD_DOMAIN="am024.limsclass.ir"
OLD_IP="212.80.21.148"

# extract IP without CIDR
NEW_IP=$(echo "$NEW_IP_CIDR" | cut -d'/' -f1)

echo "[1/7] Cleaning old Netplan configurations and generating new one..."
rm -f /etc/netplan/*.yaml
NETPLAN_FILE="/etc/netplan/50-cloud-init.yaml"

# Correct DNS format for Netplan
DNS_FORMATTED=$(echo "$DNS_SERVERS" | sed "s/ /', '/g")

cat <<EOF > "$NETPLAN_FILE"
network:
  ethernets:
    ens160:
      addresses:
        - $NEW_IP_CIDR
      routes:
        - to: 0.0.0.0/0
          via: $GATEWAY
          on-link: yes
      nameservers:
        addresses: ['$DNS_FORMATTED']
  version: 2
EOF
chmod 600 "$NETPLAN_FILE"

echo "[2/7] Renaming SSL Certificates..."
cp /etc/nginx/ssl/$OLD_DOMAIN.crt /etc/nginx/ssl/$NEW_DOMAIN.crt 2>/dev/null || true
rm /etc/nginx/ssl/$OLD_DOMAIN.crt
cp /etc/nginx/ssl/$OLD_DOMAIN.key /etc/nginx/ssl/$NEW_DOMAIN.key 2>/dev/null || true
rm /etc/nginx/ssl/$OLD_DOMAIN.key

echo "[3/7] Updating Nginx SSL paths..."
NGINX_CONF="/etc/nginx/sites-available/bigbluebutton"
if [ -f "$NGINX_CONF" ]; then
    sed -i "s|server_name .*|server_name $NEW_DOMAIN;|g" "$NGINX_CONF"
    sed -i "s|ssl_certificate .*|ssl_certificate /etc/nginx/ssl/$NEW_DOMAIN.crt;|g" "$NGINX_CONF"
    sed -i "s|ssl_certificate_key .*|ssl_certificate_key /etc/nginx/ssl/$NEW_DOMAIN.key;|g" "$NGINX_CONF"
fi

echo "[4/7] Updating STUN server domains..."
# Fix turn-stun-servers.xml directory
TURN_XML="/etc/bigbluebutton/turn-stun-servers.xml"
if [ -f "$TURN_XML" ]; then
    sed -i "s/$OLD_DOMAIN/$NEW_DOMAIN/g" "$TURN_XML"
fi

echo "[4.5/7] Updating bbb-web.properties domains..."
BBB_WEB_PROP="/etc/bigbluebutton/bbb-web.properties"
sed -i "s/$OLD_DOMAIN/$NEW_DOMAIN/g" "$BBB_WEB_PROP"


# echo "[5/7] Fixing FreeSWITCH, SIP, and SFU internal IP configurations..."

# # 5.1 Update FreeSWITCH IP
FS_VARS="/opt/freeswitch/etc/freeswitch/vars.xml"
if [ -f "$FS_VARS" ]; then
     sed -i "s|<X-PRE-PROCESS cmd=\"set\" data=\"local_ip_v4=.*\"/>|<X-PRE-PROCESS cmd=\"set\" data=\"local_ip_v4=$NEW_IP\"/>|g" "$FS_VARS"
# Dont need these two line
#     sed -i "s|<X-PRE-PROCESS cmd=\"set\" data=\"external_rtp_ip=.*\"/>|<X-PRE-PROCESS cmd=\"set\" data=\"external_rtp_ip=$NEW_IP\"/>|g" "$FS_VARS"
#     sed -i "s|<X-PRE-PROCESS cmd=\"set\" data=\"external_sip_ip=.*\"/>|<X-PRE-PROCESS cmd=\"set\" data=\"external_sip_ip=$NEW_IP\"/>|g" "$FS_VARS"
fi

# 5.2 Update SIP Nginx configuration
SIP_NGINX="/usr/share/bigbluebutton/nginx/sip.nginx"
if [ -f "$SIP_NGINX" ]; then
    # Replace new ip by old ips
    sed -i "s/$OLD_IP/$NEW_IP/g" "$SIP_NGINX"
    # Make sure proxy pass by 7443 port
    sed -i "s|proxy_pass .*|proxy_pass https://$NEW_IP:7443;|g" "$SIP_NGINX"
fi




echo "[*] Configuring systemd override and user lingering for bigbluebutton..."
# Enable lingering for bigbluebutton user
loginctl enable-linger bigbluebutton

# Dynamically get UID of bigbluebutton
BBB_UID=$(id -u bigbluebutton)

# Deploy systemd drop-in override
mkdir -p /etc/systemd/system/bbb-web.service.d/
cat <<EOF > /etc/systemd/system/bbb-web.service.d/override.conf
[Service]
LimitNOFILE=65536
LimitNOFILESoft=65536
TasksMax=infinity
Environment="XDG_RUNTIME_DIR=/run/user/${BBB_UID}"
EOF

systemctl daemon-reload

echo "[*] Tuning systemd journald log limits..."
sed -i 's/^#*SystemMaxUse=.*/SystemMaxUse=500M/' /etc/systemd/journald.conf
sed -i 's/^#*SystemMaxFileSize=.*/SystemMaxFileSize=100M/' /etc/systemd/journald.conf
systemctl restart systemd-journald



# Dont need these lines
# # 5.3 Update SFU IP using yq
# SFU_YML="/etc/bigbluebutton/bbb-webrtc-sfu/production.yml"
# if [ -f "$SFU_YML" ]; then
#     yq e -i ".freeswitch.sip_ip = \"$NEW_IP\"" "$SFU_YML"
#     chown bigbluebutton:bigbluebutton "$SFU_YML"
# fi


echo "[*] Fixing Nginx server_name..."
NGINX_CONF="/etc/nginx/sites-available/bigbluebutton"
if [ -f "$NGINX_CONF" ]; then
    sed -i "s/$OLD_IP/$NEW_IP/g" "$NGINX_CONF"
fi

echo "[*] Setting up Nginx ERP redirect and VHost for ${NEW_DOMAIN}..."

# 1. Place the modular drop-in redirect
cat << 'EOF' > /etc/bigbluebutton/nginx/erp-redirect.nginx
location = /b {
    return 301 /bigbluebutton;
}
EOF

# 2. Update the main VHost domain and SSL paths
sed -i "s/$OLD_DOMAIN/$NEW_DOMAIN/g" /etc/nginx/sites-available/bigbluebutton

# 3. Validate and reload Nginx
nginx -t && systemctl reload nginx


# Dont need these lines
# echo "[*] Fixing SFU announced IPs..."
# SFU_YML="/etc/bigbluebutton/bbb-webrtc-sfu/production.yml"
# if [ -f "$SFU_YML" ]; then
#     yq e -i ".mediasoup.webrtc.ipv4.announcedIp = \"$NEW_IP\"" "$SFU_YML"
#     yq e -i ".mediasoup.plainRtp.ipv4.announcedIp = \"$NEW_IP\"" "$SFU_YML"
#     chown bigbluebutton:bigbluebutton "$SFU_YML"
# fi


echo "[*] Updating IPs in bbb-webrtc-sfu default.yml..."
SFU_DEFAULT_YML="/usr/local/bigbluebutton/bbb-webrtc-sfu/config/default.yml"
if [ -f "$SFU_DEFAULT_YML" ]; then
    sed -i "s/$OLD_IP/$NEW_IP/g" "$SFU_DEFAULT_YML"
fi


echo "[*] Updating IPs and Domains in turnserver.conf..."
TURN_SERVER="/etc/turnserver.conf"
if [ -f "$TURN_SERVER" ]; then
    sed -i "s/$OLD_IP/$NEW_IP/g" "$TURN_SERVER"
    sed -i "s/$OLD_DOMAIN/$NEW_DOMAIN/g" "$TURN_SERVER"
fi

echo "[*] Updating IPs and Domains in hosts..."
HOSTS="/etc/hosts"
if [ -f "$HOSTS" ]; then
    sed -i "s/$OLD_IP/$NEW_IP/g" "$HOSTS"
    sed -i "s/$OLD_DOMAIN/$NEW_DOMAIN/g" "$HOSTS"
fi

#web rtc ports
sudo ufw allow 16384:32768/udp

#setup ip
echo "[6/7] Running bbb-conf --setip..."
bbb-conf --setip "$NEW_DOMAIN"

# setup secret
echo "[*] Generating a new random Secret Key..."
NEW_SECRET=$(openssl rand -hex 16)
bbb-conf --setsecret "$NEW_SECRET"

echo "[7/7] Cleaning and Restarting BBB services..."
bbb-conf --clean
bbb-conf --restart

echo "===================================================="
echo " BigBlueButton configuration updated successfully!"
echo "===================================================="

echo "Applying netplan..."
netplan apply