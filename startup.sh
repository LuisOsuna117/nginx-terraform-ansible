#!/bin/sh
##### Install Ansible ######
yum update -y
yum install git amazon-cloudwatch-agent -y
amazon-linux-extras install ansible2 epel -y
##### Clone repository to install nginx ######
git clone https://github.com/LuisOsuna117/nginx-terraform-ansible.git
cd nginx-terraform-ansible
##### RUN ansible playbook #####
ansible-playbook ./ansible/nginx/nginx_install.yml
ansible-playbook ./ansible/cloudwatch/cloudwatch-config.yml