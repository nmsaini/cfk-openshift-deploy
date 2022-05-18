#!/bin/bash

crname=$1
propval=$2

if [ -z $crname ] || [ -z $propval ]
then
    echo
    echo "Usage: $0 <CR-to-change> <yq-prop=value> < file.yaml"
    echo -e "Usage: cat file.yaml | $0 <CR-to-change> <yq-prop=value> \t\t\t\t\t\t\t\t# single"
    echo -e "Usage: cat file.yaml | $0 <CR-to-change> <yq-prop=value> | $0 <CR-to-change> <yq-prop=value> \t# multiple"
    echo -e "e.g."
    echo -e "Usage: cat file.yaml | \\"
    echo -e "\t$0 Kafka .spec.oneReplicaPerNode=true | \\"
    echo -e "\t$0 Zookeeper .spec.oneReplicaPerNode=true"
    echo
    exit 1
fi

tempDIR=$(mktemp -d)
filename=$(mktemp)
curDIR=$(pwd)
cd $tempDIR

while IFS= read line
do
    echo -e "$line" >> $filename
done

# Split up the config file into components
index=0
fileContent=$(i=$index yq eval 'select(di == env(i))' $filename)

while [ ! -z "${fileContent// }" ]
do
    type=$(i=$index yq eval 'select(di == env(i)) | .kind' $filename)
    echo "$fileContent" > $type.yaml

    ((index=index+1))
    fileContent=$(i=$index yq eval 'select(di == env(i))' $filename)
done

# yq in-place
yq eval -i $propval $crname.yaml

# combine them to a new yaml file
newfile=$(mktemp)
index=0
for file in *.yaml
do
    if [ ! $index -eq 0 ]
    then
        echo "---" >> $newfile
    fi

    cat $file >> $newfile

    ((index=index+1))
done

cat $newfile
cd $curDIR
rm -rf $tempDIR $filename $newfile

