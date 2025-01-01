Forgejo Container Setup
=========================

## Description

Supplemental notes on extending the docker-compose configuration to include a [Forgejo](https://forgejo.org) container for local development and as private hub for gitops-based workflows.

## Update Notes

Date        | Notes
----------  | -------------------------------
27 Dec 2024 | Initial write-up

## Target

Set up a local instance of Forgejo with port 443 (https) for the web interface and port 22 for ssh access to git repositories. Forgejo uses `http:` and ports 3000 and 22 by default. Forgejo will only be accessible on my local lan and is not exposed to the internet. Please note this set up would need additional hardening before using on an internet-accessible network.

See [README.md](./README.md) for more information about the current Docker host, configuration, and macvlan.

## Architechture

Forgejo uses port 3000 by default. The built-in web server apparently does not run as a privileged user as ports 80 and/or 443 will not work. I use a [Caddy](https://caddyserver.com/)-based reverse proxy with locally created certs to enable https and port 443 access. I could have also used the built-in reverse proxy capabilities of the Synology host but chose Caddy for it's simplicity and portability.

This instance of Forgejo uses the built-in sqlite database.

I use the dns names of `forge.lan` and `git.forge.lan` for this service. There is also a separate `forgejo.lan` name. All are described below.

## Set Up Steps

Forgejo and Caddy containers run via Docker on a Synology host. Synology DSM and Docker are the latest available from the Synology team.

Please note that I use a Fedora workstation so I may make assumptions about availability of tools or steps that may not work on non-linux computers. Also note that these are the steps I (more or less) followed and may not necessarily work well as a tutorial.

1. The `forgejo` service definition from the `compose.yaml` file is shown below. This is largely copied from the [Forgejo Docker](https://forgejo.org/docs/latest/admin/installation-docker/) instructions with the addition of an IP address for the container (see the project README.md for more details on the macvlan) and the volume mappings between the Synology host and the container.

   ```yaml
   forgejo:
     image: codeberg.org/forgejo/forgejo:9
     container_name: Forgejo
     environment:
       - USER_UID=1000
       - USER_GID=1000
     restart: unless-stopped
     networks:
       macvlan1:
         ipv4_address: 192.168.110.212
     volumes:
       - /volume1/docker/forgejo:/data
       - /etc/TZ:/etc/timezone:ro
       - /etc/localtime:/etc/localtime:ro
     ports:
       - '3000'
       - '22'
   ```

   1. I used the Synology web UI to create the sub-directory for the container's `/data/` directory. In my case this is a `forgejo` sub-directory in the existing `/volum1/docker` directory that is the root directory for all container volumes on this host.


1. SSH into the Synology and start `forgejo` for the first time using `docker-compose`. Forgejo will create subdirectories under `/data` on the container which are mapped to the designated location on the Synology file system.

   ```bash
   sudo docker-compose -f compose.yaml up -d forgejo
   ```

1. While still in ssh on the Synology, edit the Forgejo `app.ini` configuration file to and make necessary changes and additions. My copy is stored in this repository in the `forgejo` subdirectory. I just used vi to make the edits but there are alternatives such as downloading to your workstation or using the Synology Text Edit application.

   ```bash
   sudo vi /volume1/docker/forgejo/gitea/conf/app.ini
   ```
   1. I set `DOMAIN = forge.lan`, `SSH_DOMAIN = git.forge.lan` and `ROOT_URL = https://forge.lan`. A copy of app.ini is archived in the repository in the `./forgejo` sub-directory.

1. The `caddy` service definition is shown below. This is largely copied from the [caddy - official image](https://hub.docker.com/_/caddy) page on Docker Hub. Changes include the macvlan IP address and `volumes` mappings.

   ```yaml
   caddy:
     image: caddy:latest
     restart: unless-stopped
     networks:
       macvlan1:
         ipv4_address: 192.168.110.214
     cap_add:
       - NET_ADMIN
     ports:
       - '80'
       - '443'
       - '443/udp'
     volumes:
       - /volume1/docker/caddy/etc:/etc/caddy
       - /volume1/docker/caddy/site:/srv
       - /volume1/docker/caddy/data:/data
       - /volume1/docker/caddy/config:/config
   ```

   1. Use the Synology web UI to create the sub-directories for the container's `/etc/caddy`, `/srv`, `/data`, and `/config` directories. The `/etc/caddy` directory is where the Caddyfile will be placed as well as the custom certs. A copy of the `Caddyfile` is in the `./caddy` sub-directory of the repository.

1. Use [mkcert](https://github.com/FiloSottile/mkcert) to create the TLS certificates for the site. `mkcert` is useful if you are the only developer using the site. Other options will need to be explored for team use.

   ```bash
   mkcert -key-file syn-cert-key.pem -cert-file syn-cert.pem forge.lan forgejo.lan
   ```

1. On your workstation create the `Caddyfile` containing the reverse proxy definitioni and set the location for the self-signed TLS certs. The Caddyfile requires tabs for indentations, not spaces.

   ```
   forge.lan {
      tls /etc/caddy/certs/syn-cert.pem /etc/caddy/certs/syn-cert-key.pem
      reverse_proxy forgejo.lan:3000
   }
   ```

   1. If you have `caddy` installed on your workstation, you can use it to correctly format the `Caddyfile`. Navigate to the subdirectory containing the `Caddyfile` and execute the following:

      ```bash
      caddy fmt --overwrite
      ```

   1. Note the paths for the TLS cert and key files are relative to the container root and in the `cert` subdirectory of the `/etc/caddy` volume defined in the docker-compose service definition.

   1. Create the `certs` subdirectory in `/etc/caddy` and copy the two (2) certs into it. This can be done from the command line on the docker host machine or using a web ui if available.

1. Create dns entries for `forge.lan`, `git.forge.lan`, and `forgejo.lan`. The IP address for `forge.lan` will be the address assigned to the Caddy service. The IP address for `forgejo.lan` and `git.forge.lan` will be the address assigned to the Forgejo service. I use pi-hole for DNS services on the lan (see `compose.yaml` and README.md for more information about pi-hole setup).

1. SSH into the docker host (Synology in my case), and use `docker-compose` to start forgejo and caddy.

   ```bash
   sudo docker-compose -f compose up -d forgejo caddy
   ```

1. Use a web browser and browse to `https://forge.lan`. Create an account on the Forgejo site and configure as appropriate. Create a new project and repository in Forgejo and verify that the ssh address for the repository contains the `git.forge.lan` address.

1. Consider additional hardening steps such as configuring Forgejo to only listen for web traffic from the reverse proxy.


## Technical Notes

TBD

## Execution

Docker Compose is a command line executable available for most linux systems including the Synology. There are many references available - I find the original Docker documentation very approachable and useful: https://docs.docker.com/compose/. The version of `docker-compose` currently available for the Synology is `v2.9.0-6413-g38f6acd` which is fairly old, but at least v2.

Start all services in the default compose.yaml file
```bash
sudo docker-compose -f compose.yaml up
```

Start all services in the default compose.yaml file and detach.
```bash
sudo docker-compose -f compose.yaml up -d
```

Start the Forgejo service in the default compose.yaml file and detach.
```bash
sudo docker-compose -f compose.yaml up -d forgejo
```

## Configuration


## Credit

The open source community and sponsors for Forgejo and Caddy.

Filippo Valsorda and the other contributors for `mkcert`.
