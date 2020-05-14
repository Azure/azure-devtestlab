#!/bin/bash

: ${USERNAME:=testuser}
: ${USERPASS:=Fedora#123}

__create_rundir() {
	mkdir -p /var/run/sshd
	chmod 1777 /dev/shm
}

__create_user() {
# Create a user
useradd $USERNAME
echo -e "$USERPASS\n$USERPASS" | (passwd --stdin $USERNAME)
echo user password: $USERPASS
usermod -a -G x2gouser $USERNAME
usermod -a -G wheel $USERNAME
}

__create_hostkeys() {
ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N '' 
}

__setup_ssh() {

echo 'root:Fedora#2020' | chpasswd
sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
echo 'export NOTVISIBLE="in users profile"' >> ~/.bashrc
root@containerID$ echo "export VISIBLE=now" >> /etc/profile

ssh-keygen -A -N ''
rm -f /run/nologin
}

# Call all functions
__create_rundir
__create_hostkeys
__setup_ssh
__create_user

exec "$@"