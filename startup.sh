#!/bin/sh
##### Instance ID captured through Instance meta data #####
InstanceID=`curl -s http://169.254.169.254/latest/meta-data/instance-id`
##### Region captured through Instance meta data #####
InstanceRegion=`http://169.254.169.254/latest/meta-data/placement/region`
##### Set a tag name indicating instance is not configured ####
aws ec2 create-tags --region $InstanceRegion --resources $InstanceID --tags Key=Initialized,Value=false
##### Install Ansible ######
yum update -y
yum install git amazon-cloudwatch-agent -y
amazon-linux-extras install ansible2 epel -y
##### Clone repository to install nginx ######
git clone https://github.com/LuisOsuna117/nginx-terraform-ansible.git
cd nginx-terraform-ansible
##### RUN ansible playbook #####
ansible-playbook ./ansible/nginx/nginx_install.yml
##### Update TAG ######
aws ec2 create-tags --region $InstanceRegion --resources $InstanceID --tags Key=Initialized,Value=true