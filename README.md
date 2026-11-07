# Containerized Factorio Headless Server

**English** | [Українська](README_uk.md)

[![Build](https://github.com/craftorio/factorio/actions/workflows/build.yml/badge.svg)](https://github.com/craftorio/factorio/actions/workflows/build.yml) [![Docker Pulls](https://img.shields.io/docker/pulls/craftorio/factorio.svg)](https://hub.docker.com/r/craftorio/factorio/) [![License](https://img.shields.io/github/license/craftorio/factorio.svg)](https://github.com/craftorio/factorio)

Fork of [goofball222/factorio](https://github.com/goofball222/factorio). GitHub Actions checks the
[official API](https://factorio.com/api/latest-releases) every 2 hours and builds new images as soon as a new Factorio
headless release appears. Images are rebuilt only for a new Factorio version or a change to the Dockerfiles and
entrypoint scripts. The tags below always track the latest versions.

Images are built for `linux/amd64` and `linux/arm64` and published to:

* GitHub Container Registry: `ghcr.io/craftorio/factorio`
* Docker Hub: `craftorio/factorio`

| Docker Tag | Factorio Version | Description | Updated |
| --- | :---: | --- | :---: |
| [latest, stable, 2.1.24](https://github.com/craftorio/factorio/blob/main/stable/Dockerfile)<br>[latest-alpine, stable-alpine, 2.1.24-alpine](https://github.com/craftorio/factorio/blob/main/stable/Dockerfile.alpine) | 2.1.24 | Factorio headless server stable release | 2026-11-07 | <!-- stable -->
| [experimental](https://github.com/craftorio/factorio/blob/main/experimental/Dockerfile)<br>[experimental-alpine](https://github.com/craftorio/factorio/blob/main/experimental/Dockerfile.alpine) | 2.1.24 | Factorio headless server experimental release | 2026-11-07 | <!-- experimental -->

Version-pinned tags (`2.0.77`, `2.0.77-alpine`) are published for the stable channel on every release, so you can pin a
specific Factorio version. When the experimental channel points at a different version than stable it gets its own
version tag as well.

---

* [Recent changes, see: GitHub CHANGELOG.md](https://github.com/craftorio/factorio/blob/main/CHANGELOG.md)
* [Report any bugs, issues or feature requests on GitHub](https://github.com/craftorio/factorio/issues)

---

For security/attack surface reduction the container is configured to run the Factorio headless server with an internal user & group `factorio` having a pre-set UID & GID of 999.
The container will attempt to adjust permissions on mapped volumes and data to match before dropping privileges to start the Factorio server processes.
If the container is being run with a different Docker --user setting permissions may need to be fixed manually.

IE: `chown -R 999:999 factorio`

A custom UID and GID can be configured for the container internal factorio user and group. For more information see the "Environment variables" section in this document.

---

**Always stop the existing container and make a VERIFIED backup copy of your Factorio save data before installing newer images.**

---

## Quick start

```bash
mkdir -p /opt/factorio && cd /opt/factorio
curl -fsSLO https://raw.githubusercontent.com/craftorio/factorio/main/docker-compose.yml
docker compose up -d
docker logs -f factorio
```

The first start creates `./data` next to the compose file, fills `data/config` with the Factorio example
settings, generates a random RCON password (printed in the log and saved to `data/config/RCON.pwd`) and creates a
new map in `data/saves/save.zip`. The server is playable right away on `34197/udp`.

**Expected on a fresh install:** the log ends with
`Matching server connection failed: Error when creating server game: Missing token.`
The example `server-settings.json` has `visibility.public = true` but no factorio.com credentials, so the server
cannot register in the public server browser. Fix it by editing `data/config/server-settings.json`:

* set `name`, `description`, `game_password`, `admins`;
* either put your factorio.com `username` and `token` (from your [factorio.com profile](https://factorio.com/profile))
  for a public server, or set `"visibility": {"public": false, "lan": false}` for a private one;

then `docker compose restart factorio`. Optionally add `data/config/server-adminlist.json` and replace
`data/saves/save.zip` with your own save.

Always run `docker compose` from the directory that holds `docker-compose.yml`: the ofelia updater job mounts the
project directory by its absolute path.

**Migrating an existing server** (for example from the upstream `goofball222/factorio` image with data in
`/opt/factorio`): stop the old container, move `config`, `mods`, `saves` and `scenarios` into `./data`, put the new
`docker-compose.yml` next to it and run `docker compose up -d`. Save files are compatible as long as the Factorio
version is the same or newer.

**Updates** are automatic: GitHub Actions publishes new images within two hours of a Factorio release, and the
`ofelia` service in the compose file checks every 15 minutes, pulls the new image and recreates the server when
one is available. The server restarts only when the image actually changed; remove the `ofelia` service if you
prefer to update manually with `docker compose pull && docker compose up -d`.

---

## Usage

**The container has a single volume `/factorio` (mounted from `./data` in the compose file) with the following structure:**

    factorio
    |-- config
    |   |-- map-gen-settings.json
    |   |-- map-gen-settings.example.json
    |   |-- map-settings.json
    |   |-- map-settings.example.json
    |   |-- RCON.pw
    |   |-- server-adminlist.json
    |   |-- server-banlist.json
    |   |-- server-settings.json
    |   `-- server-whitelist.json
    |-- mods
    |   `-- mod.zip
    |-- saves
    |   `-- save.zip
    `-- scenarios
        `-- scenario.zip

**The container exposes two ports:**
* `27015/tcp`: Factorio RCON port
* `34197/udp`: Factorio default server port

---

**The most basic way to run this container:**

```bash
$ docker run --name factorio -d \
    -p 34197:34197/udp \
    craftorio/factorio
```

---

**Recommended: run via [Docker Compose](https://docs.docker.com/compose/):**

Have the container store the config, mods, saves, and scenarios on a local file-system or in a specific, known data volume (recommended for persistence and troubleshooting) and expose the RCON port for admin:

```yaml
services:
  factorio:
    image: ghcr.io/craftorio/factorio:latest
    container_name: factorio
    restart: unless-stopped
    ports:
      - "27015:27015"
      - "34197:34197/udp"
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - ./data:/factorio
    environment:
      - TZ=UTC

```

[`docker-compose.yml`](https://github.com/craftorio/factorio/blob/main/docker-compose.yml) with data stored in `./data` next to the compose file and an [ofelia](https://github.com/mcuadros/ofelia) job that every 15 minutes pulls the image and recreates the server when a new one was published.

---

**Logs are available directly from the running container, IE: "docker logs factorio"**

---

**Environment variables:**

| Variable | Default | Description |
| :--- | :---: | --- |
| `DEBUG` | ***false*** | Set to *true* for extra container verbosity for debugging |
| `FACTORIO_OPTS` | ***unset*** | Add custom command line options to factorio server executable at runtime |
| `FACTORIO_PORT` | ***unset*** | Override server default port for game client connections |
| `FACTORIO_RCON_PASSWORD` | ***unset*** | Specify the server RCON password |
| `FACTORIO_RCON_PORT` | ***27015*** | Specifies the server RCON admin port |
| `FACTORIO_SCENARIO` | ***unset*** | Specifies a scenario name for the server to run |
| `PGID` | ***999*** | Specifies the GID for the container internal factorio group (used for file ownership) |
| `PUID` | ***999*** | Specifies the UID for the container internal factorio user (used for process and file ownership) |
| `RUN_CHOWN` | ***true*** | Set to *false* to disable the container automatic `chown` at startup. Speeds up startup process on overlay2 Docker hosts. **NB/IMPORTANT:** It's critical that you insure directory/data permissions on all mapped volumes are correct before disabling this or Factorio will not start. |
| `RUNAS_UID0` | ***false*** | Set to *true* to force the container to run the Factorio server process as UID=0 (root) - **NB/IMPORTANT:** running with this set to "true" is insecure |

---

During the first launch of the container the server-settings.json and map-gen-settings.json config files will be populated with the Factorio sample/defaults if they don't already exist. It is highly recommended to edit these files and relaunch the container afterwards or provide pre-setup copies in the config directory prior to first launch. The config sample files are available in the headless server tar.gz file in the "data" folder. The container will also generate a default map / save.zip in the saves folder if one is not found on launch.

The RCON password can be set via the FACTORIO_RCON_PASSWORD ENV flag or loaded from `/factorio/config/RCON.pwd` each time the container is started. If the FACTORIO_RCON_PASSWORD ENV var is not set or the RCON.pwd file is not present a random RCON password will be generated and saved in `/factorio/config/RCON.pwd`. The active RCON password can also be found at the start of the container log file at each launch.

---

## Optional config examples

`config/server-whitelist.json` - **if present only the configured Factorio users will be allowed access**

    [
        "user1",
        "user2",
        "user3"
    ]

`config/server-banlist.json` - if present the configured Factorio user IDs will be denied access

    [
        "banneduser1",
        "banneduser2",
        "banneduser3",
        "banneduser4"
    ]

`config/server-adminlist.json` - if present the configured Factorio user IDs will have admin access

    [
        "adminuser1",
        "adminuser2"
    ]

[//]: # (Licensed under the Apache 2.0 license)
[//]: # (Copyright 2019 The Goofball - goofball222@gmail.com)
[//]: # (Copyright 2026 Craftorio - https://github.com/craftorio/factorio)
