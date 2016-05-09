#!/bin/bash
#
# Script to configure gemini-master
#
set -x
set -e

GEM_MASTER_USER=${USER}
DOMAIN_NAME=${DOMAIN_NAME:-example.com}
DHCP_START_IP=${DHCP_START_IP:-}
DHCP_END_IP=${DHCP_END_IP:-}
DHCP_LEASE_TIME=${DHCP_LEASE_TIME:-8h}
DHCP_GW=${DHCP_GW:-}
GEM_MASTER_RSA_KEY=$(cat ~/.ssh/id_rsa.pub)
node_macs=${NODE_MACS}
node_ips=${NODE_IPS}
node_names=${NODE_NAMES}
# Split node_macs|node_ips|node_names strings using "," into arrays
macs=(${node_macs//,/ })
ips=(${node_ips//,/ })
names=(${node_names//,/ })

echo "--> Creating ${PWD}/gemini-master inventory file..."
cat >> gemini-master << EOF
[gemini-masters]
${HOSTNAME} ansible_host=127.0.0.1
EOF

# Create a string containing mac,ip,name for each node
gen_hosts() {
  for index in ${!names[*]}; do 
    dnsmasq_dhcp_hosts="- ${macs[$index]},${ips[$index]},${names[$index]}"
  done
}

(gen_hosts)

echo "--> Creating ${PWD}/group_vars/all.yml file..."
cat >> group_vars/all.yml << EOF
---
# Account name used to SSH to the gemini-master node.
# The user must be able to use sudo without asking
# for password unless ansible_sudo_pass is set
ansible_ssh_user: ${GEM_MASTER_USER}

# DNS Domain to use for PXE nodes
dnsmasq_domain: '${DOMAIN_NAME}'

# IP address range to use for assigning to PXE-booted nodes
dnsmasq_dhcp_ranges:
  - start_addr: '${DHCP_START_IP}'
    end_addr: '${DHCP_END_IP}'
    lease_time: '${DHCP_LEASE_TIME}'

# Gateway IP for PXE-booted nodes
dnsmasq_option_router: '${DHCP_GW}'

# Set specific IP's for hosts within the dnsmasq_dhcp_ranges above
dnsmasq_dhcp_hosts:
  $dnsmasq_dhcp_hosts
	
# RSA key of your gemini-master node.
cloudinit_ssh_authorized_keys: >
  ${GEM_MASTER_RSA_KEY}
EOF
