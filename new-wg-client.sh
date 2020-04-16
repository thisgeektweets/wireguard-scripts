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
        domain="$(curl ifconfig.me)"
        port="1194"
        ipRange="10.68.0.0/16"
        serverPublicKey="$(cat /etc/wireguard/server_publickey)"
        serverPrivateKey="$(cat /etc/wireguard/server_privatekey)"

# Main
    # Create keys
        mkdir /etc/wireguard/clients
        wg genkey | tee /etc/wireguard/clients/$clientName-privatekey | wg pubkey > /etc/wireguard/clients/$clientName-publickey
        clientNamePublicKey="$(</etc/wireguard/clients/$clientName-publickey)"
        clientNamePrivateKey="$(</etc/wireguard/clients/$clientName-privatekey)"

    # Update wireguard main config
        echo "[Peer]" >> /etc/wireguard/wg0.conf
        echo "#$clientName" >> /etc/wireguard/wg0.conf
        echo "PublicKey = $clientNamePublicKey" >> /etc/wireguard/wg0.conf
        echo "AllowedIPs = $clientIP/32" >> /etc/wireguard/wg0.conf

    # Create client config
        touch /etc/wireguard/clients/$clientName.conf
        echo "[Interface]" > /etc/wireguard/clients/$clientName.conf
        echo "Address = $clientIP/32" >> /etc/wireguard/clients/$clientName.conf
        echo "PrivateKey = $clientNamePrivateKey" >> /etc/wireguard/clients/$clientName.conf
        echo "DNS = 1.1.1.1" >> /etc/wireguard/clients/$clientName.conf
        echo "[Peer]" >> /etc/wireguard/clients/$clientName.conf
        echo "PublicKey = $serverPublicKey" >> /etc/wireguard/clients/$clientName.conf
        echo "Endpoint = $domain:$port" >> /etc/wireguard/clients/$clientName.conf
        echo "AllowedIPs = $ipRange" >> /etc/wireguard/clients/$clientName.conf

# Post
    # Restart wg0 tunnel
        wg-quick down wg0
        wg-quick up wg0

    # Print QR Code
        qrencode -t ansiutf8 < /etc/wireguard/clients/$clientName.conf
    
    # Print new client config
        cat /etc/wireguard/clients/$clientName.conf
