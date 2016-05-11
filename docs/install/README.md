# Gemini Installation Guide

This guide walks through the steps for deploying Gemini to a baremetal
server cluster. At least 2 servers are required to support this deployment
type. One server is used as the Gemini Master and one or more servers are
used to run clustering software, such as [Kubernetes](http://kubernetes.io/).

**Note**: These steps will soon be replaced by a simple installation script.

## Before You Start

Make sure all servers are "racked and stacked" and connected to a network.

The server that acts as the Gemini Master needs to be installed with CentOS 7.
The Gemini team uses the [CentOS 7 minimal ISO](http://isoredirect.centos.org/centos/7/isos/x86_64/CentOS-7-x86_64-Minimal-1511.iso).
SSH to the Gemini Master after the CentOS 7 installation is complete and
the server has rebooted. Use gem-master01 as your Gemini Master hostname or replace
gem-master01 throughout the document with the hostname of your Gemini Master.

The Gemini Master uses IPMI to power cycle cluster nodes. Make sure cluster nodes
are configured for IPMI and the IPMI IP address is reachable from the Gemini Master.

PXE should be the first boot option for cluster nodes. This allows the cluster nodes
to have their Operating System provisioned by the Gemini Master.

Install required packages:
```
rpm -iUvh http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm
yum -y install ansible git ipmitool
```

Clone the Gemini repository and change to the ```~/gemini-ansible/``` directory:
```
git clone https://github.com/gemini-project/gemini-ansible.git && cd ~/gemini-ansible/
```

Run the pre-setup script to populate the gemini ansible roles:
```
./scripts/pre-setup.sh
```

Modify ```group_vars/all.yml``` with the specifics of your deployment environment. You
must change ```my_gemini_master_user``` to a username that has root privleges on the
Gemini Master. **Note**: You should be currently logged into the Gemini Master using this
username.

If you are using a hostname other than gem-master01, then edit the ```gemini-master```
inventory file by changing ```gem-master01``` with the hostname of your Gemini Master.
```
sed -i 's/gem-master01/${YOUR_GEMINI_MASTER_HOSTNAME}/' gemini-master
```

Run the setup script to deploy the Gemini Master node:
```
./scripts/setup.sh
```

The setup script should complete with a successful Ansible playbook run similar to this:
```
...
PLAY RECAP ********************************************************************
gem-master01               : ok=55   changed=41   unreachable=0    failed=0
```

The Gemini Master uses [ipmitool](http://linux.die.net/man/1/ipmitool) for remotely managing
cluster nodes. Test IPMI by checking the power status of each cluster node:
```
ipmitool -H ${SERVER_IPMI_IP_ADDRESS} -U ${SERVER_IPMI_USERNAME} -P${SERVER_IPMI_PASSWORD} power status
```

Power cycle each cluster node. **Note:** The boot order for cluster nodes must start with PXE:
```
ipmitool -H ${SERVER_IPMI_IP_ADDRESS} -U ${SERVER_IPMI_USERNAME} -P${SERVER_IPMI_PASSWORD} power cycle
```

The cluster nodes power cycle and are provisioned an Operating System by the Gemini Master. Make sure
you can SSH from the Gemini Master to each cluster node using the IP address(es) defined in group_vars/all.yml.
You should **not** be prompted for a password when SSH'ing to each cluster node. In the example
below, replace kube-node01 with the IP address or FQDN of your cluster node:
```
[root@gem-master01]# ssh core@kube-node01
Last login: Fri Apr  8 06:48:44 2016 from 10.30.118.132
CoreOS stable (1010.1.0)
Update Strategy: No Reboots
core@kube-node01 ~ $
```

Exit your test SSH session and change to the Contrib Ansible directory:
```
cd ~/contrib/ansible
```

Create the inventory of your cluster nodes. You must define at least one node by
IP address or FQDN for each role within the inventory file.
```
cp inventory.example.single_master inventory
vi inventory
```

Update ```group_vars/all.yml``` with the following:
```
sed -i 's/#ansible_ssh_user: root/ansible_ssh_user: core/' group_vars/all.yml
sed -i 's/#ansible_python_interpreter/ansible_python_interpreter/' group_vars/all.yml
```

Additional ```group_vars/all.yml``` can be modified according to your deployment
requirements

Update ```group_vars/all.yml``` with the url for downloading binaries.
Replace ${YOUR_GEMINI_MASTER_IP} with the IP address of your Gemini Master:
```
export GEMINI_MASTER_IP=${YOUR_GEMINI_MASTER_IP}

cat >> group_vars/all.yml << EOF

# The URL to download Kubernetes binaries for CoreOS
kube_download_url_base: "http://${GEMINI_MASTER_IP}/releases/kubernetes/v{{ kube_version }}"

# The URL to download Flannel binaries tar file for CoreOS
flannel_download_url_base: "http://${GEMINI_MASTER_IP}/releases/flannel"

# The URL to download Pypy binaries tar file for CoreOS
pypy_download_url_base: "http://${GEMINI_MASTER_IP}/releases/pypy/v{{ pypy_version }}"
EOF
```

Run the setup script to deploy the cluster node(s):
```
./setup.sh
```

The setup script should complete with a successful Ansible playbook run:
```
...
PLAY RECAP ********************************************************************
kube-node01              : ok=341  changed=102  unreachable=0    failed=0
```

Login to the Kubernetes master:
```
ssh core@kube-node01
```

Verify the Kuberenetes cluster is up:
```
core@kube-node01 ~ $ kubectl cluster-info
Kubernetes master is running at http://localhost:8080
Elasticsearch is running at http://localhost:8080/api/v1/proxy/namespaces/kube-system/services/elasticsearch-logging
Heapster is running at http://localhost:8080/api/v1/proxy/namespaces/kube-system/services/heapster
Kibana is running at http://localhost:8080/api/v1/proxy/namespaces/kube-system/services/kibana-logging
KubeDNS is running at http://localhost:8080/api/v1/proxy/namespaces/kube-system/services/kube-dns
Grafana is running at http://localhost:8080/api/v1/proxy/namespaces/kube-system/services/monitoring-grafana
InfluxDB is running at http://localhost:8080/api/v1/proxy/namespaces/kube-system/services/monitoring-influxdb

core@kube-node01 ~ $ kubectl get nodes
NAME          LABELS                               STATUS    AGE
kube-node-1   kubernetes.io/hostname=kube-node-1   Ready     34m
```

Make sure the STATUS shows Ready for each node. You are now ready to deploy Kubernetes resources. Try one of the [examples](https://github.com/kubernetes/kubernetes/tree/master/examples) from the Kubernetes project repo or continue by using the Gemini [web server](../../examples/web.yml) example:
```
curl -O https://raw.githubusercontent.com/gemini-project/gemini/master/examples/web.yml
sudo kubectl create -f web.yml
```

Verify that the example rc/pod/svc are running:
```
core@kube-node01 ~ $ kubectl get rc,pod,svc
NAME         DESIRED         CURRENT       AGE
web          1               1             2m
NAME         READY           STATUS        RESTARTS   AGE
web-0yoyz    1/1             Running       0          2m
NAME         CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
kubernetes   10.254.0.1      <none>        443/TCP    8m
web          10.254.212.64   nodes         80/TCP     2m
```

Make sure the ```READY``` from the above output shows ```1/1``` indicating the desired state and acutal state
of the web pod match. Then test the web service using curl:
```
core@kube-node01 ~ $ curl kube-node01:30302
<!DOCTYPE html>
<html>
	<head>
		<title>mini_httpd on docker</title>
    <style>
      body {
          font-family: Arial,Helvetica Neue,Helvetica,sans-serif;
      }

      #address {
        text-align: center;
        border: thin solid black;
        padding: 1ex;
        margin-top: 2ex;
        margin-bottom: 2ex;
        max-width: 40ex;
        background-color: orange;
      }

      #address strong {
        font-size: 200%;
      }
    </style>
	</head>
	<body>
  <h1>Congratulations! It worked!</h1>

  This page is being served by <a href="">mini_httpd</a> running under Docker.

  <div id="address">
    <p><strong>12.16.47.9</strong></p>
</div>
	</body>
</html>
```

Congratulations you have a functioning Kubernetes cluster!!!
