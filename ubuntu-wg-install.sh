#!/bin/bash
port=1194
networkAdapter=ens5

add-apt-repository ppa:wireguard/wireguard -y
apt update && DEBIAN_FRONTEND=noninteractive apt upgrade -y && apt autoremove -y && apt autoclean -y
apt install openresolv wireguard qrencode -y

ufw allow $port/udp
ufw allow ssh
yes | ufw enable

umask 077 /etc/wireguard/

wg genkey | tee /etc/wireguard/server_privatekey | wg pubkey > /etc/wireguard/server_publickey
serverPublicKey="$(cat /etc/wireguard/server_publickey)"
serverPrivateKey="$(cat /etc/wireguard/server_privatekey)"

cat > /etc/wireguard/wg0.conf << ENDOFFILE
# Server Interface
[Interface]
Address = 10.9.0.1/24
ListenPort = $port
PrivateKey = ${serverPrivateKey}
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $networkAdapter -j MASQUERADE; ip6tables -A FORWARD -i wg0 -j ACCEPT; ip6tables -t nat -A POSTROUTING -o $networkAdapter -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $networkAdapter -j MASQUERADE; ip6tables -D FORWARD -i wg0 -j ACCEPT; ip6tables -t nat -D POSTROUTING -o $networkAdapter -j MASQUERADE
# Peers

ENDOFFILE

cat << EOF >> /etc/sysctl.conf
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
EOF

cat > /etc/wireguard/new-wg-client.sh << ENDOFFILE
#!/bin/bash
# Variables
    # Read in user variables
        echo "Enter a name for the client and press [ENTER]:"
        read clientName
        echo ""
        echo "==========================================================================="
        echo ""
        cat /etc/wireguard/wg0.conf
        echo ""
        echo "==========================================================================="
        echo ""
        echo "Check output above for the next available IP and enter here:"
        read clientIP

    # Set script variables
        domain="\$(curl ifconfig.me)"
        port="1194"
        ipRange="10.68.0.0/16"
        serverPublicKey="\$(cat /etc/wireguard/server_publickey)"
        serverPrivateKey="\$(cat /etc/wireguard/server_privatekey)"

# Main
    # Create keys
        mkdir /etc/wireguard/clients
        wg genkey | tee /etc/wireguard/clients/\$clientName-privatekey | wg pubkey > /etc/wireguard/clients/\$clientName-publickey
        clientNamePublicKey="\$(</etc/wireguard/clients/\$clientName-publickey)"
        clientNamePrivateKey="\$(</etc/wireguard/clients/\$clientName-privatekey)"

    # Update wireguard main config
        echo "[Peer]" >> /etc/wireguard/wg0.conf
        echo "#\$clientName" >> /etc/wireguard/wg0.conf
        echo "PublicKey = \$clientNamePublicKey" >> /etc/wireguard/wg0.conf
        echo "AllowedIPs = \$clientIP/32" >> /etc/wireguard/wg0.conf

    # Create client config
        touch /etc/wireguard/clients/\$clientName.conf
        echo "[Interface]" > /etc/wireguard/clients/\$clientName.conf
        echo "Address = \$clientIP/32" >> /etc/wireguard/clients/\$clientName.conf
        echo "PrivateKey = \$clientNamePrivateKey" >> /etc/wireguard/clients/\$clientName.conf
        echo "DNS = 1.1.1.1" >> /etc/wireguard/clients/\$clientName.conf
        echo "[Peer]" >> /etc/wireguard/clients/\$clientName.conf
        echo "PublicKey = \$serverPublicKey" >> /etc/wireguard/clients/\$clientName.conf
        echo "Endpoint = \$domain:\$port" >> /etc/wireguard/clients/\$clientName.conf
        echo "AllowedIPs = \$ipRange" >> /etc/wireguard/clients/\$clientName.conf

# Post
    # Restart wg0 tunnel
        wg-quick down wg0
        wg-quick up wg0

    # Print QR Code
        qrencode -t ansiutf8 < /etc/wireguard/clients/\$clientName.conf
    
    # Print new client config
        cat /etc/wireguard/clients/\$clientName.conf
ENDOFFILE


systemctl enable wg-quick@wg0
chown -R root:root /etc/wireguard/
chmod -R og-rwx /etc/wireguard/*
chmod +x /etc/wireguard/new-wg-client.sh
wg-quick up wg0

touch /home/ubuntu/user-data-ran
reboot
