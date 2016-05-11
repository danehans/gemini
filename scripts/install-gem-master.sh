#!/bin/bash
#
# Script to install and configure gemini-master
#
# Usage:
# TODO Update usage
# curl -Ls  | sudo -H sh -s [Token] [UUID] [CertCommonName]
#
set -x
set -e

### THIS SCRIPT IS NOT FUNCTIONAL YET ###
GEM_MASTER=${GEM_MASTER:-localhost}
INVENTORY=${INVENTORY:-~/contrib/ansible/gem-master-inventory}
PLAYBOOK=${PLAYBOOK:-~/contrib/ansible/gem-master-build.yml}
PLAYBOOK_URL=${PLAYBOOK_URL:-https://raw.githubusercontent.com/danehans/contrib/release-0.1/ansible/gem-masters.yml}
PLAYBOOK_LOG=${PLAYBOOK_LOG:-/var/log/gemini-master-install.log}
# Set the interface name the broker will use
export ETH_DEV="${ETH_DEV:-eth0}"
# Set the Repo Name and Branch
export REPO_NAME="${REPO_NAME:-openshift}"
export REPO_BRANCH="${REPO_BRANCH:-master}"

if [ "$(uname -m)" != "x86_64" ]; then
	cat <<EOF
ERROR: Unsupported architecture: $(uname -m)
Only x86_64 architectures are supported at this time.
EOF
	exit 1
fi

get_distribution_type()
{
	local lsb_dist
	lsb_dist="$(lsb_release -si 2> /dev/null || echo "unknown")"
	if [ "$lsb_dist" = "unknown" ]; then
		if [ -r /etc/lsb-release ]; then
			lsb_dist="$(. /etc/lsb-release && echo "$DISTRIB_ID")"
		elif [ -r /etc/centos-release ]; then
			lsb_dist='centos'
		fi
	fi
	lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"
	echo $lsb_dist
}

case "$(get_distribution_type)" in
	centos)
		echo "-> Adding repo for Ansible package..."
		rpm -iUvh http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm
		echo "-> Installing Ansible..."
		yum -y install ansible
                echo "-> Installing Git..."
		yum install -y git
                echo "-> Making /opt/gemini directory..."
                mkdir -p /opt/gemini
                echo "-> Cloning contrib repo..."
                git clone -b release-0.1 https://github.com/danehans/contrib.git /opt/gemini/contrib
                echo "-> Cloning gem-master repos..."
                git clone https://github.com/danehans/ansible-role-ansible-controller.git /opt/gemini/contrib/ansible/roles/ansible-controller
                git clone -b pxe_coreos https://github.com/danehans/ansible-role-httpd.git /opt/gemini/contrib/ansible/roles/httpd
                git clone -b pxe_coreos https://github.com/danehans/ansible-role-tftp.git /opt/gemini/contrib/ansible/roles/tftp
                git clone -b pxe_coreos https://github.com/danehans/ansible-dnsmasq.git /opt/gemini/contrib/ansible/roles/dnsmasq
                git clone -b pxe_coreos https://github.com/danehans/ansible-coreos-cloudinit.git /opt/gemini/contrib/ansible/roles/coreos-cloudinit
                echo "->
		;;
	*)
		echo "ERROR: Cannot detect Linux distribution or it's unsupported"
		echo "Learn more: "
		exit 1
		;;
esac

echo "-> Configuring gemini-master..."
mkdir -p /etc/gemini/master
cat > /etc/gemini/master/gemini-master.conf <<EOF
{

	"Host":"${HOST}",
	"Token":"${1}",
	"UUID":"${2}",
	"CertCommonName":"${3}"
}
EOF

cat > ${INVENTORY} << EOF
[gem-masters]
${GEM_MASTER}
EOF

echo "Downloading gemini-master playbook"
curl -o ~/contrib/ansible/gem-masters.yml ${MASTER_PLAYBOOK_URL}

# Configure the Puppet manifest
if [ "${INSTALL_TYPE}" == "broker" ] ; then
  cat << EOF > /etc/puppet/configure.pp
  \$my_hostname='${HOSTNAME}.${PREFIX}'

  exec { "set_hostname":
    command => "/bin/hostname \${my_hostname}",
    unless  => "/bin/hostname | /bin/grep \${my_hostname}",
  }

  exec { "set_etc_hostname":
    command => "/bin/echo \${my_hostname} > /etc/hostname",
    unless  => "/bin/grep \${my_hostname} /etc/hostname",
  }

class { 'openshift_origin' :
  # Components to install on this host:
  roles                      => ['broker','named','activemq','datastore'],
  # BIND / named config
  # This is the key for updating the OpenShift BIND server
  bind_key                   => '${DNS_SEC_KEY}',
  # The domain under which applications should be created.
  domain                     => '${PREFIX}',
  # Apps would be named <app>-<namespace>.example.com
  # This also creates hostnames for local components under our domain
  register_host_with_named   => true,
  # Forward requests for other domains (to Google by default)
  conf_named_upstream_dns    => ['${UPSTREAM_DNS}'],
  # NTP Servers for OpenShift hosts to sync time
  ntp_servers                => ["${UPSTREAM_NTP} iburst"],
  # The FQDNs of the OpenShift component hosts
  broker_hostname            => \$my_hostname,
  named_hostname             => \$my_hostname,
  datastore_hostname         => \$my_hostname,
  activemq_hostname          => \$my_hostname,
  # Auth OpenShift users created with htpasswd tool in /etc/openshift/htpasswd
  broker_auth_plugin         => 'htpasswd',
  # Username and password for initial openshift user
  openshift_user1            => '${OSO_USERNAME}',
  openshift_password1        => '${OSO_PASSWORD}',
  #Enable development mode for more verbose logs
  development_mode           => true,
  # Set if using an external-facing ethernet device other than eth0
  conf_node_external_eth_dev => '${ETH_DEV}',
}
EOF
fi

echo "Disabling SSH strict host key checking... "
cat > ~/.ssh/config << EOF
Host *
    StrictHostKeyChecking no
EOF

echo "Running the gem-master Ansible playbook... "
ansible-playbook -i ${INVENTORY} ${PLAYBOOK} $@ | tee ${PLAYBOOK_LOG}

echo "-> Done!"
cat <<EOF

*******************************************************************************
Gemini Master installed successfully
*******************************************************************************

You are now ready to deploy a Kubernetes cluster

EOF
