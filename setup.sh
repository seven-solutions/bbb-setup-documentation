#!/bin/bash

SERVER_URL=
SERVER_IPV4=
SERVER_IPV6=
# Email for Let's Encrypt
LE_EMAIL=
# TURN Server Credentials
TURN_SERVER=
TURN_SERVER_SECRET=

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
CONFIG_URL=https://raw.githubusercontent.com/seven-solutions/bbb-setup-documentation/master/

apt update
apt -y upgrade
apt -y install software-properties-common apt-transport-https ca-certificates curl gnupg-agent
add-apt-repository universe
add-apt-repository -y ppa:ondrej/nginx-mainline # We need nginx to be compiled with OpenSSL ^1.1.1 to support TLSv1.3
add-apt-repository -y ppa:ondrej/nginx-qa
apt update
apt -y install certbot
apt -y install nginx openssl apache2-utils

wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-22 -s $SERVER_URL -e $LE_EMAIL -g

### Setup Hostname and SSL

mkdir -p /etc/nginx/ssl

wget $CONFIG_URL/bigbluebutton.nginx -O /etc/nginx/sites-available/bigbluebutton
rm /etc/nginx/sites-enabled/default
wget $CONFIG_URL/ssl.conf -O /etc/nginx/ssl/ssl.conf
sed -e "s|%SERVER_URL|$SERVER_URL|g" -i /etc/nginx/sites-available/bigbluebutton
sed -e "s|%SERVER_URL|$SERVER_URL|g" -i /etc/nginx/ssl/ssl.conf
if [ ! -f /etc/nginx/ssl/dhp-4096.pem ]; then
    openssl dhparam -out /etc/nginx/ssl/dhp-4096.pem 4096
fi


### IPv6

# /etc/nginx/conf.d/bigbluebutton_sip_addr_map.conf
wget $CONFIG_URL/bigbluebutton_sip_addr_map.conf -O /etc/nginx/conf.d/bigbluebutton_sip_addr_map.conf
sed -e "s|%SERVER_IPV4|$SERVER_IPV4|g" -i /etc/nginx/conf.d/bigbluebutton_sip_addr_map.conf
sed -e "s|%SERVER_IPV6|$SERVER_IPV6|g" -i /etc/nginx/conf.d/bigbluebutton_sip_addr_map.conf

# /etc/bigbluebutton/nginx/sip.nginx
wget $CONFIG_URL/sip.nginx -O /etc/bigbluebutton/nginx/sip.nginx
# /opt/freeswitch/conf/sip_profiles/external_ipv6.xml
wget $CONFIG_URL/external_ipv6.xml -O /opt/freeswitch/conf/sip_profiles/external_ipv6.xml

### Greenlight

cd ~/greenlight
wget $CONFIG_URL/.env -O .env

echo -e "# Secrects generated by the install script
BIGBLUEBUTTON_ENDPOINT=$(bbb-conf --secret | grep -oP 'URL: \Khttp(s)?://.*$')
BIGBLUEBUTTON_SECRET=$(bbb-conf --secret | grep -oP 'Secret: \K.*$')
SECRET_KEY_BASE=$(docker run --rm bigbluebutton/greenlight:v2 bundle exec rake secret)" >> .env
docker run --rm --env-file .env bigbluebutton/greenlight:v2 bundle exec rake conf:check
docker run --rm bigbluebutton/greenlight:v2 cat ./greenlight.nginx | sudo tee /etc/bigbluebutton/nginx/greenlight.nginx
docker run --rm bigbluebutton/greenlight:v2 cat ./docker-compose.yml > docker-compose.yml
pass=$(openssl rand -hex 8);
sed -i -e 's/POSTGRES_PASSWORD=password/POSTGRES_PASSWORD='$pass'/g' docker-compose.yml
sed -i -e 's/DB_PASSWORD=password/DB_PASSWORD='$pass'/g' .env
# TODO email

docker-compose up -d
bbb-conf --restart
docker exec greenlight-v2 bundle exec rake admin:create

### More privacy in recordings

sed -e 's|^history=[0-9]\?$|history=0|g' -i /etc/cron.daily/bigbluebutton
sed -e 's|^unrecorded_days=[0-9]\?$|unrecorded_days=0|g' -i /etc/cron.daily/bigbluebutton

### Firewall

apt -y install ufw
ufw default deny
ufw logging on
ufw allow http
ufw allow https
ufw allow ssh
ufw allow 16384:32768/udp
ufw status
ufw enable

### TURN & STUN

wget $CONFIG_URL/stun-turn-servers.xml -O /usr/share/bbb-web/WEB-INF/classes/spring/turn-stun-servers.xml
sed -e "s|%TURN_SERVER_SECRET|$TURN_SERVER_SECRET|g" -i /usr/share/bbb-web/WEB-INF/classes/spring/turn-stun-servers.xml
sed -e "s|%TURN_SERVER|$TURN_SERVER|g" -i /usr/share/bbb-web/WEB-INF/classes/spring/turn-stun-servers.xml

### Optional support for prometheus monitoring

wget https://github.com/prometheus/node_exporter/releases/download/v0.18.1/node_exporter-0.18.1.linux-amd64.tar.gz -O /tmp/node_exporter-0.18.1.linux-amd64.tar.gz
tar xvfz /tmp/node_exporter-0.18.1.linux-amd64.tar.gz -C /tmp/
mv /tmp/node_exporter-0.18.1.linux-amd64/node_exporter /usr/local/bin/node_exporter
rm -rf /tmp/node_exporter-0.18.1.linux-amd64
rm -f /tmp/node_exporter-0.18.1.linux-amd64.tar.gz
# /etc/bigbluebutton/nginx/metrics.nginx
wget $CONFIG_URL/metrics.nginx -O /etc/bigbluebutton/nginx/metrics.nginx
htpasswd -c /etc/bigbluebutton/nginx/.htpasswd metrics
wget $CONFIG_URL/node_exporter.service -O /etc/systemd/system/node_exporter.service
systemctl enable node_exporter
systemctl start node_exporter

mkdir -p /root/bbb-exporter
cd /root/bbb-exporter
wget $CONFIG_URL/bbb-exporter-docker.yml -O /root/bbb-exporter/docker-compose.yml
touch /root/bbb-exporter/secrets.env
echo -e "# Secrects generated by the install script
API_BASE_URL=$(bbb-conf --secret | grep -oP 'URL: \Khttp(s)?://.*$')api/
API_SECRET=$(bbb-conf --secret | grep -oP 'Secret: \K.*$')
" > /root/bbb-exporter/secrets.env
docker-compose up -d
