#!/bin/bash
#
# Script to set up OpenVPN for routing all traffic.
# https://github.com/mlgill/openvpn_autoconfig
#


########## PARAMETERS SET BY USER ##########
# Set the key size to 2048 (faster to generate, less secure) or 4096 (slower to generate, more secure)
RSA_KEY_SIZE=4096

# Set number of days for certificate validity--365 (1 year) is suggested
CERTIFICATE_EXPIRATION=365

# Set a unique name for each client
# This is not yet tested with spaces in client names, but quotes are definitely needed
CLIENT_LIST=( MLGILL IPAD IPHONE SPINWIZARD )

# Set the location of the OpenVPN certificates
# Location should be accessible only by root
OPENVPN_DIR=/etc/openvpn

########## END PARAMETERS SET BY USER ##########

set -e

if [[ $EUID -ne 0 ]]; then
  echo "You must be a root user" 1>&2
  exit 1
fi

apt-get update -q
debconf-set-selections <<EOF
iptables-persistent iptables-persistent/autosave_v4 boolean true
iptables-persistent iptables-persistent/autosave_v6 boolean true
EOF
apt-get install -qy openvpn curl iptables-persistent

if [[ ! -e $OPENVPN_DIR ]]; then
	mkdir $OPENVPN_DIR
fi
cd $OPENVPN_DIR

# Certificate Authority
>ca-key.pem      openssl genrsa $RSA_KEY_SIZE
>ca-csr.pem      openssl req -new -key ca-key.pem -subj /CN=OpenVPN-CA/
>ca-cert.pem     openssl x509 -req -in ca-csr.pem -signkey ca-key.pem -days $CERTIFICATE_EXPIRATION
>ca-cert.srl     echo 01

# Server Key & Certificate
>server-key.pem  openssl genrsa $RSA_KEY_SIZE
>server-csr.pem  openssl req -new -key server-key.pem -subj /CN=OpenVPN-Server/
>server-cert.pem openssl x509 -req -in server-csr.pem -CA ca-cert.pem -CAkey ca-key.pem -days $CERTIFICATE_EXPIRATION

# Client Key & Certificate
for client in ${CLIENT_LIST[@]}; do
	>"$client"-key.pem  openssl genrsa $RSA_KEY_SIZE
	>"$client"-csr.pem  openssl req -new -key "$client"-key.pem -subj /CN=OpenVPN-"$client"/
	>"$client"-cert.pem openssl x509 -req -in "$client"-csr.pem -CA ca-cert.pem -CAkey ca-key.pem -days $CERTIFICATE_EXPIRATION
done

# Diffie hellman parameters
>dh.pem     openssl dhparam $RSA_KEY_SIZE

# TLS Auth
openvpn --genkey --secret ta.key

chmod 600 *-key.pem
chmod 0600 *.key

# Set up IP forwarding and NAT for iptables
>>/etc/sysctl.conf echo net.ipv4.ip_forward=1
sysctl -p

iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE
>/etc/iptables/rules.v4 iptables-save

# Write configuration files for client and server

SERVER_IP=$(curl -s4 https://canhazip.com || echo "<insert server IP here>")

>tcp443.conf cat <<EOF
server      10.8.0.0 255.255.255.0
verb        3
key         server-key.pem
ca          ca-cert.pem
cert        server-cert.pem
dh          dh.pem
tls-auth    ta.key 0
keepalive   10 120
persist-key yes
persist-tun yes
comp-lzo    yes
push        "dhcp-option DNS 208.67.222.222"
push        "dhcp-option DNS 208.67.220.220"

# Normally, the following command is sufficient.
# However, it doesn't assign a gateway when using 
# VMware guest-only networking.
#
# push        "redirect-gateway def1 bypass-dhcp"

push        "redirect-gateway bypass-dhcp"
push        "route-metric 512"
push        "route 0.0.0.0 0.0.0.0"

ifconfig-pool-persist ipp.txt

user        nobody
group       nogroup

proto       tcp
port        443
dev         tun443
status      openvpn-status-443.log

max-clients 10
EOF

for client in ${CLIENT_LIST[@]}; do

>"$client".ovpn cat <<EOF
client
nobind
dev tun
redirect-gateway def1 bypass-dhcp
remote $SERVER_IP 443 tcp
comp-lzo yes

<key>
$(cat "$client"-key.pem)
</key>
<cert>
$(cat "$client"-cert.pem)
</cert>
<ca>
$(cat ca-cert.pem)
</ca>
<tls-auth>
$(cat ta.key)
</tls-auth>
key-direction 1
EOF

echo "VPN profile for client $client located at $OPENVPN_DIR/$client.ovpn"

done	

service openvpn restart
cd -
