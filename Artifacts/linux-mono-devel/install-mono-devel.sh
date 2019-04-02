#! /bin/sh

echo "Installing Mono runtime"

isApt=`command -v apt-get`
isRpm=`command -v rpm`

# Some of the previous commands will fail with an exit code other than zero (intentionally), 
# so we do not set error handling to stop (set e) until after they've run
set -e
set -o xtrace

if [ -r /etc/os-release ]; then
    . /etc/os-release
else
    echo "Distro without /etc/os-release available"
    exit 1
fi


if [ -n "$isApt" ]; then
    # Ubuntu, Debian
    if [ $ID = "ubuntu" ]; then
        MONO_REPO="stable-${UBUNTU_CODENAME}"
        
        if [ $VERSION_ID = "18.04" ]; then
            REQ_PACKAGES="gnupg ca-certificates"
        else
            REQ_PACKAGES="apt-transport-https"
        fi
    elif [ $ID = "debian" ]; then
        DEB_CODENAME=`echo $VERSION | awk -F"[()]"+ '{print $2}'`
        MONO_REPO="stable-${DEB_CODENAME}"

        if [ $VERSION_ID = "9" ]; then
            REQ_PACKAGES="apt-transport-https dirmngr gnupg ca-certificates"    
        else
            REQ_PACKAGES="apt-transport-https ca-certificates"
        fi
    else
        echo "Not running debian-based distribution. ID=${ID}, VERSION=${VERSION}"
        exit 1
    fi

    sudo apt-get update
    sudo apt-get install -y $REQ_PACKAGES
    sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
    echo "deb https://download.mono-project.com/repo/${ID} ${MONO_REPO} main" | sudo tee /etc/apt/sources.list.d/mono-official-stable.list
    sudo apt-get update
    sudo apt-get install -y mono-devel
elif [ -n "$isRpm" ]; then
    # Fedora, CentOS
    sudo rpm --import "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF"

    INSTALL_CMD='curl https://download.mono-project.com/repo/centos7-stable.repo | tee /etc/yum.repos.d/mono-centos7-stable.repo'

    if [ $ID = "centos" ] && [ $VERSION_ID = "6" ]; then
        INSTALL_CMD='curl https://download.mono-project.com/repo/centos6-stable.repo | tee /etc/yum.repos.d/mono-centos6-stable.repo'
    fi

    sudo su -c "$INSTALL_CMD"

    if [ $ID = "fedora" ]; then
        sudo dnf update
        dnf install -y mono-devel
    elif [ $ID = "centos" ]; then
        sudo yum install -y mono-devel
    else
        echo "RPM-based distribution not supported. ID=${ID}, VERSION=${VERSION}"
        exit 1
    fi
fi

echo "Installed Mono runtime"
