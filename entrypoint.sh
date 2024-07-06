#!/bin/bash

#set -ux
#set -u

pid=0
declare -a IPTNrs=()
IPTEntries=()
colorblack='\033[30m'
colorred='\033[31m'
colorgreen='\033[32m'
coloryellow='\033[33m'
colorblue='\033[34m'
stylereset='\033[0m'
# SIGUSR1-handler
my_handler() {
  echo "my_handler"
}
# SIGTERM-handler
term_handler() {
  if [ $pid -ne 0 ]; then
    kill -SIGTERM "$pid"
    wait "$pid"
    pid=0
  fi

  #for (( idx=${#IPTNrs[@]}-1 ; idx>=0 ; idx-- )) ; do
  #  Nr=(${IPTNrs[idx]})
  #  for (( idn=${#Nr[@]}-1 ; idn>=0 ; idn-- )) ; do
  #    echo -e "iptables -t nat -D POSTROUTING ${Nr[idn]}"
  #    iptables -t nat -D POSTROUTING ${Nr[idn]}
  #  done
  #done
  echo "Deleting ${#IPTEntries[@]} entries from iptables -t nat -L POSTROUTING -n"
  for ipe in ${IPTEntries[@]}
  do
    VIPort=(${ipe//:/ })
    echo "iptables -L POSTROUTING -t nat --line-numbers -n | grep \"vaddr ${VIPort[0]} vport ${VIPort[1]}\""
    IPTNrs=(`iptables -L POSTROUTING -t nat --line-numbers -n | grep "vaddr ${VIPort[0]} vport ${VIPort[1]}" | sed -nr 's/^([0-9]+) .*/\1/p'`)
    for (( idx=${#IPTNrs[@]}-1 ; idx>=0 ; idx-- )) ; do
      echo -e "iptables -t nat -D POSTROUTING ${IPTNrs[idx]}"
      iptables -t nat -D POSTROUTING ${IPTNrs[idx]}
    done
  done

  exit 143; # 128 + 15 -- SIGTERM
}
# setup handlers
# on callback, kill the last background process, which is `tail -f /dev/null` and execute the specified handler
#trap 'kill ${!}; my_handler' SIGUSR1
trap 'kill ${!}; term_handler' SIGTERM SIGINT

#
# set localtime
#ln -sf /usr/share/zoneinfo/$LOCALTIME /etc/localtime

function replace_vars() {
  eval "cat <<EOF
  $(<$2)
EOF
  " > $1
}

if [ -z "${INTERFACE}" ]; then
  #INTERFACE=(`ip -o -4 route show to default | awk '{print $5}'`)
  #ip route get 8.8.8.8 | head -n1 | awk -- '{print $5}'
  INTERFACE=(`ip route get 8.8.8.8 | sed -nr 's/.*dev ([^\ ]+).*/\1/p'`)
fi

replace_vars '/etc/keepalived/keepalived.conf' '/etc/keepalived/10_keepalived.conf'
#replace_vars '/etc/keepalived/notify.sh' '/etc/keepalived/10_notify.sh'
#replace_vars '/etc/keepalived/health.sh' '/etc/keepalived/10_health.sh'
#chmod +x /etc/keepalived/notify.sh /etc/keepalived/health.sh

if [ "$ENABLE_LB" = "true" ]; then
{
if [ "a" = "" ]; then
modprobe ip_vs
modprobe ip_vs_rr
modprobe ip_vs_wrr
modprobe ip_vs_sh
modprobe xt_ipvs
modprobe nf_conntrack_ipv4
modprobe nf_conntrack

mkdir -p /etc/modules-load.d
cat <<EOF | tee /etc/modules-load.d/ipvs.conf
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
xt_ipvs
nf_conntrack_ipv4
nf_conntrack
EOF

mkdir -p /etc/sysctl.d
cat <<EOF | tee /etc/sysctl.d/ipvs.conf
#0 - No source validation.
#1 - Strict mode as defined in RFC3704 Strict Reverse Path
#2 - Loose mode as defined in RFC3704 Loose Reverse Path
net.ipv4.conf.all.rp_filter=0
#net.bridge.bridge-nf-call-arptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.bridge.bridge-nf-call-iptables=1
net.ipv4.ip_nonlocal_bind=1
net.ipv4.ip_forward=1
net.ipv4.vs.conntrack=1
net.nf_conntrack_max=1048576
net.netfilter.nf_conntrack_max=1048576
net.netfilter.nf_conntrack_acct=0
net.netfilter.nf_conntrack_buckets=262144                 # hashsize = nf_conntrack_max/nf_conntrack_buckets
net.netfilter.nf_conntrack_checksum=1
net.netfilter.nf_conntrack_count=2148
# DCCP options
net.netfilter.nf_conntrack_events=1
net.netfilter.nf_conntrack_expect_max=1024
# IPv6 options
#net.netfilter.nf_conntrack_generic_timeout=600
#net.netfilter.nf_conntrack_helper=0
#net.netfilter.nf_conntrack_icmp_timeout=30
#net.netfilter.nf_conntrack_log_invalid=0
#net.netfilter.nf_conntrack_max=1048576                    # conntrack table size
# SCTP options
net.netfilter.nf_conntrack_tcp_be_liberal=0
net.netfilter.nf_conntrack_tcp_loose=1
net.netfilter.nf_conntrack_tcp_max_retrans=3
net.netfilter.nf_conntrack_tcp_timeout_close=10
net.netfilter.nf_conntrack_tcp_timeout_close_wait=60
# NF_Conntrack TCP-Timeout 6h
net.netfilter.nf_conntrack_tcp_timeout_established=21600
net.netfilter.nf_conntrack_tcp_timeout_fin_wait=120
net.netfilter.nf_conntrack_tcp_timeout_last_ack=30
net.netfilter.nf_conntrack_tcp_timeout_max_retrans=300
net.netfilter.nf_conntrack_tcp_timeout_syn_recv=60
net.netfilter.nf_conntrack_tcp_timeout_syn_sent=120
net.netfilter.nf_conntrack_tcp_timeout_time_wait=120
net.netfilter.nf_conntrack_tcp_timeout_unacknowledged=300
net.netfilter.nf_conntrack_timestamp=0
net.netfilter.nf_conntrack_udp_timeout=30
net.netfilter.nf_conntrack_udp_timeout_stream=180
#Only on Real-Servers in DR-Mode:
#net.ipv4.conf.${INTERFACE:-eth0}.arp_ignore=1
#net.ipv4.conf.${INTERFACE:-eth0}.arp_announce=2
EOF

sysctl --system
fi

VIPS=(${VIRTUAL_IP//;/ })
RIPS=(${REAL_IP//;/ })
VIPCounter=0

for VIPPort in ${VIPS[@]}
do
VIP=(${VIPPort//:/ })
cat << EOF >> /etc/keepalived/keepalived.conf
       ${VIP[0]} dev ${INTERFACE:-eth0} label ${INTERFACE:-eth0}vip:${VIRTUAL_ROUTER_ID:-51}
EOF
done
echo "   }" >> /etc/keepalived/keepalived.conf
echo "}" >> /etc/keepalived/keepalived.conf


for VIPPort in ${VIPS[@]}
do
VIP=(${VIPPort//:/ })
cat << EOF >> /etc/keepalived/keepalived.conf
  virtual_server ${VIP[0]} ${VIP[1]} {
  delay_loop 5
  # for older keepalived - Configs:
  #lb_algo lc
  #lb_kind NAT
  #NAT or Direct-Return from Real-Server
  lvs_method $LB_KIND
  #lvs_sched rr|wrr|lc|wlc|lblc|sh|mh|dh|fo|ovf|lblcr|sed|nq
  lvs_sched $LB_ALGO
  #
  # for each virtual_server  in NAT-Mode use also Source-NAT:
  #        iptables -t nat -A POSTROUTING -m ipvs --vaddr 10.84.0.19/32 --vport 8443 -j MASQUERADE
  #  Tunnel-Connection to Real-Servers
  #lvs_method TUN [type {ipip|gue port NUM|gre} [nocsum|csum|remcsum]]
  # Session-Timeout 2h
  persistence_timeout 7200
  protocol TCP
  #ha_suspend
  timeout 10
  # On daemon startup assume that all RSs are down and healthchecks failed.
  alpha
EOF

BIPS=(${RIPS[${VIPCounter}]//,/ })
for j in ${BIPS[@]}
do
IPPort=(${j//:/ })
IP=${IPPort[0]}
Port=${IPPort[1]}
if [ -z ${IPPort[1]} ]; then
  Port=${VIP[1]}
fi

cat << EOF >> /etc/keepalived/keepalived.conf
  real_server ${IP} ${Port} {
    weight 1
    TCP_CHECK {
      connect_port ${Port}
      connect_timeout 3
    }
  }
EOF
done
echo "}" >> /etc/keepalived/keepalived.conf

if [ "$LB_KIND" = "NAT" ]; then
#Add Source-NAT for this VIP:Port
echo -e "iptables -t nat -A POSTROUTING -m ipvs --vaddr ${VIP[0]}/32 --vport ${VIP[1]} -j MASQUERADE"
iptables -t nat -A POSTROUTING -m ipvs --vaddr ${VIP[0]}/32 --vport ${VIP[1]} -j MASQUERADE
#
#Save only VIP and VIP-Port for later use:
IPTEntries[${VIPCounter}]="${VIP[0]}:${VIP[1]}"
echo "${VIPCounter}: ${IPTEntries[VIPCounter]} Saved."

#Save for later use:
#IPTNr=(`iptables -L POSTROUTING -t nat --line-numbers -n | grep "vaddr ${VIP[0]} vport ${VIP[1]}" | sed -nr 's/^([0-9]+) .*/\1/p'`)
#IPTNrs[${VIPCounter}]=${IPTNr[@]}
fi

let VIPCounter++
done
}
fi

if [ "$LBMode" = "backup" ]; then
  STATE=BACKUP
else
  LBMode=main
  STATE=Master
fi

echo ""
echo -e "${colorred}Check the following settings on the base hosts:" >> /proc/1/fd/1
echo -e "==============================================="
echo ""
echo -e "The following modules must be installed:"
echo -e "    ipvsadm ipset socat iptables nftables"
echo -e ".e.g.:"
echo -e "       apt-get install ipvsadm ipset socat iptables nftables"
echo ""
echo -e "#Load Modules:"
echo "modprobe ip_vs"
echo "modprobe ip_vs_rr"
echo "modprobe ip_vs_wrr"
echo "modprobe ip_vs_sh"
echo "modprobe xt_ipvs"
echo "modprobe nf_conntrack_ipv4"
echo "modprobe nf_conntrack"
echo ""
echo "mkdir -p /etc/modules-load.d"
echo 'cat <<EOF | tee /etc/modules-load.d/ipvs.conf'
echo "ip_vs"
echo "ip_vs_rr"
echo "ip_vs_wrr"
echo "ip_vs_sh"
echo "xt_ipvs"
echo "nf_conntrack_ipv4"
echo "nf_conntrack"
echo "EOF"
echo ""
echo "Check the following sysctl - settings:"
echo "======================================"
echo "#0 - No source validation."
echo "#1 - Strict mode as defined in RFC3704 Strict Reverse Path"
echo "#2 - Loose mode as defined in RFC3704 Loose Reverse Path"
echo "net.ipv4.conf.all.rp_filter=0"
echo "#net.bridge.bridge-nf-call-arptables=1"
echo "net.bridge.bridge-nf-call-ip6tables=1"
echo "net.bridge.bridge-nf-call-iptables=1"
echo "net.ipv4.ip_nonlocal_bind=1"
echo "net.ipv4.ip_forward=1"
echo "net.ipv4.vs.conntrack=1"
echo "#Perf-Tuning:"
echo "net.nf_conntrack_max=1048576"
echo "net.netfilter.nf_conntrack_max=1048576"
echo "net.netfilter.nf_conntrack_acct=0"
echo "net.netfilter.nf_conntrack_buckets=262144                 # hashsize = nf_conntrack_max/nf_conntrack_buckets"
echo "net.netfilter.nf_conntrack_checksum=1"
echo "net.netfilter.nf_conntrack_count=2148"
echo "# DCCP options"
echo "net.netfilter.nf_conntrack_events=1"
echo "net.netfilter.nf_conntrack_expect_max=1024"
echo "# IPv6 options"
echo "#net.netfilter.nf_conntrack_generic_timeout=600"
echo "#net.netfilter.nf_conntrack_helper=0"
echo "#net.netfilter.nf_conntrack_icmp_timeout=30"
echo "#net.netfilter.nf_conntrack_log_invalid=0"
echo "#net.netfilter.nf_conntrack_max=1048576                    # conntrack table size"
echo "#"
echo "#Do not answare ARP-Messages only needed on Real-Servers in Direct-Retourn-Mode (DR)"
echo "#net.ipv4.conf.${INTERFACE:-eth0}.arp_ignore=1"
echo "#net.ipv4.conf.${INTERFACE:-eth0}.arp_announce=2"
echo ""
echo -e "${stylereset}"

cat /etc/keepalived/keepalived.conf
#  Delete iptables-Nat-Entries on shutdown:
#  iptables -vL POSTROUTING -t nat --line-numbers | grep "vaddr 10.0.2.200 vport 80"
#  iptables -t nat -D POSTROUTING 5

echo "Starting keepalived..."
/usr/sbin/keepalived -S 7 --config-id ${LBMode} -f /etc/keepalived/keepalived.conf --dump-conf --dont-fork --log-console &
pid="$!"
### wait indefinitely
#while true
#do
#  tail -f /dev/null &; wait ${!}
#done
wait $!
