# cfk-openshift-deploy

## deploying
Deploy confluent-for-kubernetes deployment using the operator

`
./create-kafka-deployment.sh <namespace> <Domain-url> <config-template.yaml> <kafka-user> <kafka-user-pass> <c3-user> <c3-user-pass>
`
 
e.g.

`
./create-kafka-deployment.sh confluent apps.ns.cp.fyre.ibm.com kafka-template.yaml kuser kuserPASS c3user c3userPASS
`

Before running this script make sure you edit the create-kafka-certs.sh and make sure line# 3 and 4 is to your liking.

This script creates the namespace, and installs the operator within the namespace. It then generates all the certificates for the components, creates the secrets and generates the deployment configuration. Apply the deployment using 

`
oc apply -f deployed-config-template.yaml
`

## licensed version
Before running the `oc apply` command update your operator with your license text.

`
helm upgrade --install cfk-operator confluentinc/confluent-for-kubernetes --set licenseKey=<CFK license key>
`

After the operator is updated, you can edit all the components in the yaml and add
```
spec:
  license:
    globalLicense: true
```
and re-apply the deployment.

```
cat deployed-kafka-template.yaml | yq e ".spec.license.globalLicense=true" - | oc apply -f -
```

if you want to keep a copy of the deployment yaml. Just pipe it into a file and save it
```
cat deployed-kafka-template.yaml | yq e ".spec.license.globalLicense=true" - > deployed-kafka-template-lic.yaml

oc apply -f deployed-kafka-template-lic.yaml
```

## removing
`
./remove-kafka-deployment.sh <namespace>
`
  
  e.g. 
  
  `
  ./remove-kafka-deployment.sh confluent
  `
  
This script deletes the current deployment from the namespace and deletes the secrets generated by the deployment. It doesn't remove the namespace. You can remove it by

` oc delete project <namespace>`
  
## prerequisites
1. **helm** 
```
  curl -fsSL -o /tmp/get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
  chmod +x /tmp/get_helm.sh
  /tmp/get_helm.sh
```
2. **keytool**
```
yum install java-1.8.0-openjdk -y
```
3. **yq**
```
VER=4.16.1 BIN=yq_linux_amd64;wget https://github.com/mikefarah/yq/releases/download/v${VER}/${BIN} -O /usr/bin/yq && chmod +x /usr/bin/yq
```

/chg0317
