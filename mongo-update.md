Updating MongoDB - An experiment
============================================================================

## Description
Unifi has released Unifi Network Application v8.1.113 with support for (up to) MongoDB 7. My instance of Unifi (now at v8.1.113) has been running on a Synology NAS for several years with many updates from Jacob Alberty. At somepoint I deployed a stand-alone MongoDB container for use by Unifi. Mongo started at v3.3 (?) and is now at v3.6. 

I am going to try to update MongoDB serially to v7 following the general path of

1. 3.6 to 4.2
1. 4.2 to 4.4
1. 4.4 to 5.0
1. 5.0 to 6.0
1. 6.0 to 7.0

I will use mongodump and mongorestore to carry out the updates. Containers make the software update side fairly trivial: update the version for mongo in compose and bring it up. Shell into the mongodb container and execute restore.

As a preliminary, I will add a volume at /dump in the container for data persistance.

As an experiment I will try a 3.6 to 4.4 jump.

I ssh into the synology to execute all docker and ssh commands into the mongo container. MongoDB is running on a network shared only with the unifi and log containers and is not accessible from elsewhere on the LAN. 

The command to shell into the running container is (using the container id):
```
sudo docker exec -it bce6ba3680a5 bash
```

## General Process
1. Stop unifi, log, and mongo containers.
2. Tag the 3.6 mongodb container for potential reuse in case of failure.
2. Update the compose definition for mongodb to provide a volume at /dump
1. Use synology web ui to copy the mongodb data folder.
2. Start the mongodb container
2. Shell into the mongodb container
2. Excute mongodump.
2. Exit and stop container.
2. Update compose file to next release and start mongo container.
3. Shell into container and mongorestore.
3. Repeat most of the cycle with each version step.

## Steps
1. ssh to the synology ```ssh syn```. 
1. Pull mongo 4.4: ```sudo docker pull mongo:4.4```
1. Stop mongo, unifi, logs: ```sudo docker-compose -f compose.yaml stop unifi mongo logs```
1. back up mongo directory in Synology web ui
1. Edit compose.yaml to add ```     - /volume1/docker/mongo/dump:/dump``` to mongo definition.
1. start mongo 3.6 ```sudo docker-compose -f compose.yaml up -d mongo```
2. find mongo container id ```sudo docker ps```
2. shell into mongo ```sudo docker exec -it 97799f4cc4fa bash```
2. Dump mongo ```mongodump```. No command line options needed. And exit.
2. Stop mongo. You can also verify in the Synology web UI that the dump files exist.
2. Update mongo version to 4.4 in ```compose.yaml```
2. In the Synology web UI, rename the mongo/db subdirectory to mongo/db3.6 and create an empty mongo/db directory. This is where the mongo database is stored. This creates an empty directory for the new version of mongo to restore the database to.
2. Start mongo (4.4 based on the edit step above). ```sudo docker-compose -f compose.yaml up -d mongo```
3. Find the mongo container id and shell into the container (as above).
3. Run mongorestore: ```mongorestore``` without any options. This takes longer than the dump process. Mine ended with: ```2024-03-21T22:06:46.736+0000	36879 document(s) restored successfully. 0 document(s) failed to restore.```.
3. I then started unifi and logs: ```sudo docker-compose -f compose.yaml up -d unifi logs```. Unifi took a bit to start then went through the device discovery process. There was data in the usage graphs and no obvious errors in the log files or web UI.
3. I left unifi running overnight with mongo 4.4 to allow time for any problems to show up. Besides, I needed to go feed the horses and take care of other chores around the place.

My Synology is old enough that the CPU does not provide AVX which is needed to deploy Mongo v5.0 or newer.

## Mongo DB Repair

I encountered the situation described on Stack Overflow: https://stackoverflow.com/questions/66508965/mongo-docker-setup-broken-after-reboot-unifi-controller-on-raspberry-pi right after an update to a current version of Unifi Network Controller (v8.2.93). Traffic displayed 0 MB and there were mongo related errors showing up in the log container.

1. Stopped all containers
2. Backed up mongo db directory in synology web ui
3. Ran repair via mongo container
```
sudo docker run -it -v /volume1/docker/mongo/db:/data/db mongo:4.4 mongod --repair
```
1. Open a bash session in mongo container and deleted lock files. Alternatively Ipotentially could have done so via Synology UI.
```
sudo docker run -it -v /volume1/docker/mongo/db:/data/db mongo:4.4 bash
cd /data/db
rm *lock
exit
```
1. Restarted mongo container. No obvious errors. Mongo container was not restarting every 20 seconds or so.
2. Restarted unifi and log containers.
3. Accessed web ui to verify proper functioning.
4. View log container for errors.

## Update Notes
Date        | Notes
----------  | -------------------------------
 7 Jun 2024      | Add notes on DB repair
21 Mar 2024      | Initial draft with notes on update from mongodb 3.6 to 4.4.

## References
1. Mongo Images: https://hub.docker.com/_/mongo
1. Mongo DB repair steps: https://stackoverflow.com/questions/66508965/mongo-docker-setup-broken-after-reboot-unifi-controller-on-raspberry-pi
1. Ubiquiti Mongo repair steps: https://help.ui.com/hc/en-us/articles/360006634094-UniFi-Repairing-Database-Issues-on-the-UniFi-Network-Application

