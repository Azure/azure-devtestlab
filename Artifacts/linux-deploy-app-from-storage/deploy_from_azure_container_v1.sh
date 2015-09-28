curl --silent --location https://deb.nodesource.com/setup_0.12 | sudo bash -
sudo apt-get -y install nodejs

sudo npm install azure-storage
sudo npm install mkdirp

# clean deployment folder prior to download
sudo rm -d -f -r $2

# download the container into the destination folder
sudo node ./download_azure_container.js $1 $2 $3
LAST_RESULT=$?

if [ $LAST_RESULT -ne 0 ] ; then
    echo "Exiting script with exit code $LAST_RESULT"
    exit $LAST_RESULT
fi

# run the install script if one is provided
if [ -n "$4" ]; then
	echo "invoking $2/$4"
	sh "$2/$4"
fi