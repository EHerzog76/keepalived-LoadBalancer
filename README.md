# keepalived-LoadBalancer
Loadbalancer with keepalived in a Container.<br>
No haproxy configuration is needed !

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
## Run in a container
### Edit the ```compose.yaml``` for your needs:
```
environment:
      # Will be auto detected if not set
      #- INTERFACE=eth0
      # LBMode    main or backup
      - LBMode=main
      - VIRTUAL_ROUTER_ID=51
      - PRIORITY=200
      - PASSWORD=LBVrrpPwd
      - LB_KIND=NAT
      # LB_ALGO: rr|wrr|lc|wlc|lblc|sh|mh|dh|fo|ovf|lblcr|sed|nq
      - LB_ALGO=rr
      - "VIRTUAL_IP=10.0.2.200:80;10.0.2.201:81"
      - "REAL_IP=10.0.0.120:80,10.0.0.121:80;10.0.0.121:81,10.0.0.121:88"
```
#### Syntax of VIRTUAL_IP:
VIP1:Port;VIP2:Port;VIP3:Port;...
#### Syntax of REAL_IP:
==== VIP1 Backend-Servers ==================   ;   === VIP2 Backend-Server =============================<br>
Backend-Server-IP1:Port,Backend-Server-IP2:Port,...;Backend-Server-IP1:Port,Backend-Server-IP2:Port,...<br>

```sh
docker compose up -d
```
## Background Informations
### keepalived
With keepalived the main and optional the backup Loadbalancer will be started.<br>
Use following commands to view what happens:
```sh
ip addr list

2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 74:5d:21:ff:88:aa brd ff:ff:ff:ff:ff:ff
    inet 10.0.2.2/24 brd 10.0.2.255 scope global dynamic noprefixroute eth0
       valid_lft 546946sec preferred_lft 546946sec
    inet 10.0.2.200/32 scope global eth0vip:51                  <=== VIP of Loadbalancer
       valid_lft forever preferred_lft forever
    inet 10.0.2.201/32 scope global eth0vip:51                  <=== VIP of Loadbalancer
       valid_lft forever preferred_lft forever
    inet6 fe80::647e:5d24:539f:caf5/64 scope link noprefixroute 
       valid_lft forever preferred_lft forever
```
```sh
ipvsadm -Ln

IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  10.0.2.200:80 rr persistent 7200
  -> 10.0.0.120:80                Masq    1      0          0         
  -> 10.0.0.121:80                Masq    1      0          0         
TCP  10.0.2.201:80 rr persistent 7200
  -> 10.0.0.121:81                Masq    1      0          0
  -> 10.0.0.121:88                Masq    1      0          0
```
### iptables/nftables
With iptables, we configure the source NAT for our VIP´s to the backend servers.<br>
This is the reason, why we need no haproxy configuration.<br>
To view the configuration use:
```sh
iptables -t nat -L POSTROUTING -n

Chain POSTROUTING (policy ACCEPT)
target     prot opt source               destination         
MASQUERADE  all  --  0.0.0.0/0            0.0.0.0/0            vaddr 10.0.2.200 vport 80
MASQUERADE  all  --  0.0.0.0/0            0.0.0.0/0            vaddr 10.0.2.201 vport 80
```
