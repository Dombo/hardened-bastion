#!/usr/bin/env bash

export DEBIAN_FRONTEND=noninteractive

##############
# Install deps
##############
apt-get update
apt-get install python-pip unzip -y
pip install --upgrade ansible --timeout 10 --retries 12
#####################

set -e
BUCKET_NAME=${bucket_name}
BUCKET_URI="s3://$BUCKET_NAME/${payload_name}"
SSH_USER=${global_ssh_user}
BOOTSTRAP_PAYLOAD_DIR=/home/$SSH_USER/bootstrap_payload_playbook/
PATH=/usr/local/bin:$PATH

# Retrieve the bootstrap payload & unpack it
aws s3 cp $BUCKET_URI $BOOTSTRAP_PAYLOAD_DIR
cd $BOOTSTRAP_PAYLOAD_DIR
unzip ${payload_name}

# Configure the system
ansible-playbook playbook.yml -c local -i hosts -u ubuntu -v