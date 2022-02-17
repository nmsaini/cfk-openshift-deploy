In order to build the connect CR, at times you will need customer jars added to the connectors. 
These jars can be hosted on a local/remote website from where "Connect pod" can download the connectors during the "init" phase.
If you don't have a website (public url), here are instructions on building your own Docker Image that could be run inside the same namespace or same K8s env.

# Step1 Download connector plugins from Confluent hub
go to https://www.confluent.io/hub/ and download the connector zip to your local folder (preferrable in a diff dir than this project).

# Step2 Create a lib folder for the additional jars that are needed (custom jars)
create a folder in the same folder as the zip file. Name this folder as ${zip}.lib (where ${zip} is the zip name downloaded)
e.g. connector plugin file confluentinc-kafka-connect-jdbc-10.3.2.zip will create a folder with name confluentinc-kafka-connect-jdbc-10.3.2.zip.lib


