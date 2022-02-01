#!/bin/bash

CERT_SUBJ='/C=US/ST=State/L=City/O=IBM Organization/OU=Cloud'
ROOT_CERT_SUBJ=$CERT_SUBJ/CN=CertCA

namespace=$1
exthost=$2

if [ -z $namespace ] || [ -z $exthost ]
then
    echo "Usage: create-certs.sh <namespace for deployment> <external host> "
    exit 1
fi

components="kafka connect replicator schemaregistry ksqldb controlcenter zookeeper proxy"

# Change to certs directory
if [ ! -d certs ]
then
    mkdir certs
fi

cd certs

if [ -z $(oc get secret kafka-tls --ignore-not-found=true |grep -q kafka-tls)  ]
then

    # Create new certs

    # Root key
    openssl genrsa -out confluentCA-key.pem 2048

    # Root cert
    openssl req -x509  -new -nodes -key confluentCA-key.pem -days 3650 -out confluentCA.pem -subj "$ROOT_CERT_SUBJ"

    for component in $components
    do
        # Server key
        openssl genrsa -out $component-key.pem 2048

        # Create CSR
        openssl req -new -key $component-key.pem -out $component.csr -subj "$CERT_SUBJ/CN=*.$component.$namespace.svc.cluster.local"
        
        # Sign the CSR
        openssl x509 -req -in $component.csr -extensions server_ext -CA confluentCA.pem -CAkey confluentCA-key.pem -CAcreateserial -out $component.pem -days 3650 -extfile <( echo "[server_ext]"; echo "extendedKeyUsage=serverAuth,clientAuth"; echo "subjectAltName=DNS:*.$exthost,DNS:$component,DNS:*.$component,DNS:*.$component.$namespace.svc.cluster.local,DNS:$component.$namespace.svc.cluster.local")
    
        # Now create the secret
        oc create secret generic $component-tls \
            --from-file=fullchain.pem=$component.pem \
            --from-file=cacerts.pem=confluentCA.pem \
            --from-file=privkey.pem=$component-key.pem

    done
fi

cd ..

exit 0
