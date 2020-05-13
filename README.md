Yet Another Unifi Controller, Pi-Hole, and DNS-Over-HTTPS Setup using Docker Compose
============================================================================

## Description
A docker-compose yaml file to manage a Unifi Controller service, a Pi-Hole service, and a DNS-Over-HTTPS client service for my home network. Also included is a supporting script for the docker host. Additional services may be included for development/testing (e.g. a local docker registry) or to support one of the other services (e.g. logs and mongo for the Unifi Controller).

Version 2 of the Docker compose format is used because macvlan networks are not supported in version 3 as a network configuration at this time. If compose format version 3 is required then the macvlan can be established via an external docker command.

In addition, a separate bash script is provided that enables the docker host to have a direct network connection to the containers on the docker macvlan. See the technical notes below.

## Target
A home or small office network that uses [Ubiquiti](https://www.ubnt.com) Unifi equipment and would benefit from a [Pi-Hole](https://www.pi-hole.net) DNS server and DNS-Over-HTTPS for encryption of DNS queries to upstream DNS provider(s).

## Services
Service           | Notes
----------------  | ---------------------------------------------
Unifi Controller  | Web based Unifi network management application
Pi-Hole           | Blocking/filtering/caching DNS server
DOH Client        | Uses HTTPS to send DNS queries to upstream
Mongo             | Database used by Unifi Controller
Logs              | Log display for Unifi Controller
Registry          | Private instance of a Docker registry for development

The Unifi Controller is the web-based management application for Unifi network equipment. I use Jacob Alberty's [docker-based](https://github.com/jacobalberty/unifi-docker) version of the software. Please note that Ubiquiti does not officially support this software running in a Docker container at this time (April 2020). The Controller is used to manage all aspects of a Unifi network. The mongo and log services both support the Unifi Controller.

The [Pi-Hole](https://www.pi-hole.net) is the upstream DNS server to all networks (VLANs) defined in the Controller. Pi-Hole provides network level blocking of ads found on web pages, in mobile apps, and smart devices commonly found on home or office networks. The Pi-Hole also provides DNS caching for improved performance.

The [DNS-Over-HTTPS (DOH) client](https://hub.docker.com/r/buckaroogeek/doh-client) is the upstream DNS provider to the Pi-Hole. The DOH client receives DNS queries from the Pi-Hole using the standard plain text DNS protocol and forwards them to an upstream DNS server on the internet using an encrypted protocol (https). Google and CloudFlare are two well-known provides of DNS over HTTPS on the internet. The primary benefit of DOH is that by using HTTPS for DNS, none of the internet service providers between the home or office network and the upstream DOH server can see and monitor the DNS traffic.

The Registry service is extraneous to the Unifi Controller and supporting services. I use this for development purposes and should be deleted if not needed.

## Docker Host
[Synology](https://www.synology.com) Network Attached Storage (NAS) device. Specifically a DS218+ (as I write this in April 2020). The DS218+ is used, in my case, as the docker host but any computer running docker on the same network should suffice. In principle, these services could be deployed to a computer that is external to the home network (e.g. Amazon cloud). I have not done so, and caution anyone using this compose file in the cloud to thoroughly investigate and mitigate any possible security ramifications.

## Network Topology
All unifi equipment, including a gateway (USG), switches (three 8 port switches), access points (five access points in 3 buildings), the wireless bridges between buildings (three [Ubiquiti AirMax Nanobeams](https://www.ui.com/airmax/nanobeam-ac-gen2/)), the Controller, and the Synology (docker host) are all on the same subnet - for example all using 192.168.110.x IP addresses. Docker is configured with a docker macvlan so that each container (controller, pi-hole, doh client) also has a unique IP address on the same subnet. See the technical notes below and the docker-compose.yaml file for more details on the macvlan. 

The docker macvlan (macvlan1) is configured in the docker-compose.yaml file to include this IP range: 192.168.110.192/26. See the [CIDR Subnet Calculator](https://www.xarg.org/tools/subnet-calculator/?q=192.168.110.192%2F26) for more details. Please be aware that the IP addresses in this macvlan subnet overlap with the IP address configuration for all other network equipment on local area network. I compensate for this overlap, which can cause a lot of problems if not accounted for, by only using hard coded IP addresses for all devices on this subnet (192.168.110.1/24). All other devices such as personal computers, smart phones, Tivo, etc, on the home network use another VLAN (actually multiple VLANs for family devices and computers, guest access, IOT devices that contact the internet, and a NoT VLAN for devices that only need access to a local home automation service).

## Usage and Technical Notes

Docker-compose is used to manage all containers on the docker host. On the Synology, this is done from the command line and not from the Docker web GUI. [Docker-compose](https://docs.docker.com/compose/reference/overview/) has complete control over all images and containers. Individual containers can be managed (start, stop, inspect, update) as well as all containers at the same time./

The .env file in the repository is not used at this time. 

See the [Pi-Hole README.md](https://github.com/pi-hole/docker-pi-hole) for additional variables and configuration options.

See the [DOH Client Docker Hub page](https://hub.docker.com/r/buckaroogeek/doh-client) for additional configuration options for the DOH client. See the configuration note below to make any needed changes to the doh-client.conf file and where to place it. By default the DOH Client will respond to dig and other DNS tools from devices on the same network. This makes testing easier. The configuration file can be used to lock down the DOH client so that it is only listening to the Pi-Hole server.

See Jacob's [Unifi Docker README.md](https://github.com/jacobalberty/unifi-docker) for additional Unifi Controller options. 

Several containers use external volumes to preserve information or data across container restarts. Before deploying this docker-compose.yaml file, use the Synology File Station web interface to create each mount point. For the Pi-Hole service create two subdirectories at /volume1/docker/pihole/pihole-configs and /volume1/docker/pihole/dnsmasq.d-configs. The DOH client has one mount point at /volume1/docker/dohclient and so forth for all services defined in the compose file. These must exist before starting the containers.

The PiHole docker container uses the WEBPASSWORD environment variable to define the admin password for the web interface. Set this to your own value.

As noted above, a docker macvlan is used to provide fixed IP addresses to all containers managed as a service in the docker-compose yaml file/. Using a docker macvlan on any linux docker host creates a complication in that by default a network path between the host IP and the docker macvlan IP space does not exist unless additional steps are taken. See the excellent overview of the problem and solution at https://blog.oddbit.com/post/2018-03-12-using-docker-macvlan-networks/. I have a small script to correct this complication on the docker host. Other network configurations are possible but beyond the scope of this readme. Please be aware that making the configuration enabled by the script persistent across system reboots and network restarts is beyond the scope of this repository and these notes.

## Configuration

Before starting the the DOH Client, download the example doh-client.conf file from this repository and edit as needed. Select which upstream DOH servers to use. By default, both Google and CloudFlare servers are enabled along with a Random selection protocol. Use the Synology web inteface to upload this configuration file to the correct location (matching the volume defined for the DOH Client service).

Once the services are running, the Unifi Controller will need to be configured to use the Pi-Hole DNS server for each appropriate network. Settings, Network, Edit Network, then select Manual for DHCP Name Server (mislabeled this should be Domain Name Server) and set the Pi-Hole IP for DNS 1. Set an alternative DNS server (e.g. the Unifi Gateway or other suitable IP) for DNS server 2 and 3. If the client device cannot connect to the Pi-Hole, DNS will still function.

In the Pi-Hole web interface navigate to Settings, DNS tab and check Custom 1(IPV4). Set the IP address for the DOH Client docker container here and the port (e.g. 192.168.110.203#53).

## Credit
DOH Client original source code: https://github.com/m13253/dns-over-https

DOH Client docker repository: https://hub.docker.com/r/buckaroogeek/doh-client

Jacob Alberty's unifi docker repository: https://github.com/jacobalberty/unifi-docker

Pi-Hole Docker code: https://github.com/pi-hole/docker-pi-hole

Tony Lawrence's inspiring write up on running a Pi-Hole with Docker on a Synology NAS: http://tonylawrence.com/posts/unix/synology/free-your-synology-ports/


