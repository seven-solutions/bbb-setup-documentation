#!/bin/bash

TURN_SERVER=turn.datenanfragen.de
REALM=datenanfragen.de
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
CONFIG_URL=https://raw.githubusercontent.com/seven-solutions/bbb-setup-documentation/master/

add-apt-repository ppa:certbot/certbot
apt update
apt -y upgrade
apt -y install coturn certbot

# SSL
certbot certonly --standalone --preferred-challenges http --deploy-hook "systemctl restart coturn" -d $TURN_SERVER

# Coturn
wget $CONFIG_URL/turn/turnserver.conf -O /etc/turnserver.conf
sed -e "s|%TURN_SERVER|$TURN_SERVER|g" -i /etc/turnserver.conf
sed -e "s|%REALM|$REALM|g" -i /etc/turnserver.conf
AUTH_SECRET=$(openssl rand -hex 25)
sed -e "s|%AUTH_SECRET|$AUTH_SECRET|g" -i /etc/turnserver.conf

echo "Auth Secret: $AUTH_SECRET"

wget $CONFIG_URL/turn/logrotate -O /etc/logrotate.d/turn

touch /etc/default/coturn
echo "TURNSERVER_ENABLED=1" > /etc/default/coturn
systemctl start coturn

# Firewall
ufw default deny
ufw allow ssh
ufw allow 443
ufw allow 3478
ufw allow 49152:65535/udp
