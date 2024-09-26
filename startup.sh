#!/bin/sh

log() {
  echo "[l2tp-vpn-client @$(date +'%F %T')] $1"
}

# Fungsi untuk mendapatkan IP publik
getPublicIP() {
  local ip=$(curl -s ifconfig.me)
  echo $ip
}

setupVPN() {
  log "Editing configuration files"

  # Ambil IP publik untuk konfigurasi
  VPN_SERVER_IPV4=$(getPublicIP)
  log "Public IP: $VPN_SERVER_IPV4"

  # Mengganti nilai konfigurasi dengan environment variable
  sed -i 's/right=.*/right='$VPN_SERVER_IPV4'/' /etc/ipsec.conf
  echo ': PSK "'$VPN_PSK'"' > /etc/ipsec.secrets
  sed -i 's/lns = .*/lns = '$VPN_SERVER_IPV4'/' /etc/xl2tpd/xl2tpd.conf
  sed -i 's/name .*/name '$VPN_USERNAME'/' /etc/ppp/options.l2tpd.client
  sed -i 's/password .*/password '$VPN_PASSWORD'/' /etc/ppp/options.l2tpd.client
  
  log "Launching IPsec"
  ipsec start
  sleep 3
  ipsec status

  log "Launching xl2tpd"
  xl2tpd -D &
  
  log "Connecting to PPP daemon"
  echo "c myVPN" > /var/run/xl2tpd/l2tp-control

  log "L2TP server started"
}

echo "-------------------------------------"
echo "Starting L2TP VPN Server"
echo "-------------------------------------"

setupVPN

# Menjaga container tetap berjalan
tail -f /dev/null
