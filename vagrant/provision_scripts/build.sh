#Gets the gemini repo
git clone https://github.com/gemini-project/gemini-ansible.git && cd ~/gemini-ansible

#Sets the ssh user name
sed -i "s/ansible_ssh_user: my_gemini_master_user/ansible_ssh_user: vagrant/" group_vars/all.yml

#removes the option router for the intnet, we only need one default gateway
sed -i "s/dnsmasq_option_router: '10.10.10.1'/#dnsmasq_option_router: '10.10.10.1'/" group_vars/all.yml

#Default Netmask does not like this end addr
sed -i "s/start_addr: '10.10.10.10'/start_addr: '10.10.10.30'/" group_vars/all.yml
sed -i "s/end_addr: '10.30.118.100'/end_addr: '10.10.10.100'/" group_vars/all.yml

#Overwriting the default node example
sed -i "s/- name: 'my_cluster_node'/- name: 'node1'/" group_vars/all.yml
sed -i "s/mac: 'AA:BB:44:33:22:11'/mac: '00:00:00:00:00:01'/" group_vars/all.yml
sed -i "s/ip: '10.10.10.10'/ip: '10.10.10.11'/" group_vars/all.yml

#Appending 10 more nodes to the file
sed -i "/ip: '10.10.10.11'/r /vagrant/provision_files/nodes.txt" group_vars/all.yml

#Removing so we can append our key here
sed -i '$ d' group_vars/all.yml

#Fetches the gemini master building repos
./scripts/pre-setup.sh

#Copys the ssh key into position
echo -n " " >> ~/gemini-ansible/group_vars/all.yml
cat ~/.ssh/id_rsa.pub >> ~/gemini-ansible/group_vars/all.yml

#Replaces the ansible fact to use the correct IP address, Vagrant has to have a NAT adapter as the default, so we need to assign http, tftp, dhcp to run on the second adapter that can reach our cluster
grep -rl "ansible_default_ipv4.address" . | xargs sed -i 's/ansible_default_ipv4.address/ansible_enp0s8.ipv4.address/'

#So no response is required to run the ansible playbook
export ANSIBLE_HOST_KEY_CHECKING=False

#Actually builds the gem master
./scripts/setup.sh
