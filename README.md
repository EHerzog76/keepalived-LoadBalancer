# keepalived-LoadBalancer
Loadbalancer with keepalived in a Container

# Installation
## Prerequisites for the Linux base hosts
### The following modules must be installed:
    ipvsadm ipset socat iptables nftables
### Load Modules
```
modprobe ip_vs
modprobe ip_vs_rr
modprobe ip_vs_wrr
modprobe ip_vs_sh
modprobe xt_ipvs
modprobe nf_conntrack
#Deprecated
modprobe nf_conntrack_ipv4
```

### sysctl - settings
```
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
#
#Perf-Tuning:
net.nf_conntrack_max=1048576
net.netfilter.nf_conntrack_max=1048576
net.netfilter.nf_conntrack_acct=0
net.netfilter.nf_conntrack_buckets=262144          # hashsize = nf_conntrack_max/nf_conntrack_buckets
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
#
#Do not answare ARP-Messages, only needed on Real-Servers in Direct-Retourn-Mode (DR)
#net.ipv4.conf.${INTERFACE:-eth0}.arp_ignore=1
#net.ipv4.conf.${INTERFACE:-eth0}.arp_announce=2
```
