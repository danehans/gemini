#!/bin/bash

base_dir=${BASE_DIR:-~/gemini/provisioners/ansible/roles}
contrib_base_dir=${CONTRIB_BASE_DIR:-~}

echo "-> Setting Up SSH"
ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

#TODO: For loop that checks if ${base_dir}/$file exists before cloning the repos.
echo "-> Cloning Repos"
git clone https://github.com/gemini-project/contrib.git ${contrib_base_dir}/contrib
git clone https://github.com/gemini-project/ansible-role-collins.git ${base_dir}/collins
git clone https://github.com/gemini-project/ansible-role-ansible-controller.git ${base_dir}/ansible-controller
git clone -b pxe_coreos https://github.com/gemini-project/ansible-role-httpd.git ${base_dir}/httpd
git clone -b pxe_coreos https://github.com/gemini-project/ansible-role-tftp.git ${base_dir}/tftp
git clone -b pxe_coreos https://github.com/gemini-project/ansible-dnsmasq.git ${base_dir}/dnsmasq
git clone -b pxe_coreos https://github.com/gemini-project/ansible-coreos-cloudinit.git ${base_dir}/coreos-cloudinit

# Show the populated roles directory
echo "-> These are your Ansible roles"
ls -al ${base_dir}
ls -al ${contrib_base_dir}/contrib/ansible/roles

# Pre-setup complete
echo "-> Your Gemini Ansible roles have been successfully created"
