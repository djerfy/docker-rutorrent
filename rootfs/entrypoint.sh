#!/bin/sh

if [ "$(echo ${DEBUG} | tr '[A-Z]' '[a-z]')" == "true" ]; then
    set -x
fi

CSI="\033["
CEND="${CSI}0m"
CRED="${CSI}1;31m"
CGREEN="${CSI}1;32m"
CYELLOW="${CSI}1;33m"
CBLUE="${CSI}1;34m"

f_log() {
    LOG_TYPE="$1"
    LOG_MESSAGE="$2"
    case "$LOG_TYPE" in
        "info")
            echo -ne "[${CBLUE}info......${CEND}][$(date +%d/%m/%Y) $(date +%H:%M:%S)] ${LOG_MESSAGE}\n"
            ;;
        "success")
            echo -ne "[${CGREEN}success...${CEND}][$(date +%d/%m/%Y) $(date +%H:%M:%S)] ${LOG_MESSAGE}\n"
            ;;
        "warning")
            echo -ne "[${CYELLOW}warning...${CEND}][$(date +%d/%m/%Y) $(date +%H:%M:%S)] ${LOG_MESSAGE}\n"
            ;;
        "error")
            echo -ne "[${CRED}error.....${CEND}][$(date +%d/%m/%Y) $(date +%H:%M:%S)] ${LOG_MESSAGE}\n"
            exit 1
            ;;
        "critical")
            echo -ne "[${CRED}critical..${CEND}][$(date +%d/%m/%Y) $(date +%H:%M:%S)] ${LOG_MESSAGE}\n"
            exit 1
            ;;
    esac
}

# Create torrent user/group
f_log info "Create torrent username ..."
GROUP_NAME=$(grep ':'${GID}':' /etc/group | cut -d\: -f1)
[ -z "${GROUP_NAME}" ] && addgroup -g ${GID} torrent; GROUP_NAME=torrent
USER_NAME=$(grep ${UID} /etc/passwd | cut -d\: -f1)
[ -z "${USER_NAME}" ] && adduser -h /home/torrent -s /bin/sh -G ${GROUP_NAME} -D -u ${UID} torrent; USER_NAME=torrent
f_log success "Create torrent username done"

# Create folders
f_log info "Create folders ..."
mkdir -p /data/torrents /data/.watch /data/.state /data/.session /config/rtorrent /config/custom_plugins \
    /config/custom_themes /home/torrent /var/run/torrent /var/log/torrent
f_log success "Create folders done"

# Generate configuration
f_log info "Generate global configuration ..."
if [ "${WEBROOT}" != "/" ]; then
    sed -e 's|<webroot>|'"${WEBROOT}"'|g' \
        -e 's|<webroot_rpc>|'"${WEBROOT}"'|g' \
        -e 's|<folder>||g' \
        -i /etc/nginx/nginx.conf
    if [ "${WEBROOT}" != "/torrent" ]; then
        mv /var/www/html/torrent /var/www/html${WEBROOT}
    fi
    sed -i 's|<webroot>|'${WEBROOT}'/|g' /var/www/html${WEBROOT}/conf/config.php
    for DIR in share conf; do
        if [ -d "/config/rutorrent/${DIR}" ]; then
            rm -rf /var/www/html${WEBROOT}/${DIR}
            ln -sf /config/rutorrent/${DIR} /var/www/html${WEBROOT}/${DIR}
        else
            mv /var/www/html${WEBROOT}/${DIR} /config/rutorrent/
            ln -sf /config/rutorrent/${DIR} /var/www/html${WEBROOT}/${DIR}
        fi
    done
    if [ -d "/config/custom_plugins/" ]; then
        [ "$(ls /config/custom_plugins/)" ] && for LIST in $(ls /config/custom_plugins); do
            if [ ! -d "/var/www/html${WEBROOT}/plugins/${LIST}" ]; then
                ln -sf /config/custom_plugins/${LIST} /var/www/html${WEBROOT}/plugins/${LIST}
            fi
        done
    fi
    if [ -d "/config/custom_themes/" ]; then
        [ "$(ls /config/custom_themes/)" ] && for LIST in $(ls /config/custom_themes); do
            if [ ! -d "/var/www/html${WEBROOT}/theme/themes/${LIST}" ]; then
                mkdir -p /var/www/html${WEBROOT}/theme/themes
                ln -sf /config/custom_themes/${LIST} /var/www/html${WEBROOT}/theme/themes/${LIST}
            fi
        done
    fi
else
    sed -e 's|<webroot>||g' \
        -e 's|<webroot_rpc>||g' \
        -e 's|<folder>|/torrent|g' \
        -i /etc/nginx/nginx.conf
    sed -i 's|<webroot>|/|g' /var/www/html/torrent/conf/config.php
    for DIR in share conf; do
        if [ -d "/config/rutorrent/${DIR}" ]; then
            rm -rf /var/www/html/torrent/${DIR}
            ln -sf /config/rutorrent/${DIR} /var/www/html/torrent/${DIR}
        else
            mv /var/www/html/torrent/${DIR} /config/rutorrent
            ln -sf /config/rutorrent/${DIR} /var/www/html/torrent/${DIR}
        fi
    done
    if [ -d "/config/custom_plugins/" ]; then
        [ "$(ls /config/custom_plugins/)" ] && for LIST in $(ls /config/custom_plugins); do
            if [ ! -d "/var/www/html/torrent/plugins/${LIST}" ]; then
                ln -sf /config/custom_plugins/${LIST} /var/www/html/torrent/plugins/${LIST}
            fi
        done
    fi
    if [ -d "/config/custom_themes/" ]; then
        [ "$(ls /config/custom_themes/)" ] && for LIST in $(ls /config/custom_themes); do
            if [ ! -d "/var/www/html/torrent/theme/themes/${LIST}" ]; then
                mkdir -p /var/www/html/torrent/theme/themes
                ln -sf /config/custom_themes/${LIST} /var/www/html/torrent/theme/themes/${LIST}
            fi
        done
    fi
fi
sed -e 's|<RTORRENT_PORT>|'${RTORRENT_PORT}'|g' \
    -e 's|<RTORRENT_DHT>|'${RTORRENT_DHT}'|g' \
    -i /home/torrent/.rtorrent.rc
f_log success "Generate global configuration done"

# Externalize rtorrent configuration
f_log info "Check and generate .rtorrent.rc ..."
if [ ! -e "/config/rtorrent/.rtorrent.rc" ]; then
    mv /home/torrent/.rtorrent.rc /config/rtorrent/.rtorrent.rc
    ln -sf /config/rtorrent/.rtorrent.rc /home/torrent/.rtorrent.rc
else
    grep -qE "(system.method.set_key|use_udp_trackers|peer_exchange)" /config/rtorrent/.rtorrent.rc
    if [ "$?" -ne "0" ]; then
        f_log info "Migrate to 0.9.7 configuration format ..."
        mv /config/rtorrent/.rtorrent.rc /config/rtorrent/.rtorrent.rc.old
        mv /home/torrent/.rtorrent.rc /config/rtorrent/.rtorrent.rc
        ln -sf /config/rtorrent/.rtorrent.rc /home/torrent/.rtorrent.rc
        f_log success "Migrate to 0.9.7 configuration format done"
    fi
fi
f_log success "Check and generate .rtorrent.rc done"    

# Configure filebot
f_log info "Install filebot ..."
if [ -z "${FILEBOT_FOLDER}" ]; then
    DIRNAME="Media"
else
    DIRNAME=${FILEBOT_FOLDER}
fi
for FILEBOT_DIR in movies animes music tv; do
    [ ! -e "/data/${DIRNAME}/${FILEBOT_DIR}" ] && mkdir -p /data/${DIRNAME}/${FILEBOT_DIR}
    find /data/${DIRNAME}/${FILEBOT_DIR} ! -user ${USER_NAME} -o ! -group ${GROUP_NAME} -exec chown ${USER_NAME}:${GROUP_NAME} {} \;
done
grep -qE "method.set_key.*event.download.finished" /home/torrent/.rtorrent.rc
if [ "$?" -ne "0" ]; then
    echo 'method.set_key = event.download.finished,filebot,"execute2={/usr/local/bin/postdl,$d.base_path=,$d.name=,$d.custom1=}"' >> /home/torrent/.rtorrent.rc
fi
grep -qE "method.set_key.*event.download.erased" /home/torrent/.rtorrent.rc
if [ "$?" -ne "0" ]; then
    echo 'method.set_key = event.download.erased,filebot_cleaner,"execute2=/usr/local/bin/postrm"' >> /home/torrent/.rtorrent.rc
fi
sed -e 's|<FILEBOT_MOVIES>|'"$FILEBOT_MOVIES"'|' \
    -e 's|<FILEBOT_METHOD>|'"$FILEBOT_METHOD"'|' \
    -e 's|<FILEBOT_MUSICS>|'"$FILEBOT_MUSICS"'|' \
    -e 's|<FILEBOT_SERIES>|'"$FILEBOT_SERIES"'|' \
    -e 's|<FILEBOT_ANIMES>|'"$FILEBOT_ANIMES"'|' \
    -i /usr/local/bin/postdl
chmod +x /usr/local/bin/post*
f_log success "Install filebot done"

# Install GeoIP files
f_log info "Install GeoIP files (country/city) ..."
for GEOFILE in GeoLiteCity GeoLiteCountry; do
    wget https://geolite.maxmind.com/download/geoip/database/${GEOFILE}.dat.gz -O /usr/share/GeoIP/${GEOFILE}.dat.gz
    gzip -d /usr/share/GeoIP/${GEOFILE}.dat.gz
    rm -f /usr/share/GeoIP/${GEOFILE}.dat.gz
done
f_log success "Install GeoIP files (country/city) done"

# Install plowshare
f_log info "Install plowshare ..."
if [ -e "/home/torrent/.config/plowshare" ]; then
    su-exec ${USER_NAME}:${GROUP_NAME} plowod --update > /dev/null 2>&1
    res=$?
else
    su-exc ${USER_NAME}:${GROUP_NAME} plowod --install > /dev/null 2>&1
    res=$?
fi
[[ $? == 0 ]]; f_log success "Install plowshare done" || (f_log error "Install plowshare failed" && exit 1)

# Apply default files permissions
f_log info "Apply default files permissions ..."
mkdir -p /run/nginx
for FOLDER in /var/www /home/torrent /var/lib/nginx /etc/php7 /etc/nginx /var/log/torrent /var/run/torrent /tmp /config /etc/supervisor; do
    mkdir -p ${FOLDER}
    find ${FOLDER} ! -user ${USER_NAME} -a ! -group ${GROUP_NAME} -exec chown ${USER_NAME}:${GROUP_NAME} {} \;
done
f_log success "Apply default files permissions done"

# Apply medias permissions
f_log info "Apply medias permissions ..."
find /data ! -user ${USER_NAME} -a ! -group ${GROUP_NAME} -exec chown ${USER_NAME}:${GROUP_NAME} {} \;
f_log success "Apply medias permissions done"

# Create empty logs files
f_log info "Create logs files stdout/stderr ..."
touch /tmp/stdout-filebot.log /tmp/stdout-supervisor.log /tmp/stdout-nginx.log /tmp/stderr-nginx.log /tmp/stdout-rtorrent.log /tmp/stderr-php-fpm.log
chown ${USER_NAME}:${GROUP_NAME} /tmp/std*-*.log
f_log success "Create logs files stdout/stderr done"

# Remove lock
f_log info "Remove rtorrent lock file ..."
[ -e "/data/.session/rtorrent.lock" ] && rm -f /data/.session/rtorrent.lock
f_log success "Remove rtorrent lock file done"

# Starting processes
f_log info "Starting services in progress ..."
if [ $# -eq 0 ]; then
    exec su-exec ${USER_NAME}:${GROUP_NAME} /sbin/tini -- tail -F /tmp/std*-*.log &
    exec su-exec ${USER_NAME}:${GROUP_NAME} /sbin/tini -- supervisord -c /etc/supervisor/supervisord.conf
else
    exec su-exec ${USER_NAME}:${GROUP_NAME} /sbin/tini -- tail -F /tmp/std*-*.log &
    exec su-exec ${USER_NAME}:${GROUP_NAME} /sbin/tini -- $@
fi

