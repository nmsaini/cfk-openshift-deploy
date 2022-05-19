#!/bin/bash
#
# Requirement to have a folder with conflunent-hub connectors zips
# To add jars to this zip create a folder with zipname.lib
# Copy all the jars that are needed to be added to the lib of that zipname
# The script goes through all the zips in that folder and see if there is a
# corresponding lib folder with jars and add those to the lib folder inside the zip
#
# requires zip/unzip installed
#


# pass in the folder where there are orig zips and zip+jars
if [ -z $1 ]; then
        echo Usage: $0 foldername-with-zips
        exit -1;
fi

FOLDER_TO_PROCESS=$1
ZIPFOLDER=zip-files

if [ ! -d $FOLDER_TO_PROCESS ]; then
        echo folder $FOLDER_TO_PROCESS not found;
        exit -1;
fi

pushd $FOLDER_TO_PROCESS > /dev/null

# for each zip in the folder recursively look for jars to be copied into
for plugin in *.zip
do
        pluginname=$plugin # ${plugin%.*}
        echo zip to process $pluginname

        if [ -d ${pluginname}.lib ]; then
                echo found lib folder $pluginname.lib

                # before proceeding lets make sure there are jars in the folder
                for jar in $pluginname.lib/*.jar
                do
                        if [ ! -f $jar ]; then
                                echo no jars found in $pluginname.lib....breaking loop!
                                break 2
                        fi
                done

                libname=$(unzip -l $plugin | grep "lib/$" | cut -c31-)

                # create if not there
                if [ ! -d $libname ]; then
                        echo found jars making temp dir $libname
                        mkdir -p $libname
                fi

                # copy jars into the lib folder of the zip
                cp $pluginname.lib/*.jar $libname

                # make a copy of zip
                cp $pluginname $pluginname.updated

                # update the zip with the new folder with jars
                zip -ur $pluginname.updated $libname > /dev/null

                # now lets remove the temp files
                rm -rf ${pluginname%.*}
        fi
done

popd > /dev/null

if [ ! -d $ZIPFOLDER ]; then
        echo creating $ZIPFOLDER folder
        mkdir -p $ZIPFOLDER
fi

# lets move all the zip files
for zip in $FOLDER_TO_PROCESS/*.updated
do
        filename=$(basename $zip)
        mv $zip $ZIPFOLDER/${filename%.*}
done

# generate hash
cd $ZIPFOLDER && sha512sum *.zip > hash.txt

# generate yaml snippet
PYAML=plugin-snippet-yaml.txt
# zero out
echo "" > $PYAML
for file in *.zip
do
        zip=$(basename $(echo ${file%.*})|cut -f2-4 -d-)
	echo "url:" >> $PYAML
        echo "  - name: $zip" >> $PYAML
        echo "    archivePath: http://plugin-downloader:8080/"$(basename $file) >> $PYAML
        echo "    checksum: "$(sha512sum $file|cut -f1 -d ' ') >> $PYAML
done

