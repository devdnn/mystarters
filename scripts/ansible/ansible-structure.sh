#!/bin/bash

# Define the base directory
# Check if an argument is provided for the base directory; if not, use the current directory
baseDir="${1:-$(pwd)}"

echo "Creating directory structure in: ${baseDir}"

# Create directory structure
echo "Creating directory structure..."
mkdir -p ${baseDir}/inventory/{group_vars,host_vars} \
         ${baseDir}/roles/common/{tasks,handlers,defaults,vars} \
         ${baseDir}/playbooks

# Create empty main.yml files for handlers, defaults, and vars in both roles
touch "${baseDir}/roles/common/handlers/main.yml"
touch "${baseDir}/roles/common/defaults/main.yml"
touch "${baseDir}/roles/common/vars/main.yml"

# Create inventory file
echo "[developers]" > "${baseDir}/inventory/hosts"
echo "developer01 ansible_host=192.168.1.100" >> "${baseDir}/inventory/hosts"

# Create group_vars and host_vars
echo "ansible_user: dnndev" > "${baseDir}/inventory/group_vars/developers.yml"
echo "ansible_ssh_private_key_file: ~/.ssh/id_rsa" > "${baseDir}/inventory/host_vars/developer01.yml"

# Common role tasks creation
cat <<EOF > "${baseDir}/roles/common/tasks/main.yml"
- name: Update and upgrade apt packages
  ansible.builtin.apt:
    update_cache: yes
    upgrade: dist
EOF

# Playbooks creation
cat <<EOF > "${baseDir}/playbooks/setup_common.yml"
- name: Setup Common System Components
  hosts: all
  become: yes

  roles:
    - common
EOF

# ansible.cfg creation
cat <<EOF > "${baseDir}/ansible.cfg"
[defaults]
nocows = True
roles_path = ./roles:/etc/ansible/roles
inventory = inventory/hosts
log_path=./log/ansible.log
remote_user = dnndev
stdout_callback = yaml
bin_ansible_callbacks = True

[privilege_escalation]
become=True
EOF

echo "Ansible directory structure and basic files created in the current location."
