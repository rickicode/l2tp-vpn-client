#!/bin/sh

log() {
  echo "[l2tp-vpn-server @$(date +'%F %T')] $1"
}

# Fungsi untuk mendapatkan IP publik
getPublicIP() {
  local ip=$(curl -s ifconfig.me)
  echo $ip
}

# Create IPsec config
createIPsecConf() {
  local public_ip=$1

  log "Creating IPsec configuration at /etc/ipsec.conf"
  cat > /etc/ipsec.conf <<EOF
version 2.0

config setup
  ikev1-policy=accept
  virtual-private=%v4:10.0.0.0/8,%v4:192.168.0.0/16,%v4:172.16.0.0/12,%v4:!192.168.42.0/24
  uniqueids=no

conn shared
  left=%defaultroute
  leftid=$public_ip
  right=%any
  encapsulation=yes
  authby=secret
  pfs=no
  rekey=no
  keyingtries=5
  dpddelay=30
  dpdtimeout=300
  dpdaction=clear
  ikev2=never
  ike=aes256-sha2;modp2048,aes128-sha2;modp2048,aes256-sha1;modp2048,aes128-sha1;modp2048,aes256-sha2;modp1024,aes128-sha1;modp1024,aes256-sha2;modp1536,aes128-sha1;modp1536
  phase2alg=aes_gcm-null,aes128-sha1,aes256-sha1,aes256-sha2_512,aes128-sha2,aes256-sha2
  ikelifetime=24h
  salifetime=24h
  sha2-truncbug=no

conn L2TP-PSK
  auto=add
  left=%defaultroute
  leftid=$public_ip
  right=%any
  rightprotoport=17/1701
  type=transport
  authby=secret
  keyexchange=ikev1
  ike=aes256-sha2;modp2048,aes128-sha2;modp2048,aes256-sha1;modp2048,aes128-sha1;modp2048,aes256-sha2;modp1024,aes128-sha1;modp1024,aes256-sha2;modp1536,aes128-sha1;modp1536
  phase2alg=aes_gcm-null,aes128-sha1,aes256-sha1,aes256-sha2_512,aes128-sha2,aes256-sha2
  ikelifetime=8h
  salifetime=1h
  dpddelay=30
  dpdtimeout=120
  dpdaction=clear
  rekey=no
  compress=no
EOF
  log "IPsec configuration has been created"
}

setupVPN() {
  log "Editing configuration files"

  # Ambil IP publik untuk konfigurasi
  VPN_SERVER_IPV4=$(getPublicIP)
  log "Public IP: $VPN_SERVER_IPV4"

  # Buat file ipsec.conf dengan pengaturan dari environment variable
  createIPsecConf "$VPN_SERVER_IPV4"

  # Mengganti nilai konfigurasi PSK dan XL2TPD
  echo ': PSK "'$VPN_PSK'"' > /etc/ipsec.secrets
  sed -i 's/lns = .*/lns = '$VPN_SERVER_IPV4'/' /etc/xl2tpd/xl2tpd.conf

  # Tambahkan akun ke chap-secrets
  echo "$VPN_USERNAME * $VPN_PASSWORD *" >> /etc/ppp/chap-secrets

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
