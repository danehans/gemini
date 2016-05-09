#!/bin/bash
#
# Script to configure gemini-master
#
set -x
set -e

#NUM_NODES=${NUM_NODES:-}
#NODE_NAMES=${NODE_NAMES:-}
#NODE_MACS=${NODE_MACS:-}
#NODE_IPS=${NODE_IPS:-}

node_macs=${NODE_MACS}
node_ips=${NODE_IPS}
node_names=${NODE_NAMES}

macs=(${node_macs//,/ })
ips=(${node_ips//,/ })
names=(${node_names//,/ })

gen_hosts() {
#  for n in ${!NODE_NAMES[*]}; do
  for index in ${!names[*]}; do 
#  while [  $NUM_NODES -gt 0 ]; do
    host_list="- ${macs[$index]},${ips[$index]},${names[$index]}"
#    let NUM_NODES=NUM_NODES-1
  done
}

(gen_hosts)

echo $host_list
