#!/bin/bash

# this script installs the operator
# generates the deployment yaml with the correct secrets and LB urls
# it does not deploy the yaml

namespace=$1
domain=$2
filename=$3
kafkaUser=$4
kafkaPass=$5
c3User=$6
c3Pass=$7

if [ -z $namespace ] || [ -z $domain ] || [ -z $filename ] || [ -z $kafkaUser ] || [ -z $kafkaPass ] || [ -z $c3User ] || [ -z $c3Pass ]
then
    echo "Usage: create-kafka-deployment.sh <namespace for deployment> <cluster domain> <config yaml> <kafka username> <kafka password> <c3 username> <c3 password>"
    exit 1
fi

# Copy config file to new file to avoid corrupting the old one
cp $filename deployed-$filename
filename=deployed-$filename

# Create and configure namespace
echo Creating and configuring namespace
oc new-project $namespace
oc project $namespace
oc adm policy add-scc-to-group privileged system:serviceaccounts:$namespace

# Check if helm repo exists, if not add it
if  helm repo list | grep -q "confluentinc" 
then
    echo Repo installed, skipping
else
    echo Repo not installed, installing
    helm repo add confluentinc https://packages.confluent.io/helm
    helm repo update
fi

# Install the operator
echo Installing the operator
helm upgrade --install cfk-operator confluentinc/confluent-for-kubernetes

# Create certificates
if [ -z $(oc get secret kafka-tls --ignore-not-found=true |grep -q kafka-tls) ] 
then
    ./create-kafka-certs.sh $namespace $domain
fi

# Create a PKCS12 keystore with the CA cert
echo Creating keystore
keytool -keystore confluent-$namespace.p12 -storetype PKCS12 -import -file ./certs/confluentCA.pem -storepass password -noprompt

# Run the create-secrets script
echo Creating auth secrets
./create-kafka-secrets.sh $namespace $kafkaUser $kafkaPass $c3User $c3Pass

# Edit the namespaces and route prefixes in the configuration yaml.  
# splits the file into its component parts, and then edit each one
# finally recombine them

# temp dir for writing files
if [ -d operatorTemp ]
then
    rm -rf operatorTemp
fi

mkdir operatorTemp
cd operatorTemp

if [ -f newFile.yaml ]
then
    rm newFile.yaml
fi

# Split up the config file into components

echo Scanning input configuration file
index=0
fileContent=$(i=$index yq eval 'select(di == env(i))' ../$filename)

while [ ! -z "${fileContent// }" ]
do
    type=$(i=$index yq eval 'select(di == env(i)) | .kind' ../$filename)
    echo $type added to configuration
    echo "$fileContent" > $type.yaml

    ((index=index+1))
    fileContent=$(i=$index yq eval 'select(di == env(i))' ../$filename)

done

echo Configuring routes for external access

# Change the route prefix for the Kafka brokers
yq eval -i ".spec.listeners.external.externalAccess.route.brokerPrefix = \"kafka-$namespace-\"" Kafka.yaml
yq eval -i ".spec.listeners.external.externalAccess.route.bootstrapPrefix = \"kafka-$namespace\"" Kafka.yaml
yq eval -i ".spec.listeners.external.externalAccess.route.domain = \"$domain\"" Kafka.yaml

# Change the kafka endpoint for the components and whilst we're there, update the 
# domain for the external access if present. See security note in the README

for component in ControlCenter SchemaRegistry Connect KsqlDB Kafka
do
    file="$component".yaml
    lowercaseComponent=$(echo $component | tr '[:upper:]' '[:lower:]')
    yq eval -i ".spec.dependencies.kafka.bootstrapEndpoint = \"kafka.$namespace.svc.cluster.local:9071\"" $file

    # Only modify the route if it's present
    if  [[ $(yq eval ".spec.externalAccess" $file) != "null" ]]
    then
        yq eval -i ".spec.externalAccess.route.domain = \"$domain\"" $file
    fi
done

# Set up the tls config with the certificates generated earlier
for component in ControlCenter SchemaRegistry Connect KsqlDB Zookeeper Kafka
do
    file="$component".yaml
    lowercaseComponent=$(echo $component | tr '[:upper:]' '[:lower:]')

    # Configure the tls secret for each component
    yq eval -i "del(.spec.tls)" $file
    yq eval -i ".spec.tls.secretRef = \"$lowercaseComponent-tls\"" $file
done

echo Configuring Control Center to point to the right endpoints for the components

# Cofigure component endpoints in Control Center
if [ -e ControlCenter.yaml ]
then
    if [ -e Connect.yaml ]
    then
        yq eval -i ".spec.dependencies.connect.[0].url = \"https://connect.$namespace.svc.cluster.local:8083\"" ControlCenter.yaml      
    fi

    if [ -e SchemaRegistry.yaml ]
    then
        yq eval -i ".spec.dependencies.schemaRegistry.url = \"https://schemaregistry.$namespace.svc.cluster.local:8081\"" ControlCenter.yaml
    fi

    if [ -e KsqlDB.yaml ]
    then
        yq eval -i ".spec.dependencies.ksqldb.[0].url = \"https://ksqldb.$namespace.svc.cluster.local:8088\"" ControlCenter.yaml
    fi
fi

echo Adding basic auth to Schema Registry
# Add basic auth to the schema registry and the dependency in C3, but not the others as it's not yet supported
yq eval -i ".spec.authentication.type = \"basic\"" SchemaRegistry.yaml
yq eval -i ".spec.authentication.basic.secretRef = \"sr-listener\"" SchemaRegistry.yaml
yq eval -i ".spec.dependencies.schemaRegistry.authentication.type = \"basic\"" ControlCenter.yaml
yq eval -i ".spec.dependencies.schemaRegistry.authentication.basic.secretRef = \"c3-sr\"" ControlCenter.yaml

echo Creating final YAML file
# Replace the namespace element in each file and then cat them to the temp file
index=0
for file in *.yaml
do
    yq eval -i ".metadata.namespace = \"$namespace\"" $file

    if [ ! $index -eq 0 ]
    then
        echo "---" >> newFile.yaml
    fi

    cat $file >> newFile.yaml

    ((index=index+1))
done

cp newFile.yaml ../$filename
cd ..

# clean up temp dir 
rm -rf operatorTemp

echo generated deployment YAML configuration...use oc apply -f ./$filename to apply!

echo Trust store is: confluent-$namespace.p12, password is password

