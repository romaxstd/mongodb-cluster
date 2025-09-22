# Deploy a basic GCP infrastructure (main.tf):

-VPC network with Cloud Router & Cloud NAT

-3 compute instances in separate zones for HA

-Firewall rules

# Deploy a self-managed MongoDB replica set for testing (repl_set.sh): 

-Install a MongoDB Community Server

-Holds the packages to prevent version changes

-Creates the local data directories

Creates the config file for the replica set member
 
-Starts the mongod service that's prepared to join a replica set

-Creates the replica set configuration that's used to initiate the replica set through mongosh
