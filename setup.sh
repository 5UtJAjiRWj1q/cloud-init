#!/bin/bash

cd $(dirname $0)
MYNAME=$(pwd)/$(basename $0)

command="$1"
shift

while [[ $# -gt 0 ]] ; do
  key="$1"

  case $key in
    --hcloud-token)
        TOKEN="$2"
        shift
        shift
      ;;
    --whitelisted-ips)
        WHITELIST_S="$2"
        shift
        shift
      ;;
    --floating-ips)
        FLOATING_IPS="--floating-ips"
        shift
      ;;
    *)
      shift
    ;;
  esac
done

FLOATING_IPS=${FLOATING_IPS:-""}

function apt-get() {
  i=0
  tput sc
  while fuser /var/lib/dpkg/lock >/dev/null 2>&1 ; do
      case $(($i % 4)) in
          0 ) j="-" ;;
          1 ) j="\\" ;;
          2 ) j="|" ;;
          3 ) j="/" ;;
      esac
      tput rc
      echo -en "\r[$j] Waiting for other software managers to finish..." 
      sleep 0.5
      ((i=i+1))
  done 

  /usr/bin/apt-get "$@"
}

function updateSystem() {
  NEW_NODE_IPS=( $(curl -s -H 'Accept: application/json' -H "Authorization: Bearer ${TOKEN}" 'https://api.hetzner.cloud/v1/servers' | jq -r '.servers[].public_net.ipv4.ip') )

  touch /etc/current_node_ips
  cp /etc/current_node_ips /etc/old_node_ips
  echo "" > /etc/current_node_ips

  for IP in "${NEW_NODE_IPS[@]}"; do
    ufw allow from "$IP"
    echo "$IP" >> /etc/current_node_ips
  done

  IFS=$'\r\n' GLOBIGNORE='*' command eval 'OLD_NODE_IPS=($(cat /etc/old_node_ips))'

  declare -a REMOVED=()
  for i in "${OLD_NODE_IPS[@]}"; do
    skip=
    for j in "${NEW_NODE_IPS[@]}"; do
      [[ $i == $j ]] && { skip=1; break; }
    done
    [[ -n $skip ]] || REMOVED+=("$i")
  done
  declare -a REMOVED

  for IP in "${REMOVED[@]}"; do
    ufw deny from "$IP"
  done

  FLOATING_IPS=${FLOATING_IPS:-"0"}

  if [ -n "$FLOATING_IPS" ]; then
    FLOATING_IPS=( $(curl -s -H 'Accept: application/json' -H "Authorization: Bearer ${TOKEN}" 'https://api.hetzner.cloud/v1/floating_ips' | jq -r '.floating_ips[].ip') )    

    for IP in "${FLOATING_IPS[@]}"; do
      ip addr add $IP/32 dev eth0
    done  
  fi
}

function setupSystem() {
  chmod +x ${MYNAME}

  sed -i 's/[#]*PermitRootLogin yes/PermitRootLogin prohibit-password/g' /etc/ssh/sshd_config
  sed -i 's/[#]*PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config

  systemctl restart sshd
  apt-get install -yq jq ufw fail2ban

  ufw allow proto tcp from any to any port 22,80,443
  ufw -f enable

  IFS=', ' read -r -a WHITELIST <<< "$WHITELIST_S"

  for IP in "${WHITELIST[@]}"; do
    ufw allow from "$IP"
  done

  ufw allow from 10.43.0.0/16
  ufw allow from 10.42.0.0/16

  ufw -f default deny incoming
  ufw -f default allow outgoing

  crontab -l | {
    cat
    echo "*/5 * * * * root ${MYNAME} update --hcloud-token ${TOKEN} --whitelisted-ips ${WHITELIST_S} ${FLOATING_IPS}"
  } | crontab -

  updateSystem
}

case $command in
  setup)
    setupSystem
    ;;
  update)
    updateSystem
    ;;
  *)
    echo "unknown command!"
    ;;
esac
