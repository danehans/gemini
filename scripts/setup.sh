#!/bin/bash

inventory=${INVENTORY:-~/gemini-ansible/inventory/gemini-master}
playbook=${PLAYBOOK:-~/gemini-ansible/playbooks/gemini-master.yml}

ansible-playbook -i ${inventory} ${playbook} $@
