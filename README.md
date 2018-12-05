<p align="center">
    <img alt="docker-rutorrent" src="https://mbtskoudsalg.com/images/macbook-pro-transparent-png.png" height="140" />
    <p align="center">
        <a href="https://github.com/djerfy/docker-rutorrent"><img alt="Github" src="https://flat.badgen.net/badge/github/master/green?icon=github"></a>
        <a href="https://hub.docker.com/r/djerfy/rutorrent"><img alt="Docker" src="https://flat.badgen.net/badge/docker/latest/green?icon=docker"></a>
        <img alt="Version" src="https://flat.badgen.net/badge/version/v0.0.0/yellow">
        <a href="https://github.com/djerfy/docker-rutorrent/issues"><img alt="Issues" src="https://flat.badgen.net/github/open-issues/djerfy/docker-rutorrent"></a>
        <img alt="Services" src="https://flat.badgen.net/badge/services/rtorrent,rutorrent,filebot?list=1">
        <a href="https://twitter.com/djerfy><img alt="Twitter" src="https://flat.badgen.net/badge/twitter/djerfy/blue?icon=twitter"></a>
    </p>
</p>

# Docker rTorrent + ruTorrent + Filebot

> Image of origin comes from [xataz](https://github.com/xataz): [docker-rtorrent-rutorrent](https://github.com/xataz/docker-rtorrent-rutorrent)

## Features

* Based on Alpine Linux
* Tools compiled from sources
* Filebot is included by default
* No **root** process
* Save custom configuration rTorrent and ruTorrent
* Logs in output (Supervisor, Nginx, PHP-FPM, rTorrent)
* Various plugins activated (GeoIP, ratiocolor, showip, checksfs, ...)

## Tags

* latest ([Dockerfile](https://github.com/djerfy/docker-rutorrent/Dockerfile))

## Description

What is [ruTorrent](https://github.com/Novik/ruTorrent)?

* **ruTorrent** is a frontend for popular Bittorent client rtorrent.
* This project is released under the GPLv3 license, for more details, see at the LICENSE.md file in the source code.

What is [rTorrent](https://github.com/rakshasa/rtorrent)?

* **ruTorrent** is the popular Bittorrent client.

## Configuration

### Environments

* `UID`: define uid to running services (default: 991)
* `GID`: define gid to running services (default: 991)
* `WEBROOT`: default access ruTorrent (default: /)
* `RTORRENT_PORT`: port used for rTorrent (default: 6881)
* `RTORRENT_DHT`: if DHT is to be used (default: off)
* `FILEBOT_FOLDER`: defined emplacement to create files (default: Media)
* `FILEBOT_METHOD`: method for rename media (default: symlink)
* `FILEBOT_MOVIES`: regex for rename movies (default: "{n} ({y})")
* `FILEBOT_MUSICS`: regex for rename musics (default: "{n}/{fn}")
* `FILEBOT_SERIES`: regex for rename tvshow (default: "{n}/Season {s.pad(2)}/{s00e00} - {t}")
* `FILEBOT_ANIMES`: regex for rename animes (default: "{n}/{e.pad(3)} - {t}")
* `FILEBOT_LICENSE_FILE`: defined the license file to load (default: none)
* `DEBUG`: running with debug output (bool) (default: false)
* `SKIP_PERMS`: don't apply chown on medias (movies, tvshow, animes, ...) (default: no)

### Volumes

* `/data`: folder for download torrents
* `/config`: folder for rTorrent and ruTorrent configuration

### Ports

* `8080`: ruTorrent interface
* `6881`: rTorrent (override with `RTORRENT_PORT`)

## Usage

### Basic

Access to ruTorrent interface: `http://xxx.xxx.xxx.xxx:8080/`

```bash
docker container run -d --name rutorrent -p 8080:8080 -p 6881:6881 djerfy/rutorrent:latest
```

### Advanced

With custom values:

```bash
docker container run -d \
    --name rutorrent \
    -p 8080:8080 \
    -p 9999:9999 \
    -e WEBROOT=/ \
    -e RTORRENT_DHT=on \
    -e RTORRENT_PORT=9999 \
    -e FILEBOT_METHOD=move \
    -e UID=1001 \
    -e GID=1001 \
    -e DEBUG=true \
    -v $(pwd)/data/data:/data \
    -v $(pwd)/data/config:/config \
    djerfy/rutorrent:latest
```

## Contributing

Any contributions, are very welcome!
