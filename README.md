# reomor_infra
reomor Infra repository

## HW03
### description
different variants to connect host through basion host

connect to private host through bastion via one console command
```
ssh reomor@10.132.0.3 -o "proxycommand ssh -W %h:%p reomor@35.210.242.212"
```
connect to private via alias e.g. ssh someinternalhost
add config to ~/.ssh/config
```
 Host bastion
    User reomor
    Hostname 35.210.242.212

 Host someinternalhost
    User reomor
    Hostname 10.132.0.3
    ProxyCommand ssh -q -W %h:%p bastion
```
install pritunl-client-electron to use cloud-bastion.ovpn
or
openvpn --config cloud-bastion.ovpn
```
bastion_IP = 35.210.242.212
someinternalhost_IP = 10.132.0.3
```
usage of valid certificate in pritunl panel
```
Setting - Lets Encrypt Domain - 35.210.242.212.sslip.io
```
https://35.210.242.212.sslip.io - pritunl panel with valid certificate

## HW04
### description
create VM instance with deployed application (puma-server) via gcloud

```
testapp_IP=104.199.36.51
testapp_port=9292
```
```
gcloud compute instances create reddit-app \
  --boot-disk-size=10GB \
  --image-family ubuntu-1604-lts \
  --image-project=ubuntu-os-cloud \
  --machine-type=g1-small \
  --tags puma-server \
  --restart-on-failure \
  --metadata-from-file startup-script=startup_script.sh
```
gcloud command to create reddit firewall rule
```
gcloud compute firewall-rules create default-puma-server --allow tcp:9292 \
--target-tags=puma-server --description="Reddit firewall rule added by gcloud compute firewall-rules"
```

## HW05
### description
building VM image with embedded application (puma-server) and VM instance with packer and gcloud
add credentials
```
gcloud auth application-default login
```
useful commands
```
packer validate ./ubuntu16.json
packer build ubuntu16.json
packer build -var-file variables.json ubuntu16.json 
```
## HW06
### description
useful commands
```
terraform init
terraform plan
terraform apply -auto-approve=true
terrafrom show
terraform refresh
terraform output
terraform output app_external_ip
terraform taint google_compute_instance.app
terraform destroy
terraform fmt
```
#### Optional*
add ssh key to project metadata
```
resource "google_compute_project_metadata" "ssh_keys" {
  project = "${var.project}"
  metadata {
    ssh-keys = "appuser1:${file(var.public_key_path)}"
  }
}
```
or
```
resource "google_compute_project_metadata_item" "appuser1" {
  key = "ssh-keys"
  value = "appuser1:${file(var.public_key_path)}"
}

```
add ssh keys to project metadata
```
resource "google_compute_project_metadata" "ssh_keys" {
  project = "${var.project}"
  metadata {
    ssh-keys = "appuser1:${file(var.public_key_path)}\nappuser2:${file(var.public_key_path)}"
  }
}
```
after add new ssh key through GCP web-interface
```
terraform apply
```
deletes all existing ssh-key and inserts only keys in template main.tf
#### Optional**
the problem of such configuration is:
 - each instance needs manual add in cluster
 - each instance has external ip
 - lb starts delay too much

## HW07

[![Build Status](https://api.travis-ci.com/Otus-DevOps-2018-09/reomor_infra.svg?branch=terraform-2)](https://github.com/Otus-DevOps-2018-09/reomor_infra/tree/terraform-2)

### description
using terraform modules and backend to store terraform state in GCP

if terraform controls yout firewall rules - do NOT forget to add default-ssh-allow after 
```
terraform destroy
gcloud compute firewall-rules create default-allow-ssh --allow tcp:22
```
so that parker could get ssh access to VM
import rule to terraform state
```
terraform import google_compute_firewall.firewall_ssh default-allow-ssh
terraform get
```
list of all buckets
```
gsutil ls
```
---
Optional *
if stage and prod have common bucket:
```
provider "google" {
  version = "1.4.0"
  project = "${var.project}"
  region  = "${var.region}"
  zone    = "${var.zone}"
}

resource "google_storage_bucket" "state_bucket" {
  name = "terraform-state-storage-bucket"

  versioning {
    enabled = true
  }

  force_destroy = true

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_storage_bucket_acl" "state_storage_bucket_acl" {
  bucket         = "${google_storage_bucket.state_bucket.name}"
  predefined_acl = "private"
}
```
and the same backend without prefix
```
terraform {
  backend "gcs" {
    bucket = "terraform-state-storage-bucket"
  }
}
```
apply at the same time in stage and prod gives lock:
```
terraform apply
Terraform acquires a state lock to protect the state from being written...
```
but both see the same state
---
Optional **
add provisioner to transfer db server ip address
```
connection {
    type        = "ssh"
    user        = "appuser"
    agent       = false
    private_key = "${file(var.private_key_path)}"
  }

  provisioner "file" {
    source      = "${path.module}/files/puma.service"
    destination = "/tmp/puma.service"
  }

  provisioner "file" {
    source      = "${path.module}/files/deploy.sh"
    destination = "/tmp/deploy.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/deploy.sh",
      "/tmp/deploy.sh ${var.db_internal_ip}"
    ]
  }
```
difference from base deploy.sh is
```
...
sudo mv /tmp/puma.service /etc/systemd/system/puma.service
sudo sed -i "s/Environment=/Environment=DATABASE_URL=$DATABASE_URL/" /etc/systemd/system/puma.service
sudo systemctl start puma
...
```
add provisioner to allow mongod access not only from localhost
```
connection {
    type        = "ssh"
    user        = "appuser"
    agent       = false
    private_key = "${file(var.private_key_path)}"
  }

  provisioner "file" {
    source      = "${path.module}/files/bind.sh"
    destination = "/tmp/bind.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/bind.sh",
      "/tmp/bind.sh"
    ]
  }
```
content of bind.sh is
```
sudo sed -i "s/bindIp: 127.0.0.1/bindIp: 0.0.0.0/" /etc/mongod.conf
sudo service mongod restart
```

## HW08

[![Build Status](https://api.travis-ci.com/Otus-DevOps-2018-09/reomor_infra.svg?branch=ansible-1)](https://github.com/Otus-DevOps-2018-09/reomor_infra/tree/ansible-1)

### description
study ansible base concepts in practice

install pip
```
sudo apt-get install python-setuptools python-dev build-essential
sudo easy_install pip
sudo pip install -r requirments.txt
```
inventory file for ansible ./inventory
```
appserver ansible_host=35.241.231.203 ansible_user=appuser ansible_private_key_file=~/.ssh/appuser
dbserver ansible_host=35.195.244.14 ansible_user=appuser ansible_private_key_file=~/.ssh/appuser
```
ansible check ssh connection
```
ansible appserver -i ./inventory -m ping
```
add ansible.cfg
```
[defaults]
inventory = ./inventory
remote_user = appuser
private_key_file = ~/.ssh/appuser
host_key_checking = False
retry_files_enabled = False
```
check access 
```
ansible dbserver -m command -a uptime
```
groups of hosts in inventory
```
[app]
appserver ansible_host=35.241.231.203
[db]
dbserver ansible_host=35.195.244.14
```
add inventory.yml
```
all:
  children:  
    app:
      hosts:
        appserver:
          ansible_host: 35.241.231.203
    db:
      hosts:
        dbserver:
          ansible_host: 35.195.244.14
```
do command with all
```
ansible all -m ping -i inventory.yml
```
with one
```
ansible app -m ping -i inventory.yml
```
commands execution
```
ansible app -m command -a 'ruby -v' #without command shell
ansible app -m shell -a 'ruby -v; bundler -v'
```
check service is running (three ways)
```bash
ansible db -m command -a 'systemctl status mongod'
ansible db -m systemd -a name=mongod
ansible db -m service -a name=mongod
```
using git module 
```bash
ansible app -m git -a 'repo=https://github.com/express42/reddit.git dest=/home/appuser/reddit'
```
creating playbook
```
```
after 'rm -rf ~/reddit' repository clone and status is changed
```
TASK [Clone repo] ***
changed: [appserver]

PLAY RECAP ***
appserver                  : ok=2    changed=1    unreachable=0    failed=0
```
dynamic hosts - inventory.json
```json
{
    "all": {
        "hosts": [],
        "children": ["appserver", "dbserver"] 
    },
    "appserver": ["35.241.231.203"],
    "dbserver": ["35.195.244.14"]
}
```
get dynamic hosts - dynamic_hosts.sh
```bash
#!/bin/sh
set -e

cat ./inventory.json
```
ansible command for hosts in dynamic inventory
```bash
ansible all -m ping -i ./dynamic_hosts.sh
```

## HW09

[![Build Status](https://api.travis-ci.com/Otus-DevOps-2018-09/reomor_infra.svg?branch=ansible-2)](https://github.com/Otus-DevOps-2018-09/reomor_infra/tree/ansible-2)

### description

```
pip install apache-libcloud
```
playbook for mongo
```
---
- name: Configure hosts and deploy application
  hosts: all
  tasks:
    - name: Change mongo config file
      become: true
      template:
        src: templates/mongod.conf.j2
        dest: /etc/mongod.conf
        mode: 0644
      tags: db-tag

```
parametrized template
```
# Where and how to store data.
storage:
  dbPath: /var/lib/mongodb
  journal:
    enabled: true

# where to write logging data.
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

# network interfaces
net:
  port: {{ mongo_port | default('27017') }}
  bindIp: {{ mongo_bind_ip }}
```
--check - test 
--limit db (group hosts limit)
default inventory is file `inventory`
```
ansible-playbook reddit_app.yml --check --limit db
ansible-playbook reddit_app.yml --check --limit app --tags app-tag
```
deploy application
```
ansible-playbook reddit_app.yml --check --limit app --tags deploy-tag
ansible-playbook reddit_app.yml --limit app --tags deploy-tag
```
one playbook - multiple scenarios
```
---
- name: Mongo configuration
  hosts: db
  tags: db-tag
  become: true
  vars:
    mongo_bind_ip: 0.0.0.0
  tasks:
    - name: Change mongo config file
      template:
        src: templates/mongod.conf.j2
        dest: /etc/mongod.conf
        mode: 0644
      notify: restart mongod

  handlers:
  - name: restart mongod
    service: name=mongod state=restarted

- name: App configuration
  hosts: app
  tags: app-tag
  become: true
  vars:
    mongo_bind_ip: 0.0.0.0
    db_host: 10.132.0.2
  tasks:
    - name: Add unit file for Puma
      become: true
      copy:
        src: files/puma.service
        dest: /etc/systemd/system/puma.service
      tags: app-tag
      notify: restart puma

    - name: Add config for DB connection
      template:
        src: templates/db_config.j2
        dest: /home/appuser/db_config
        owner: appuser
        group: appuser

    - name: Enable puma
      become: true
      systemd: name=puma enabled=yes

  handlers:  
  - name: restart puma
    become: true
    systemd: name=puma state=restarted
```
commands
```
ansible-playbook reddit_app2.yml --tags db-tag --check
ansible-playbook reddit_app2.yml --tags db-tag
ansible-playbook reddit_app2.yml --tags app-tag --check
ansible-playbook reddit_app2.yml --tags app-tag
```
add deploy scenario
```
- name: App deploy
  hosts: app
  tags: deploy-tag
  tasks:
    - name: Fetch the latest version of application code
      git:
        repo: 'https://github.com/express42/reddit.git'
        dest: /home/appuser/reddit
        version: monolith
      notify: restart puma

    - name: Bundle install
      bundler:
        state: present
        chdir: /home/appuser/reddit

  handlers:  
  - name: restart puma
    become: true
    systemd: name=puma state=restarted
```
command
```
ansible-playbook reddit_app2.yml --tags deploy-tag --check
ansible-playbook reddit_app2.yml --tags deploy-tag
```
multiple scenarios in multiple files
```
---
- import_playbook: app.yml
- import_playbook: db.yml
- import_playbook: deploy.yml
```
command
```
ansible-playbook site.yml --check
ansible-playbook site.yml
```
GCE (gce.py and gce.ini)
download from and put in dynamic-inventory dir
```
https://github.com/ansible/ansible/tree/devel/contrib/inventory
```
install pycrypto
```
pip install pycrypto
```
Set the following environment variables before running Ansible in order to configure your credentials:
```
GCE_EMAIL
GCE_PROJECT
GCE_CREDENTIALS_FILE_PATH
```
try (chmod +x before) to get list of all instances
```
./gce.py --list
```
there are gce_tags like ["reddit-db"]
```
ansible -i ./dynamic-inventory/ reddit-db -m ping
```
build packer image from root
```
packer build -var-file packer/variables.json packer/app.json
```

## HW10

[![Build Status](https://api.travis-ci.com/Otus-DevOps-2018-09/reomor_infra.svg?branch=ansible-3)](https://github.com/Otus-DevOps-2018-09/reomor_infra/tree/ansible-3)

### description

create ansible role structure
```
ansible-galaxy init role-name
```
run ansible with roles with dynamic inventory
```
. export_vars.gpe.sh
ansible-playbook site.yml -i ./dynamic-inventory/ --check
ansible-playbook site.yml -i ./dynamic-inventory
```
group_vars directory in playbook-dir or inventory-file allows creating files with vars for groups
```
ansible-playbook playbooks/site.yml --check
ansible-playbook playbooks/site.yml
```

```
ansible-playbook -i environments/prod/inventory playbooks/site.yml --check
```
install nginx
```
ansible-galaxy install -r environments/stage/requirements.yml
```
add vault_password_file in ansible.cfg and encrypt
```
vault_password_key = ~/.ansible/vault.key
ansible-vault encrypt environments/prod/credentials.yml
ansible-vault edit environments/prod/credentials.yml
ansible-vault decrypt environments/prod/credentials.yml
```
add dynamic inventory to environment
```
. export_vars_gpe.sh
ansible-playbook -i environments/stage/dynamic-inventory.sh playbooks/site.yml --check
ansible-playbook -i environments/stage/dynamic-inventory.sh playbooks/site.yml
```
in order to use dynamic inventory with GCP you have to name files in group_var like tag_host-name
i've just done sed from that to host-name
```
./dynamic-inventory/gce.py --list | sed 's/tag_reddit-db/db/g; s/tag_reddit-app/app/g; s/reddit-db/db/g; s/reddit-app/app/g'
```
