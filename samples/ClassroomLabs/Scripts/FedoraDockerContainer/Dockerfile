from fedora:32

RUN dnf clean all && dnf -y update \
 && dnf -y install openssh-server passwd\
 && dnf -y groupinstall "Xfce Desktop" \
 && dnf -y install x2goserver \
 && dnf clean all

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/sbin/sshd", "-D"]

EXPOSE 22
