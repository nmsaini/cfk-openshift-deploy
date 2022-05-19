## Applying multiple YQ style inserts to the final yaml

You can certainly chain multiple YQ inserts on the command line using the `set-cr-value-using-yq.sh` script. 
However, they get cumbersome after retyping a few times. It is much easier to track these in a properties 
file and (re)applied multiple times. Store your CR and YQ-change on a single line as follows:
```
echo \
"Kafka .spec.oneReplicaPerNode=true
Zookeeper .spec.oneReplicaPerNode=true" \
> final-changes.properties

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

```
chaincmd="cat deployed-file.yaml"

while IFS= read -r line; do
    chaincmd="$chaincmd | ./set-cr-value-using-yq.sh $line"
done < final-changes.properties

eval "$chaincmd" > deployed-edited-$(date +"%Y%m%d").yaml

```

/chg0519
