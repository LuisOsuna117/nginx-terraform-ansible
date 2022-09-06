#!/bin/sh
##### Instance ID captured through Instance meta data #####
InstanceID=`/usr/bin/curl -s http://169.254.169.254/latest/meta-data/instance-id`
##### Region captured through Instance meta data #####
InstanceRegion=`/usr/bin/curl -s http://169.254.169.254/latest/meta-data/placement/region`
##### Set a tag name indicating instance is not configured ####
aws ec2 create-tags --region $InstanceRegion --resources $InstanceID --tags Key=Initialized,Value=false Key=Updated,Value=false Key=Installed,Value=false
##### Install Ansible ######
yum update -y
aws ec2 create-tags --region $InstanceRegion --resources $InstanceID --tags Key=Updated,Value=true
yum install git amazon-cloudwatch-agent -y
amazon-linux-extras install ansible2 epel -y
aws ec2 create-tags --region $InstanceRegion --resources $InstanceID --tags Key=Installed,Value=true
##### Clone repository to install nginx ######
git clone https://github.com/LuisOsuna117/nginx-terraform-ansible.git
cd nginx-terraform-ansible
##### RUN ansible playbook #####
ansible-playbook ./ansible/nginx/nginx_install.yml
ansible-playbook ./ansible/cloudwatch/cloudwatch-config.yml
##### Update TAG ######
aws ec2 create-tags --region $InstanceRegion --resources $InstanceID --tags Key=Initialized,Value=true