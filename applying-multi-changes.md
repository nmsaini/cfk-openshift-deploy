## Applying multiple YQ style inserts to the final yaml

create a properties file to keep track of all the changes needed
```
echo "
Kafka .spec.oneReplicaPerNode=true
Zookeeper .spec.oneReplicaPerNode=true
" > final-changes.properties
```

Now chain all these changes to the original file in one go using set-cr-value-using-yq.sh.

```
chaincmd="cat deployed-file.yaml"

while IFS= read -r line; do
    chaincmd="$chaincmd | ./set-cr-value-using-yq.sh $line"
done < final-changes.properties

eval "$chaincmd"
```

This will output the new yaml on your stdout.
You can pipe that into a new yaml.

/chg0519
