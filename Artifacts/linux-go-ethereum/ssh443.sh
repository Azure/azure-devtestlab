file=/etc/ssh/sshd_config
cp -p $file $file.old &&
awk '/Port/ { print; print "Port 443"; next }1' $file > $file.tmp && mv $file.tmp $file
Port=22
