ip link add shim link eth0 type macvlan mode bridge
ip addr add 192.168.110.193/32 dev shim
ip link set shim up
ip route add 192.168.110.192/26 dev shim

