sudo apt-get -y update
sudo apt-get -y install docker.io

sudo docker run --name $1 -d $2 $3
