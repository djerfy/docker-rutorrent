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

# Create torrent group
if [ "${GID}" == "0" ]; then
    f_log warning "Skip creating group because you use GID 0 (not recommanded) ..."
else
    f_log info "Creating group torrent ..."
    if [ "$(egrep -c ':'${GID}':' /etc/group)" -eq "1" ]; then
        GROUP_NAME=$(egrep ':'${GID}':' /etc/group | cut -d\: -f1)
        GROUP_LASTGID=$(cat /etc/group | egrep -v "^no(body|group):" | cut -d\: -f3 | sort -n | tail -n1)
        GROUP_NEXTGID=$((GROUP_LASTGID+1))
        f_log warning "Already exist group with GID ${GID}: ${GROUP_NAME}"
        groupmod -g ${GROUP_NEXTGID} ${GROUP_NAME}
        if [ "$?" -eq "0" ]; then
            f_log warning "Automatic change group ${GROUP_NAME} with GID ${GROUP_NEXTGID} ..."
        else
            f_log error "Unable automatic change group ${GROUP_NAME} with GID ${GROUP_NEXTGID} :("
            exit 1
        fi
    fi
    if [ "$(egrep -c ':'${GID}':' /etc/group)" -eq "0" ]; then
        addgroup -g ${GID} torrent
        GROUP_NAME=torrent
        f_log success "Group torrent created with GID ${GID}"
    else
        f_log error "Unable to create group torrent with GID ${GID} :("
        exit 1
    fi
fi

# Create torrent user
if [ "${UID}" == "0" ]; then
    f_log info "Skip creating user because you use  UID 0 (not recommanded) ..."
else
    f_log info "Creating user torrent ..."
    if [ "$(egrep -c ':'${UID}':' /etc/passwd)" -eq "1" ]; then
        USER_NAME=$(egrep ':'${UID}':' /etc/passwd | cut -d\: -f1)
        USER_LASTUID=$(cat /etc/passwd | egrep -v "^nobody:" | cut -d\: -f3 | sort -n | tail -n1)
        USER_NEXTUID=$((USER_LASTUID+1))
        f_log warning "Already exist user with UID ${UID}: ${USER_NAME}"
        usermod -u ${USER_NEXTUID} ${GROUP_NAME}
        if [ "$?" -eq "0" ]; then
            f_log warning "Automatic change user ${USER_NAME} with UID ${USER_NEXTUID} ..."
        else
            f_log error "Unable automatic change user ${USER_NAME} with UID ${USER_NEXTGID} :("
            exit 1
        fi
    fi
    if [ "$(egrep -c ':'${UID}':' /etc/passwd)" -eq "0" ]; then
        adduser -h /home/torrent -s /bin/sh -G ${GROUP_NAME} -D -u ${UID} torrent
        USER_NAME=torrent
        f_log success "User torrent created with UID ${UID}"
    else
        f_log error "Unable to create user torrent with UID ${UID} :("
        exit 1
    fi
fi

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
            mkdir -p /config/rutorrent/${DIR}
            mv /var/www/html${WEBROOT}/${DIR}/* /config/rutorrent/${DIR}/
            rm -rf /var/www/html${WEBROOT}/${DIR}
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
            if [ ! -d "/var/www/html${WEBROOT}/plugins/theme/themes/${LIST}" ]; then
                mkdir -p /var/www/html${WEBROOT}/plugins/theme/themes
                ln -sf /config/custom_themes/${LIST} /var/www/html${WEBROOT}/plugins/theme/themes/${LIST}
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
            mkdir -p /config/rutorrent/${DIR}
            mv /var/www/html/torrent/${DIR}/* /config/rutorrent/${DIR}/
            rm -rf /var/www/html/torrent/${DIR}
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
sed -e 's|<RTORRENT_PORT>|'${RTORRENT_PORT:-6881}'|g' \
    -e 's|<RTORRENT_DHT>|'${RTORRENT_DHT:-off}'|g' \
    -i /home/torrent/.rtorrent.rc
f_log success "Generate global configuration done"

# Externalize rtorrent configuration
f_log info "Configuration .rtorrent.rc ..."
if [ ! -e "/config/rtorrent/.rtorrent.rc" ]; then
    f_log info "Generate .rtorrent.rc ..."
    mv /home/torrent/.rtorrent.rc /config/rtorrent/.rtorrent.rc
    ln -sf /config/rtorrent/.rtorrent.rc /home/torrent/.rtorrent.rc
    f_log success "Generate .rtorrent.rc done"
else
    grep -qE "^# rtorrent: v0.9.8$" /config/rtorrent/.rtorrent.rc
    if [ "$?" -ne "0" ]; then
        f_log info "Migrate to 0.9.8 ..."
        mv /config/rtorrent/.rtorrent.rc /config/rtorrent/.rtorrent.rc.old
        mv /home/torrent/.rtorrent.rc /config/rtorrent/.rtorrent.rc
        ln -sf /config/rtorrent/.rtorrent.rc /home/torrent/.rtorrent.rc
        f_log success "Migrate to 0.9.8 done"
    else
        f_log success "Already up to date"
    fi
fi
f_log success "Configuration .rtorrent.rc done"

# Fix initplugins path
f_log info "Apply path initplugins ..."
grep -qE " /nginx/" /home/torrent/.rtorrent.rc
if [ "$?" -eq "0" ]; then
    sed -i "s# /nginx/# /var/#g" /home/torrent/.rtorrent.rc
    f_log success "Apply path initplugins done"
else
    f_log info "Path initplugins already applied"
fi

# Configure filebot
f_log info "Install filebot ..."
if [ -z "${FILEBOT_FOLDER}" ]; then
    DIRNAME="Media"
else
    DIRNAME=${FILEBOT_FOLDER}
fi
if [ -z "${FILEBOT_EXCLUDE_FILE}" ]; then
    FILEBOT_EXCLUDE_FILE="/data/${FILEBOT_FOLDER}/amc.excludes"
fi
touch ${FILEBOT_EXCLUDE_FILE}
for FILEBOT_DIR in movies animes music tvshow; do
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
sed -e 's|<FILEBOT_MOVIES>|'"${FILEBOT_MOVIES}"'|' \
    -e 's|<FILEBOT_METHOD>|'"${FILEBOT_METHOD}"'|' \
    -e 's|<FILEBOT_MUSICS>|'"${FILEBOT_MUSICS}"'|' \
    -e 's|<FILEBOT_SERIES>|'"${FILEBOT_SERIES}"'|' \
    -e 's|<FILEBOT_ANIMES>|'"${FILEBOT_ANIMES}"'|' \
    -e 's|<FILEBOT_EXCLUDE_FILE>|'"${FILEBOT_EXCLUDE_FILE}"'|' \
    -e 's|<FILEBOT_LANG>|'"${FILEBOT_LANG}"'|' \
    -e 's|<FILEBOT_CONFLICT>|'"${FILEBOT_CONFLICT}"'|' \
    -e 's|<DIRNAME>|'"${DIRNAME}"'|' \
    -i /usr/local/bin/postdl
sed -e 's|<DIRNAME>|'"${DIRNAME}"'|' \
    -i /usr/local/bin/postrm
chmod +x /usr/local/bin/post*
f_log success "Install filebot done"

# Apply license filebot if defined
f_log info "License filebot ..."
if [ ! -z "${FILEBOT_LICENSE_FILE}" ]; then
    if [ -e "${FILEBOT_LICENSE_FILE}" ]; then
        if [ -e "/filebot/filebot.sh" ]; then
            /filebot/filebot.sh --license "${FILEBOT_LICENSE_FILE}"
            f_log success "License filebot done"
        else
            f_log error "Unable load license ${FILEBOT_LICENSE_FILE}: filebot script not found"
        fi
    else
        f_log error "Unable load license ${FILEBOT_LICENSE_FILE}: file not found"
    fi
fi

# Display details if use script after filebot executing
f_log info "Exec script after filebot ..."
if [ "${FILEBOT_SCRIPT}" = "yes" ] && [ ! -z "${FILEBOT_SCRIPT_DIR}" ]; then
    f_log info "Exec script after filebot yes => ${FILEBOT_SCRIPT_DIR}/postexec"
else
    f_log info "Exec script after filebot no"
fi

# Install GeoIP files
f_log info "Install GeoIP2 files (country/city) ..."
mkdir -p /usr/share/GeoIP /var/www/html/torrent/plugins/geoip2/database
cd /usr/share/GeoIP
wget -q https://geolite.maxmind.com/download/geoip/database/GeoLite2-City.tar.gz -O GeoLite2-City.tar.gz
wget -q https://geolite.maxmind.com/download/geoip/database/GeoLite2-Country.tar.gz -O GeoLite2-Country.tar.gz
tar -xzf GeoLite2-City.tar.gz
tar -xzf GeoLite2-Country.tar.gz
rm -f GeoLite2-*.tar.gz
mv GeoLite2-*/*.mmdb .
cp *.mmdb /var/www/html/torrent/plugins/geoip2/database/
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

# Apply filebot permissions
f_log info "Apply filebot permissions ..."
chown ${USER_NAME}:${GROUP_NAME} -R /filebot
f_log success "Apply filebot permissions done"

# Apply url access on ruTorrent plugins
f_log info "Apply access url on plugins ..."
if [ ! -z "${BASEURL_USER}" -a ! -z "${BASEURL_PASS}" ]; then
    BASEURL_AUTH="${BASEURL_USER}:${BASEURL_PASS}@"
fi
sed -i 's|<BASEURL_SCHEME>|'${BASEURL_SCHEME:-http}'|g' /var/www/html/torrent/plugins/fileshare/conf.php /var/www/html/torrent/plugins/mediastream/conf.php
sed -i 's|<BASEURL>|'${BASEURL_AUTH}${BASEURL:-localhost}'|g' /var/www/html/torrent/plugins/fileshare/conf.php /var/www/html/torrent/plugins/mediastream/conf.php
f_log success "Apply access url on plugins done"

# Apply medias/sessions permissions
if [ "${SKIP_PERMS}" != "yes" ]; then
    f_log info "Apply medias/sessions permissions ..."
    find /data ! -user ${USER_NAME} -a ! -group ${GROUP_NAME} -exec chown ${USER_NAME}:${GROUP_NAME} {} \;
    f_log success "Apply medias/sessions permissions done"
fi

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
    exec su-exec ${USER_NAME}:${GROUP_NAME} /sbin/tini -s -- tail -F /tmp/std*-*.log &
    exec su-exec ${USER_NAME}:${GROUP_NAME} /sbin/tini -s -- supervisord -c /etc/supervisor/supervisord.conf
else
    exec su-exec ${USER_NAME}:${GROUP_NAME} /sbin/tini -s -- tail -F /tmp/std*-*.log &
    exec su-exec ${USER_NAME}:${GROUP_NAME} /sbin/tini -s -- $@
fi

