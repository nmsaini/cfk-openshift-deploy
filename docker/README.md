## Prerequistes for running the script
  - zip
  - unzip

In order to build the connect CR, at times you will need custom jars added to the connectors. 
These plugin zips can be hosted on a local/remote website from where "Connect pod" can download the connectors during the "init" phase.
If you don't have a website (public url), here are instructions on building your own Docker Image that could be run inside your openshift cluster.

## Step 1. Download connector plugins from Confluent hub
go to https://www.confluent.io/hub/ and download the connector zip to your local folder (preferrable in a diff folder than this project).

## Step 2. Create a lib folder for the additional jars that are needed (custom jars)
create a folder in the same folder as the zip file. Name this folder as ${zip}.lib (where ${zip} is the zip name downloaded)
e.g. connector plugin file `confluentinc-kafka-connect-jdbc-10.3.2.zip` will create a folder with name `confluentinc-kafka-connect-jdbc-10.3.2.zip.lib`

## Step 3. Copy the custom jar file into the lib folder
copy the custom jar file into the lib folder created in Step 2 above

## Step 4. Run the script to create new zips with bundled custom jars
From the docker folder run the script `./build-connector-plugins.sh <folder-with-plugin-zips-n-libs>`
```
./build-connector-plugins.sh /home/user/folder-with-plugins
```

This generates a folder with all the new connector plugins zips along with a hash file. 
The hash file has all the hashs for the connector zips that are needed for the connector POD to download and validate.

## Step 5. Build an App to run nginx web-server to host these zip files
```
oc new-app --name plugin-downloader --strategy docker --binary
```
This creates a build-config with a Docker build. 

## Step 6. Start build of the App and run
To build the image all we need is a Dockerfile which is in our current directory.
```
oc start-build plugin-downloader --from-dir . --follow
```
If everything goes well there should be a running POD with the web-server running in the namespace. 

## Step 7. Need to expose the web-server so it is reachable via a service
Now all that is needed is a service to be exposed so other pods can get to the web-server. Our nginx is running on Port 8080 so that is the one we need to expose.
```
oc expose deployment plugin-downloader --port 8080
```

## Step 8. Point your connect yaml to download zips from plugin-downloader service
Edit your Connect CR yaml such that your connector plugins can be downloaded from your local web-server url. There is a yaml snippet generated in the downloader which will help in building your Connect CR. Here is a example snippet of your final connect CR yaml (see archivePath element).
```
  build:
    type: onDemand
    onDemand:
      plugins:
        locationType: url
        url:
          - name: kafka-connect-jdbc
            archivePath: http://plugin-downloader:8080/confluentinc-kafka-connect-jdbc-10.3.2.zip
            checksum: ff1516edbe99f259973855ac90467c9273b4
```
The checksum should be the value from the hash.txt file that was generated.
If you are running this app in a different namespace, you can change the url to `http://plugin-downloader.*namespace*.svc:8080/...` or if you want to 
connect from outside the cluster simply expose the service as a route like 
```
oc expose svc/plugin-downloader
```
verify
```
curl $(oc get route plugin-downloader -ojsonpath="{.spec.host}")
```

Remember 💣 - you cannot mix `locationType: confluentHub` and `locationType: url` in the same Connect CR! You can either have one or the other but **NOT** both.

*If you ever change the zips versions etc simply re-run Step 6, and delete the connect pod so it recreates the CR, and re-downloads the plugins!*
