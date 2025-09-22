#!/bin/bash
set -ex

### RUN THIS SCRIPT ON ALL INSTANCES THAT ARE TO BE PART OF THE REPLICA SET

### This script: 
# Installs a MongoDB Community Server
# Holds the packages to prevent version changes
# Creates the local data directories
# Creates the config file for the replica set member
# Starts the mongod service that's prepared to join a replica set
# Creates the replica set configuration that's used to initiate the replica set through mongosh
# FYI the mongosh operations are not scripted, only described
###

# Update list of available packages & upgrade the system by installing/upgrading packages
apt update && apt upgrade -y

# Install some utilities 
apt install htop lsof netcat-openbsd gnupg curl -y

# Import the MongoDB public GPG key
curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | \
   gpg -o /usr/share/keyrings/mongodb-server-8.0.gpg \
   --dearmor

# Create the list file for Debian 12
echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] http://repo.mongodb.org/apt/debian bookworm/mongodb-org/8.0 main" | \
    tee /etc/apt/sources.list.d/mongodb-org-8.0.list

#  Reload the local package database
apt update

# Install MongoDB Community Server specific version
version="8.0.12"

apt install -y \
   mongodb-org=${version} \
   mongodb-org-database=${version} \
   mongodb-org-server=${version} \
   mongodb-mongosh \
   mongodb-org-shell=${version} \
   mongodb-org-mongos=${version} \
   mongodb-org-tools=${version} \
   mongodb-org-database-tools-extra=${version}

# Hold the package at the currently installed version
echo "mongodb-org hold" | dpkg --set-selections
echo "mongodb-org-database hold" | dpkg --set-selections
echo "mongodb-org-server hold" | dpkg --set-selections
echo "mongodb-mongosh hold" | dpkg --set-selections
echo "mongodb-org-mongos hold" | dpkg --set-selections
echo "mongodb-org-tools hold" | dpkg --set-selections
echo "mongodb-org-database-tools-extra hold" | dpkg --set-selections

# Create the necessary data directories for each replica set member
repl_set_name="rs0"
mkdir -p /srv/mongodb/${repl_set_name}-{0..2}
chown -R mongodb:mongodb /srv/mongodb/

# Create new mongod.conf for replica set member
hostname_local=$(hostname)
repl_set_ordinal=${hostname_local:(-1)} #To print the last n characters of a string in Bash, you can use parameter expansion with negative offsets.
fqdn_local=$(hostname -f)

cat << EOF > /etc/mongod.conf
# mongod.conf
# created by Guy's script

storage:
  dbPath: /srv/mongodb/${repl_set_name}-${repl_set_ordinal}

systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

net:
  port: 27017
  bindIp: 127.0.0.1,${fqdn_local}

processManagement:
  timeZoneInfo: /usr/share/zoneinfo

replication:
   oplogSizeMB: 128
   replSetName: "${repl_set_name}"
EOF

# Start local MongoDB service and set it to autostart on boot
systemctl start mongod.service && systemctl enable mongod.service

# Create a replica set configuration object
# This will be used to initiate the replica set
cat << EOF > ./rsconf
rsconf = {
  _id: "rs0",
  members: [
    {
     _id: 0,
     host: "${fqdn_repl_member_0}:27017"
    },
    {
     _id: 1,
     host: "${fqdn_repl_member_1}:27017"
    },
    {
     _id: 2,
     host: "${fqdn_repl_member_2}:27017"
    }
   ]
}
EOF

## Test Connections Between all Members
## All members of a replica set must be able to connect to every other member of the set to support replication
## Always verify connections in both "directions".
##
# # FQDN for a given host can be found by running "hostname -f" on the local host
# fqdn_repl_member_0="mongodb-repl-member-0.us-central1-a.c.tf01-472217.internal"
# fqdn_repl_member_1="mongodb-repl-member-1.us-central1-b.c.tf01-472217.internal"
# fqdn_repl_member_2="mongodb-repl-member-2.us-central1-c.c.tf01-472217.internal"
##
# # Use netcat to test connectivity to the mongod service port
# nc -zv ${fqdn_repl_member_0} 27017
# nc -zv ${fqdn_repl_member_1} 27017
# nc -zv ${fqdn_repl_member_2} 27017


## Initiate the replica set
## THE FOLLOWING STEP IS ONLY DONE ONCE, ON ONE OF THE REPLICA SET MEMBERS
## To initiate the replica set, Connect to one of your mongod instances through mongosh
## Then do steps 1 & 2
# 1. Create a replica set configuration object in mongosh environment, using the rsconf from above
# 2. Initiate the replica set - rs.initiate( rsconf )

## Some useful shell methods
# rs.status() - Returns the replica set status from the point of view of the member where the method is run.
# rs.conf() - Returns a document that contains the current replica set configuration
# rs.printReplicationInfo() - Prints a formatted report of the replica set member's oplog
# rs.printSecondaryReplicationInfo() - Prints a formatted report of the replica set status from the perspective of the secondary member of the set.

#Sources:
#https://www.mongodb.com/docs/manual/tutorial/install-mongodb-on-debian/
#https://www.mongodb.com/docs/manual/tutorial/deploy-replica-set-for-testing/