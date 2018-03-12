#!/usr/bin/env bash

export DEBIAN_FRONTEND=noninteractive

##############
# Install deps
##############
apt-get update
apt-get install python-pip jq -y
pip install --upgrade pip --timeout 10 --retries 12
pip install --upgrade awscli --timeout 10 --retries 12
#####################

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

aws ec2 associate-address --region ${region} --instance-id $INSTANCE_ID --allocation-id ${ip_id} --allow-reassociation