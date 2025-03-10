Yet Another Unifi Controller, Pi-Hole, and Forgejo Set-up using Docker Compose
============================================================================

## Description

A docker-compose yaml file to manage a Unifi Controller service, a Pi-Hole service, and a DNS-Over-HTTPS client service for my home network. Also included is a supporting script for the docker host. Additional services may be included for development/testing (e.g. a local docker registry) or to support one of the other services (e.g. logs and mongo for the Unifi Controller).

The `compose.yaml` file uses Docker Compose V2 file specification (not to be confused with the Compose V1 specification which has Version 1, Version 2, or Version 3 formats).

A separate bash script is provided that enables the docker host to have a direct network connection to the containers on the docker macvlan. See the technical notes below. See ./scripts/shim.sh for the script.

## Update Notes

Date        | Notes
----------  | -------------------------------
23 Feb 2025 | DNS-Over-HTTPS container has been replaced by the DOT service in my pfsense firewall. Forgejo will replace Registry for local container registry services. Pi-Holein process of updating to the current V6 release.
26 Dec 2024 | Add support for caddy as reverse proxy and forgejo. Initial reverse proxy will be forge.lan which is the name forgejo server will use. Forge.lan will use the caddy IP, git.forge.lan will use the forgejo IP. All dns names served via Pi Hole.
1 Dec 2023  | Synology DSM 7.2 uses docker-compose v2 (although not as 'docker compose'). Added compose.yaml to replace docker-compose.yaml. Very similar with addition of unifibridge network to isolate unifi log and unifi mongo containers on a docker bridge network and remove them from the macvlan. Logs and mongo did not need to be visible on lan. Also moved unifi to buckaroogeek as Jacob Alberty has not been online to update his images for quite some time. I hope he is all right.
8 Dec 2022  | Synology DSM 7 uses systemd. The docker macvlan post by Ivan Smirnov (see below) outlines a simple integration of the shim.sh script with systemd which helps to automate network configuration for macvlan containers following network restarts.
8 March 2021| DOH-Client tag moved from latest to current release (2.2.10). The rpmcache service is still a work in progress and will not work correctly.
6 June      | Added this update comment section. Added a command line section.
31 May      | Added docker-compose-farmos.yaml - docker configuration for farmos and database. FarmOS (farmos.org) is an open source farm management application that I am exploring for my small hay business.

## Target
A home or small office network that uses [Ubiquiti](https://www.ubnt.com) Unifi equipment and would benefit from a [Pi-Hole](https://www.pi-hole.net) DNS server which uses a pfsense firewall provides DNS-Over-TLS (DOT) encryption of DNS queries to upstream DNS provider(s).

Important Note: this configuration is designed for a home network that is double NATed by my ISP and behind a couple of firewalls I manage. It can be adapted to other environments but will need a thorough understanding of the security implications when doing so.

## Services
Service           | Notes
----------------  | ---------------------------------------------
Unifi Controller  | Web based Unifi network management application
Pi-Hole           | Blocking/filtering/caching DNS server
~~DOH Client~~        | ~~Uses HTTPS to send DNS queries to upstream~~
Mongo             | Database used by Unifi Controller
Logs              | Log display for Unifi Controller
~~Registry~~          | ~~Private instance of a Docker registry for development~~
Caddy             | Caddy based reverse proxy for Forgejo
Forgejo           | Forgejo is an open source alternative to github or gitlab. It has been adopted recently as the next gen replacement for dist-git.

The Unifi Controller is the web-based management application for Unifi network equipment. I use Jacob Alberty's [docker-based](https://github.com/jacobalberty/unifi-docker) version of the software. Please note that Ubiquiti does not officially support this software running in a Docker container at this time (April 2020). The Controller is used to manage all aspects of a Unifi network. The mongo and log services both support the Unifi Controller.

The [Pi-Hole](https://www.pi-hole.net) is the upstream DNS server to all networks (VLANs) defined in the Controller. Pi-Hole provides network level blocking of ads found on web pages, in mobile apps, and smart devices commonly found on home or office networks. The Pi-Hole also provides DNS caching for improved performance.

The [DNS-Over-HTTPS (DOH) client](https://hub.docker.com/r/buckaroogeek/doh-client) is the upstream DNS provider to the Pi-Hole. The DOH client receives DNS queries from the Pi-Hole using the standard plain text DNS protocol and forwards them to an upstream DNS server on the internet using an encrypted protocol (https). Google and CloudFlare are two well-known provides of DNS over HTTPS on the internet. The primary benefit of DOH is that by using HTTPS for DNS, none of the internet service providers between the home or office network and the upstream DOH server can see and monitor the DNS traffic.

~~The Registry service is extraneous to the Unifi Controller and supporting services. I use this for development purposes and should be deleted if not needed.~~

Forgejo is a github-like service for a git repository server and companion web user interface. Forgejo also provides a container registry service built-in. This service will be used as the foundation for a git-ops based ecosystem of bootc containers running an in-house Kubernetes cluster on VMs and Raspberry Pi devices.

## Docker Host
[Synology](https://www.synology.com) Network Attached Storage (NAS) device. Specifically a DS218+ (as I write this in April 2020). The DS218+ is used, in my case, as the docker host but any computer running docker on the same network should suffice. In principle, these services could be deployed to a computer that is external to the home network (e.g. Amazon cloud). I have not done so, and caution anyone using this compose file in the cloud to thoroughly investigate and mitigate any possible security ramifications.

## Network Topology
All unifi equipment, including a gateway (USG), switches (three 8 port switches), access points (five access points in 3 buildings), the wireless bridges between buildings (three [Ubiquiti AirMax Nanobeams](https://www.ui.com/airmax/nanobeam-ac-gen2/)), the Controller, and the Synology (docker host) are all on the same subnet - for example all using 192.168.110.x IP addresses. Docker is configured with a docker macvlan so that each container (controller, pi-hole, doh client) also has a unique IP address on the same subnet. See the technical notes below and the compose.yaml file for more details on the macvlan. 

The docker macvlan (macvlan1) is configured in the compose.yaml file to include this IP range: 192.168.110.192/26. See the [CIDR Subnet Calculator](https://www.xarg.org/tools/subnet-calculator/?q=192.168.110.192%2F26) for more details. Please be aware that the IP addresses in this macvlan subnet overlap with the IP address configuration for all other network equipment on local area network. I compensate for this overlap, which can cause a lot of problems if not accounted for, by only using hard coded IP addresses for all devices on this subnet (192.168.110.1/24). All other devices such as personal computers, smart phones, Tivo, etc, on the home network use another VLAN (actually multiple VLANs for family devices and computers, guest access, IOT devices that contact the internet, and a NoT VLAN for devices that only need access to a local home automation service).

Why use a macvlan for the containers? The macvlan simplifies configuration and results in a system that is easier to understand. Since the Pi-Hole and DOH Client containers both use port 53, having a unique IP on the home network avoids the need to map ports and juggle configurations. Similarly, for port 443 used by both the Unifi and Pi-Hole containers, separate IPs offer the same benefit. Other docker network configurations are feasible however. This configuration is just what works for me - but then my background in IT goes back to punch cards so I could well just be old fashioned!

## Technical Notes

Docker-compose is used to manage all containers on the docker host. On the Synology, this is done from the command line and not from the Docker web GUI. [Docker-compose](https://docs.docker.com/compose/reference/overview/) has complete control over all images and containers. Individual containers can be managed (start, stop, inspect, update) as well as all containers at the same time./

~~The .env file in the repository is not used at this time. I may use it to reduce duplication of some parameters in the compose file.~~

[Docker Compose Secrets](https://docs.docker.com/compose/how-tos/use-secrets/) is used to provide the web admin password to the Pi-Hole container. The Pi-Hole docker container uses the WEBPASSWORD_FILE environment variable to define the admin password for the web interface. Set this to your own value.

See [README-FORGEJO.md](README-FORGEJO.md) for additional notes on setting up the Forgejo container.

See the [Pi-Hole README.md](https://github.com/pi-hole/docker-pi-hole) for additional Pi-Hole variables and configuration options.

See the [DOH Client Docker Hub page](https://hub.docker.com/r/buckaroogeek/doh-client) for additional configuration options for the DOH client. See the configuration note below to make any needed changes to the doh-client.conf file and where to place it. By default the DOH Client will respond to dig and other DNS tools from any IP. This makes testing easier and in my case not a significant security problem of itself (rather my problems are much greater if that is happening). The configuration file can be used to lock down the DOH client so that it is only listening to the Pi-Hole server.

See Jacob's [Unifi Docker README.md](https://github.com/jacobalberty/unifi-docker) for additional Unifi Controller options. 

Several containers use external volumes to preserve information or data across container restarts. Before deploying this compose.yaml file, use the Synology File Station web interface to create each mount point. For the Pi-Hole service create two subdirectories at /volume1/docker/pihole/pihole-configs and /volume1/docker/pihole/dnsmasq.d-configs. The DOH client has one mount point at /volume1/docker/dohclient and so forth for all services defined in the compose file. These must exist before starting the containers.


As noted above, a docker macvlan is used to provide fixed IP addresses to all containers managed as a service in the compose.yaml file/. Using a docker macvlan on any linux docker host creates a complication in that by default a network path between the host IP and the docker macvlan IP space does not exist unless additional steps are taken. See the excellent overview of the problem and solution at https://blog.oddbit.com/post/2018-03-12-using-docker-macvlan-networks/. I have a small script to correct this complication on the docker host. Other network configurations are possible but beyond the scope of this readme. Please be aware that making the configuration enabled by the script persistent across system reboots and network restarts can vary based on the docker host OS. For a Synology NAS with DSM 7 or newer, the section on Persisting the macvlan network settings from https://blog.ivansmirnov.name/set-up-pihole-using-docker-macvlan-network/ is helpful.

```
sudo cp scripts/shim.sh /usr/local/bin
sudo chmod +x /usr/local/bin/shim.sh
sudo cp macvlan-shim.service /etc/systemd/system
sudo chmod go+r /etc/systemd/system/macvlan-shim.service
sudo systemctl start macvlan-shim.service
```

A the next network restart or system boot, the shim.sh script will execute and enable local area network connection to containers on the docker macvlan.


## Execution

Docker Compose is a command line executable available for most linux systems uncluding the Synology. There are many references available - I find the original Docker documentation very approachable and useful: https://docs.docker.com/compose/.

Start all services in the default compose.yaml file
```bash
sudo docker-compose up
```

Start all services in the default compose.yaml file and detach.
```bash
sudo docker-compose up -d
```

Start the Pi-Hole service in the default compose.yaml file and detach.
```bash
sudo docker-compose up -d pihole
```

Start all services in both compose.yaml files and detach.
```bash
sudo docker-compose up -d -f compose.yaml -f docker-compose-farmos.yaml
```

## Configuration

Before starting the the DOH Client, download the example doh-client.conf file from this repository and edit as needed. Select which upstream DOH servers to use. By default, both Google and CloudFlare servers are enabled along with a Random selection protocol. Use the Synology web inteface to upload this configuration file to the correct location (matching the volume defined for the DOH Client service). There is a default doh-client.conf file bundled in the Docker image which has the client listening to port 53 from any IP and using CloudFlare as the upstream DNS service. If this is suitable, remove the volume configuration line for the DOH client in the compose file.

Once the services are running, the Unifi Controller will need to be configured to use the Pi-Hole DNS server for each appropriate network. Settings, Network, Edit Network, then select Manual for DHCP Name Server (mislabeled this should be Domain Name Server) and set the Pi-Hole IP for DNS 1. Set an alternative DNS server (e.g. the Unifi Gateway or other suitable IP) for DNS server 2 and 3. If the client device cannot connect to the Pi-Hole, DNS will still function.

In the Pi-Hole web interface navigate to Settings, DNS tab and check Custom 1(IPV4). Set the IP address for the DOH Client docker container here and the port (e.g. 192.168.110.203#53).

Once the containers are running with the macvlan, you can use the shim.sh script as root on the docker host machine (Synology in my case) to create a network path from the docker host IP (synology IP in my case) to the container IPs. Making this configuration persistent is beyond the scope of this readme (Synology does not make it super easy).

## Credit
DOH Client original source code: https://github.com/m13253/dns-over-https

DOH Client docker repository: https://hub.docker.com/r/buckaroogeek/doh-client

Jacob Alberty's unifi docker repository: https://github.com/jacobalberty/unifi-docker

Pi-Hole Docker code: https://github.com/pi-hole/docker-pi-hole

Tony Lawrence's inspiring write up on running a Pi-Hole with Docker on a Synology NAS: http://tonylawrence.com/posts/unix/synology/free-your-synology-ports/

Chris Sherwood at Crosstalk Solutions and his excellent You Tube series for Ubiquiti equipment and Synology configuration - https://www.youtube.com/channel/UCVS6ejD9NLZvjsvhcbiDzjw

Willie Howe for his excellent YouTube Channel covering Ubiquiti and Synology - https://www.youtube.com/channel/UCD-QkofF-bFBAcI83U8ZZeg

Ivan Smirnov for an excellent recent blog post on setting up a docker macvlan for a pihole container: https://blog.ivansmirnov.name/set-up-pihole-using-docker-macvlan-network/
