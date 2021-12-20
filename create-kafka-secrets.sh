#!/bin/bash

namespace=$1
kafkaUser=$2
kafkaPass=$3
c3User=$4
c3Pass=$5

if [ -z $namespace ] || [ -z $kafkaUser ] || [ -z $kafkaPass ] || [ -z $c3User ] || [ -z $c3Pass ]
then
    echo "Usage: create-secrets.sh <namespace for deployment> <kafka username> <kafka password> <c3 username> <c3 password>"
    exit 1
fi

# Set up credentials
mkdir temp

# Simple credential file for Kafka user
echo "username=$kafkaUser" > temp/kafka-plain.txt
echo "password=$kafkaPass" >> temp/kafka-plain.txt

# JSON digest file format for Kafka user
echo "{" > temp/digest.json
echo "  \"$kafkaUser\": \"$kafkaPass\"" >> temp/digest.json
echo "}" >> temp/digest.json

# Basic client auth Kafka creds
echo "$kafkaUser: $kafkaPass" > temp/kafka-basic.txt

# Admin Kafka client creds
echo "$kafkaUser: $kafkaPass,admin" > temp/kafka-roles.txt

# C3 user login
echo "$c3User: $c3Pass,Administrators" > temp/c3-user.txt

# Metric reporter
echo "username=operator" > temp/metric-cred.txt
echo "password=operator-secret" >> temp/metric-cred.txt

# Now create the secrets from these files

# Kafka and Zookeeper

# Kafka listener
oc create secret generic kafka-listener \
    --from-file=plain-users.json=temp/digest.json

# Zookeeper listener
oc create secret generic zookeeper-listener \
    --from-file=digest-users.json=temp/digest.json

# Kafka -> Zookeeper
oc create secret generic kafka-zookeeper \
    --from-file=digest.txt=temp/kafka-plain.txt

# Components connecting to Kafka

# Connect -> Kafka
oc create secret generic connect-kafka \
    --from-file=plain.txt=temp/kafka-plain.txt

# Schema Registry -> Kafka
oc create secret generic sr-kafka \
    --from-file=plain.txt=temp/kafka-plain.txt

# KSQL -> Kafka
oc create secret generic ksql-kafka \
    --from-file=plain.txt=temp/kafka-plain.txt

# Listeners for the components

# Connect listener
oc create secret generic connect-listener \
    --from-file=basic.txt=temp/kafka-roles.txt

# KSQL Listener
oc create secret generic ksql-listener \
    --from-file=basic.txt=temp/kafka-roles.txt

# SR Listener
oc create secret generic sr-listener \
    --from-file=basic.txt=temp/kafka-roles.txt

# Control Center

# User login for C3
oc create secret generic c3-user \
    --from-file=basic.txt=temp/c3-user.txt 

# C3 -> Connect
oc create secret generic c3-connect \
    --from-file=basic.txt=temp/kafka-plain.txt

# C3 -> KSQL
oc create secret generic c3-ksql \
    --from-file=basic.txt=temp/kafka-plain.txt

# C3 -> SR
oc create secret generic c3-sr \
    --from-file=basic.txt=temp/kafka-plain.txt

# Credentials for the metric reporter
oc create secret generic metric-credentials \
    --from-file=plain.txt=temp/metric-cred.txt

rm -rf temp