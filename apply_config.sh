#!/bin/bash
# /etc/bigbluebutton/bbb-conf/apply-config.sh

source /etc/bigbluebutton/bbb-conf/apply-lib.sh
enableUFWRules

# bigbluebutton.properties
sed -i 's/appLogLevel=.*/appLogLevel=Error/g' /usr/share/bbb-web/WEB-INF/classes/bigbluebutton.properties
sed -i 's/defaultWelcomeMessage=.*/defaultWelcomeMessage=Welcome to <b>%%CONFNAME%%<\/b>!<br>some sample text <a href="event:http:\/\/www.bigbluebutton.org\/html5"><u>link text<\/u><\/a>.<br><br>Other stuff/g' /usr/share/bbb-web/WEB-INF/classes/bigbluebutton.properties
sed -i 's/defaultWelcomeMessageFooter=.*/defaultWelcomeMessageFooter=This server runs on muffins! <a href="https:\/\/your-website.tld\/" target="_blank"><u>your website name<\/u><\/a>./g' /usr/share/bbb-web/WEB-INF/classes/bigbluebutton.properties
sed -i 's/defaultMaxUsers=.*/defaultMaxUsers=150/g' /usr/share/bbb-web/WEB-INF/classes/bigbluebutton.properties
sed -i 's/maxInactivityTimeoutMinutes=.*/maxInactivityTimeoutMinutes=35/g' /usr/share/bbb-web/WEB-INF/classes/bigbluebutton.properties
sed -i 's/warnMinutesBeforeMax=.*/warnMinutesBeforeMax=5/g' /usr/share/bbb-web/WEB-INF/classes/bigbluebutton.properties
sed -i 's/meetingExpireIfNoUserJoinedInMinutes=.*/meetingExpireIfNoUserJoinedInMinutes=5/g' /usr/share/bbb-web/WEB-INF/classes/bigbluebutton.properties
sed -i 's/meetingExpireWhenLastUserLeftInMinutes=.*/meetingExpireWhenLastUserLeftInMinutes=1/g' /usr/share/bbb-web/WEB-INF/classes/bigbluebutton.properties
sed -i 's/userInactivityThresholdInMinutes=.*/userInactivityThresholdInMinutes=30/g' /usr/share/bbb-web/WEB-INF/classes/bigbluebutton.properties
sed -i 's/userActivitySignResponseDelayInMinutes=.*/userActivitySignResponseDelayInMinutes=0/g' /usr/share/bbb-web/WEB-INF/classes/bigbluebutton.properties
sed -i 's/keepEvents=.*/keepEvents=false/g' /usr/share/bbb-web/WEB-INF/classes/bigbluebutton.properties
sed -i 's/breakoutRoomsRecord=.*/breakoutRoomsRecord=false/g' /usr/share/bbb-web/WEB-INF/classes/bigbluebutton.properties

# Kurento settings
yq w -i /usr/share/meteor/bundle/programs/server/assets/app/config/settings.yml public.kurento.cameraProfiles.[0].name 'Niedrig'
yq w -i /usr/share/meteor/bundle/programs/server/assets/app/config/settings.yml public.kurento.cameraProfiles.[1].name 'Normal'
yq w -i /usr/share/meteor/bundle/programs/server/assets/app/config/settings.yml public.kurento.cameraProfiles.[2].name 'Hoch (nur Teilnehmer_innen)'
yq w -i /usr/share/meteor/bundle/programs/server/assets/app/config/settings.yml public.kurento.cameraProfiles.[3].name 'Hoch (nur Presentator_innen)'
yq w -i /usr/local/bigbluebutton/bbb-webrtc-sfu/config/default.yml log.level 'error'
sed -e 's|^export GST_DEBUG=\(.*\)\?|export GST_DEBUG="1"|g' -i /etc/default/kurento-media-server

# Static file content
cat 'Nothing to see here.' > /var/www/bigbluebutton-default/index.html
cp /var/www/bigbluebutton-default/default_modified.pdf /var/www/bigbluebutton-default/default.pdf
cp /var/www/bigbluebutton-default/default_modified.pptx /var/www/bigbluebutton-default/default.pptx
cp /var/www/bigbluebutton-default/images/favicon_modified.ico /var/www/bigbluebutton-default/images/favicon.ico

# STUN
sed -i 's/stun:stun.freeswitch.org/stun:%TURN_SERVER/g' /usr/share/bbb-web/WEB-INF/classes/spring/turn-stun-servers.xml

# Log and cache retention
sed -e 's|^history=[0-9]*\?$|history=0|g' -i /etc/cron.daily/bigbluebutton
sed -e 's|^unrecorded_days=[0-9]*\?$|unrecorded_days=0|g' -i /etc/cron.daily/bigbluebutton
sed -e 's|^published_days=[0-9]*\?$|published_days=1|g' -i /etc/cron.daily/bigbluebutton
sed -e 's|^log_history=[0-9]*\?$|log_history=7|g' -i /etc/cron.daily/bigbluebutton
sed -e 's|rotate [0-9]*\?$|rotate 7|g' -i /etc/logrotate.d/bbb-record-core.logrotate
sed -e 's|rotate [0-9]*\?$|rotate 7|g' -i /etc/logrotate.d/bbb-webrtc-sfu.logrotate

# Freeswitch
sed -e 's|loglevel = "DEBUG"\?$|loglevel = "ERROR"|g' -i /etc/bbb-fsesl-akka/application.conf
sed -e 's|<logger name="\(.*\)" level=".*" />|\<logger name="\1" level="ERROR" />|g' -i /etc/bbb-fsesl-akka/logback.xml

# Red5
sed -e 's|<level .*/></logger>|\<level value="ERROR"/></logger>|g' -i /etc/red5/logback.xml
sed -e 's|<logger name="\(.*\)" level=".*" />|\<logger name="\1" level="ERROR" />|g' -i /etc/red5/logback.xml

# Placetel firewall rules
ufw allow from 185.79.24.0/22 to any port 5060
ufw allow from 185.79.24.0/22 to any port 8933
ufw deny from any to any port 5060
ufw deny from any to any port 8933
