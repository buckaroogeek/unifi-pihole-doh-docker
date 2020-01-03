docker network create -d macvlan -o parent=eth0  --subnet 192.168.110.0/24 --gateway 192.168.110.1 --ip-range 192.168.110.201/28 piholenet

