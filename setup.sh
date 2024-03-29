#!/bin/bash

cd $(dirname $0)
MYNAME=$(pwd)/$(basename $0)

CONFIGFILE=/etc/proventis/setup.config

while [[ $# -gt 0 ]] ; do
  key="$1"

  case $key in
    --docker)
        DOCKERINSTALL="1"
        shift
      ;;
    --local)
        LOCALINSTALL="1"
        shift
      ;;
    *)
      shift
    ;;
  esac
done

export DEBIAN_FRONTEND=noninteractive

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

function installDocker() {
  (
    source /etc/os-release
    curl -fsSL https://download.docker.com/linux/${ID}/gpg | apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/${ID} $(lsb_release -cs) stable"
    apt-get -yq update
    #DOCKER_VERSION=$(apt list -a docker-ce 2>/dev/null | awk '{print $2;}' | grep "19." | head -n 1)
    #( set -x ; apt-get -yq --allow-downgrades install "docker-ce=$DOCKER_VERSION" "docker-ce-cli=$DOCKER_VERSION" containerd.io )
    ( set -x ; apt-get -yq --allow-downgrades install "docker-ce" "docker-ce-cli" containerd.io )
    systemctl enable docker
    systemctl start docker
  )
}

function installDefaultSoftware() {
  apt-get -yq install apt-transport-https ca-certificates curl gnupg2 software-properties-common rsync mc open-iscsi ufw dstat fail2ban
  cat > $HOME/.bash_aliases <<EOF
alias l='ls -CF'
alias mc='. /usr/share/mc/bin/mc-wrapper.sh'
export EDITOR=mcedit
EOF
  echo 'SELECTED_EDITOR="/usr/bin/mcedit"' > $HOME/.selected_editor
}

function setupCACertificate() {
  cat > /usr/local/share/ca-certificates/Proventis-CA-2.crt <<EOF
-----BEGIN CERTIFICATE-----
MIIFijCCA3KgAwIBAgIJAPtW92iJXVb2MA0GCSqGSIb3DQEBCwUAMFoxCzAJBgNV
BAYTAkRFMQ8wDQYDVQQHDAZCZXJsaW4xHjAcBgNVBAoMFXByb3ZlbnRpcyBHbWJI
IEJlcmxpbjEaMBgGA1UEAwwRcHJvdmVudGlzIEdtYkggQ0EwHhcNMTkwOTAyMTE0
MTA2WhcNMzkwODI4MTE0MTA2WjBaMQswCQYDVQQGEwJERTEPMA0GA1UEBwwGQmVy
bGluMR4wHAYDVQQKDBVwcm92ZW50aXMgR21iSCBCZXJsaW4xGjAYBgNVBAMMEXBy
b3ZlbnRpcyBHbWJIIENBMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA
3LFe0FH6pWcDAw+vZ7h0nSFTbnSwH0PlFnw6p/S3SK4xvjGOkIrobFR9a7t1gO8e
uwcb+Q74d2ZiNWHV3EnWS24eX96dKZgTkETPacqpnnN4M5LlfkHys0+2+LhAIlo/
jqzhAHRPGaYaPTm3aXcMg3UHlpe8UCNuNNZgkefypAMksOsRyt/xnCEy9g9xiEsc
h+FCpkw+yIYQnTzSgbFo/hcO1T4F6So2SUGPjLDSDkPbCQ8lR69akwJlJJD4Wej0
SNXh1NVbi4miAXl0Xiak39z7QiSvWm4yq4McvgdEDdQRqcd0BgmGjZPNwFKnpCIG
5QT9Gr5bXlUlkM4sA9iReITgDNSxL55fLSvfF86/g7E7JzhAyqQf0LA9MzoRJjh9
Ql+4w99uZvRJL5KVfSSV7RrBhnhuNq/sxMm96VcFTZv3QePzIvBMlB8Pq+fKmWzS
Qix+2gnePmov92TDZ5y5xLuVNCxUqsgeRBoNSocK+mpi+sOENeYS+qkoKUMktDvh
Vshg740ZzB0lyH8s7aHGeCPv0f3RrbKuk5fNeSWqkXY/1HUgefnFQLexPHjRYfTt
KaeUIR9+rT7H7Z2CnPpwQn0zyk2ujMLB5N4tSoNrrb89FqWjhyqxwVQX4qSEG64E
NlMikqj0R5pBF6FoPIFk8gt43VIO/LEPJdmumJS2ayECAwEAAaNTMFEwHQYDVR0O
BBYEFKajP3VghdgMsYJ0b1swAewu3FOrMB8GA1UdIwQYMBaAFKajP3VghdgMsYJ0
b1swAewu3FOrMA8GA1UdEwEB/wQFMAMBAf8wDQYJKoZIhvcNAQELBQADggIBAMA+
oDlkkxj6qTk3fc4GScrsKIAX7RbuKwL0zrdS6mXMKbWhsTm22t49VTkOyFbJ2YP1
/13QfiFuV55sS6dl8PZBn2b1q13CASXM2/hEifW+Xr6H5A2DnIu48DR1wQAqZKYO
C1UU4DWCd8Bb4aNnbwSmn4t6AwzCF7Q0oYRmk2RiKZ2Wnh2U51NinI0jQwoyi26y
wuT025+YKdkrAyGZkK9saPWkJ6I/GGE9tGyxYYb+fYjy6IazumrF4OTAfoG0ro9d
2CxEnELOZJTPVP+hi1qZ2Q8IQkyrpZ0DO/vB8ZBnk4GmOZASOJs/scXDejMgqGTK
uJQeGk3erwiElss5rmdNYy06kpXlMG7avJn60UwqTbqNaw1k5OcQ8vYY+WKicqW7
t/9Myvry5PQTQezneKU8rJZ/EBmCSRPdA/7KhJWPvTluy5Uf1wZAeMQHmK6+c9xk
D7EHpRJTWlMEdpcDuduzxvfchFKOA9iCM9Efz/erERZT53Jpp9b6bHW/9V0hHiHv
OSXKj7LdrfsMYWY1xeeXmJTVyAKqQ3JuMSwZN4/21LMgi3KPW6C5jZRhpBHH5UGd
apvcSs9FxM/ievugbC815LKD8XPXQihfmakMCynAmuSpuBson5yYWC8UslpK7RhY
D3SZjPRlJRdjxLxbiaTF5vop5HN57AIhyHHI8voZ
-----END CERTIFICATE-----
EOF
  update-ca-certificates
}

function installPostfix() {
  mailhost="server-$(hostname -s).cluster.proventis.info"
  debconf-set-selections <<< "postfix postfix/mailname string ${mailhost}"
  debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
  apt-get -yq install postfix
  echo "root: server-$(hostname -s)@proventis.net" >> /etc/aliases
  newaliases
  postconf -e "inet_interfaces=loopback-only"
  postconf -e "myhostname=${mailhost}"
  postconf -e "mydomain=${mailhost}"
  postfix reload
}

function disablePasswordAuthentication() {
  sed -i 's/[#]*PermitRootLogin yes/PermitRootLogin prohibit-password/g' /etc/ssh/sshd_config
  sed -i 's/[#]*PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config

  systemctl restart sshd
}

function setupFirewall() {
  ufw allow proto tcp from any to any port 22,80,443,6443

  ufw allow from 10.43.0.0/16
  ufw allow from 10.42.0.0/16
  ufw allow from 10.0.0.0/16
  ufw allow from 10.244.0.0/16

  ufw allow in on docker0 from 172.17.0.0/16

  ufw allow from 217.111.101.34

  ufw -f default deny incoming
  ufw -f default allow outgoing

  ufw enable <<< "y"
}

function setupSystem() {
  chmod +x ${MYNAME}

  disablePasswordAuthentication

  if [ -z  "$LOCALINSTALL" ]; then
    # warten so dass rancher erstmal installieren kann
    sleep 5m
    apt-get -yq upgrade
  else
    apt-get -yq update
    apt-get -yq dist-upgrade
  fi
  installDefaultSoftware
  setupCACertificate
  installPostfix
  setupFirewall
  applySysconfig

  if [ -n "$DOCKERINSTALL" ]; then
    installDocker
  fi

}

function applySysconfig() {
  echo "vm.max_map_count=524288" >> /etc/sysctl.conf

  echo "* hard nofile 131072" >> /etc/security/limits.conf
  echo "root hard nofile 131072" >> /etc/security/limits.conf
}

setupSystem
