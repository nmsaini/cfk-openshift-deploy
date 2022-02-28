#!/bin/bash

namespace=$1

if [ -z $namespace ]
then
    echo "Usage: remove.sh <confluent namespace>"
    exit 1
fi

oc project $namespace

# remove all components
oc delete KafkaRestProxies.platform.confluent.io restproxy
oc delete ControlCenter.platform.confluent.io controlcenter
oc delete Connect.platform.confluent.io connect
oc delete KsqlDB.platform.confluent.io ksqldb
oc delete SchemaRegistry.platform.confluent.io schemaregistry
oc delete Kafka.platform.confluent.io kafka
oc delete Zookeeper.platform.confluent.io zookeeper

helm delete cfk-operator

secrets="zookeeper-listener \
    kafka-listener \
    kafka-zookeeper \
    connect-kafka \
    sr-kafka \
    ksql-kafka \
    connect-listener \
    ksql-listener \
    sr-listener \
    c3-listener \
    c3-connect \
    c3-ksql \
    c3-kafka \
    c3-sr \
    proxy-listener \
    metric-credentials \
    kafka-tls \
    connect-tls \
    replicator-tls \
    schemaregistry-tls \
    ksqldb-tls \
    controlcenter-tls \
    zookeeper-tls \
    kafkarestproxy-tls \
    proxy-kafka \
    proxy-sr \
    ca-pair-sslcerts"

for secret in $secrets
do
    oc delete secret $secret
done

rm confluent-$namespace.p12
rm k-truststore.jks
